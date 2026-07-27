import Combine
import Foundation

struct NFCNavigationDecision: Equatable {
    let familyId: Int
    let spaceId: Int
}

func nfcNavigationDecision(
    destination: NFCSpaceDestinationDTO,
    availableFamilyIds: Set<Int>
) -> NFCNavigationDecision? {
    availableFamilyIds.contains(destination.familyId)
        ? NFCNavigationDecision(
            familyId: destination.familyId,
            spaceId: destination.spaceId
        )
        : nil
}

enum NFCResolutionFailureDecision: Equatable {
    case discardToken(message: String)
    case reauthenticate(message: String)
    case retry(message: String)

    var message: String {
        switch self {
        case let .discardToken(message),
             let .reauthenticate(message),
             let .retry(message):
            message
        }
    }

    var consumesToken: Bool {
        if case .discardToken = self {
            return true
        }
        return false
    }

    var offersRetry: Bool {
        if case .retry = self {
            return true
        }
        return false
    }

    var requiresAuthentication: Bool {
        if case .reauthenticate = self {
            return true
        }
        return false
    }
}

func nfcResolutionFailureDecision(for error: Error) -> NFCResolutionFailureDecision {
    if error is URLError {
        return .retry(message: "网络不可用，请联网后重试。")
    }

    if let apiError = error as? APIError {
        switch apiError {
        case let .server(statusCode, _) where statusCode == 401:
            return .reauthenticate(
                message: "登录状态已失效，请重新登录后继续。"
            )
        case let .server(statusCode, _) where statusCode == 403:
            return .discardToken(message: "你没有权限访问这个空间。")
        case let .server(statusCode, _) where statusCode == 404:
            return .discardToken(message: "该 NFC 贴纸已失效。")
        default:
            return .retry(
                message: apiError.errorDescription ?? "服务器响应无效"
            )
        }
    }

    return .retry(message: error.localizedDescription)
}

func isCurrentNfcResolution(
    resolvingToken: String,
    pendingToken: String?,
    isCancelled: Bool
) -> Bool {
    !isCancelled && pendingToken == resolvingToken
}

enum NFCNavigationCommitDecision: Equatable {
    case navigate(NFCNavigationDecision)
    case retry(message: String)
    case ignore

    var consumesToken: Bool {
        if case .navigate = self {
            return true
        }
        return false
    }

    var navigation: NFCNavigationDecision? {
        if case let .navigate(decision) = self {
            return decision
        }
        return nil
    }
}

func nfcNavigationCommitDecision(
    navigation: NFCNavigationDecision,
    syncSucceeded: Bool,
    targetIsReady: Bool,
    resolvingToken: String,
    pendingToken: String?,
    isCancelled: Bool
) -> NFCNavigationCommitDecision {
    guard isCurrentNfcResolution(
        resolvingToken: resolvingToken,
        pendingToken: pendingToken,
        isCancelled: isCancelled
    ) else {
        return .ignore
    }

    guard syncSucceeded, targetIsReady else {
        return .retry(message: "网络不可用，请联网后重试。")
    }

    return .navigate(navigation)
}

private enum NFCDeepLinkContinuationError: LocalizedError {
    case retry(message: String)

    var errorDescription: String? {
        switch self {
        case let .retry(message):
            message
        }
    }
}

@MainActor
func continuePendingNfcLink(
    router: NFCDeepLinkRouter,
    authenticationToken: String,
    families: [FamilyDTO],
    resolve: (String, String) async throws -> NFCSpaceDestinationDTO,
    reloadFamilies: (String) async throws -> [FamilyDTO],
    updateFamilies: ([FamilyDTO]) -> Void,
    sync: (Int, String) async -> Bool,
    targetIsReady: (Int, Int) -> Bool,
    navigate: (NFCNavigationDecision) -> Void
) async throws {
    guard let pendingToken = router.pendingToken else {
        return
    }

    func isCurrent() -> Bool {
        isCurrentNfcResolution(
            resolvingToken: pendingToken,
            pendingToken: router.pendingToken,
            isCancelled: Task.isCancelled
        )
    }

    let destination = try await resolve(pendingToken, authenticationToken)
    guard isCurrent() else {
        return
    }

    var availableFamilies = families
    if !availableFamilies.contains(where: { $0.id == destination.familyId }) {
        availableFamilies = try await reloadFamilies(authenticationToken)
        guard isCurrent() else {
            return
        }
        updateFamilies(availableFamilies)
    }

    guard let navigation = nfcNavigationDecision(
        destination: destination,
        availableFamilyIds: Set(availableFamilies.map(\.id))
    ) else {
        throw APIError.server(
            statusCode: 403,
            message: "你没有权限访问这个空间。"
        )
    }

    let syncSucceeded = await sync(navigation.familyId, authenticationToken)
    let ready = syncSucceeded && targetIsReady(
        navigation.spaceId,
        navigation.familyId
    )

    switch nfcNavigationCommitDecision(
        navigation: navigation,
        syncSucceeded: syncSucceeded,
        targetIsReady: ready,
        resolvingToken: pendingToken,
        pendingToken: router.pendingToken,
        isCancelled: Task.isCancelled
    ) {
    case let .navigate(decision):
        navigate(decision)
        router.consumePendingToken()
    case let .retry(message):
        throw NFCDeepLinkContinuationError.retry(message: message)
    case .ignore:
        return
    }
}

@MainActor
final class NFCDeepLinkRouter: ObservableObject {
    @Published private(set) var pendingToken: String?
    @Published var message: String?

    private let defaults: UserDefaults
    private let storageKey = "pendingNfcToken"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pendingToken = defaults.string(forKey: storageKey)
    }

    func token(from url: URL) -> String? {
#if DEBUG
        if url.scheme == "operationshome", url.host == "nfc" {
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? ""
            let parts = path.components(separatedBy: "/")
            guard parts.count == 2,
                  parts[0].isEmpty,
                  let token = parts[1].nonEmpty else {
                return nil
            }
            return token
        }
#endif
        guard url.scheme == "https" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "nfc" else { return nil }
        return parts[1].nonEmpty
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let token = token(from: url) else { return false }
        pendingToken = token
        defaults.set(token, forKey: storageKey)
        return true
    }

    func consumePendingToken() {
        pendingToken = nil
        defaults.removeObject(forKey: storageKey)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
