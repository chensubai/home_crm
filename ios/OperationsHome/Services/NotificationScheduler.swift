import Foundation
import UserNotifications

struct NotificationSchedule {
    let identifier: String
    let components: DateComponents
    let repeats: Bool
}

struct NotificationScheduler {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func cancel(reminderId: Int) async {
        let center = UNUserNotificationCenter.current()
        let baseIdentifier = "reminder-\(reminderId)"
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0 == baseIdentifier || $0.hasPrefix("\(baseIdentifier)-") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func schedule(reminder: ReminderRecord) async {
        await cancel(reminderId: reminder.remoteId)

        let content = UNMutableNotificationContent()
        content.title = "方寸"
        content.body = reminder.title
        content.sound = .default

        for schedule in schedules(for: reminder) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.components, repeats: schedule.repeats)
            let request = UNNotificationRequest(identifier: schedule.identifier, content: content, trigger: trigger)

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func schedules(for reminder: ReminderRecord) -> [NotificationSchedule] {
        guard reminder.isEnabled, reminder.deletedAt == nil, reminder.completedAt == nil else { return [] }
        guard reminder.repeatRule != .none || reminder.remindAt > .now else { return [] }

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: reminder.remindAt)
        let baseIdentifier = "reminder-\(reminder.remoteId)"

        switch reminder.repeatRule {
        case .none:
            return [NotificationSchedule(
                identifier: baseIdentifier,
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.remindAt),
                repeats: false
            )]
        case .daily:
            return [NotificationSchedule(identifier: baseIdentifier, components: time, repeats: true)]
        case .weekly:
            let weekdays = reminder.repeatValue?
                .split(separator: ",")
                .compactMap { Int($0) }
                .filter { (1...7).contains($0) }

            return (weekdays?.isEmpty == false ? weekdays! : [calendar.component(.weekday, from: reminder.remindAt)]).map { weekday in
                var components = time
                components.weekday = weekday
                return NotificationSchedule(
                    identifier: "\(baseIdentifier)-weekday-\(weekday)",
                    components: components,
                    repeats: true
                )
            }
        case .monthly:
            var components = time
            components.day = Int(reminder.repeatValue ?? "") ?? calendar.component(.day, from: reminder.remindAt)
            return [NotificationSchedule(identifier: baseIdentifier, components: components, repeats: true)]
        case .yearly:
            return [NotificationSchedule(
                identifier: baseIdentifier,
                components: calendar.dateComponents([.month, .day, .hour, .minute], from: reminder.remindAt),
                repeats: true
            )]
        }
    }
}
