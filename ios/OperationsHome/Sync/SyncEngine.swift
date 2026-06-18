import Foundation
import SwiftData

@MainActor
final class SyncEngine: ObservableObject {
    @Published var isSyncing = false
    @Published var lastError: String?

    private let scheduler = NotificationScheduler()

    func pull(familyId: Int, token: String, context: ModelContext) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let cursor = UserDefaults.standard.string(forKey: "syncCursor.\(familyId)")
            let payload = try await APIClient(token: token).sync(familyId: familyId, since: cursor)
            merge(payload, context: context)
            UserDefaults.standard.set(payload.cursor, forKey: "syncCursor.\(familyId)")
            try context.save()
            rescheduleReminders(familyId: familyId, context: context)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func merge(_ payload: SyncPayload, context: ModelContext) {
        for space in payload.spaces {
            upsertSpace(space, context: context)
        }
        for item in payload.items {
            upsertItem(item, context: context)
        }
        for reminder in payload.reminders {
            upsertReminder(reminder, context: context)
        }
    }

    private func upsertSpace(_ dto: SpaceDTO, context: ModelContext) {
        let id = dto.id
        let descriptor = FetchDescriptor<SpaceRecord>(predicate: #Predicate { $0.remoteId == id })
        let record = (try? context.fetch(descriptor).first) ?? SpaceRecord(remoteId: dto.id, familyId: dto.familyId, name: dto.name)
        record.familyId = dto.familyId
        record.name = dto.name
        record.detail = dto.description
        record.imageKey = dto.imageKey
        record.imageUrl = dto.imageUrl
        record.imageHash = dto.imageHash
        record.updatedAt = dto.updatedAt ?? .now
        record.deletedAt = dto.deletedAt
        if record.modelContext == nil { context.insert(record) }
    }

    private func upsertItem(_ dto: ItemDTO, context: ModelContext) {
        let id = dto.id
        let descriptor = FetchDescriptor<ItemRecord>(predicate: #Predicate { $0.remoteId == id })
        let record = (try? context.fetch(descriptor).first) ?? ItemRecord(remoteId: dto.id, familyId: dto.familyId, spaceId: dto.spaceId, name: dto.name, quantity: dto.quantity)
        record.familyId = dto.familyId
        record.spaceId = dto.spaceId
        record.name = dto.name
        record.category = dto.category
        record.quantity = dto.quantity
        record.unit = dto.unit
        record.barcode = dto.barcode
        record.expiresAt = dto.expiresAt
        record.statusRaw = dto.status
        record.notes = dto.notes
        record.imageKey = dto.imageKey
        record.imageUrl = dto.imageUrl
        record.imageHash = dto.imageHash
        record.updatedAt = dto.updatedAt ?? .now
        record.deletedAt = dto.deletedAt
        if record.modelContext == nil { context.insert(record) }
    }

    private func upsertReminder(_ dto: ReminderDTO, context: ModelContext) {
        let id = dto.id
        let descriptor = FetchDescriptor<ReminderRecord>(predicate: #Predicate { $0.remoteId == id })
        let record = (try? context.fetch(descriptor).first) ?? ReminderRecord(remoteId: dto.id, familyId: dto.familyId, title: dto.title, kind: .importantDate, remindAt: dto.remindAt)
        record.familyId = dto.familyId
        record.title = dto.title
        record.kindRaw = dto.kind
        record.remindAt = dto.remindAt
        record.repeatRuleRaw = dto.repeatRule
        record.repeatValue = dto.repeatValue
        record.notes = dto.notes
        record.completedAt = dto.completedAt
        record.updatedAt = dto.updatedAt ?? .now
        record.deletedAt = dto.deletedAt
        if record.modelContext == nil { context.insert(record) }
    }

    private func rescheduleReminders(familyId: Int, context: ModelContext) {
        let descriptor = FetchDescriptor<ReminderRecord>(predicate: #Predicate { $0.familyId == familyId && $0.deletedAt == nil })
        guard let reminders = try? context.fetch(descriptor) else { return }
        for reminder in reminders {
            scheduler.schedule(reminder: reminder)
        }
    }
}
