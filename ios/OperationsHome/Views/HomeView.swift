import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @State private var families: [FamilyDTO] = []
    @State private var newFamilyName = ""
    @State private var errorMessage = ""
    @State private var isLoadingFamilies = false
    @State private var didLoadFamilies = false
    @State private var selectedTab: HomeTab = .spaces
    @Namespace private var tabAnimation

    var body: some View {
        Group {
            if isLoadingFamilies && !didLoadFamilies {
                LoadingFamiliesView()
            } else if didLoadFamilies && families.isEmpty {
                CreateFamilyView(
                    familyName: $newFamilyName,
                    message: errorMessage,
                    isLoading: isLoadingFamilies,
                    onCreate: { Task { await createFamily() } },
                    onRefresh: { Task { await loadFamilies() } }
                )
            } else {
                ZStack {
                    OnboardingBackground()

                    VStack(spacing: 0) {
                        familyBar

                        Group {
                            switch selectedTab {
                            case .spaces:
                                SpacesView(session: session, sync: sync, familyName: selectedFamilyName)
                            case .reminders:
                                RemindersView(session: session, sync: sync)
                            case .profile:
                                ProfileView(session: session)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    GlassTabBar(selection: $selectedTab, namespace: tabAnimation)
                        .padding(.horizontal, 26)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
            }
        }
        .task { await loadFamilies() }
    }

    private var selectedFamilyName: String {
        guard let selectedFamilyId = session.selectedFamilyId,
              let family = families.first(where: { $0.id == selectedFamilyId }) else {
            return families.first?.name ?? "我的家庭"
        }
        return family.name
    }

    private var familyBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("家庭空间")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("家庭", selection: Binding(
                        get: { session.selectedFamilyId ?? families.first?.id ?? 0 },
                        set: { session.selectedFamilyId = $0 == 0 ? nil : $0 }
                    )) {
                        ForEach(families) { family in
                            Text(family.name).tag(family.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(red: 0.16, green: 0.18, blue: 0.16))
                }

                Spacer()

                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: sync.isSyncing ? "arrow.triangle.2.circlepath.circle" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.76), in: Circle())
                }
                .accessibilityLabel("刷新")
            }

            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            if let lastError = sync.lastError {
                Text(lastError).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func loadFamilies() async {
        guard let token = session.token else { return }
        isLoadingFamilies = true
        defer {
            isLoadingFamilies = false
            didLoadFamilies = true
        }

        do {
            families = try await APIClient(token: token).families()
            if let selectedFamilyId = session.selectedFamilyId,
               !families.contains(where: { $0.id == selectedFamilyId }) {
                session.selectedFamilyId = families.first?.id
            } else if session.selectedFamilyId == nil {
                session.selectedFamilyId = families.first?.id
            }
            errorMessage = ""
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createFamily() async {
        guard let token = session.token else { return }
        do {
            let family = try await APIClient(token: token).createFamily(name: newFamilyName)
            families.append(family)
            session.selectedFamilyId = family.id
            newFamilyName = ""
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refresh() async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        await sync.pull(familyId: familyId, token: token, context: context)
    }
}

private enum HomeTab: String, CaseIterable, Identifiable {
    case spaces
    case reminders
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spaces: "空间"
        case .reminders: "提醒"
        case .profile: "个人中心"
        }
    }

    var icon: String {
        switch self {
        case .spaces: "cabinet"
        case .reminders: "bell"
        case .profile: "person.crop.circle"
        }
    }
}

private struct GlassTabBar: View {
    @Binding var selection: HomeTab
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? Color(red: 0.20, green: 0.32, blue: 0.25) : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        if selection == tab {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.84))
                                .matchedGeometryEffect(id: "selectedTab", in: namespace)
                                .shadow(color: Color(red: 0.34, green: 0.45, blue: 0.34).opacity(0.18), radius: 14, y: 8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.34))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 24, y: 12)
        )
    }
}

private struct LoadingFamiliesView: View {
    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                Text("正在整理你的家庭空间")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CreateFamilyView: View {
    @Binding var familyName: String
    var message: String
    var isLoading: Bool
    var onCreate: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 18) {
                        FamilyIllustration()
                            .padding(.top, 10)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("创建你的家庭空间")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                            Text("给家起个名字，后面就能邀请成员一起管理柜子、物品和提醒。")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                    }

                    VStack(spacing: 14) {
                        OnboardingTextField(
                            title: "家庭名称",
                            placeholder: "例如：小佳的家",
                            text: $familyName,
                            systemImage: "house"
                        )

                        Button {
                            onCreate()
                        } label: {
                            Label(isLoading ? "正在创建" : "创建家庭", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                        }
                        .buttonStyle(PrimaryOnboardingButtonStyle())
                        .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                        Button {
                            onRefresh()
                        } label: {
                            Label("刷新家庭列表", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(SoftSecondaryButtonStyle())
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct FamilyIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.70))
                .frame(height: 190)
                .shadow(color: Color(red: 0.65, green: 0.45, blue: 0.25).opacity(0.12), radius: 26, y: 16)

            VStack(spacing: 0) {
                Image(systemName: "house.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color(red: 0.32, green: 0.45, blue: 0.36))
                    .frame(width: 82, height: 82)
                    .background(Color(red: 0.86, green: 0.92, blue: 0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.99, green: 0.79, blue: 0.48))
                        .frame(width: 72, height: 54)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.73, green: 0.83, blue: 0.70))
                        .frame(width: 96, height: 68)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.63, blue: 0.54))
                        .frame(width: 72, height: 54)
                }
                .offset(y: -2)
            }
        }
    }
}
