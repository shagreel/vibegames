import Foundation
import FirebaseDatabase

/// Sending feedback from inside the app.
///
/// Nobody playing these games has a GitHub account, and asking them to make one
/// to report a bug means the bug never gets reported. So the app posts to an
/// inbox in the database — a write-only node anyone can add to — and a scheduled
/// GitHub Action drains it into issues on the repository.
///
/// There is no token here and none anywhere else. That is the whole reason for
/// the two-step: a token in a client is a token anyone can read out of it.
enum FeedbackService {

    /// The rules accept only these two, so a typo cannot invent a third source.
    enum Source: String {
        case ios
        case web
    }

    enum Failure: LocalizedError {
        case tooShort
        case tooLong
        case unavailable(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .tooShort:
                return "Please write a little more."
            case .tooLong:
                return "Please keep it under \(FeedbackService.maximumLength) characters."
            case .unavailable(let reason):
                return reason
            case .timedOut:
                return "The game service did not answer. Your note is saved and will send when it can."
            }
        }
    }

    /// What happened to a note.
    enum Delivery: Equatable {
        /// The database has it.
        case sent
        /// It is on disk and will be retried; nothing is lost.
        case queued
    }

    static let minimumLength = 4
    static let maximumLength = 2000

    static var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    /// Posts the feedback, or saves it for the next attempt.
    ///
    /// A note is written to disk before the first attempt. If the database
    /// answers, it is removed and the caller can say it arrived. If it does not,
    /// the note stays in the outbox and is retried on the next launch or
    /// foreground — so closing the app is no longer a way to lose a report.
    static func send(_ text: String,
                     from source: Source,
                     game: String?) async throws -> Delivery {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLength else { throw Failure.tooShort }
        guard trimmed.count <= maximumLength else { throw Failure.tooLong }

        guard let database = FirebaseBootstrapper.database else {
            throw Failure.unavailable(
                FirebaseBootstrapper.unavailableReason?.explanation
                    ?? "Sending needs a connection to the game service."
            )
        }

        let note = try await FeedbackOutbox.shared.enqueue(
            text: trimmed,
            source: source.rawValue,
            game: game.flatMap { $0.isEmpty ? nil : $0 }
        )

        let delivered = await FeedbackOutbox.shared.flush { note in
            try await post(note, database: database)
        }
        return delivered.contains(note.id) ? .sent : .queued
    }

    /// Retries anything left from a previous launch or a failed send.
    static func flushPending() async {
        guard isAvailable, let database = FirebaseBootstrapper.database else { return }
        _ = await FeedbackOutbox.shared.flush { note in
            try await post(note, database: database)
        }
    }

    /// Writes one note, waiting no longer than fifteen seconds for an answer.
    ///
    /// A `setValue` with no connection can wait indefinitely. The timeout is
    /// what lets the sheet say "saved" instead of staying on "Sending…" until
    /// the phone is put away.
    private static func post(_ note: FeedbackOutbox.Note,
                             database: Database) async throws {
        let reference = database.reference(withPath: "feedback").child(note.id)

        var payload: [String: Any] = [
            "text": note.text,
            "source": note.source,
            "createdAt": note.createdAt,
        ]
        // The rules cap this at forty; a title is shorter than that, but a note
        // must never be rejected because a future game title is not.
        if let game = note.game { payload["game"] = String(game.prefix(40)) }

        do {
            try await write(payload, to: reference)
        } catch let error as NSError where error.domain == "com.firebase" && error.code == 1 {
            // The rules only refuse a new entry when that key already exists.
            // Its own id means a previous attempt reached the server and the
            // acknowledgement did not: the note arrived, so do not write twice.
            return
        }
    }

    /// The write, with a deadline.
    ///
    /// A completion block rather than the async overload because the async
    /// overload has no timeout, and a phone with no signal can leave it waiting
    /// for as long as the app lives.
    private static func write(_ payload: [String: Any],
                              to reference: DatabaseReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let lock = NSLock()
            var finished = false

            func finish(_ result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                continuation.resume(with: result)
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15) {
                finish(.failure(Failure.timedOut))
            }

            reference.setValue(payload) { error, _ in
                if let error {
                    finish(.failure(error))
                } else {
                    finish(.success(()))
                }
            }
        }
    }
}
