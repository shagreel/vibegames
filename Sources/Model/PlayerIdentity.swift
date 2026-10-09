import Foundation

/// Stable per-install identity, shared by every game in the suite so a player
/// keeps one name across all of them.
///
/// The web client uses a browser-scoped id; this is the app-scoped equivalent,
/// and deliberately shares no storage keys with the browser.
enum PlayerIdentity {
    /// The keys are not private because the hub binds to them directly with
    /// `@AppStorage`, so a name typed there is the same value every game reads.
    static let idKey = "vibegames.playerID"
    static let nameKey = "vibegames.playerName"
    /// Set once the first-run prompt has been answered or waved away — without
    /// it the app would ask again on every launch after a skip.
    ///
    /// A string rather than a bool on purpose: a launch argument always arrives
    /// in `UserDefaults` as text, so a `Bool` sitting here cannot be overridden
    /// from the command line and tests cannot force a first run.
    static let askedKey = "vibegames.namePromptAnswered"

    /// The value written once the prompt has been dealt with. Any non-empty
    /// value counts, so the exact word is not load-bearing.
    static let askedValue = "yes"

    /// The name as it should be shown and stored: trimmed, and nil rather than
    /// blank, so a field full of spaces never counts as a name.
    static func clean(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Migrates the older Vibe-Words-only keys if they are present, so an
    /// existing install does not lose the player's name.
    private static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: nameKey) == nil else { return }

        if let legacy = defaults.string(forKey: "vibewords.playerName") {
            defaults.set(legacy, forKey: nameKey)
        }
        if let legacy = defaults.string(forKey: "vibewords.playerID") {
            defaults.set(legacy, forKey: idKey)
        }
    }

    static var id: String {
        migrateIfNeeded()
        if let existing = UserDefaults.standard.string(forKey: idKey) { return existing }
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(generated, forKey: idKey)
        return generated
    }

    /// The stored name, trimmed, or nil if there is not one.
    static var name: String? {
        get {
            migrateIfNeeded()
            return clean(UserDefaults.standard.string(forKey: nameKey))
        }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    static var hasName: Bool { name != nil }
}
