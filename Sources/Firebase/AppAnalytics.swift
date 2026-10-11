import Foundation
import FirebaseAnalytics

/// What the app tells Analytics, in one place.
///
/// A single file earns its keep twice over. The events cannot drift apart
/// between the games — a report is only worth reading if a game start is
/// spelled the same way everywhere — and the values match the ones the web
/// client sends, so the two can be read side by side.
///
/// **Nothing here identifies anybody.** No names, no game codes, no free text
/// from the feedback box. These are counts of things happening, which is all
/// that is wanted and all that should ever be sent.
///
/// Every method is a no-op until Firebase is configured, so a checkout with no
/// `GoogleService-Info.plist` — where solo play still works — logs nothing and
/// breaks nothing.
///
/// One thing is deliberately *not* here: an "app launched" event. Analytics
/// already records `first_open` and `session_start` on its own, with the
/// retention and engagement reporting built around them, and a hand-rolled
/// duplicate would only be a worse version of the same number.
enum AppAnalytics {

    /// Every game. The raw values are the web client's route names, so
    /// `vibe-trio` means one thing across both apps rather than three.
    enum Game: String {
        case five = "vibe-five"
        case words = "vibe-words"
        case sudoku = "vibe-sudoku"
        case trio = "vibe-trio"
        case blurt = "vibe-blurt"

        /// What the game is called on screen. Here rather than at each call
        /// site so the heart button and the note it sends cannot disagree.
        var title: String {
            switch self {
            case .five: return "Vibe Five"
            case .words: return "Vibe Words"
            case .sudoku: return "Vibe Sudoku"
            case .trio: return "Vibe Trio"
            case .blurt: return "Vibe Blurt"
            }
        }
    }

    enum Mode: String {
        case solo
        case shared
    }

    enum Outcome: String {
        case won
        case lost
        /// The game reached its own end without anybody winning it. Vibe Trio is
        /// the case: the deck runs out, and the score is the result.
        case completed
    }

    // MARK: - Setup

    /// Turns collection on. Called from the bootstrapper, after
    /// `FirebaseApp.configure()` has succeeded.
    ///
    /// Collecting is on by default; this says so out loud, in the same spirit as
    /// the Crashlytics call next to it. Note that the switch that actually
    /// decides whether anything leaves the device is in the Firebase console —
    /// a plist written before Analytics was enabled there carries
    /// `IS_ANALYTICS_ENABLED = false`.
    static func start() {
        guard FirebaseBootstrapper.isConfigured else { return }
        Analytics.setAnalyticsCollectionEnabled(true)
    }

    // MARK: - The four screens

    /// Which game people open. This is the step before `gameStart`, and the
    /// difference between the two is the interesting part: a game that is opened
    /// and never started has a lobby problem, not a game problem.
    static func screen(_ name: String) {
        log(AnalyticsEventScreenView, [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name,
        ])
    }

    /// The same, for a game, so the name cannot be misspelled at the
    /// call site and matches the web client's.
    static func screen(_ game: Game) {
        screen(game.rawValue)
    }

    // MARK: - Playing

    /// - Parameters:
    ///   - pack: Vibe Five's pack, when the round came from a named one.
    ///   - grade: Vibe Sudoku's difficulty.
    ///   - round: which round of a pass-the-phone game this is.
    static func gameStart(_ game: Game,
                          mode: Mode,
                          pack: String? = nil,
                          grade: String? = nil,
                          round: Int? = nil) {
        var parameters: [String: Any] = [
            "game_name": game.rawValue,
            "mode": mode.rawValue,
        ]
        if let pack { parameters["pack"] = pack }
        if let grade { parameters["grade"] = grade }
        if let round { parameters["round"] = round }
        log("game_start", parameters)
    }

    /// - Parameters:
    ///   - score: whatever the game counts. Comparable within a game, not across.
    ///   - seconds: how long it took, when the game has a notion of that.
    ///   - round: which round of a pass-the-phone game this was.
    static func gameFinish(_ game: Game,
                           mode: Mode,
                           outcome: Outcome,
                           score: Int? = nil,
                           seconds: Int? = nil,
                           round: Int? = nil) {
        var parameters: [String: Any] = [
            "game_name": game.rawValue,
            "mode": mode.rawValue,
            "outcome": outcome.rawValue,
        ]
        if let score { parameters["score"] = score }
        if let seconds { parameters["seconds"] = seconds }
        if let round { parameters["round"] = round }
        log("game_finish", parameters)
    }

    // MARK: - Around the games

    /// Someone sent a note. Worth knowing the form works, and roughly how often
    /// people bother — not what they wrote.
    static func feedbackSent(game: Game? = nil) {
        log("feedback_sent", game.map { ["game_name": $0.rawValue] } ?? [:])
    }

    /// The heart was tapped. This is the top of the donation funnel, and the
    /// step that says whether anyone finds it at all.
    static func supportOpened(game: Game? = nil) {
        log("support_open", game.map { ["game_name": $0.rawValue] } ?? [:])
    }

    /// The Venmo link was followed. Nothing comes back from Venmo, so this is
    /// the only signal that a treat was ever on its way.
    static func donationTapped() {
        log("donation_tap")
    }

    // Note: there is no `share` event here. iOS shares through `ShareLink`,
    // which offers no way to observe a tap, and a `simultaneousGesture` on top
    // of it is a guess rather than a measurement. The web client logs `share`,
    // where the click is an ordinary handler — so that count is web-only, and
    // knowingly so rather than by oversight.

    // MARK: - Plumbing

    /// The one place an event is actually sent. The names above are the wire
    /// format: snake_case, no spaces, and short enough for Analytics' limits.
    private static func log(_ name: String, _ parameters: [String: Any] = [:]) {
        guard FirebaseBootstrapper.isConfigured else { return }
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }
}
