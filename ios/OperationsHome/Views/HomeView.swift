import SwiftData
import SwiftUI

enum HomeFamilyPhase: Equatable {
    case loading
    case failed
    case create
    case content
}

func homeFamilyPhase(isLoading: Bool, didLoadSuccessfully: Bool, familyCount: Int) -> HomeFamilyPhase {
    if didLoadSuccessfully {
        return familyCount == 0 ? .create : .content
    }
    return isLoading ? .loading : .failed
}

func inviteCodeForSubmission(_ value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    guard normalized.count == 8,
          normalized.unicodeScalars.allSatisfy(allowed.contains) else {
        return nil
    }
    return normalized
}

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @ObservedObject var router: NFCDeepLinkRouter
    @State private var families: [FamilyDTO] = []
    @State private var newFamilyName = ""
    @State private var inviteCode = ""
    @State private var errorMessage = ""
    @State private var isLoadingFamilies = true
    @State private var isCreatingFamily = false
    @State private var isJoiningFamily = false
    @State private var didLoadFamiliesSuccessfully = false
    @State private var selectedTab: HomeTab = .spaces
    @State private var requestedSpaceId: Int?
    @State private var nfcAlertOffersRetry = false
    @Namespace private var tabAnimation

    var body: some View {
        Group {
            switch homeFamilyPhase(
                isLoading: isLoadingFamilies,
                didLoadSuccessfully: didLoadFamiliesSuccessfully,
                familyCount: families.count
            ) {
            case .loading:
                LoadingFamiliesView()
            case .failed:
                FamilyLoadFailureView(
                    message: errorMessage,
                    onRetry: { Task { await loadFamilies() } },
                    onLogout: { session.token = nil }
                )
            case .create:
                CreateFamilyView(
                    familyName: $newFamilyName,
                    inviteCode: $inviteCode,
                    message: errorMessage,
                    isLoading: isLoadingFamilies,
                    isCreating: isCreatingFamily,
                    isJoining: isJoiningFamily,
                    onCreate: { Task { await createFamily() } },
                    onJoin: { Task { await joinFamily() } },
                    onRefresh: { Task { await loadFamilies() } }
                )
            case .content:
                ZStack {
                    OnboardingBackground()

                    VStack(spacing: 0) {
                        familyBar

                        Group {
                            switch selectedTab {
                            case .spaces:
                                SpacesView(
                                    session: session,
                                    sync: sync,
                                    familyName: selectedFamilyName,
                                    requestedSpaceId: $requestedSpaceId
                                )
                            case .reminders:
                                RemindersView(session: session, sync: sync)
                            case .profile:
                                ProfileView(
                                    session: session,
                                    family: selectedFamily,
                                    onFamilyUpdated: { await loadFamilies() }
                                )
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
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .task(id: router.pendingToken) {
            if !didLoadFamiliesSuccessfully {
                await loadFamilies()
            }
            await resolvePendingNfcLink()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, didLoadFamiliesSuccessfully else { return }
            Task { await loadFamilies() }
        }
        .alert(
            "NFC 贴纸",
            isPresented: Binding(
                get: { router.message != nil },
                set: { isPresented in
                    if !isPresented {
                        router.message = nil
                        nfcAlertOffersRetry = false
                    }
                }
            )
        ) {
            if nfcAlertOffersRetry {
                Button("重试") {
                    router.message = nil
                    Task { await resolvePendingNfcLink() }
                }
                Button("稍后", role: .cancel) {
                    router.message = nil
                }
            } else {
                Button("知道了") {
                    router.message = nil
                }
            }
        } message: {
            Text(router.message ?? "")
        }
    }

    private var selectedFamilyName: String {
        guard let selectedFamilyId = session.selectedFamilyId,
              let family = families.first(where: { $0.id == selectedFamilyId }) else {
            return families.first?.name ?? "我的家庭"
        }
        return family.name
    }

    private var selectedFamily: FamilyDTO? {
        guard let selectedFamilyId = session.selectedFamilyId else { return families.first }
        return families.first(where: { $0.id == selectedFamilyId })
    }

    private var familyBar: some View {
        VStack(spacing: 8) {
            ZStack {
                Menu {
                    ForEach(families) { family in
                        Button(family.name) {
                            session.selectedFamilyId = family.id
                            Task { await refresh() }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(selectedFamilyName)
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 48)
                .accessibilityLabel("切换家庭")

                HStack {
                    Spacer()
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: sync.isSyncing ? "arrow.triangle.2.circlepath.circle" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                            .frame(width: 38, height: 38)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel("刷新")
                }
            }
            .frame(height: 44)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
            }

            if let lastError = sync.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func loadFamilies() async {
        guard let token = session.token else {
            isLoadingFamilies = false
            errorMessage = "登录状态已失效，请重新登录"
            return
        }
        isLoadingFamilies = true
        defer { isLoadingFamilies = false }

        do {
            try await reloadFamilies(token: token)
            errorMessage = ""
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createFamily() async {
        guard let token = session.token else { return }
        isCreatingFamily = true
        defer { isCreatingFamily = false }

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

    private func joinFamily() async {
        guard let token = session.token,
              let code = inviteCodeForSubmission(inviteCode) else {
            return
        }
        isJoiningFamily = true
        defer { isJoiningFamily = false }

        do {
            let family = try await APIClient(token: token).acceptInvite(code: code)
            families = [family]
            session.selectedFamilyId = family.id
            inviteCode = ""
            errorMessage = ""
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refresh() async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        await sync.pull(familyId: familyId, token: token, context: context)
    }

    private func reloadFamilies(token: String) async throws {
        families = try await APIClient(token: token).families()
        didLoadFamiliesSuccessfully = true
        if let selectedFamilyId = session.selectedFamilyId,
           !families.contains(where: { $0.id == selectedFamilyId }) {
            session.selectedFamilyId = families.first?.id
        } else if session.selectedFamilyId == nil {
            session.selectedFamilyId = families.first?.id
        }
    }

    private func resolvePendingNfcLink() async {
        guard let token = session.token,
              let pendingToken = router.pendingToken else {
            return
        }

        router.message = nil
        nfcAlertOffersRetry = false

        do {
            try await continuePendingNfcLink(
                router: router,
                authenticationToken: token,
                families: families,
                resolve: { pendingToken, authenticationToken in
                    try await APIClient(token: authenticationToken)
                        .resolveNfcToken(pendingToken)
                },
                reloadFamilies: { authenticationToken in
                    try await APIClient(token: authenticationToken).families()
                },
                updateFamilies: { refreshedFamilies in
                    families = refreshedFamilies
                    didLoadFamiliesSuccessfully = true
                },
                sync: { familyId, authenticationToken in
                    await sync.pull(
                        familyId: familyId,
                        token: authenticationToken,
                        context: context
                    )
                },
                targetIsReady: { spaceId, familyId in
                    isActiveSpaceAvailable(id: spaceId, familyId: familyId)
                },
                navigate: { navigation in
                    session.selectedFamilyId = navigation.familyId
                    selectedTab = .spaces
                    requestedSpaceId = navigation.spaceId
                }
            )
        } catch {
            guard isCurrentNfcResolution(
                resolvingToken: pendingToken,
                pendingToken: router.pendingToken,
                isCancelled: Task.isCancelled
            ) else {
                return
            }
            let failure = nfcResolutionFailureDecision(for: error)
            if failure.requiresAuthentication {
                router.message = nil
                nfcAlertOffersRetry = false
                session.token = nil
                return
            }
            router.message = failure.message
            nfcAlertOffersRetry = failure.offersRetry
            if failure.consumesToken {
                router.consumePendingToken()
            }
        }
    }

    private func isActiveSpaceAvailable(id: Int, familyId: Int) -> Bool {
        let descriptor = FetchDescriptor<SpaceRecord>(
            predicate: #Predicate { $0.remoteId == id }
        )
        guard let space = try? context.fetch(descriptor).first else {
            return false
        }
        return space.familyId == familyId && space.deletedAt == nil
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

private struct FamilyLoadFailureView: View {
    var message: String
    var onRetry: () -> Void
    var onLogout: () -> Void

    var body: some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 18) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color(red: 0.32, green: 0.45, blue: 0.36))
                Text("家庭信息加载失败")
                    .font(.title3.bold())
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    onRetry()
                } label: {
                    Label("重新加载", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(PrimaryOnboardingButtonStyle())
                .frame(maxWidth: 260)

                Button("重新登录", action: onLogout)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }
}

private struct CreateFamilyView: View {
    @Binding var familyName: String
    @Binding var inviteCode: String
    var message: String
    var isLoading: Bool
    var isCreating: Bool
    var isJoining: Bool
    var onCreate: () -> Void
    var onJoin: () -> Void
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
                            Text("开始你的家庭空间")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                            Text("创建一个新家庭，或使用邀请码加入家人已有的空间。")
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
                            Label(isCreating ? "正在创建" : "创建家庭", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                        }
                        .buttonStyle(PrimaryOnboardingButtonStyle())
                        .disabled(
                            familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || isLoading
                                || isCreating
                                || isJoining
                        )

                        HStack(spacing: 12) {
                            Divider()
                            Text("已有邀请码")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                            Divider()
                        }
                        .frame(height: 20)

                        OnboardingTextField(
                            title: "邀请码",
                            placeholder: "输入 8 位邀请码",
                            text: $inviteCode,
                            systemImage: "person.badge.plus"
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.join)
                        .onSubmit {
                            if inviteCodeForSubmission(inviteCode) != nil {
                                onJoin()
                            }
                        }

                        Button {
                            onJoin()
                        } label: {
                            Label(isJoining ? "正在加入" : "加入家庭", systemImage: "person.2.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(SoftSecondaryButtonStyle())
                        .disabled(
                            inviteCodeForSubmission(inviteCode) == nil
                                || isLoading
                                || isCreating
                                || isJoining
                        )

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
