import SwiftData
import SwiftUI

struct ItemsView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @Query private var allItems: [ItemRecord]
    @Query private var allSpaces: [SpaceRecord]
    @State private var isAdding = false
    @State private var message = ""
    var spaceFilter: SpaceRecord?

    private var items: [ItemRecord] {
        allItems
            .filter {
                $0.familyId == session.selectedFamilyId
                    && $0.deletedAt == nil
                    && (spaceFilter == nil || $0.spaceId == spaceFilter?.remoteId)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var spacesById: [Int: SpaceRecord] {
        Dictionary(uniqueKeysWithValues: allSpaces.map { ($0.remoteId, $0) })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text(quantityText(for: item))
                                .font(.subheadline.monospacedDigit())
                        }
                        HStack {
                            Text(item.category ?? "未分类")
                            Text(item.status.title)
                            if let expiresAt = item.expiresAt {
                                Text(expiresAt, style: .date)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let spaceId = item.spaceId, let space = spacesById[spaceId] {
                            Text(space.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button {
                                Task { await adjust(item, delta: -1) }
                            } label: {
                                Label("减少", systemImage: "minus")
                            }
                            .buttonStyle(.bordered)
                            .disabled(item.quantity == 0)

                            Button {
                                Task { await adjust(item, delta: 1) }
                            } label: {
                                Label("增加", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
            .navigationTitle(spaceFilter?.name ?? "物品")
            .toolbar {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $isAdding) {
                ItemFormView(session: session, sync: sync, initialSpaceId: spaceFilter?.remoteId)
            }
        }
    }

    private func quantityText(for item: ItemRecord) -> String {
        let unit = item.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return unit.isEmpty ? "数量 \(item.quantity)" : "数量 \(item.quantity) \(unit)"
    }

    private func adjust(_ item: ItemRecord, delta: Int) async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        let previousQuantity = item.quantity
        item.quantity = max(0, previousQuantity + delta)

        do {
            let dto = try await APIClient(token: token).adjustItem(id: item.remoteId, delta: delta, reason: "iOS 快捷调整")
            item.familyId = dto.familyId
            item.spaceId = dto.spaceId
            item.name = dto.name
            item.category = dto.category
            item.quantity = dto.quantity
            item.unit = dto.unit
            item.barcode = dto.barcode
            item.expiresAt = dto.expiresAt
            item.statusRaw = dto.status
            item.notes = dto.notes
            item.updatedAt = dto.updatedAt ?? .now
            item.deletedAt = dto.deletedAt
            try? context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
        } catch {
            item.quantity = previousQuantity
            try? context.save()
            message = error.localizedDescription
        }
    }
}

struct ItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @Query private var allSpaces: [SpaceRecord]
    @State private var name = ""
    @State private var category = ""
    @State private var quantity = 1
    @State private var unit = ""
    @State private var barcode = ""
    @State private var status = ItemStatus.idle
    @State private var showingScanner = false
    @State private var message = ""
    var initialSpaceId: Int?

    private var spaces: [SpaceRecord] {
        allSpaces.filter { $0.familyId == session.selectedFamilyId && $0.deletedAt == nil }
    }

    @State private var selectedSpaceId: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("物品名称", text: $name)
                    Picker("存放位置", selection: $selectedSpaceId) {
                        ForEach(spaces) { space in
                            Text(space.name).tag(Optional(space.remoteId))
                        }
                    }
                    TextField("分类", text: $category)
                    Picker("状态", selection: $status) {
                        ForEach(ItemStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section("库存") {
                    Stepper("数量 \(quantity)", value: $quantity, in: 0...9999)
                    TextField("单位，例如：个、包、瓶", text: $unit)
                }

                Section("条码") {
                    HStack {
                        TextField("条码/二维码", text: $barcode)
                        Button {
                            showingScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }

                if !message.isEmpty {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(name.isEmpty || session.selectedFamilyId == nil || selectedSpaceId == nil)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { code in
                    barcode = code
                    showingScanner = false
                }
            }
        }
        .onAppear {
            if selectedSpaceId == nil {
                selectedSpaceId = initialSpaceId ?? spaces.first?.remoteId
            }
        }
    }

    private func save() async {
        guard let token = session.token, let familyId = session.selectedFamilyId, let selectedSpaceId else { return }
        var payload: [String: EncodableValue] = [
            "family_id": .int(familyId),
            "space_id": .int(selectedSpaceId),
            "name": .string(name),
            "quantity": .int(quantity),
            "status": .string(status.rawValue)
        ]
        if !category.isEmpty { payload["category"] = .string(category) }
        if !unit.isEmpty { payload["unit"] = .string(unit) }
        if !barcode.isEmpty { payload["barcode"] = .string(barcode) }

        do {
            let dto = try await APIClient(token: token).createItem(payload)
            let item = ItemRecord(
                remoteId: dto.id,
                familyId: dto.familyId,
                spaceId: dto.spaceId,
                name: dto.name,
                category: dto.category,
                quantity: dto.quantity,
                unit: dto.unit,
                barcode: dto.barcode,
                expiresAt: dto.expiresAt,
                status: ItemStatus(rawValue: dto.status) ?? .idle,
                notes: dto.notes,
                updatedAt: dto.updatedAt ?? .now,
                deletedAt: dto.deletedAt
            )
            context.insert(item)
            try? context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
