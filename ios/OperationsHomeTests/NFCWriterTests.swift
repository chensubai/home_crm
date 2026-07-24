import CoreNFC
import XCTest
@testable import OperationsHome

private enum TestFailure: LocalizedError {
    case write

    var errorDescription: String? {
        "写入测试失败"
    }
}

private final class FakeNFCWriter: NFCWriting {
    var isAvailable = true
    var result: Result<Void, Error> = .success(())
    private(set) var writtenURL: URL?

    func write(url: URL) async throws {
        writtenURL = url
        try result.get()
    }
}

private final class FakeNFCWriterSession: NFCWriterSession {
    var alertMessage = ""
    var connectionError: Error?
    var onInvalidate: (() -> Void)?
    private(set) var beginCount = 0
    private(set) var restartPollingCount = 0
    private(set) var invalidateCount = 0
    private(set) var invalidationMessages: [String] = []

    func begin() {
        beginCount += 1
    }

    func restartPolling() {
        restartPollingCount += 1
    }

    func connect(to tag: NFCWriterTag, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(connectionError)
    }

    func invalidate() {
        invalidateCount += 1
        onInvalidate?()
    }

    func invalidate(errorMessage: String) {
        invalidationMessages.append(errorMessage)
        onInvalidate?()
    }

    func matches(_ session: NFCNDEFReaderSession) -> Bool {
        false
    }
}

private final class FakeNFCWriterTag: NFCWriterTag {
    var status: NFCNDEFStatus = .readWrite
    var capacity = 1024
    var queryError: Error?
    var writeError: Error?
    var defersWriteCompletion = false
    private(set) var queryCount = 0
    private(set) var writtenMessage: NFCNDEFMessage?
    private var pendingWriteCompletion: ((Error?) -> Void)?

    func queryNDEFStatus(
        completionHandler: @escaping (NFCNDEFStatus, Int, Error?) -> Void
    ) {
        queryCount += 1
        completionHandler(status, capacity, queryError)
    }

    func writeNDEF(
        _ message: NFCNDEFMessage,
        completionHandler: @escaping (Error?) -> Void
    ) {
        writtenMessage = message
        if defersWriteCompletion {
            pendingWriteCompletion = completionHandler
        } else {
            completionHandler(writeError)
        }
    }

    func completeWrite(with error: Error?) {
        let completion = pendingWriteCompletion
        pendingWriteCompletion = nil
        completion?(error)
    }
}

@MainActor
final class NFCWriterTests: XCTestCase {
    private let url = URL(string: "https://nfc.example.com/nfc/ABC123")!

    func testWriteViewModelWritesExactUniversalLinkAndShowsSuccess() async {
        let writer = FakeNFCWriter()
        let model = NFCWriteViewModel(writer: writer)

        await model.write(url: url)

        XCTAssertEqual(writer.writtenURL, url)
        XCTAssertEqual(model.state, .success)
    }

    func testMissingDomainAndUnsupportedDeviceShowActionableStates() async {
        let writer = FakeNFCWriter()
        writer.isAvailable = false
        let model = NFCWriteViewModel(writer: writer)

        await model.write(url: nil)
        XCTAssertEqual(model.state, .domainUnavailable)

        await model.write(url: URL(string: "https://nfc.example.com/nfc/ABC123"))
        XCTAssertEqual(model.state, .deviceUnavailable)
    }

    func testWriteViewModelMapsCancellationToReadyAndOtherErrorsToFailure() async {
        let writer = FakeNFCWriter()
        let model = NFCWriteViewModel(writer: writer)

        writer.result = .failure(CancellationError())
        await model.write(url: url)
        XCTAssertEqual(model.state, .ready)

        writer.result = .failure(TestFailure.write)
        await model.write(url: url)
        XCTAssertEqual(model.state, .failed("写入测试失败"))
    }

    func testWriterRejectsUnavailableDeviceWithoutStartingSession() async {
        let session = FakeNFCWriterSession()
        let writer = makeWriter(available: false, session: session)

        await assertWriteError(.deviceUnavailable) {
            try await writer.write(url: url)
        }
        XCTAssertEqual(session.beginCount, 0)
    }

    func testWriterRejectsSecondWriteWhileSessionIsActive() async {
        let session = FakeNFCWriterSession()
        let writer = makeWriter(session: session)
        let firstWrite = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)

        await assertWriteError(.writeInProgress) {
            try await writer.write(url: url)
        }

        firstWrite.cancel()
        _ = try? await firstWrite.value
    }

    func testMultipleTagsRestartPollingThenSingleTagWritesExactURL() async throws {
        let session = FakeNFCWriterSession()
        let tag = FakeNFCWriterTag()
        let writer = makeWriter(session: session)
        let write = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)

        writer.handleDetectedTags([tag, FakeNFCWriterTag()], session: session)

        XCTAssertEqual(session.restartPollingCount, 1)
        XCTAssertEqual(tag.queryCount, 0)

        writer.handleDetectedTags([tag], session: session)
        try await write.value

        XCTAssertEqual(tag.writtenMessage?.records.first?.wellKnownTypeURIPayload(), url)
        XCTAssertEqual(session.invalidateCount, 1)
        XCTAssertEqual(session.alertMessage, "写入成功。")
    }

    func testNotSupportedReadOnlyAndInsufficientCapacityAreRejected() async {
        await assertTagFailure(
            status: .notSupported,
            capacity: 1024,
            expected: .tagNotSupported
        )
        await assertTagFailure(
            status: .readOnly,
            capacity: 1024,
            expected: .tagReadOnly
        )
        await assertTagFailure(
            status: .readWrite,
            capacity: 0,
            expected: .insufficientCapacity
        )
    }

    func testSuccessfulWriteCompletesOnceWhenInvalidationReentersSynchronously() async throws {
        let session = FakeNFCWriterSession()
        let tag = FakeNFCWriterTag()
        let writer = makeWriter(session: session)
        session.onInvalidate = {
            writer.handleInvalidation(TestFailure.write, session: session)
        }
        let write = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)

        writer.handleDetectedTags([tag], session: session)

        try await write.value
        writer.handleInvalidation(TestFailure.write, session: session)
    }

    func testUserCancellationAndLateInvalidationCompleteOnce() async {
        let session = FakeNFCWriterSession()
        let writer = makeWriter(session: session)
        let write = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)
        let cancellation = NSError(
            domain: NFCErrorDomain,
            code: NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue
        )

        writer.handleInvalidation(cancellation, session: session)

        await assertCancellation { try await write.value }
        writer.handleInvalidation(TestFailure.write, session: session)
    }

    func testTaskCancellationInvalidatesSessionAndIgnoresLateDelegateCallback() async {
        let session = FakeNFCWriterSession()
        let writer = makeWriter(session: session)
        let write = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)

        write.cancel()

        await assertCancellation { try await write.value }
        XCTAssertEqual(session.invalidateCount, 1)
        writer.handleInvalidation(TestFailure.write, session: session)
    }

    func testInvalidationWinsRaceWithLateWriteCallback() async {
        let session = FakeNFCWriterSession()
        let tag = FakeNFCWriterTag()
        tag.defersWriteCompletion = true
        let writer = makeWriter(session: session)
        let write = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)
        writer.handleDetectedTags([tag], session: session)

        writer.handleInvalidation(TestFailure.write, session: session)

        await assertTestFailure { try await write.value }
        tag.completeWrite(with: nil)
    }

    func testWriteViewAcceptsRequiredDependencies() {
        let writer = FakeNFCWriter()

        _ = NFCWriteView(
            spaceName: "客厅柜子",
            url: url,
            writer: writer,
            onClose: {}
        )
    }

    private func makeWriter(
        available: Bool = true,
        session: FakeNFCWriterSession
    ) -> NFCWriter {
        NFCWriter(
            availability: { available },
            sessionFactory: { _ in session }
        )
    }

    private func waitForSessionToBegin(_ session: FakeNFCWriterSession) async {
        for _ in 0..<20 where session.beginCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(session.beginCount, 1)
    }

    private func assertTagFailure(
        status: NFCNDEFStatus,
        capacity: Int,
        expected: NFCWriterError
    ) async {
        let session = FakeNFCWriterSession()
        let tag = FakeNFCWriterTag()
        tag.status = status
        tag.capacity = capacity
        let writer = makeWriter(session: session)
        let write = Task { try await writer.write(url: url) }
        await waitForSessionToBegin(session)

        writer.handleDetectedTags([tag], session: session)

        await assertWriteError(expected) { try await write.value }
        XCTAssertEqual(session.invalidationMessages.count, 1)
    }

    private func assertWriteError(
        _ expected: NFCWriterError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch {
            XCTAssertEqual(error as? NFCWriterError, expected)
        }
    }

    private func assertCancellation(
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    private func assertTestFailure(
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected test failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, TestFailure.write.localizedDescription)
        }
    }
}
