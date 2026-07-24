import Combine
import Foundation

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
