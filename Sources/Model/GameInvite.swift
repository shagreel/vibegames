import Foundation

/// What to send when inviting somebody to a shared game.
///
/// It used to be a code and an instruction to open the app, which means the
/// person on the other end has to install something before they can play. The
/// browser takes the same room in a link, so the invite carries one: one tap and
/// they are in the game, and the code is still there for anyone who would rather
/// use the app.
///
/// One definition, so the four games cannot word the invitation four ways — and
/// so the path in the link is written down once rather than remembered.
enum GameInvite {

    /// The browser's route for a game.
    ///
    /// Not the analytics name: this is the address the website serves, and it is
    /// what the link has to point at.
    static func path(for game: AppAnalytics.Game) -> String {
        switch game {
        case .five: return "five"
        case .words: return "words"
        case .sudoku: return "sudoku"
        case .trio: return "trio"
        case .blurt: return "blurt"
        case .ten: return "ten"
        }
    }

    /// The room, as a link into the browser version.
    static func link(game: AppAnalytics.Game, code: String) -> String {
        "https://play.vibegames.party/\(path(for: game))?game=\(code)"
    }

    /// The whole invitation: the link, and the code for anybody using the app.
    static func text(game: AppAnalytics.Game, code: String) -> String {
        "Join my \(game.title) game — \(link(game: game, code: code)) — "
            + "or open the app and enter code \(GameCode.display(code))."
    }
}
