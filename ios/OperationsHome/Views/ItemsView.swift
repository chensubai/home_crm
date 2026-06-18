import SwiftData
import SwiftUI

struct ItemsView: View {
    @Environment(\.dismiss) private var dismiss
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
                    itemRow(item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }
            .navigationTitle(spaceFilter?.name ?? "物品")
            .navigationBarBackButtonHidden(spaceFilter != nil)
            .toolbar {
                if spaceFilter != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("返回")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加物品")
                }
            }
            .sheet(isPresented: $isAdding) {
                ItemFormView(session: session, sync: sync, initialSpaceId: spaceFilter?.remoteId)
            }
        }
    }

    private func itemRow(_ item: ItemRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color(.secondarySystemGroupedBackground)
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Color(.secondarySystemGroupedBackground)
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.category ?? "未分类")
                        if let expiresAt = item.expiresAt {
                            Text("·")
                            Text(expiresAt, style: .date)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let spaceId = item.spaceId, let space = spacesById[spaceId] {
                        Text(space.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    statusBadge(item.status)
                    Text(quantityText(for: item))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .lineLimit(1)
                }
            }

            HStack {
                Spacer()
                Button {
                    Task { await adjust(item, delta: -1) }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(item.quantity == 0)
                .accessibilityLabel("减少数量")

                Button {
                    Task { await adjust(item, delta: 1) }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("增加数量")
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: ItemStatus) -> some View {
        Text(status.title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status == .expired ? .red : .secondary)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
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
            item.imageKey = dto.imageKey
            item.imageUrl = dto.imageUrl
            item.imageHash = dto.imageHash
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
    @State private var imageData: Data?
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

                Section("物品图片") {
                    ImageInputView(imageData: $imageData)
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
            let dto = try await APIClient(token: token).createItem(payload, imageData: imageData)
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
                imageKey: dto.imageKey,
                imageUrl: dto.imageUrl,
                imageHash: dto.imageHash,
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
