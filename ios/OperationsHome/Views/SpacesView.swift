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
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("今天想找什么？")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                                Text("搜索物品后，会展示包含它的储物空间。")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                isAdding = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                                    .frame(width: 42, height: 42)
                                    .background(Color.white.opacity(0.86), in: Circle())
                                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 8)
                            }
                            .accessibilityLabel("添加空间")
                        }

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
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
        .frame(height: 48)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 10)
    }
}

private struct SpaceCardView: View {
    var space: SpaceRecord
    var itemTypeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            coverImage
            .frame(height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(space.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(locationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(itemTypeCount) 类物品")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.30, green: 0.48, blue: 0.36))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
    }

    private var locationText: String {
        let detail = space.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return detail.isEmpty ? "未设置位置" : detail
    }

    private var cardColor: Color {
        let colors: [Color] = [
            Color(red: 0.76, green: 0.57, blue: 0.42),
            Color(red: 0.50, green: 0.66, blue: 0.55),
            Color(red: 0.89, green: 0.68, blue: 0.44),
            Color(red: 0.71, green: 0.57, blue: 0.78),
            Color(red: 0.43, green: 0.63, blue: 0.68)
        ]
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
            LinearGradient(
                colors: [cardColor.opacity(0.85), cardColor.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                .foregroundStyle(Color(red: 0.32, green: 0.45, blue: 0.36))
                .frame(width: 86, height: 86)
                .background(Color.white.opacity(0.78), in: Circle())
            Text(title)
                .font(.headline.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct FormHeaderView: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                .frame(width: 58, height: 58)
                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct GlassSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            content
        }
        .padding(14)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, y: 10)
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
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormHeaderView(
                            title: "添加空间",
                            subtitle: "记录柜子、抽屉或收纳箱，让物品有清楚的位置。",
                            systemImage: "cabinet"
                        )

                        VStack(spacing: 12) {
                            OnboardingTextField(title: "空间名称", placeholder: "例如：客厅柜子", text: $name, systemImage: "square.grid.2x2")
                            OnboardingTextField(title: "位置", placeholder: "例如：客厅", text: $detail, systemImage: "location")
                            OnboardingTextField(title: "NFC UID", placeholder: "可选", text: $nfcUid, systemImage: "wave.3.right")
                        }

                        GlassSection(title: "空间图片") {
                            ImageInputView(imageData: $imageData)
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
