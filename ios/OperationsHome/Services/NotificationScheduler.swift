import Foundation
import UserNotifications

struct NotificationScheduler {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func schedule(reminder: ReminderRecord) {
        guard reminder.deletedAt == nil, reminder.completedAt == nil else { return }
        guard reminder.repeatRule != .none || reminder.remindAt > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "运营小家"
        content.body = reminder.title
        content.sound = .default

        for schedule in schedules(for: reminder) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components, repeats: schedule.repeats)
            let request = UNNotificationRequest(identifier: schedule.identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
    }

    private func schedules(for reminder: ReminderRecord) -> [(identifier: String, components: DateComponents, repeats: Bool)] {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: reminder.remindAt)
        let baseIdentifier = "reminder-\(reminder.remoteId)"

        switch reminder.repeatRule {
        case .none:
            return [(baseIdentifier, calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.remindAt), false)]
        case .daily:
            return [(baseIdentifier, time, true)]
        case .weekly:
            let weekdays = reminder.repeatValue?
                .split(separator: ",")
                .compactMap { Int($0) }
                .filter { (1...7).contains($0) }

            return (weekdays?.isEmpty == false ? weekdays! : [calendar.component(.weekday, from: reminder.remindAt)]).map { weekday in
                var components = time
                components.weekday = weekday
                return ("\(baseIdentifier)-weekday-\(weekday)", components, true)
            }
        case .monthly:
            var components = time
            components.day = Int(reminder.repeatValue ?? "") ?? calendar.component(.day, from: reminder.remindAt)
            return [(baseIdentifier, components, true)]
        case .yearly:
            return [(baseIdentifier, calendar.dateComponents([.month, .day, .hour, .minute], from: reminder.remindAt), true)]
        }
    }
}
