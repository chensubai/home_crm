import SwiftData
import SwiftUI

struct SpacesView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @Query private var allSpaces: [SpaceRecord]
    @State private var name = ""
    @State private var nfcUid = ""
    @State private var message = ""

    private var spaces: [SpaceRecord] {
        allSpaces
            .filter { $0.familyId == session.selectedFamilyId && $0.deletedAt == nil }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("新增空间") {
                    TextField("例如：客厅柜子", text: $name)
                    TextField("NFC UID（可选）", text: $nfcUid)
                    Button("添加空间") {
                        Task { await addSpace() }
                    }
                    .disabled(name.isEmpty || session.selectedFamilyId == nil)
                }

                Section("储物空间") {
                    ForEach(spaces) { space in
                        NavigationLink {
                            ItemsView(session: session, sync: sync, spaceFilter: space)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(space.name).font(.headline)
                                if let nfcUid = space.nfcUid, !nfcUid.isEmpty {
                                    Text("NFC \(nfcUid)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !message.isEmpty {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("空间")
        }
    }

    private func addSpace() async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        do {
            let dto = try await APIClient(token: token).createSpace(familyId: familyId, name: name, nfcUid: nfcUid.isEmpty ? nil : nfcUid)
            context.insert(SpaceRecord(remoteId: dto.id, familyId: dto.familyId, name: dto.name, detail: dto.description, nfcUid: nfcUid.isEmpty ? nil : nfcUid))
            try? context.save()
            name = ""
            nfcUid = ""
            await sync.pull(familyId: familyId, token: token, context: context)
        } catch {
            message = error.localizedDescription
        }
    }
}
