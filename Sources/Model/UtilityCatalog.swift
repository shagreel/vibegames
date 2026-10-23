import SwiftUI

/// Where the utilities live in the navigation stack.
///
/// The list is its own destination so the hub has one button rather than a row
/// of tools: this is meant to grow — a timer, a scorekeeper, a coin — and a hub
/// with a dozen tool buttons on it stops being a hub.
enum UtilityRoute: Hashable {
    case list
    case dice
}

/// A tool on the utilities screen. The shape of a game's hub entry, without the
/// "coming soon" case: a utility that is not ready simply is not listed.
struct UtilityEntry: Identifiable {
    let id: String
    let route: UtilityRoute
    let title: String
    let tagline: String
    let symbol: String
    let gradient: LinearGradient

    static let all: [UtilityEntry] = [
        UtilityEntry(
            id: "dice",
            route: .dice,
            title: "Dice",
            tagline: "d4, d6, d8, d10, d12, d20. Roll one, or a handful.",
            symbol: "dice.fill",
            gradient: VibeTheme.vibeUtility
        )
    ]
}
