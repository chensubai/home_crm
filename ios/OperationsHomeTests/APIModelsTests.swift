import Foundation
import XCTest
@testable import OperationsHome

final class APIModelsTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testDecodesInteractionContractFields() throws {
        let user = try decoder.decode(UserDTO.self, from: Data(#"{"id":9,"phone":"13800000019","name":"小佳","avatar_key":"users/9/avatar/a.jpg","avatar_url":"https://cdn.example.com/a.jpg","avatar_hash":"avatar-hash"}"#.utf8))
        let family = try decoder.decode(FamilyDTO.self, from: Data(#"{"id":3,"name":"小佳的家","role":"owner"}"#.utf8))
        let member = try decoder.decode(FamilyMemberDTO.self, from: Data(#"{"id":5,"family_id":3,"user_id":10,"name":"家人","phone":"13800000012","role":"member"}"#.utf8))
        let invite = try decoder.decode(FamilyInviteDTO.self, from: Data(#"{"id":7,"family_id":3,"code":"ABCD1234","phone":null,"expires_at":"2026-07-24T09:00:00Z"}"#.utf8))
        let space = try decoder.decode(SpaceDTO.self, from: Data(#"{"id":11,"family_id":3,"name":"客厅柜子","nfc_uid":"nfc-updated"}"#.utf8))
        let reminder = try decoder.decode(ReminderDTO.self, from: Data(#"{"id":12,"family_id":3,"title":"缴费","kind":"important_date","remind_at":"2026-07-18T09:00:00Z","repeat_rule":"none","is_enabled":false}"#.utf8))

        XCTAssertEqual(user.avatarHash, "avatar-hash")
        XCTAssertEqual(family.role, "owner")
        XCTAssertEqual(member.phone, "13800000012")
        XCTAssertEqual(invite.code, "ABCD1234")
        XCTAssertEqual(space.nfcUid, "nfc-updated")
        XCTAssertFalse(reminder.isEnabled)
    }

    func testLegacyRepeatingReminderOpensAsPeriodicTask() {
        XCTAssertEqual(
            normalizedReminderKind(storedKind: .importantDate, repeatRule: .weekly),
            .periodicTask
        )
    }

    func testSpaceUpdatePayloadSendsNullForClearedOptionalFields() throws {
        let payload = spaceUpdatePayload(name: "客厅柜子", description: nil, nfcUid: nil)
        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["name"] as? String, "客厅柜子")
        XCTAssertTrue(object.keys.contains("description"))
        XCTAssertTrue(object["description"] is NSNull)
        XCTAssertTrue(object.keys.contains("nfc_uid"))
        XCTAssertTrue(object["nfc_uid"] is NSNull)
    }

    func testItemAdjustmentGateSerializesRequestsForTheSameItem() {
        var gate = ItemAdjustmentGate()

        XCTAssertTrue(gate.begin(itemId: 11))
        XCTAssertFalse(gate.begin(itemId: 11))
        XCTAssertTrue(gate.begin(itemId: 12))
        XCTAssertTrue(gate.isAdjusting(itemId: 11))

        gate.end(itemId: 11)

        XCTAssertTrue(gate.begin(itemId: 11))
    }

    func testFailedFamilyLoadDoesNotOfferFamilyCreation() {
        XCTAssertEqual(
            homeFamilyPhase(isLoading: false, didLoadSuccessfully: false, familyCount: 0),
            .failed
        )
        XCTAssertEqual(
            homeFamilyPhase(isLoading: false, didLoadSuccessfully: true, familyCount: 0),
            .create
        )
    }
}
