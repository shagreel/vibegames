import Foundation
import FirebaseDatabase

/// A point-in-time view of a shared game, parsed from the Realtime Database.
///
/// The shape mirrors what the web client has always written, so both can sit
/// in the same game:
///
///     games/{gameId}
///       word        "CRANE"
///       creator     "Alex"
///       createdAt   1737052800000
///       started     true
///       winner      { name, timestamp }
///       restartTime 1737052810000
///       players/{playerId} { name, joinedAt }
struct GameSnapshot: Equatable {
    var exists = false
    var word: String?
    var creator: String?
    var started = false
    var winner: Winner?
    var restartTime: Date?
    var players: [Player] = []

    struct Winner: Equatable {
        var name: String
        var timestamp: Date
    }

    struct Player: Equatable, Identifiable {
        var id: String
        var name: String
        var joinedAt: Date

        var isCurrentPlayer: Bool { id == PlayerIdentity.id }
    }

    init() {}

    /// Parses the raw `Any` that Firebase hands back. Returns a non-existent
    /// snapshot rather than failing, so the UI can show "join this game".
    init(rawValue: Any?) {
        guard let object = rawValue as? [String: Any] else { return }

        exists = true
        creator = object["creator"] as? String

        if let rawWord = object["word"] as? String, rawWord.count == WordGameEngine.wordSize {
            word = rawWord.uppercased()
        }

        started = (object["started"] as? Bool) ?? false

        if let rawWinner = object["winner"] as? [String: Any],
           let name = rawWinner["name"] as? String {
            winner = Winner(name: name, timestamp: Self.date(fromMilliseconds: rawWinner["timestamp"]))
        }

        if let rawRestart = object["restartTime"] as? NSNumber {
            restartTime = Date(timeIntervalSince1970: rawRestart.doubleValue / 1000)
        }

        if let rawPlayers = object["players"] as? [String: Any] {
            players = rawPlayers.compactMap { key, value in
                guard let entry = value as? [String: Any],
                      let name = entry["name"] as? String else { return nil }
                return Player(id: key,
                              name: name,
                              joinedAt: Self.date(fromMilliseconds: entry["joinedAt"]))
            }
            .sorted { $0.joinedAt < $1.joinedAt }
        }
    }

    private static func date(fromMilliseconds value: Any?) -> Date {
        let milliseconds = (value as? NSNumber)?.doubleValue ?? 0
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}

/// Opaque token for a live observation, so the game model never has to know
/// about Firebase types.
struct GameObservation: Hashable {
    let gameID: String
    fileprivate let handle: DatabaseHandle
}

/// Reads and writes shared games. Every method is a no-op when Firebase has not
/// been configured, which keeps solo play working with no backend at all.
@MainActor
final class VibeWordsService {

    static let shared = VibeWordsService()
    private init() {}

    var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    private var database: Database? { FirebaseBootstrapper.database }

    private func gameReference(_ gameID: String) -> DatabaseReference? {
        database?.reference(withPath: "games/\(gameID)")
    }

    // MARK: - Observing

    /// Watches a whole game node. One listener covers word, started, winner,
    /// restartTime and players, which keeps the client simple.
    func observe(gameID: String, onChange: @escaping (GameSnapshot) -> Void) -> GameObservation? {
        guard let reference = gameReference(gameID) else { return nil }
        let handle = reference.observe(.value) { snapshot in
            onChange(GameSnapshot(rawValue: snapshot.value))
        }
        return GameObservation(gameID: gameID, handle: handle)
    }

    func stopObserving(_ observation: GameObservation?) {
        guard let observation else { return }
        gameReference(observation.gameID)?.removeObserver(withHandle: observation.handle)
    }

    // MARK: - Writing

    func createGame(gameID: String,
                    word: String,
                    creatorName: String,
                    playerID: String) async throws {
        guard let reference = gameReference(gameID) else { return }

        try await reference.setValue([
            "word": word.uppercased(),
            "creator": creatorName,
            "started": false,
            "createdAt": Self.milliseconds(Date()),
            "players": [
                playerID: ["name": creatorName, "joinedAt": Self.milliseconds(Date())]
            ]
        ])

        registerPresence(gameID: gameID, playerID: playerID)
    }

    func joinGame(gameID: String, playerID: String, name: String) async throws {
        guard let reference = gameReference(gameID) else { return }

        let playerReference = reference.child("players").child(playerID)
        let existing = try await playerReference.getData()

        if !existing.exists() {
            try await playerReference.setValue([
                "name": name,
                "joinedAt": Self.milliseconds(Date())
            ])
        }

        registerPresence(gameID: gameID, playerID: playerID)
    }

    /// Removes the player automatically when the app is killed or loses the
    /// network, matching the web client's behaviour.
    func registerPresence(gameID: String, playerID: String) {
        guard let reference = gameReference(gameID) else { return }
        reference.child("players").child(playerID).onDisconnectRemoveValue()
    }

    /// Takes the player off the roster the moment they leave.
    ///
    /// `onDisconnect` only covers a phone that dies or loses signal; somebody
    /// who taps back is still connected, so without this the room goes on
    /// counting a ghost until the app is closed.
    func removePresence(gameID: String, playerID: String) {
        gameReference(gameID)?.child("players").child(playerID).removeValue()
    }

    func startGame(gameID: String) async throws {
        try await gameReference(gameID)?.child("started").setValue(true)
    }

    /// Only records a winner if nobody has won yet, so the first solver keeps it.
    func recordWinnerIfAbsent(gameID: String, name: String) async throws {
        guard let reference = gameReference(gameID)?.child("winner") else { return }
        let existing = try await reference.getData()
        guard !existing.exists() else { return }

        try await reference.setValue([
            "name": name,
            "timestamp": Self.milliseconds(Date())
        ])
    }

    func beginRestart(gameID: String, word: String, after seconds: TimeInterval = 10) async throws {
        guard let reference = gameReference(gameID) else { return }

        try await reference.child("word").setValue(word.uppercased())
        try await reference.child("winner").removeValue()
        try await reference.child("restartTime").setValue(Self.milliseconds(Date().addingTimeInterval(seconds)))
    }

    func clearRestartTime(gameID: String) async throws {
        try await gameReference(gameID)?.child("restartTime").removeValue()
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}
