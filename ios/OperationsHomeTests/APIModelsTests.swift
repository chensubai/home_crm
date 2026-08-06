import Foundation
import UIKit
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

    func testAvatarCompressionProducesJPEGNoLargerThan500KB() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800))
        let source = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        }

        let data = try XCTUnwrap(AvatarImageProcessor.compressedJPEG(from: source))

        XCTAssertLessThanOrEqual(data.count, 512_000)
    }

    func testAvatarSquareCropReturnsSquareImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        let source = renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }

        let cropped = try XCTUnwrap(
            AvatarImageProcessor.squareCrop(
                image: source,
                cropRect: CGRect(x: 100, y: 0, width: 600, height: 600)
            )
        )

        XCTAssertEqual(cropped.size.width, cropped.size.height)
    }

    func testImageCropProcessorProducesConfiguredAspectRatios() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900))
        let source = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
        }

        let spaceCrop = try XCTUnwrap(
            ImageCropProcessor.centerCrop(image: source, aspectRatio: 4 / 3)
        )
        let itemCrop = try XCTUnwrap(
            ImageCropProcessor.centerCrop(image: source, aspectRatio: 1)
        )

        XCTAssertEqual(spaceCrop.size.width / spaceCrop.size.height, 4 / 3, accuracy: 0.01)
        XCTAssertEqual(itemCrop.size.width, itemCrop.size.height, accuracy: 0.01)
    }

    func testImageCropProcessorCompressesWithin500KB() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800))
        let source = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        }

        let data = try XCTUnwrap(ImageCropProcessor.compressedJPEG(from: source))

        XCTAssertLessThanOrEqual(data.count, 512_000)
    }

    func testSpaceWritePayloadsNeverSendNfcUid() throws {
        let createData = try JSONEncoder().encode(
            spaceCreatePayload(familyId: 3, name: "客厅柜子", description: nil)
        )
        let createObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: createData) as? [String: Any]
        )
        let updateData = try JSONEncoder().encode(
            spaceUpdatePayload(name: "客厅柜子", description: nil)
        )
        let updateObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: updateData) as? [String: Any]
        )

        XCTAssertEqual(createObject["family_id"] as? Int, 3)
        XCTAssertNil(createObject["nfc_uid"])
        XCTAssertTrue(updateObject.keys.contains("description"))
        XCTAssertTrue(updateObject["description"] is NSNull)
        XCTAssertNil(updateObject["nfc_uid"])

        XCTAssertNil(
            spaceCreateMultipartFields(
                familyId: 3,
                name: "客厅柜子",
                description: nil
            )["nfc_uid"]
        )
        XCTAssertNil(
            spaceUpdateMultipartFields(
                name: "客厅柜子",
                description: nil
            )["nfc_uid"]
        )
    }

    func testApiErrorPreservesHttpStatusAndServerMessage() {
        let error = apiError(
            statusCode: 403,
            data: Data(#"{"message":"Forbidden by server"}"#.utf8)
        )

        XCTAssertEqual(error.statusCode, 403)
        XCTAssertEqual(error.errorDescription, "Forbidden by server")
    }

    func testApiClientReadsInfoPlistBaseURLAndKeepsExplicitInjection() {
        let configured = APIClient(
            token: "configured-token",
            infoDictionary: ["APIBaseURL": "https://api.operationshome.example/api"],
            debugDefaultBaseURL: URL(string: "http://localhost:8080/api")
        )
        let injected = APIClient(
            baseURL: URL(string: "https://injected.example/api")!,
            token: "injected-token"
        )

        XCTAssertEqual(
            configured.baseURL,
            URL(string: "https://api.operationshome.example/api")
        )
        XCTAssertEqual(configured.token, "configured-token")
        XCTAssertEqual(injected.baseURL, URL(string: "https://injected.example/api"))
        XCTAssertEqual(injected.token, "injected-token")
    }

    func testApiClientOnlyUsesLocalhostWhenDebugFallbackIsProvided() {
        let debugClient = APIClient(
            infoDictionary: [:],
            debugDefaultBaseURL: URL(string: "http://localhost:8080/api")
        )
        let releaseClient = APIClient(
            infoDictionary: [:],
            debugDefaultBaseURL: nil
        )

        XCTAssertEqual(
            debugClient.baseURL,
            URL(string: "http://localhost:8080/api")
        )
        XCTAssertNil(releaseClient.baseURL)
    }

    func testLegacyReminderDateKeepsLocalWallClockTime() {
        guard let date = DateParser.parse("1970-01-01 10:01:00") else {
            return XCTFail("Expected legacy date to parse")
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 1)
    }

    func testMissingReleaseApiBaseURLFailsWithActionableMessage() async {
        let client = APIClient(
            infoDictionary: [:],
            debugDefaultBaseURL: nil
        )

        do {
            try await client.sendSms(phone: "13800000000")
            XCTFail("Expected API configuration failure")
        } catch {
            XCTAssertEqual(
                error as? APIError,
                .configuration(
                    message: "未配置 API 服务地址，请在 Release 构建设置中设置 API_BASE_URL。"
                )
            )
        }
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

    func testInviteCodeForSubmissionNormalizesAndValidatesEightCharacters() {
        XCTAssertEqual(inviteCodeForSubmission(" ab12cd34 "), "AB12CD34")
        XCTAssertNil(inviteCodeForSubmission("ABC1234"))
        XCTAssertNil(inviteCodeForSubmission("        "))
    }

    func testFamilySettingsAndMemberManagementPermissionsStaySeparate() {
        XCTAssertTrue(FamilyScreenPermissions.showsMemberManagementEntry(role: "owner"))
        XCTAssertFalse(FamilyScreenPermissions.showsMemberManagementEntry(role: "member"))

        XCTAssertTrue(FamilyScreenPermissions.canEditFamily(role: "owner", mode: .settings))
        XCTAssertFalse(FamilyScreenPermissions.canEditFamily(role: "owner", mode: .memberManagement))
        XCTAssertFalse(FamilyScreenPermissions.canEditFamily(role: "member", mode: .settings))

        XCTAssertFalse(FamilyScreenPermissions.canManageMembers(role: "owner", mode: .settings))
        XCTAssertTrue(FamilyScreenPermissions.canManageMembers(role: "owner", mode: .memberManagement))
        XCTAssertFalse(FamilyScreenPermissions.canManageMembers(role: "member", mode: .memberManagement))
    }
}
