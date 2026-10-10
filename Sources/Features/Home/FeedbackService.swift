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

        var errorDescription: String? {
            switch self {
            case .tooShort:
                return "Please write a little more."
            case .tooLong:
                return "Please keep it under \(FeedbackService.maximumLength) characters."
            case .unavailable(let reason):
                return reason
            }
        }
    }

    static let minimumLength = 4
    static let maximumLength = 2000

    static var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    /// Posts the feedback and returns once the database has it.
    ///
    /// Throws rather than failing quietly: "Sent, thank you" for a message that
    /// went nowhere is worse than an error, because the person then believes
    /// they have been heard.
    static func send(_ text: String,
                     from source: Source,
                     game: String?) async throws {
        guard let database = FirebaseBootstrapper.database else {
            throw Failure.unavailable(
                FirebaseBootstrapper.unavailableReason?.explanation
                    ?? "Sending needs a connection to the game service."
            )
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumLength else { throw Failure.tooShort }
        guard trimmed.count <= maximumLength else { throw Failure.tooLong }

        var payload: [String: Any] = [
            "text": trimmed,
            "source": source.rawValue,
            "createdAt": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let game, !game.isEmpty { payload["game"] = game }

        // childByAutoId rather than a timestamp: two people writing at the same
        // moment must not land on the same key.
        try await database.reference(withPath: "feedback")
            .childByAutoId()
            .setValue(payload)
    }
}
