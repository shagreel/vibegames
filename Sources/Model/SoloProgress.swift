import Foundation

/// A solo game left in progress, kept on this device.
///
/// Leaving a game used to end it: the board, the puzzle or the word went with
/// the screen. The owner's note is that a solo game is a sitting rather than a
/// commitment — pressing back should not throw it away, and coming back should
/// ask whether to carry on or start again.
///
/// One record per game. The game decides what is in `payload` (a seed and what
/// has been done to it, as a rule) and what the `summary` says, because only the
/// game knows what "in progress" looks like.
struct SoloProgress: Equatable {
    let game: String
    let savedAt: Date
    /// A line for the resume prompt: "12 pairs taken, 8 rows left".
    let summary: String
    let payload: Data
}

/// Where solo progress lives: one entry per game, in `UserDefaults`, so it
/// survives leaving the screen, the app and the launch.
enum SoloProgressStore {

    private static var defaults: UserDefaults { .standard }

    private static func key(_ game: String) -> String { "solo.\(game).progress" }

    /// The record on disk, as opposed to the state inside it.
    private struct Record: Codable {
        var game: String
        var savedAt: Date
        var summary: String
        var payload: Data
    }

    /// Keeps a game so it can be picked up later.
    static func save<State: Encodable>(_ state: State, game: String, summary: String) {
        guard let payload = try? JSONEncoder().encode(state) else { return }
        let record = Record(game: game, savedAt: Date(), summary: summary, payload: payload)
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key(game))
    }

    /// The game's state, if one was saved and can still be read.
    ///
    /// A record from an older version of the game decodes to nothing and is
    /// cleared: half a board is worse than a new one.
    static func state<State: Decodable>(_ type: State.Type, game: String) -> State? {
        guard let record = record(game: game) else { return nil }
        guard let state = try? JSONDecoder().decode(State.self, from: record.payload) else {
            clear(game: game)
            return nil
        }
        return state
    }

    /// What the resume prompt needs to know, without opening the state.
    static func saved(game: String) -> SoloProgress? {
        guard let record = record(game: game) else { return nil }
        return SoloProgress(game: record.game,
                            savedAt: record.savedAt,
                            summary: record.summary,
                            payload: record.payload)
    }

    static func clear(game: String) {
        defaults.removeObject(forKey: key(game))
    }

    private static func record(game: String) -> Record? {
        guard let data = defaults.data(forKey: key(game)) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }
}
