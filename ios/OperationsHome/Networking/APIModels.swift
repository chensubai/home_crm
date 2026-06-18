import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let ok: Bool
    let data: T
}

struct EmptyPayload: Codable {}

struct AuthResponse: Codable {
    let token: String
    let user: UserDTO
}

struct UserDTO: Codable, Identifiable {
    let id: Int
    let phone: String
    let name: String
}

struct FamilyDTO: Codable, Identifiable {
    let id: Int
    let name: String
}

struct SpaceDTO: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let name: String
    let description: String?
    let imageKey: String?
    let imageUrl: String?
    let imageHash: String?
    let updatedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case name
        case description
        case imageKey = "image_key"
        case imageUrl = "image_url"
        case imageHash = "image_hash"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct ItemDTO: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let spaceId: Int?
    let name: String
    let category: String?
    let quantity: Int
    let unit: String?
    let barcode: String?
    let expiresAt: Date?
    let status: String
    let notes: String?
    let imageKey: String?
    let imageUrl: String?
    let imageHash: String?
    let updatedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case spaceId = "space_id"
        case name
        case category
        case quantity
        case unit
        case barcode
        case expiresAt = "expires_at"
        case status
        case notes
        case imageKey = "image_key"
        case imageUrl = "image_url"
        case imageHash = "image_hash"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct ReminderDTO: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let title: String
    let kind: String
    let remindAt: Date
    let repeatRule: String
    let repeatValue: String?
    let notes: String?
    let completedAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case title
        case kind
        case remindAt = "remind_at"
        case repeatRule = "repeat_rule"
        case repeatValue = "repeat_value"
        case notes
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct SyncPayload: Codable {
    let cursor: String
    let spaces: [SpaceDTO]
    let items: [ItemDTO]
    let reminders: [ReminderDTO]
}
