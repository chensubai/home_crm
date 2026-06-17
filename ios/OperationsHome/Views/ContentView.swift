import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var session = SessionStore()
    @StateObject private var sync = SyncEngine()

    var body: some View {
        Group {
            if session.token == nil {
                LoginView(session: session)
            } else {
                HomeView(session: session, sync: sync)
            }
        }
        .task {
            await NotificationScheduler().requestAuthorization()
        }
    }
}
