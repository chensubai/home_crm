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
    let avatarKey: String?
    let avatarUrl: String?
    let avatarHash: String?

    enum CodingKeys: String, CodingKey {
        case id
        case phone
        case name
        case avatarKey = "avatar_key"
        case avatarUrl = "avatar_url"
        case avatarHash = "avatar_hash"
    }
}

struct FamilyDTO: Codable, Identifiable {
    let id: Int
    let name: String
    let role: String
}

struct FamilyMemberDTO: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let userId: Int
    let name: String
    let phone: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case userId = "user_id"
        case name
        case phone
        case role
    }
}

struct FamilyInviteDTO: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let code: String
    let phone: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case code
        case phone
        case expiresAt = "expires_at"
    }
}

struct SpaceDTO: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let name: String
    let description: String?
    let nfcUid: String?
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
        case nfcUid = "nfc_uid"
        case imageKey = "image_key"
        case imageUrl = "image_url"
        case imageHash = "image_hash"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

struct NFCTokenDTO: Codable {
    let token: String
    let url: URL?
}

struct NFCSpaceDestinationDTO: Codable {
    let spaceId: Int
    let familyId: Int
    let spaceName: String

    enum CodingKeys: String, CodingKey {
        case spaceId = "space_id"
        case familyId = "family_id"
        case spaceName = "space_name"
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
    let isEnabled: Bool
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
        case isEnabled = "is_enabled"
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
