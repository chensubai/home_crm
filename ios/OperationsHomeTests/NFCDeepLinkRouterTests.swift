import XCTest
@testable import OperationsHome

@MainActor
final class NFCDeepLinkRouterTests: XCTestCase {
    func testParsesUniversalAndDevelopmentLinks() {
        let router = NFCDeepLinkRouter()

        XCTAssertEqual(
            router.token(from: URL(string: "https://nfc.example.com/nfc/ABC123")!),
            "ABC123"
        )
        XCTAssertEqual(
            router.token(from: URL(string: "operationshome://nfc/ABC123")!),
            "ABC123"
        )
        XCTAssertNil(router.token(from: URL(string: "https://nfc.example.com/items/1")!))
    }

    func testDevelopmentLinkRequiresExactlyOneNonEmptyTokenSegment() {
        let router = NFCDeepLinkRouter()

        XCTAssertNil(router.token(from: URL(string: "operationshome://nfc/ABC123/extra")!))
        XCTAssertNil(router.token(from: URL(string: "operationshome://nfc/")!))
        XCTAssertNil(router.token(from: URL(string: "operationshome://nfc//ABC123")!))
        XCTAssertNil(router.token(from: URL(string: "operationshome://nfc/ABC123/")!))
    }

    func testPendingTokenSurvivesRouterRecreationUntilConsumed() {
        let suite = "NFCDeepLinkRouterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        var router: NFCDeepLinkRouter? = NFCDeepLinkRouter(defaults: defaults)
        XCTAssertTrue(router?.handle(URL(string: "operationshome://nfc/ABC123")!) == true)
        router = nil

        let restored = NFCDeepLinkRouter(defaults: defaults)
        XCTAssertEqual(restored.pendingToken, "ABC123")
        restored.consumePendingToken()
        XCTAssertNil(restored.pendingToken)
        defaults.removePersistentDomain(forName: suite)
    }
}
