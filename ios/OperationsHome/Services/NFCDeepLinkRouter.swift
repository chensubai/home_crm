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
    case retry(message: String)

    var message: String {
        switch self {
        case let .discardToken(message), let .retry(message):
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
}

func nfcResolutionFailureDecision(for error: Error) -> NFCResolutionFailureDecision {
    if error is URLError {
        return .retry(message: "网络不可用，请联网后重试。")
    }

    if let apiError = error as? APIError {
        switch apiError {
        case let .server(statusCode, _) where statusCode == 403:
            return .discardToken(message: "你没有权限访问这个空间。")
        case let .server(statusCode, _) where statusCode == 404:
            return .discardToken(message: "该 NFC 贴纸已失效。")
        default:
            return .discardToken(
                message: apiError.errorDescription ?? "服务器响应无效"
            )
        }
    }

    return .discardToken(message: error.localizedDescription)
}

func isCurrentNfcResolution(
    resolvingToken: String,
    pendingToken: String?,
    isCancelled: Bool
) -> Bool {
    !isCancelled && pendingToken == resolvingToken
}

@MainActor
final class NFCDeepLinkRouter: ObservableObject {
    @Published private(set) var pendingToken: String?
    @Published var requestedSpaceId: Int?
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
