import SwiftData
import SwiftUI

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @Query private var allReminders: [ReminderRecord]
    @State private var isAdding = false
    @State private var message = ""

    private var reminders: [ReminderRecord] {
        allReminders
            .filter { $0.familyId == session.selectedFamilyId && $0.deletedAt == nil }
            .sorted { $0.remindAt < $1.remindAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("家庭提醒")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.16))
                                Text("重要日期、周期任务和物品过期都放在这里。")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                isAdding = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Color(red: 0.20, green: 0.32, blue: 0.25))
                                    .frame(width: 42, height: 42)
                                    .background(Color.white.opacity(0.86), in: Circle())
                                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 8)
                            }
                            .accessibilityLabel("新建提醒")
                        }
                        .padding(.horizontal, 18)

                        if reminders.isEmpty {
                            ReminderEmptyState()
                                .padding(.horizontal, 18)
                        } else {
                            List {
                                ForEach(reminders) { reminder in
                                    AlarmReminderRow(
                                        time: reminderTime(for: reminder),
                                        title: reminder.title,
                                        subtitle: reminderDetail(for: reminder),
                                        isEnabled: reminder.completedAt == nil
                                    )
                                    .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await delete(reminder) }
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                        }

                        if !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAdding) {
                ReminderFormView(session: session, sync: sync)
            }
        }
    }

    private func reminderTime(for reminder: ReminderRecord) -> String {
        reminder.remindAt.formatted(date: .omitted, time: .shortened)
    }

    private func reminderDetail(for reminder: ReminderRecord) -> String {
        if reminder.repeatRule == .none {
            let date = ReminderDateFormatters.chineseDate.string(from: reminder.remindAt)
            return "\(reminder.title) · \(date) · 不重复"
        }

        return "\(reminder.title) · \(repeatTitle(for: reminder.repeatRule, value: reminder.repeatValue))"
    }

    private func repeatTitle(for rule: RepeatRule, value: String?) -> String {
        switch rule {
        case .none: "不重复"
        case .daily: "每天"
        case .weekly: WeeklyRepeatChoice.title(for: value)
        case .monthly: "每月\(value ?? String(Calendar.current.component(.day, from: Date())))日"
        case .yearly: "每年"
        }
    }

    private func delete(_ reminder: ReminderRecord) async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        let previousDeletedAt = reminder.deletedAt
        reminder.deletedAt = .now
        try? context.save()

        do {
            try await APIClient(token: token).deleteReminder(id: reminder.remoteId)
            await sync.pull(familyId: familyId, token: token, context: context)
        } catch {
            reminder.deletedAt = previousDeletedAt
            try? context.save()
            message = error.localizedDescription
        }
    }
}

private struct AlarmReminderRow: View {
    var time: String
    var title: String
    var subtitle: String
    var isEnabled: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(time)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .foregroundStyle(isEnabled ? Color(red: 0.16, green: 0.18, blue: 0.16) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: .constant(isEnabled))
                .labelsHidden()
                .tint(Color(red: 0.30, green: 0.48, blue: 0.36))
                .disabled(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
    }
}

private struct ReminderEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color(red: 0.32, green: 0.45, blue: 0.36))
                .frame(width: 86, height: 86)
                .background(Color.white.opacity(0.78), in: Circle())
            Text("还没有提醒")
                .font(.headline.weight(.bold))
            Text("添加生日、缴费日或固定家务，让家里的小事按时出现。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @State private var title = ""
    @State private var reminderDate = Date()
    @State private var reminderTime = Date().addingTimeInterval(3600)
    @State private var kind = ReminderKind.importantDate
    @State private var repeatRule = RepeatRule.none
    @State private var weeklyChoice = WeeklyRepeatChoice.workdays
    @State private var monthlyDay = Calendar.current.component(.day, from: Date())
    @State private var notes = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormHeaderView(
                            title: "新提醒",
                            subtitle: "一次性提醒选择日期和时间；周期提醒只设置触发时间。",
                            systemImage: "bell"
                        )

                        VStack(spacing: 12) {
                            OnboardingTextField(title: "提醒标题", placeholder: "例如：交水电费", text: $title, systemImage: "text.badge.checkmark")

                            GlassSection(title: "类型") {
                                Picker("类型", selection: $kind) {
                                    Text("重要日期").tag(ReminderKind.importantDate)
                                    Text("周期任务").tag(ReminderKind.periodicTask)
                                    Text("物品过期").tag(ReminderKind.itemExpiry)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        GlassSection(title: "提醒规则") {
                            Picker("重复", selection: $repeatRule) {
                                Text("不重复").tag(RepeatRule.none)
                                Text("每天").tag(RepeatRule.daily)
                                Text("每周").tag(RepeatRule.weekly)
                                Text("每月").tag(RepeatRule.monthly)
                            }

                            if repeatRule == .none {
                                DatePicker("日期", selection: $reminderDate, displayedComponents: .date)
                                DatePicker("时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            } else {
                                DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)

                                if repeatRule == .weekly {
                                    Picker("重复日期", selection: $weeklyChoice) {
                                        ForEach(WeeklyRepeatChoice.allCases) { choice in
                                            Text(choice.title).tag(choice)
                                        }
                                    }
                                }

                                if repeatRule == .monthly {
                                    Picker("每月日期", selection: $monthlyDay) {
                                        ForEach(1...31, id: \.self) { day in
                                            Text("\(day)日").tag(day)
                                        }
                                    }
                                }
                            }
                        }

                        GlassSection(title: "备注") {
                            TextField("可选", text: $notes, axis: .vertical)
                                .lineLimit(3...5)
                        }

                        if !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(title.isEmpty || session.selectedFamilyId == nil)
                }
            }
        }
    }

    private func save() async {
        guard let token = session.token, let familyId = session.selectedFamilyId else { return }
        var payload: [String: EncodableValue] = [
            "family_id": .int(familyId),
            "title": .string(title),
            "kind": .string(kind.rawValue),
            "remind_at": .date(scheduledRemindAt),
            "repeat_rule": .string(repeatRule.rawValue)
        ]
        if let repeatValue {
            payload["repeat_value"] = .string(repeatValue)
        }
        if !notes.isEmpty { payload["notes"] = .string(notes) }

        do {
            let dto = try await APIClient(token: token).createReminder(payload)
            let reminder = ReminderRecord(remoteId: dto.id, familyId: dto.familyId, title: dto.title, kind: ReminderKind(rawValue: dto.kind) ?? .importantDate, remindAt: dto.remindAt, repeatRule: RepeatRule(rawValue: dto.repeatRule) ?? .none, repeatValue: dto.repeatValue, notes: dto.notes)
            context.insert(reminder)
            NotificationScheduler().schedule(reminder: reminder)
            try? context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }

    private var scheduledRemindAt: Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: reminderTime)

        if repeatRule == .none {
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            components.hour = time.hour
            components.minute = time.minute
            return calendar.date(from: components) ?? reminderDate
        }

        switch repeatRule {
        case .daily:
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = time.hour
            components.minute = time.minute
            let today = calendar.date(from: components) ?? Date()
            return today > Date() ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case .weekly:
            return nextWeeklyDate(hour: time.hour ?? 9, minute: time.minute ?? 0)
        case .monthly:
            return nextMonthlyDate(hour: time.hour ?? 9, minute: time.minute ?? 0)
        case .yearly:
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = time.hour
            components.minute = time.minute
            let today = calendar.date(from: components) ?? Date()
            return today > Date() ? today : (calendar.date(byAdding: .year, value: 1, to: today) ?? today)
        case .none:
            return Date()
        }
    }

    private var repeatValue: String? {
        switch repeatRule {
        case .none, .daily, .yearly:
            nil
        case .weekly:
            weeklyChoice.rawValue
        case .monthly:
            String(monthlyDay)
        }
    }

    private func nextWeeklyDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)
        let candidates = weeklyChoice.weekdays.compactMap { weekday -> Date? in
            var daysToAdd = (weekday - currentWeekday + 7) % 7
            var targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
            var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = hour
            components.minute = minute
            guard let date = calendar.date(from: components) else { return nil }
            if date > now { return date }

            daysToAdd += 7
            targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
            components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components)
        }

        return candidates.sorted().first ?? now
    }

    private func nextMonthlyDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var candidate = calendar.dateComponents([.year, .month], from: now)
        let range = calendar.range(of: .day, in: .month, for: now)
        candidate.day = min(monthlyDay, range?.count ?? monthlyDay)
        candidate.hour = hour
        candidate.minute = minute

        if let date = calendar.date(from: candidate), date > now {
            return date
        }

        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        var next = calendar.dateComponents([.year, .month], from: nextMonth)
        let nextRange = calendar.range(of: .day, in: .month, for: nextMonth)
        next.day = min(monthlyDay, nextRange?.count ?? monthlyDay)
        next.hour = hour
        next.minute = minute
        return calendar.date(from: next) ?? now
    }
}

private enum ReminderDateFormatters {
    static let chineseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

private enum WeeklyRepeatChoice: String, CaseIterable, Identifiable {
    case workdays = "2,3,4,5,6"
    case monday = "2"
    case tuesday = "3"
    case wednesday = "4"
    case thursday = "5"
    case friday = "6"
    case saturday = "7"
    case sunday = "1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workdays: "工作日"
        case .monday: "每周一"
        case .tuesday: "每周二"
        case .wednesday: "每周三"
        case .thursday: "每周四"
        case .friday: "每周五"
        case .saturday: "每周六"
        case .sunday: "每周日"
        }
    }

    var weekdays: [Int] {
        rawValue.split(separator: ",").compactMap { Int($0) }
    }

    static func title(for rawValue: String?) -> String {
        guard let rawValue, let choice = WeeklyRepeatChoice(rawValue: rawValue) else {
            return "每周"
        }

        return choice.title
    }
}
