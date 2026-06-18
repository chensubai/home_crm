import SwiftData
import SwiftUI

struct SpacesView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    var familyName: String

    @Query private var allSpaces: [SpaceRecord]
    @Query private var allItems: [ItemRecord]
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var message = ""

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var spaces: [SpaceRecord] {
        allSpaces
            .filter { $0.familyId == session.selectedFamilyId && $0.deletedAt == nil }
            .sorted { $0.name < $1.name }
    }

    private var visibleSpaces: [SpaceRecord] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return spaces }

        let matchedSpaceIds = Set(itemsMatching(keyword).compactMap(\.spaceId))
        return spaces.filter { matchedSpaceIds.contains($0.remoteId) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SearchField(text: $searchText, placeholder: "搜索物品")

                    if spaces.isEmpty {
                        EmptyStateView(
                            systemImage: "cabinet",
                            title: "还没有储物空间",
                            subtitle: "先添加一个柜子、抽屉或收纳箱，再开始管理物品。"
                        )
                    } else if visibleSpaces.isEmpty {
                        EmptyStateView(
                            systemImage: "magnifyingglass",
                            title: "没有找到相关空间",
                            subtitle: "换个关键词试试，或在对应空间里新增这个物品。"
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(visibleSpaces) { space in
                                NavigationLink {
                                    ItemsView(session: session, sync: sync, spaceFilter: space)
                                } label: {
                                    SpaceCardView(
                                        space: space,
                                        itemTypeCount: itemTypeCount(for: space)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(familyName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加空间")
                }
            }
            .sheet(isPresented: $isAdding) {
                SpaceFormView(session: session, sync: sync)
            }
        }
    }

    private func itemsMatching(_ keyword: String) -> [ItemRecord] {
        allItems.filter { item in
            item.familyId == session.selectedFamilyId
                && item.deletedAt == nil
                && (
                    item.name.localizedStandardContains(keyword)
                    || (item.category?.localizedStandardContains(keyword) ?? false)
                    || (item.barcode?.localizedStandardContains(keyword) ?? false)
                )
        }
    }

    private func itemTypeCount(for space: SpaceRecord) -> Int {
        allItems.filter {
            $0.familyId == session.selectedFamilyId
                && $0.deletedAt == nil
                && $0.spaceId == space.remoteId
        }.count
    }
}

private struct SearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SpaceCardView: View {
    var space: SpaceRecord
    var itemTypeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            coverImage
            .frame(height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(space.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(locationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(itemTypeCount) 类物品")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var locationText: String {
        let detail = space.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return detail.isEmpty ? "未设置位置" : detail
    }

    private var cardColor: Color {
        let colors: [Color] = [.brown, .mint, .indigo, .orange, .teal, .purple]
        return colors[abs(space.remoteId) % colors.count]
    }

    @ViewBuilder
    private var coverImage: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.tertiarySystemGroupedBackground))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var imageURL: URL? {
        guard let imageUrl = space.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !imageUrl.isEmpty else {
            return nil
        }

        return URL(string: imageUrl)
    }

    private var placeholderImage: some View {
        ZStack {
            cardColor
            Image(systemName: "cabinet.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

private struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 86, height: 86)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}

private struct SpaceFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @State private var name = ""
    @State private var detail = ""
    @State private var nfcUid = ""
    @State private var imageData: Data?
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("例如：客厅柜子", text: $name)
                    TextField("位置，例如：客厅", text: $detail)
                    TextField("NFC UID（可选）", text: $nfcUid)
                }

                Section("空间图片") {
                    ImageInputView(imageData: $imageData)
                }

                if !message.isEmpty {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加空间")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await addSpace() } }
                        .disabled(name.isEmpty || session.selectedFamilyId == nil)
                }
            }
        }
    }

    private func addSpace() async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        do {
            let dto = try await APIClient(token: token).createSpace(
                familyId: familyId,
                name: name,
                description: detail.isEmpty ? nil : detail,
                nfcUid: nfcUid.isEmpty ? nil : nfcUid,
                imageData: imageData
            )
            context.insert(SpaceRecord(
                remoteId: dto.id,
                familyId: dto.familyId,
                name: dto.name,
                detail: dto.description,
                nfcUid: nfcUid.isEmpty ? nil : nfcUid,
                imageKey: dto.imageKey,
                imageUrl: dto.imageUrl,
                imageHash: dto.imageHash
            ))
            try? context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
