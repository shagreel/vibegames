import SwiftUI

/// Destinations the hub can navigate to. Add a case per playable game.
enum GameRoute: Hashable {
    case vibeFive
    case vibeWords
    case vibeSudoku
    case vibeTrio
    case vibeBlurt
    case vibeTen
}

/// A tile on the hub home screen.
struct GameEntry: Identifiable {
    let id: String
    /// `nil` means the game is announced but not playable yet.
    let route: GameRoute?
    let title: String
    let tagline: String
    let symbol: String
    let gradient: LinearGradient

    var isAvailable: Bool { route != nil }

    static let all: [GameEntry] = [
        GameEntry(
            id: "vibe-five",
            route: .vibeFive,
            title: "Vibe Five",
            tagline: "Name three things before the buzzer.",
            symbol: "5.circle.fill",
            gradient: VibeTheme.vibeFive
        ),
        GameEntry(
            id: "vibe-words",
            route: .vibeWords,
            title: "Word Vibe",
            tagline: "Guess the five-letter word. First to solve wins.",
            symbol: "textformat.abc",
            gradient: VibeTheme.vibeWords
        ),
        GameEntry(
            id: "vibe-sudoku",
            route: .vibeSudoku,
            title: "Number Vibe",
            tagline: "Fill the grid. Race your friends to it.",
            symbol: "square.grid.3x3.fill",
            gradient: VibeTheme.vibeSudoku
        ),
        GameEntry(
            id: "vibe-trio",
            route: .vibeTrio,
            title: "Vibe Pairings",
            tagline: "Three cards where every feature matches or differs.",
            symbol: "square.on.square.dashed",
            gradient: VibeTheme.vibeTrio
        ),
        GameEntry(
            id: "vibe-ten",
            route: .vibeTen,
            title: "Vibe Ten",
            tagline: "Pair the digits. Clear the board. First to clear it wins.",
            symbol: "10.circle.fill",
            gradient: VibeTheme.vibeTen
        ),
        GameEntry(
            id: "vibe-blurt",
            route: .vibeBlurt,
            title: "Similar Vibe",
            tagline: "Describe it. Don't say it. Two teams, one word.",
            symbol: "bubble.left.and.exclamationmark.bubble.right.fill",
            gradient: VibeTheme.vibeBlurt
        )
    ]
}
