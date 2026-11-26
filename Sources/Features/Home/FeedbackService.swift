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
                return "The game service did not answer."
            }
        }
    }

    static let minimumLength = 4
    static let maximumLength = 2000

    static var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    /// Saves the feedback and starts sending it.
    ///
    /// Returns once the note is on disk, not once the database has it: the
    /// outbox owns delivery from then on. The sheet can say "sent" straight
    /// away, and a connection that drops or a phone that is put away cannot
    /// take the note with it.
    static func send(_ text: String,
                     from source: Source,
                     game: String?) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLength else { throw Failure.tooShort }
        guard trimmed.count <= maximumLength else { throw Failure.tooLong }

        guard let database = FirebaseBootstrapper.database else {
            throw Failure.unavailable(
                FirebaseBootstrapper.unavailableReason?.explanation
                    ?? "Sending needs a connection to the game service."
            )
        }

        try await FeedbackOutbox.shared.enqueue(
            text: trimmed,
            source: source.rawValue,
            game: game.flatMap { $0.isEmpty ? nil : $0 }
        )

        // Try at once, but do not make the sheet wait for the round trip. If
        // this task is cut short, `retryPending` and the reconnect observer
        // pick the note up; if the app dies, it is already on disk.
        Task { await flushPending() }
    }

    /// Retries anything left from a previous launch or a failed send.
    static func flushPending() async {
        guard isAvailable, let database = FirebaseBootstrapper.database else { return }
        _ = await FeedbackOutbox.shared.flush { note in
            try await post(note, database: database)
        }
    }

    /// Keeps the outbox moving while the app is in front of somebody.
    ///
    /// The disk copy is the guarantee; this is what makes the guarantee become
    /// "arrived" without needing the person to close and reopen the app, or to
    /// send another note to kick the queue.
    static func retryPending() async {
        while !Task.isCancelled {
            await flushPending()
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }

    /// Flushes as soon as the Realtime Database reconnects, rather than waiting
    /// for the next retry tick. Called once, while the app is starting.
    static func observeConnection() {
        guard let database = FirebaseBootstrapper.database else { return }
        database.reference(withPath: ".info/connected").observe(.value) { snapshot in
            guard snapshot.value as? Bool == true else { return }
            Task { await flushPending() }
        }
    }

    /// Writes one note, waiting no longer than fifteen seconds for an answer.
    ///
    /// A `setValue` with no connection can wait indefinitely. The timeout lets
    /// the sheet finish rather than staying on "Sending…" until the phone is put
    /// away; the note is already on disk.
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
