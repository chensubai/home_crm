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
    @State private var editingItem: ItemRecord?
    @State private var deletingItem: ItemRecord?
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
                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ForEach(items) { item in
                    itemRow(item)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("删除物品", role: .destructive) {
                                deletingItem = item
                            }
                        }
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
            .sheet(item: $editingItem) { item in
                ItemFormView(session: session, sync: sync, item: item)
            }
            .alert(
                "删除物品",
                isPresented: Binding(
                    get: { deletingItem != nil },
                    set: { if !$0 { deletingItem = nil } }
                ),
                presenting: deletingItem
            ) { item in
                Button("删除", role: .destructive) {
                    Task { await delete(item) }
                }
                Button("取消", role: .cancel) {}
            } message: { item in
                Text("确定删除“\(item.name)”吗？此操作无法恢复。")
            }
        }
    }

    private func itemRow(_ item: ItemRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                editingItem = item
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    itemImage(item)

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
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑物品 \(item.name)")

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

    private func itemImage(_ item: ItemRecord) -> some View {
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
            apply(dto, to: item)
            try context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            message = ""
        } catch {
            item.quantity = previousQuantity
            try? context.save()
            message = error.localizedDescription
        }
    }

    private func delete(_ item: ItemRecord) async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        defer { deletingItem = nil }

        do {
            try await APIClient(token: token).deleteItem(id: item.remoteId)
            item.deletedAt = .now
            try context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            message = ""
        } catch {
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
    var initialSpaceId: Int?
    var item: ItemRecord?
    @State private var name: String
    @State private var category: String
    @State private var quantity: Int
    @State private var unit: String
    @State private var barcode: String
    @State private var status: ItemStatus
    @State private var selectedSpaceId: Int?
    @State private var hasExpiry: Bool
    @State private var expiresAt: Date
    @State private var notes: String
    @State private var showingScanner = false
    @State private var imageData: Data?
    @State private var message = ""

    init(session: SessionStore, sync: SyncEngine, initialSpaceId: Int? = nil, item: ItemRecord? = nil) {
        self._session = ObservedObject(wrappedValue: session)
        self._sync = ObservedObject(wrappedValue: sync)
        self.initialSpaceId = initialSpaceId
        self.item = item
        self._name = State(initialValue: item?.name ?? "")
        self._category = State(initialValue: item?.category ?? "")
        self._quantity = State(initialValue: item?.quantity ?? 1)
        self._unit = State(initialValue: item?.unit ?? "")
        self._barcode = State(initialValue: item?.barcode ?? "")
        self._status = State(initialValue: item?.status ?? .idle)
        self._selectedSpaceId = State(initialValue: item?.spaceId ?? initialSpaceId)
        self._hasExpiry = State(initialValue: item?.expiresAt != nil)
        self._expiresAt = State(initialValue: item?.expiresAt ?? .now)
        self._notes = State(initialValue: item?.notes ?? "")
    }

    private var spaces: [SpaceRecord] {
        allSpaces.filter { $0.familyId == session.selectedFamilyId && $0.deletedAt == nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormHeaderView(
                            title: item == nil ? "添加物品" : "编辑物品",
                            subtitle: item == nil ? "补充物品信息、位置和图片，之后就能快速查找。" : "修改物品信息、库存、存放位置或图片。",
                            systemImage: "shippingbox"
                        )

                        VStack(spacing: 12) {
                            OnboardingTextField(title: "物品名称", placeholder: "例如：抽纸", text: $name, systemImage: "tag")
                            GlassSection(title: "存放与状态") {
                                Picker("存放位置", selection: $selectedSpaceId) {
                                    ForEach(spaces) { space in
                                        Text(space.name).tag(Optional(space.remoteId))
                                    }
                                }
                                Picker("状态", selection: $status) {
                                    ForEach(ItemStatus.allCases) { status in
                                        Text(status.title).tag(status)
                                    }
                                }
                            }
                            OnboardingTextField(title: "分类", placeholder: "例如：日用品", text: $category, systemImage: "folder")
                        }

                        GlassSection(title: "库存") {
                            Stepper("数量 \(quantity)", value: $quantity, in: 0...9999)
                                .font(.headline.weight(.semibold))
                            OnboardingTextField(title: "单位", placeholder: "例如：个、包、瓶", text: $unit, systemImage: "number")
                        }

                        GlassSection(title: "保质期与备注") {
                            Toggle("设置保质期", isOn: $hasExpiry)
                            if hasExpiry {
                                DatePicker("保质期", selection: $expiresAt, displayedComponents: .date)
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                            }
                            OnboardingTextField(title: "备注", placeholder: "可选", text: $notes, systemImage: "note.text")
                        }

                        GlassSection(title: "条码") {
                            HStack(spacing: 10) {
                                OnboardingTextField(title: "条码/二维码", placeholder: "扫码或手动输入", text: $barcode, systemImage: "barcode")
                                Button {
                                    showingScanner = true
                                } label: {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                                        .frame(width: 52, height: 52)
                                }
                                .buttonStyle(SoftSecondaryButtonStyle())
                            }
                        }

                        GlassSection(title: "物品图片") {
                            ImageInputView(imageData: $imageData, existingImageURL: existingImageURL)
                        }

                        if !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.selectedFamilyId == nil || selectedSpaceId == nil)
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

    private var existingImageURL: URL? {
        guard let value = item?.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return URL(string: value)
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
        payload["category"] = category.isEmpty ? .null : .string(category)
        payload["unit"] = unit.isEmpty ? .null : .string(unit)
        payload["barcode"] = barcode.isEmpty ? .null : .string(barcode)
        payload["expires_at"] = hasExpiry ? .date(expiresAt) : .null
        payload["notes"] = notes.isEmpty ? .null : .string(notes)

        do {
            let client = APIClient(token: token)
            if let item {
                let dto = try await client.updateItem(id: item.remoteId, payload: payload, imageData: imageData)
                apply(dto, to: item)
            } else {
                let dto = try await client.createItem(payload, imageData: imageData)
                context.insert(makeItem(from: dto))
            }
            try context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

private func makeItem(from dto: ItemDTO) -> ItemRecord {
    ItemRecord(
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
}

private func apply(_ dto: ItemDTO, to item: ItemRecord) {
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
}
