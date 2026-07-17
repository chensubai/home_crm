import Foundation

@MainActor
final class SessionStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var token: String? {
        didSet {
            if let token {
                defaults.set(token, forKey: "apiToken")
            } else {
                defaults.removeObject(forKey: "apiToken")
                user = nil
                selectedFamilyId = nil
            }
        }
    }
    @Published var user: UserDTO? {
        didSet {
            if let user, let data = try? JSONEncoder().encode(user) {
                defaults.set(data, forKey: "currentUser")
            } else {
                defaults.removeObject(forKey: "currentUser")
            }
        }
    }
    @Published var selectedFamilyId: Int? {
        didSet {
            if let selectedFamilyId {
                defaults.set(selectedFamilyId, forKey: "selectedFamilyId")
            } else {
                defaults.removeObject(forKey: "selectedFamilyId")
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        token = defaults.string(forKey: "apiToken")
        let familyId = defaults.integer(forKey: "selectedFamilyId")
        selectedFamilyId = familyId == 0 ? nil : familyId
        if token != nil,
           let data = defaults.data(forKey: "currentUser"),
           let storedUser = try? JSONDecoder().decode(UserDTO.self, from: data) {
            user = storedUser
        } else {
            user = nil
        }
    }

    func refreshUser() async {
        guard let token,
              let refreshedUser = try? await APIClient(token: token).me() else { return }
        user = refreshedUser
    }
}

struct APIClient {
    var baseURL = URL(string: "http://localhost:8080/api")!
    var token: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = DateParser.parse(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(baseURL: URL = URL(string: "http://localhost:8080/api")!, token: String? = nil) {
        self.baseURL = baseURL
        self.token = token
    }

    func sendSms(phone: String) async throws {
        let _: SmsSendResponse = try await request("auth/sms/send", method: "POST", body: SmsSendRequest(phone: phone))
    }

    func verifySms(phone: String, code: String, name: String?) async throws -> AuthResponse {
        try await request("auth/sms/verify", method: "POST", body: SmsVerifyRequest(phone: phone, code: code, name: name))
    }

    func me() async throws -> UserDTO {
        try await request("auth/me")
    }

    func updateProfile(name: String, avatarData: Data? = nil) async throws -> UserDTO {
        if let avatarData {
            return try await requestMultipart(
                "profile",
                method: "POST",
                fields: ["_method": "PATCH", "name": name],
                fileFieldName: "avatar",
                imageData: avatarData
            )
        }

        return try await request("profile", method: "PATCH", body: ProfileUpdateRequest(name: name))
    }

    func families() async throws -> [FamilyDTO] {
        try await request("families")
    }

    func createFamily(name: String) async throws -> FamilyDTO {
        try await request("families", method: "POST", body: FamilyCreateRequest(name: name))
    }

    func updateFamily(id: Int, name: String) async throws -> FamilyDTO {
        try await request("families/\(id)", method: "PATCH", body: FamilyCreateRequest(name: name))
    }

    func familyMembers(familyId: Int) async throws -> [FamilyMemberDTO] {
        try await request("families/\(familyId)/members")
    }

    func inviteMember(familyId: Int, phone: String?) async throws -> FamilyInviteDTO {
        try await request("families/\(familyId)/invites", method: "POST", body: FamilyInviteRequest(phone: phone))
    }

    func removeMember(familyId: Int, memberId: Int) async throws {
        try await requestVoid("families/\(familyId)/members/\(memberId)", method: "DELETE")
    }

    func spaces(familyId: Int) async throws -> [SpaceDTO] {
        try await request("spaces?family_id=\(familyId)")
    }

    func createSpace(familyId: Int, name: String, description: String? = nil, nfcUid: String?, imageData: Data? = nil) async throws -> SpaceDTO {
        if let imageData {
            var fields = [
                "family_id": String(familyId),
                "name": name
            ]
            if let description, !description.isEmpty { fields["description"] = description }
            if let nfcUid, !nfcUid.isEmpty { fields["nfc_uid"] = nfcUid }
            return try await requestMultipart("spaces", method: "POST", fields: fields, imageData: imageData)
        }

        return try await request("spaces", method: "POST", body: SpaceCreateRequest(familyId: familyId, name: name, description: description, nfcUid: nfcUid))
    }

    func updateSpace(id: Int, name: String, description: String?, nfcUid: String?, imageData: Data? = nil) async throws -> SpaceDTO {
        if let imageData {
            return try await requestMultipart(
                "spaces/\(id)",
                method: "POST",
                fields: [
                    "_method": "PATCH",
                    "name": name,
                    "description": description ?? "",
                    "nfc_uid": nfcUid ?? ""
                ],
                imageData: imageData
            )
        }

        return try await request(
            "spaces/\(id)",
            method: "PATCH",
            body: spaceUpdatePayload(name: name, description: description, nfcUid: nfcUid)
        )
    }

    func deleteSpace(id: Int) async throws {
        try await requestVoid("spaces/\(id)", method: "DELETE")
    }

    func items(familyId: Int) async throws -> [ItemDTO] {
        try await request("items?family_id=\(familyId)")
    }

    func createItem(_ payload: [String: EncodableValue], imageData: Data? = nil) async throws -> ItemDTO {
        if let imageData {
            let fields = Dictionary(uniqueKeysWithValues: payload.compactMap { key, value in
                value.multipartValue.map { (key, $0) }
            })
            return try await requestMultipart("items", method: "POST", fields: fields, imageData: imageData)
        }

        return try await request("items", method: "POST", body: payload)
    }

    func updateItem(id: Int, payload: [String: EncodableValue], imageData: Data? = nil) async throws -> ItemDTO {
        if let imageData {
            var fields = Dictionary(uniqueKeysWithValues: payload.compactMap { key, value in
                value.multipartValue.map { (key, $0) }
            })
            fields["_method"] = "PATCH"
            return try await requestMultipart("items/\(id)", method: "POST", fields: fields, imageData: imageData)
        }

        return try await request("items/\(id)", method: "PATCH", body: payload)
    }

    func deleteItem(id: Int) async throws {
        try await requestVoid("items/\(id)", method: "DELETE")
    }

    func adjustItem(id: Int, delta: Int, reason: String?) async throws -> ItemDTO {
        try await request("items/\(id)/adjust", method: "POST", body: ItemAdjustRequest(delta: delta, reason: reason))
    }

    func reminders(familyId: Int) async throws -> [ReminderDTO] {
        try await request("reminders?family_id=\(familyId)")
    }

    func createReminder(_ payload: [String: EncodableValue]) async throws -> ReminderDTO {
        try await request("reminders", method: "POST", body: payload)
    }

    func updateReminder(id: Int, payload: [String: EncodableValue]) async throws -> ReminderDTO {
        try await request("reminders/\(id)", method: "PATCH", body: payload)
    }

    func deleteReminder(id: Int) async throws {
        try await requestVoid("reminders/\(id)", method: "DELETE")
    }

    func sync(familyId: Int, since: String?) async throws -> SyncPayload {
        let suffix = since.map { "&since=\($0.urlQueryValue)" } ?? ""
        return try await request("sync?family_id=\(familyId)\(suffix)")
    }

    private func request<T: Decodable, B: Encodable>(_ path: String, method: String = "GET", body: B? = Optional<EmptyPayload>.none) async throws -> T {
        guard let url = URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let error = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(error.message)
            }

            throw APIError.server("请求失败：HTTP \(http.statusCode)")
        }

        return try decoder.decode(APIEnvelope<T>.self, from: data).data
    }

    private func requestVoid<B: Encodable>(_ path: String, method: String, body: B? = Optional<EmptyPayload>.none) async throws {
        guard let url = URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(error.message)
            }
            throw APIError.server("请求失败：HTTP \(http.statusCode)")
        }
    }

    private func requestMultipart<T: Decodable>(_ path: String, method: String, fields: [String: String], fileFieldName: String = "image", imageData: Data) async throws -> T {
        guard let url = URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path) else {
            throw URLError(.badURL)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.appendMultipartField(name: key, value: value, boundary: boundary)
        }
        body.appendMultipartFile(name: fileFieldName, filename: "upload.jpg", mimeType: "image/jpeg", data: imageData, boundary: boundary)
        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let error = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(error.message)
            }
            throw APIError.server("请求失败：HTTP \(http.statusCode)")
        }

        return try decoder.decode(APIEnvelope<T>.self, from: data).data
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应无效"
        case let .server(message):
            return message
        }
    }
}

private struct APIErrorResponse: Decodable {
    let message: String
}

private enum DateParser {
    private static let iso8601 = ISO8601DateFormatter()

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let mysqlDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        iso8601.date(from: value)
            ?? iso8601WithFractionalSeconds.date(from: value)
            ?? mysqlDateTime.date(from: value)
    }
}

private extension String {
    var urlQueryValue: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

private extension Data {
    mutating func appendString(_ value: String) {
        append(Data(value.utf8))
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendMultipartFile(name: String, filename: String, mimeType: String, data: Data, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }
}

private struct SmsSendRequest: Encodable {
    let phone: String
}

private struct SmsSendResponse: Decodable {
    let expiresIn: Int?
    let mockCode: String?

    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case mockCode = "mock_code"
    }
}

private struct SmsVerifyRequest: Encodable {
    let phone: String
    let code: String
    let name: String?
}

private struct FamilyCreateRequest: Encodable {
    let name: String
}

private struct FamilyInviteRequest: Encodable {
    let phone: String?
}

private struct ProfileUpdateRequest: Encodable {
    let name: String
}

private struct SpaceCreateRequest: Encodable {
    let familyId: Int
    let name: String
    let description: String?
    let nfcUid: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case name
        case description
        case nfcUid = "nfc_uid"
    }
}

private struct ItemAdjustRequest: Encodable {
    let delta: Int
    let reason: String?
}

enum EncodableValue: Encodable {
    case int(Int)
    case string(String)
    case date(Date)
    case bool(Bool)
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .date(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var multipartValue: String? {
        switch self {
        case .int(let value): String(value)
        case .string(let value): value
        case .date(let value): ISO8601DateFormatter().string(from: value)
        case .bool(let value): value ? "1" : "0"
        case .null: ""
        }
    }
}

func spaceUpdatePayload(name: String, description: String?, nfcUid: String?) -> [String: EncodableValue] {
    [
        "name": .string(name),
        "description": description.map(EncodableValue.string) ?? .null,
        "nfc_uid": nfcUid.map(EncodableValue.string) ?? .null
    ]
}
