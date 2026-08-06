import XCTest
@testable import OperationsHome

final class NotificationSchedulerTests: XCTestCase {
    func testReminderIsScheduledThirtyMinutesEarly() {
        let reminderDate = Date(timeIntervalSinceNow: 3600)
        let reminder = ReminderRecord(remoteId: 1, familyId: 1, title: "缴费", kind: .importantDate, remindAt: reminderDate)

        let schedule = try! XCTUnwrap(NotificationScheduler().schedules(for: reminder).first)
        let expected = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate.addingTimeInterval(-30 * 60))
        XCTAssertEqual(schedule.components, expected)
    }

    func testItemExpiryIsScheduledTwoDaysEarly() {
        let reminderDate = Date(timeIntervalSinceNow: 4 * 24 * 60 * 60)
        let reminder = ReminderRecord(remoteId: 2, familyId: 1, title: "牛奶", kind: .itemExpiry, remindAt: reminderDate)

        let schedule = try! XCTUnwrap(NotificationScheduler().schedules(for: reminder).first)
        let expectedDate = Calendar.current.date(byAdding: .day, value: -2, to: reminderDate)!
        let expected = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: expectedDate)
        XCTAssertEqual(schedule.components, expected)
    }

    func testPastEarlyNotificationProducesNoSchedule() {
        let reminder = ReminderRecord(remoteId: 3, familyId: 1, title: "已过期", kind: .importantDate, remindAt: Date(timeIntervalSinceNow: 10 * 60))

        XCTAssertTrue(NotificationScheduler().schedules(for: reminder).isEmpty)
    }

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
