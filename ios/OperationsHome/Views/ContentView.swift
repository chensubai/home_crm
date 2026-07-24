import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var router: NFCDeepLinkRouter
    @StateObject private var session = SessionStore()
    @StateObject private var sync = SyncEngine()

    var body: some View {
        Group {
            if session.token == nil {
                LoginView(session: session)
            } else {
                HomeView(session: session, sync: sync)
                    .environmentObject(router)
            }
        }
        .onOpenURL { router.handle($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            router.handle(url)
        }
        .task {
            await NotificationScheduler().requestAuthorization()
        }
        .task(id: session.token) {
            await session.refreshUser()
        }
    }
}
