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

    func testNfcDestinationOnlyNavigatesInsideLoadedMemberships() {
        let target = NFCSpaceDestinationDTO(
            spaceId: 11,
            familyId: 3,
            spaceName: "玄关柜"
        )

        XCTAssertEqual(
            nfcNavigationDecision(
                destination: target,
                availableFamilyIds: [3, 4]
            ),
            NFCNavigationDecision(familyId: 3, spaceId: 11)
        )
        XCTAssertNil(
            nfcNavigationDecision(
                destination: target,
                availableFamilyIds: [4]
            )
        )
    }

    func testNfcResolutionFailureUsesStatusSpecificCopyAndTokenPolicy() {
        XCTAssertEqual(
            nfcResolutionFailureDecision(
                for: APIError.server(statusCode: 403, message: "server copy")
            ),
            .discardToken(message: "你没有权限访问这个空间。")
        )
        XCTAssertEqual(
            nfcResolutionFailureDecision(
                for: APIError.server(statusCode: 404, message: "server copy")
            ),
            .discardToken(message: "该 NFC 贴纸已失效。")
        )
        XCTAssertEqual(
            nfcResolutionFailureDecision(
                for: APIError.server(statusCode: 500, message: "服务暂时不可用")
            ),
            .discardToken(message: "服务暂时不可用")
        )
        XCTAssertEqual(
            nfcResolutionFailureDecision(for: URLError(.notConnectedToInternet)),
            .retry(message: "网络不可用，请联网后重试。")
        )
    }

    func testSpaceNavigationWaitsForTargetAndAvoidsDuplicatePushes() {
        XCTAssertEqual(
            spaceNavigationTransition(
                path: [],
                requestedSpaceId: 11,
                availableSpaceIds: [10]
            ),
            SpaceNavigationTransition(path: [], consumesRequest: false)
        )
        XCTAssertEqual(
            spaceNavigationTransition(
                path: [],
                requestedSpaceId: 11,
                availableSpaceIds: [10, 11]
            ),
            SpaceNavigationTransition(path: [11], consumesRequest: true)
        )
        XCTAssertEqual(
            spaceNavigationTransition(
                path: [11],
                requestedSpaceId: 11,
                availableSpaceIds: [11]
            ),
            SpaceNavigationTransition(path: [11], consumesRequest: true)
        )
    }

    func testOnlyCurrentUncancelledNfcResolutionCanMutateRoutingState() {
        XCTAssertTrue(
            isCurrentNfcResolution(
                resolvingToken: "token-a",
                pendingToken: "token-a",
                isCancelled: false
            )
        )
        XCTAssertFalse(
            isCurrentNfcResolution(
                resolvingToken: "token-a",
                pendingToken: "token-b",
                isCancelled: false
            )
        )
        XCTAssertFalse(
            isCurrentNfcResolution(
                resolvingToken: "token-a",
                pendingToken: "token-a",
                isCancelled: true
            )
        )
    }

    func testSyncFailureRetainsPendingTokenAndOffersExactRetry() {
        let navigation = NFCNavigationDecision(familyId: 3, spaceId: 11)
        let result = nfcNavigationCommitDecision(
            navigation: navigation,
            syncSucceeded: false,
            targetIsReady: false,
            resolvingToken: "token-a",
            pendingToken: "token-a",
            isCancelled: false
        )

        XCTAssertEqual(
            result,
            .retry(message: "网络不可用，请联网后重试。")
        )
        XCTAssertFalse(result.consumesToken)
        XCTAssertNil(result.navigation)
    }

    func testNavigationMutationWaitsForReadyCurrentPostSyncDecision() {
        let navigation = NFCNavigationDecision(familyId: 3, spaceId: 11)

        XCTAssertEqual(
            nfcNavigationCommitDecision(
                navigation: navigation,
                syncSucceeded: true,
                targetIsReady: true,
                resolvingToken: "token-a",
                pendingToken: "token-b",
                isCancelled: false
            ),
            .ignore
        )
        XCTAssertEqual(
            nfcNavigationCommitDecision(
                navigation: navigation,
                syncSucceeded: true,
                targetIsReady: false,
                resolvingToken: "token-a",
                pendingToken: "token-a",
                isCancelled: false
            ),
            .retry(message: "网络不可用，请联网后重试。")
        )

        let ready = nfcNavigationCommitDecision(
            navigation: navigation,
            syncSucceeded: true,
            targetIsReady: true,
            resolvingToken: "token-a",
            pendingToken: "token-a",
            isCancelled: false
        )
        XCTAssertEqual(ready.navigation, navigation)
        XCTAssertTrue(ready.consumesToken)
    }

    func testSpaceFormDismissalGateBlocksSaveAndNfcPreparation() {
        let context = SpaceNFCContext(
            spaceId: 11,
            spaceName: "玄关柜",
            dismissFormAfterClose: true
        )
        let presentation = NFCWritePresentation(
            spaceId: 11,
            spaceName: "玄关柜",
            token: "secure-token",
            url: URL(string: "https://nfc.example.com/nfc/secure-token"),
            dismissFormAfterClose: true
        )

        XCTAssertTrue(
            spaceFormBlocksInteractiveDismiss(
                isSaving: true,
                nfcFlow: .idle
            )
        )
        XCTAssertTrue(
            spaceFormBlocksInteractiveDismiss(
                isSaving: false,
                nfcFlow: .requesting(context)
            )
        )
        XCTAssertTrue(
            spaceFormBlocksInteractiveDismiss(
                isSaving: false,
                nfcFlow: .ready(presentation)
            )
        )
        XCTAssertFalse(
            spaceFormBlocksInteractiveDismiss(
                isSaving: false,
                nfcFlow: .failed(context, message: "服务暂时不可用")
            )
        )
        XCTAssertFalse(
            spaceFormBlocksInteractiveDismiss(
                isSaving: false,
                nfcFlow: .idle
            )
        )
    }

    func testNewSpaceNfcFailureRetainsSavedSpaceForRetryOrClose() {
        let context = SpaceNFCContext(
            spaceId: 11,
            spaceName: "玄关柜",
            dismissFormAfterClose: true
        )
        var state = SpaceNFCFlowState.requesting(context)

        state.tokenRequestFailed(message: "服务暂时不可用")

        XCTAssertEqual(state.context, context)
        XCTAssertEqual(state.failureMessage, "服务暂时不可用")
        XCTAssertTrue(state.canRetry)
        XCTAssertTrue(state.shouldDismissFormAfterClose)

        state.retry()
        XCTAssertEqual(state, .requesting(context))

        state.tokenRequestSucceeded(
            token: "secure-token",
            url: URL(string: "https://nfc.example.com/nfc/secure-token")
        )
        XCTAssertEqual(state.presentation?.spaceId, 11)
        XCTAssertEqual(state.presentation?.token, "secure-token")
        XCTAssertTrue(state.presentation?.dismissFormAfterClose == true)
    }
}
