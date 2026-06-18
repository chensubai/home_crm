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
                TabView {
                    SpacesView(session: session, sync: sync, familyName: selectedFamilyName)
                        .tabItem { Label("空间", systemImage: "cabinet") }
                    RemindersView(session: session, sync: sync)
                        .tabItem { Label("提醒", systemImage: "bell") }
                    ProfileView(session: session)
                        .tabItem { Label("个人中心", systemImage: "person.crop.circle") }
                }
                .safeAreaInset(edge: .top) {
                    familyBar
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
            HStack {
                Picker("家庭", selection: Binding(
                    get: { session.selectedFamilyId ?? families.first?.id ?? 0 },
                    set: { session.selectedFamilyId = $0 == 0 ? nil : $0 }
                )) {
                    ForEach(families) { family in
                        Text(family.name).tag(family.id)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: sync.isSyncing ? "arrow.triangle.2.circlepath.circle" : "arrow.triangle.2.circlepath")
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            if let lastError = sync.lastError {
                Text(lastError).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .background(.bar)
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
