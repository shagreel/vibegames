import Foundation
import FirebaseDatabase

/// One player's row in a shared game.
struct VibeTenScore: Equatable {
    var score: Int
    /// When that player's board ran out of moves, in milliseconds. Nil while
    /// they are still playing.
    var finishedAt: Int64?
}

/// A shared Vibe Ten game.
///
///     ten/{gameId}
///       meta/
///         seed        1234567890
///         creator     "Alex"
///         createdAt   1737052800000
///         started     true
///       players/{playerId} { name, joinedAt }
///       scores/{playerId}  { score, finishedAt }
///
/// The board is never stored: it is a pure function of the seed, so every device
/// — phone or browser — deals the identical 162 digits from one number. Only the
/// scores travel, and each player writes their own.
struct VibeTenSnapshot: Equatable {
    var exists = false
    var seed: UInt32?
    var creator: String?
    var started = false
    var restartTime: Date?
    /// Who is here, by player id.
    var players: [String: String] = [:]
    /// What each player has done, by player id.
    var scores: [String: VibeTenScore] = [:]

    var playerCount: Int { players.count }

    func name(of playerID: String) -> String? { players[playerID] }

    init() {}

    init(meta: Any?, players: Any?, scores: Any?) {
        if let object = meta as? [String: Any] {
            exists = true
            creator = object["creator"] as? String
            started = (object["started"] as? Bool) ?? false
            if let rawSeed = object["seed"] as? NSNumber {
                let value = rawSeed.uint64Value
                if value <= UInt64(UInt32.max) { seed = UInt32(value) }
            }
            if let rawRestart = object["restartTime"] as? NSNumber {
                restartTime = Date(timeIntervalSince1970: rawRestart.doubleValue / 1000)
            }
        }

        for (key, value) in players as? [String: Any] ?? [:] {
            if let entry = value as? [String: Any], let name = entry["name"] as? String {
                self.players[key] = name
            }
        }

        for (key, value) in scores as? [String: Any] ?? [:] {
            guard let entry = value as? [String: Any] else { continue }
            let score = (entry["score"] as? NSNumber)?.intValue ?? 0
            let finishedAt = (entry["finishedAt"] as? NSNumber)?.int64Value
            self.scores[key] = VibeTenScore(score: score, finishedAt: finishedAt)
        }
    }
}

/// One player's place in a room, for the scoreboard.
struct VibeTenStanding: Identifiable, Equatable {
    let id: String
    let name: String
    let score: Int
    let finishedAt: Int64?

    var isFinished: Bool { finishedAt != nil }
}

/// Ranked by the rule the game is played by: most pairs wins, and a tie goes to
/// whoever ran out of moves first.
func vibeTenRank(_ a: VibeTenStanding, _ b: VibeTenStanding) -> Bool {
    if a.score != b.score { return a.score > b.score }
    switch (a.finishedAt, b.finishedAt) {
    case let (first?, second?): return first < second
    case (_?, nil): return true
    case (nil, _?): return false
    case (nil, nil): return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

/// A live room, held open by three observers.
final class VibeTenObservation {
    fileprivate var handles: [(query: DatabaseQuery, handle: DatabaseHandle)] = []
    fileprivate var meta: Any?
    fileprivate var players: Any?
    fileprivate var scores: Any?
    fileprivate var onChange: ((VibeTenSnapshot) -> Void)?

    fileprivate func emit() {
        onChange?(VibeTenSnapshot(meta: meta, players: players, scores: scores))
    }
}

@MainActor
final class VibeTenService {

    static let shared = VibeTenService()
    private init() {}

    var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    private var database: Database? { FirebaseBootstrapper.database }

    private func gameReference(_ gameID: String) -> DatabaseReference? {
        database?.reference(withPath: "ten/\(gameID)")
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }

    // MARK: - Observing

    func observe(gameID: String,
                 playerID: String?,
                 onChange: @escaping (VibeTenSnapshot) -> Void) -> VibeTenObservation? {
        guard let reference = gameReference(gameID) else { return nil }

        let observation = VibeTenObservation()
        observation.onChange = onChange

        let meta = reference.child("meta")
        observation.handles.append((meta, meta.observe(.value) { [weak observation] snapshot in
            observation?.meta = snapshot.value
            observation?.emit()
        }))

        let players = reference.child("players")
        observation.handles.append((players, players.observe(.value) { [weak observation] snapshot in
            observation?.players = snapshot.value
            observation?.emit()
        }))

        let scores = reference.child("scores")
        observation.handles.append((scores, scores.observe(.value) { [weak observation] snapshot in
            observation?.scores = snapshot.value
            observation?.emit()
        }))

        // Presence again on every reconnect: a dropped socket has just taken
        // this player off the roster, and nothing else puts them back.
        if let playerID, let database {
            let connected = database.reference(withPath: ".info/connected")
            observation.handles.append((connected, connected.observe(.value) { snapshot in
                guard snapshot.value as? Bool == true else { return }
                Task { try? await VibeTenService.shared.markPresent(gameID: gameID, playerID: playerID) }
            }))
        }

        return observation
    }

    func stopObserving(_ observation: VibeTenObservation?) {
        guard let observation else { return }
        for (query, handle) in observation.handles {
            query.removeObserver(withHandle: handle)
        }
        observation.handles = []
        observation.onChange = nil
    }

    // MARK: - Writing

    func createGame(gameID: String,
                    seed: UInt32,
                    creatorName: String,
                    playerID: String) async throws {
        guard let reference = gameReference(gameID) else { return }

        try await reference.child("meta").setValue([
            "seed": Int(seed),
            "creator": creatorName,
            "createdAt": Self.milliseconds(Date()),
            "started": false
        ])
        try await joinGame(gameID: gameID, playerID: playerID, name: creatorName)
    }

    func joinGame(gameID: String, playerID: String, name: String) async throws {
        guard let reference = gameReference(gameID) else { return }

        let existing = try await reference.child("players").child(playerID).getData()
        if !existing.exists() {
            try await reference.child("players").child(playerID).setValue([
                "name": name,
                "joinedAt": Self.milliseconds(Date())
            ])
        }
        try await markPresent(gameID: gameID, playerID: playerID)
    }

    /// Puts the player on the roster and clears them when the socket drops.
    ///
    /// The name lives in the same entry as the presence, so a room can list who
    /// is in it without a second observer.
    func markPresent(gameID: String, playerID: String) async throws {
        guard let reference = gameReference(gameID)?.child("players").child(playerID) else { return }
        try await reference.onDisconnectRemoveValue()
    }

    func removePresence(gameID: String, playerID: String) {
        gameReference(gameID)?.child("players").child(playerID).removeValue()
    }

    func startGame(gameID: String) async throws {
        try await gameReference(gameID)?.child("meta/started").setValue(true)
    }

    /// Records this player's score, and when their board ran out of moves.
    func recordScore(gameID: String,
                     playerID: String,
                     score: Int,
                     finishedAt: Date?) async throws {
        guard let reference = gameReference(gameID)?.child("scores").child(playerID) else { return }
        var value: [String: Any] = ["score": score]
        if let finishedAt {
            value["finishedAt"] = Self.milliseconds(finishedAt)
        }
        try await reference.updateChildValues(value)
    }

    /// Deals a new board to the whole room.
    func beginRestart(gameID: String, seed: UInt32) async throws {
        guard let reference = gameReference(gameID) else { return }
        try await reference.child("meta/seed").setValue(Int(seed))
        // The scores belong to the round, so they go with it.
        try await reference.child("scores").removeValue()
    }
}
