import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @State private var families: [FamilyDTO] = []
    @State private var newFamilyName = ""
    @State private var errorMessage = ""

    var body: some View {
        TabView {
            SpacesView(session: session, sync: sync)
                .tabItem { Label("空间", systemImage: "cabinet") }
            RemindersView(session: session, sync: sync)
                .tabItem { Label("提醒", systemImage: "bell") }
            ProfileView(session: session)
                .tabItem { Label("个人中心", systemImage: "person.crop.circle") }
        }
        .safeAreaInset(edge: .top) {
            familyBar
        }
        .task { await loadFamilies() }
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

            if families.isEmpty {
                HStack {
                    TextField("创建家庭", text: $newFamilyName)
                    Button("创建") { Task { await createFamily() } }
                        .disabled(newFamilyName.isEmpty)
                }
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
        do {
            families = try await APIClient(token: token).families()
            if session.selectedFamilyId == nil {
                session.selectedFamilyId = families.first?.id
            }
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
