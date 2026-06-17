import SwiftData
import SwiftUI

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var session: SessionStore
    @ObservedObject var sync: SyncEngine
    @Query private var allReminders: [ReminderRecord]
    @State private var isAdding = false

    private var reminders: [ReminderRecord] {
        allReminders
            .filter { $0.familyId == session.selectedFamilyId && $0.deletedAt == nil }
            .sorted { $0.remindAt < $1.remindAt }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(reminders) { reminder in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title).font(.headline)
                        Text(reminder.remindAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("提醒")
            .toolbar {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $isAdding) {
                ReminderFormView(session: session, sync: sync)
            }
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
