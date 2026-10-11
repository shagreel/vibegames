import SwiftUI

/// Destinations the hub can navigate to. Add a case per playable game.
enum GameRoute: Hashable {
    case vibeFive
    case vibeWords
    case vibeSudoku
    case vibeTrio
    case vibeBlurt
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
            title: "Vibe Words",
            tagline: "Guess the five-letter word. First to solve wins.",
            symbol: "textformat.abc",
            gradient: VibeTheme.vibeWords
        ),
        GameEntry(
            id: "vibe-sudoku",
            route: .vibeSudoku,
            title: "Vibe Sudoku",
            tagline: "Fill the grid. Race your friends to it.",
            symbol: "square.grid.3x3.fill",
            gradient: VibeTheme.vibeSudoku
        ),
        GameEntry(
            id: "vibe-trio",
            route: .vibeTrio,
            title: "Vibe Trio",
            tagline: "Three cards where every feature matches or differs.",
            symbol: "square.on.square.dashed",
            gradient: VibeTheme.vibeTrio
        ),
        GameEntry(
            id: "vibe-blurt",
            route: .vibeBlurt,
            title: "Vibe Blurt",
            tagline: "Describe it. Don't say it. Two teams, one word.",
            symbol: "bubble.left.and.exclamationmark.bubble.right.fill",
            gradient: VibeTheme.vibeBlurt
        ),
        GameEntry(
            id: "odd-one-out",
            route: nil,
            title: "Odd One Out",
            tagline: "Spot the impostor, fast.",
            symbol: "square.on.circle",
            gradient: LinearGradient(
                colors: [Color(red: 0.24, green: 0.80, blue: 0.62),
                         Color(red: 0.62, green: 0.92, blue: 0.36)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]
}
