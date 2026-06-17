import SwiftData
import SwiftUI

@main
struct OperationsHomeApp: App {
    private let container: ModelContainer

    init() {
        container = try! ModelContainer(
            for: FamilyRecord.self,
            FamilyMemberRecord.self,
            SpaceRecord.self,
            ItemRecord.self,
            ReminderRecord.self,
            PendingChange.self
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
