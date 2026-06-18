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
            List {
                ForEach(reminders) { reminder in
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(reminderSubtitle(for: reminder))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: reminder.completedAt == nil ? "bell.fill" : "bell.slash")
                            .foregroundStyle(reminder.completedAt == nil ? .blue : .secondary)
                            .frame(width: 32, height: 32)
                    }
                    .padding(.vertical, 6)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await delete(reminder) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("提醒")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新建提醒")
                }
            }
            .sheet(isPresented: $isAdding) {
                ReminderFormView(session: session, sync: sync)
            }
        }
    }

    private func reminderSubtitle(for reminder: ReminderRecord) -> String {
        let date = reminder.remindAt.formatted(date: .abbreviated, time: .shortened)
        return "\(date) · \(repeatTitle(for: reminder.repeatRule))"
    }

    private func repeatTitle(for rule: RepeatRule) -> String {
        switch rule {
        case .none: "不重复"
        case .daily: "每天"
        case .weekly: "每周"
        case .monthly: "每月"
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

struct ReminderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @State private var title = ""
    @State private var remindAt = Date().addingTimeInterval(3600)
    @State private var kind = ReminderKind.importantDate
    @State private var repeatRule = RepeatRule.none
    @State private var notes = ""
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("标题", text: $title)
                Picker("类型", selection: $kind) {
                    Text("重要日期").tag(ReminderKind.importantDate)
                    Text("周期任务").tag(ReminderKind.periodicTask)
                    Text("物品过期").tag(ReminderKind.itemExpiry)
                }
                DatePicker("提醒时间", selection: $remindAt)
                Picker("重复", selection: $repeatRule) {
                    Text("不重复").tag(RepeatRule.none)
                    Text("每天").tag(RepeatRule.daily)
                    Text("每周").tag(RepeatRule.weekly)
                    Text("每月").tag(RepeatRule.monthly)
                    Text("每年").tag(RepeatRule.yearly)
                }
                TextField("备注", text: $notes, axis: .vertical)
                if !message.isEmpty {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新提醒")
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
            "remind_at": .date(remindAt),
            "repeat_rule": .string(repeatRule.rawValue)
        ]
        if !notes.isEmpty { payload["notes"] = .string(notes) }

        do {
            let dto = try await APIClient(token: token).createReminder(payload)
            let reminder = ReminderRecord(remoteId: dto.id, familyId: dto.familyId, title: dto.title, kind: ReminderKind(rawValue: dto.kind) ?? .importantDate, remindAt: dto.remindAt, repeatRule: RepeatRule(rawValue: dto.repeatRule) ?? .none, notes: dto.notes)
            context.insert(reminder)
            NotificationScheduler().schedule(reminder: reminder)
            try? context.save()
            await sync.pull(familyId: familyId, token: token, context: context)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
