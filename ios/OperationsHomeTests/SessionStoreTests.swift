import Foundation
import XCTest
@testable import OperationsHome

@MainActor
final class SessionStoreTests: XCTestCase {
    func testUserSurvivesSessionStoreRecreationAndClearsOnLogout() {
        let suite = "SessionStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        var store: SessionStore? = SessionStore(defaults: defaults)
        store?.token = "test-token"
        store?.user = UserDTO(
            id: 9,
            phone: "13800000019",
            name: "小佳",
            avatarKey: nil,
            avatarUrl: nil,
            avatarHash: nil
        )
        store = nil

        let restored = SessionStore(defaults: defaults)
        XCTAssertEqual(restored.user?.id, 9)
        XCTAssertEqual(restored.user?.name, "小佳")

        restored.token = nil
        XCTAssertNil(restored.user)
        defaults.removePersistentDomain(forName: suite)
    }
}
