import Combine
import CoreNFC
import Foundation

protocol NFCWriting {
    var isAvailable: Bool { get }
    func write(url: URL) async throws
}

enum NFCWriteState: Equatable {
    case ready
    case writing
    case success
    case domainUnavailable
    case deviceUnavailable
    case failed(String)
}

@MainActor
final class NFCWriteViewModel: ObservableObject {
    @Published private(set) var state: NFCWriteState = .ready

    private let writer: NFCWriting

    init(writer: NFCWriting) {
        self.writer = writer
    }

    func write(url: URL?) async {
        guard let url else {
            state = .domainUnavailable
            return
        }
        guard writer.isAvailable else {
            state = .deviceUnavailable
            return
        }

        state = .writing
        do {
            try await writer.write(url: url)
            state = .success
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

enum NFCWriterError: LocalizedError, Equatable {
    case deviceUnavailable
    case invalidURL
    case writeInProgress
    case tagNotSupported
    case tagReadOnly
    case insufficientCapacity

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            "此设备不支持 NFC 写入。"
        case .invalidURL:
            "无法创建 NFC 链接内容。"
        case .writeInProgress:
            "已有 NFC 写入正在进行。"
        case .tagNotSupported:
            "此 NFC 贴纸不支持 NDEF 写入。"
        case .tagReadOnly:
            "此 NFC 贴纸为只读，无法写入。"
        case .insufficientCapacity:
            "NFC 贴纸容量不足，无法写入此链接。"
        }
    }
}

protocol NFCWriterSession: AnyObject {
    var alertMessage: String { get set }

    func begin()
    func restartPolling()
    func connect(to tag: NFCWriterTag, completionHandler: @escaping (Error?) -> Void)
    func invalidate()
    func invalidate(errorMessage: String)
    func matches(_ session: NFCNDEFReaderSession) -> Bool
}

protocol NFCWriterTag: AnyObject {
    func queryNDEFStatus(
        completionHandler: @escaping (NFCNDEFStatus, Int, Error?) -> Void
    )
    func writeNDEF(
        _ message: NFCNDEFMessage,
        completionHandler: @escaping (Error?) -> Void
    )
}

final class NFCWriter: NSObject, NFCWriting, NFCNDEFReaderSessionDelegate {
    typealias SessionFactory = (NFCNDEFReaderSessionDelegate) -> NFCWriterSession

    private final class ActiveWrite {
        let continuation: CheckedContinuation<Void, Error>
        let session: NFCWriterSession
        let message: NFCNDEFMessage
        let cancellation: WriteCancellation
        var isProcessingTag = false

        init(
            continuation: CheckedContinuation<Void, Error>,
            session: NFCWriterSession,
            message: NFCNDEFMessage,
            cancellation: WriteCancellation
        ) {
            self.continuation = continuation
            self.session = session
            self.message = message
            self.cancellation = cancellation
        }
    }

    private final class WriteCancellation {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }

    private enum Invalidation {
        case none
        case silent
        case message(String)
    }

    private let availability: () -> Bool
    private let sessionFactory: SessionFactory
    private let lock = NSLock()
    private var activeWrite: ActiveWrite?

    var isAvailable: Bool {
        availability()
    }

    init(
        availability: @escaping () -> Bool = { NFCNDEFReaderSession.readingAvailable },
        sessionFactory: @escaping SessionFactory = {
            CoreNFCWriterSession(delegate: $0)
        }
    ) {
        self.availability = availability
        self.sessionFactory = sessionFactory
        super.init()
    }

    func write(url: URL) async throws {
        guard isAvailable else {
            throw NFCWriterError.deviceUnavailable
        }
        guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(
            string: url.absoluteString
        ) else {
            throw NFCWriterError.invalidURL
        }

        let message = NFCNDEFMessage(records: [payload])
        let cancellation = WriteCancellation()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                startWrite(
                    message: message,
                    cancellation: cancellation,
                    continuation: continuation
                )
            }
        } onCancel: { [weak self] in
            cancellation.cancel()
            self?.cancelWrite(matching: cancellation)
        }
    }

    func readerSession(
        _ session: NFCNDEFReaderSession,
        didInvalidateWithError error: Error
    ) {
        guard let writerSession = activeSession(matching: session) else { return }
        handleInvalidation(error, session: writerSession)
    }

    func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {}

    func readerSession(
        _ session: NFCNDEFReaderSession,
        didDetect tags: [NFCNDEFTag]
    ) {
        guard let writerSession = activeSession(matching: session) else { return }
        handleDetectedTags(
            tags.map(CoreNFCWriterTag.init),
            session: writerSession
        )
    }

    func handleDetectedTags(
        _ tags: [NFCWriterTag],
        session: NFCWriterSession
    ) {
        lock.lock()
        guard let activeWrite,
              activeWrite.session === session,
              !activeWrite.isProcessingTag else {
            lock.unlock()
            return
        }

        guard tags.count == 1, let tag = tags.first else {
            lock.unlock()
            session.alertMessage = "检测到多个 NFC 贴纸，请只保留一个后重试。"
            session.restartPolling()
            return
        }

        activeWrite.isProcessingTag = true
        lock.unlock()

        session.connect(to: tag) { [weak self, weak session] error in
            guard let self, let session else { return }
            if let error {
                self.finish(
                    .failure(error),
                    session: session,
                    invalidation: .message(error.localizedDescription)
                )
                return
            }
            self.queryStatus(of: tag, session: session)
        }
    }

    func handleInvalidation(
        _ error: Error,
        session: NFCWriterSession
    ) {
        let result: Result<Void, Error>
        if Self.isUserCancellation(error) {
            result = .failure(CancellationError())
        } else {
            result = .failure(error)
        }
        finish(result, session: session, invalidation: .none)
    }

    private func startWrite(
        message: NFCNDEFMessage,
        cancellation: WriteCancellation,
        continuation: CheckedContinuation<Void, Error>
    ) {
        let session = sessionFactory(self)

        lock.lock()
        let startError: Error?
        if activeWrite != nil {
            startError = NFCWriterError.writeInProgress
        } else if cancellation.isCancelled {
            startError = CancellationError()
        } else {
            activeWrite = ActiveWrite(
                continuation: continuation,
                session: session,
                message: message,
                cancellation: cancellation
            )
            session.alertMessage = "将 iPhone 顶部靠近 NFC 贴纸。"
            session.begin()
            startError = nil
        }
        lock.unlock()

        if let startError {
            continuation.resume(throwing: startError)
            return
        }
    }

    private func cancelWrite(matching cancellation: WriteCancellation) {
        lock.lock()
        guard let activeWrite,
              activeWrite.cancellation === cancellation else {
            lock.unlock()
            return
        }
        self.activeWrite = nil
        lock.unlock()

        activeWrite.session.invalidate()
        activeWrite.continuation.resume(throwing: CancellationError())
    }

    private func queryStatus(
        of tag: NFCWriterTag,
        session: NFCWriterSession
    ) {
        tag.queryNDEFStatus { [weak self, weak session] status, capacity, error in
            guard let self, let session else { return }
            if let error {
                self.finish(
                    .failure(error),
                    session: session,
                    invalidation: .message(error.localizedDescription)
                )
                return
            }

            guard let message = self.activeMessage(for: session) else { return }
            switch status {
            case .notSupported:
                self.fail(.tagNotSupported, session: session)
            case .readOnly:
                self.fail(.tagReadOnly, session: session)
            case .readWrite:
                guard capacity >= message.length else {
                    self.fail(.insufficientCapacity, session: session)
                    return
                }
                self.write(message, to: tag, session: session)
            @unknown default:
                self.fail(.tagNotSupported, session: session)
            }
        }
    }

    private func write(
        _ message: NFCNDEFMessage,
        to tag: NFCWriterTag,
        session: NFCWriterSession
    ) {
        tag.writeNDEF(message) { [weak self, weak session] error in
            guard let self, let session else { return }
            if let error {
                self.finish(
                    .failure(error),
                    session: session,
                    invalidation: .message(error.localizedDescription)
                )
                return
            }

            session.alertMessage = "写入成功。"
            self.finish(.success(()), session: session, invalidation: .silent)
        }
    }

    private func fail(
        _ error: NFCWriterError,
        session: NFCWriterSession
    ) {
        finish(
            .failure(error),
            session: session,
            invalidation: .message(error.localizedDescription)
        )
    }

    private func finish(
        _ result: Result<Void, Error>,
        session: NFCWriterSession,
        invalidation: Invalidation
    ) {
        lock.lock()
        guard let activeWrite, activeWrite.session === session else {
            lock.unlock()
            return
        }
        self.activeWrite = nil
        lock.unlock()

        switch invalidation {
        case .none:
            break
        case .silent:
            session.invalidate()
        case let .message(message):
            session.invalidate(errorMessage: message)
        }
        activeWrite.continuation.resume(with: result)
    }

    private func activeSession(
        matching readerSession: NFCNDEFReaderSession
    ) -> NFCWriterSession? {
        lock.lock()
        defer { lock.unlock() }
        guard let session = activeWrite?.session,
              session.matches(readerSession) else {
            return nil
        }
        return session
    }

    private func activeMessage(
        for session: NFCWriterSession
    ) -> NFCNDEFMessage? {
        lock.lock()
        defer { lock.unlock() }
        guard let activeWrite, activeWrite.session === session else {
            return nil
        }
        return activeWrite.message
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NFCErrorDomain
            && error.code
                == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue
    }
}

private final class CoreNFCWriterSession: NFCWriterSession {
    private let session: NFCNDEFReaderSession

    var alertMessage: String {
        get { session.alertMessage }
        set { session.alertMessage = newValue }
    }

    init(delegate: NFCNDEFReaderSessionDelegate) {
        session = NFCNDEFReaderSession(
            delegate: delegate,
            queue: .main,
            invalidateAfterFirstRead: false
        )
    }

    func begin() {
        session.begin()
    }

    func restartPolling() {
        session.restartPolling()
    }

    func connect(
        to tag: NFCWriterTag,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let tag = tag as? CoreNFCWriterTag else {
            completionHandler(NFCWriterError.tagNotSupported)
            return
        }
        session.connect(to: tag.tag, completionHandler: completionHandler)
    }

    func invalidate() {
        session.invalidate()
    }

    func invalidate(errorMessage: String) {
        session.invalidate(errorMessage: errorMessage)
    }

    func matches(_ session: NFCNDEFReaderSession) -> Bool {
        self.session === session
    }
}

private final class CoreNFCWriterTag: NFCWriterTag {
    let tag: NFCNDEFTag

    init(tag: NFCNDEFTag) {
        self.tag = tag
    }

    func queryNDEFStatus(
        completionHandler: @escaping (NFCNDEFStatus, Int, Error?) -> Void
    ) {
        tag.queryNDEFStatus(completionHandler: completionHandler)
    }

    func writeNDEF(
        _ message: NFCNDEFMessage,
        completionHandler: @escaping (Error?) -> Void
    ) {
        tag.writeNDEF(message, completionHandler: completionHandler)
    }
}
