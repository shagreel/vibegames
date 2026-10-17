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

    /// The longest name anybody may have.
    ///
    /// The database has always capped a name at 24 characters and the clients
    /// did not, so a longer name failed every write it was part of — joining a
    /// room, being listed in it, recording a win — with a bare
    /// `PERMISSION_DENIED`. One number, here and in the web client, and the
    /// same one as the rules.
    static let maxNameLength = 24

    /// The name as it should be shown and stored: trimmed, without the
    /// invisible characters a name must not carry, capped, and nil rather than
    /// blank, so a field full of spaces never counts as a name.
    ///
    /// The invisible ones are the zero-width characters and the bidi overrides
    /// that let one player's name render as another's in a room's list.
    static func clean(_ raw: String?) -> String? {
        let stripped = (raw ?? "").unicodeScalars.filter { scalar in
            let value = scalar.value
            let control = value < 0x20 || (value >= 0x7F && value <= 0x9F)
            let invisible = value >= 0x200B && value <= 0x200F
            let bidi = value >= 0x202A && value <= 0x202E
            let isolates = value >= 0x2066 && value <= 0x2069
            return !control && !invisible && !bidi && !isolates
        }

        let trimmed = String(String.UnicodeScalarView(stripped))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    /// Forgets the name, leaving the install and its id alone.
    ///
    /// The privacy page tells people they can clear it; until now the only way
    /// was to type a different one.
    static func forgetName() {
        UserDefaults.standard.removeObject(forKey: nameKey)
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
