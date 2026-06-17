import Foundation
import UserNotifications

struct NotificationScheduler {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func schedule(reminder: ReminderRecord) {
        guard reminder.deletedAt == nil, reminder.completedAt == nil, reminder.remindAt > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "运营小家"
        content.body = reminder.title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.remindAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeatRule != .none)
        let request = UNNotificationRequest(identifier: "reminder-\(reminder.remoteId)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
