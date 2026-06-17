import Foundation
import SwiftData

enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case inUse = "in_use"
    case idle
    case expired

    var id: String { rawValue }
    var title: String {
        switch self {
        case .inUse: "使用中"
        case .idle: "闲置"
        case .expired: "过期"
        }
    }
}

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case importantDate = "important_date"
    case periodicTask = "periodic_task"
    case itemExpiry = "item_expiry"

    var id: String { rawValue }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
}

@Model
final class FamilyRecord {
    @Attribute(.unique) var remoteId: Int
    var name: String
    var role: String
    var updatedAt: Date

    init(remoteId: Int, name: String, role: String = "member", updatedAt: Date = .now) {
        self.remoteId = remoteId
        self.name = name
        self.role = role
        self.updatedAt = updatedAt
    }
}

@Model
final class FamilyMemberRecord {
    @Attribute(.unique) var remoteId: Int
    var familyId: Int
    var userId: Int
    var name: String
    var phone: String
    var role: String

    init(remoteId: Int, familyId: Int, userId: Int, name: String, phone: String, role: String) {
        self.remoteId = remoteId
        self.familyId = familyId
        self.userId = userId
        self.name = name
        self.phone = phone
        self.role = role
    }
}

@Model
final class SpaceRecord {
    @Attribute(.unique) var remoteId: Int
    var familyId: Int
    var name: String
    var detail: String?
    var nfcUid: String?
    var updatedAt: Date
    var deletedAt: Date?

    init(remoteId: Int, familyId: Int, name: String, detail: String? = nil, nfcUid: String? = nil, updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.remoteId = remoteId
        self.familyId = familyId
        self.name = name
        self.detail = detail
        self.nfcUid = nfcUid
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

@Model
final class ItemRecord {
    @Attribute(.unique) var remoteId: Int
    var familyId: Int
    var spaceId: Int?
    var name: String
    var category: String?
    var quantity: Int
    var unit: String?
    var barcode: String?
    var expiresAt: Date?
    var statusRaw: String
    var notes: String?
    var updatedAt: Date
    var deletedAt: Date?

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .idle }
        set { statusRaw = newValue.rawValue }
    }

    init(remoteId: Int, familyId: Int, spaceId: Int?, name: String, category: String? = nil, quantity: Int, unit: String? = nil, barcode: String? = nil, expiresAt: Date? = nil, status: ItemStatus = .idle, notes: String? = nil, updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.remoteId = remoteId
        self.familyId = familyId
        self.spaceId = spaceId
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.barcode = barcode
        self.expiresAt = expiresAt
        self.statusRaw = status.rawValue
        self.notes = notes
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

@Model
final class ReminderRecord {
    @Attribute(.unique) var remoteId: Int
    var familyId: Int
    var title: String
    var kindRaw: String
    var remindAt: Date
    var repeatRuleRaw: String
    var notes: String?
    var completedAt: Date?
    var updatedAt: Date
    var deletedAt: Date?

    var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .importantDate }
        set { kindRaw = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }

    init(remoteId: Int, familyId: Int, title: String, kind: ReminderKind, remindAt: Date, repeatRule: RepeatRule = .none, notes: String? = nil, completedAt: Date? = nil, updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.remoteId = remoteId
        self.familyId = familyId
        self.title = title
        self.kindRaw = kind.rawValue
        self.remindAt = remindAt
        self.repeatRuleRaw = repeatRule.rawValue
        self.notes = notes
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

@Model
final class PendingChange {
    var entity: String
    var operation: String
    var payload: Data
    var createdAt: Date

    init(entity: String, operation: String, payload: Data, createdAt: Date = .now) {
        self.entity = entity
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
    }
}
