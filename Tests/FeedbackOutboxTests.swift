import XCTest
@testable import VibeGames

/// The feedback outbox is the difference between "the send failed" and "the note
/// is gone". These use a temporary file rather than the real one.
final class FeedbackOutboxTests: XCTestCase {

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("feedback-outbox-\(UUID().uuidString).json")
    }

    func testANoteSurvivesARestartAndLeavesOnlyAfterItIsSent() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let outbox = FeedbackOutbox(fileURL: url)
        let note = try await outbox.enqueue(text: "The dice show the old roll.",
                                            source: "ios",
                                            game: "Dice")

        // A fresh reader is what a relaunch does.
        let reloaded = FeedbackOutbox(fileURL: url)
        let before = await reloaded.pending
        XCTAssertEqual(before, [note], "the note was on disk before it was sent")

        var attempted: [String] = []
        let delivered = await reloaded.flush { item in
            attempted.append(item.id)
            throw NSError(domain: "test", code: 1)
        }
        XCTAssertTrue(delivered.isEmpty)
        XCTAssertEqual(attempted, [note.id], "a failure stops the flush rather than skipping ahead")

        let afterFailure = await reloaded.pending
        XCTAssertEqual(afterFailure, [note], "a failed send keeps the note")

        let sent = await reloaded.flush { _ in }
        XCTAssertEqual(sent, [note.id])

        let afterSuccess = await reloaded.pending
        XCTAssertTrue(afterSuccess.isEmpty, "only a delivered note is removed")
    }

    func testTheOldestNoteIsSentFirstAndHoldsTheQueue() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let outbox = FeedbackOutbox(fileURL: url)
        let first = try await outbox.enqueue(text: "First note", source: "ios", game: nil)
        let second = try await outbox.enqueue(text: "Second note", source: "ios", game: nil)

        var attempted: [String] = []
        let delivered = await outbox.flush { item in
            attempted.append(item.id)
            throw NSError(domain: "test", code: 1)
        }

        XCTAssertTrue(delivered.isEmpty)
        XCTAssertEqual(attempted, [first.id], "the second note waits behind the first")
        let pending = await outbox.pending
        XCTAssertEqual(pending, [first, second], "both are still safe")

        let all = await outbox.flush { _ in }
        XCTAssertEqual(all, [first.id, second.id])
        let empty = await outbox.pending
        XCTAssertTrue(empty.isEmpty)
    }
}
