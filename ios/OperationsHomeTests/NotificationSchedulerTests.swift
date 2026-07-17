import XCTest
@testable import OperationsHome

final class NotificationSchedulerTests: XCTestCase {
    func testDisabledReminderProducesNoSchedules() {
        let reminder = ReminderRecord(
            remoteId: 7,
            familyId: 1,
            title: "缴费",
            kind: .importantDate,
            remindAt: Date().addingTimeInterval(3600),
            isEnabled: false
        )

        XCTAssertTrue(NotificationScheduler().schedules(for: reminder).isEmpty)
    }

    func testWeeklyReminderUsesOneIdentifierPerWeekday() {
        let reminder = ReminderRecord(
            remoteId: 8,
            familyId: 1,
            title: "打扫",
            kind: .periodicTask,
            remindAt: Date().addingTimeInterval(3600),
            repeatRule: .weekly,
            repeatValue: "2,3,4,5,6"
        )

        XCTAssertEqual(NotificationScheduler().schedules(for: reminder).map(\.identifier), [
            "reminder-8-weekday-2",
            "reminder-8-weekday-3",
            "reminder-8-weekday-4",
            "reminder-8-weekday-5",
            "reminder-8-weekday-6",
        ])
    }
}
