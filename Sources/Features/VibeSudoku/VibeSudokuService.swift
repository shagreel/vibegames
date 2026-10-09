import Foundation
import FirebaseDatabase

/// A point-in-time view of a shared Sudoku game.
///
/// Only the *seed* is stored, never the board. Every device rebuilds the same
/// puzzle from it, so a game costs a handful of bytes rather than 81 numbers,
/// and the answer is never sitting in the database for a client to read.
///
///     sudoku/{gameId}
///       seed        1234567890
///       difficulty  "easy"
///       creator     "Alex"
///       createdAt   1737052800000
///       started     true
///       winner      { name, timestamp }
///       restartTime 1737052810000
///       players/{playerId} { name, joinedAt }
struct SudokuSnapshot: Equatable {
    var exists = false
    var seed: UInt32?
    var difficulty: SudokuDifficulty = .fallback
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
    }

    init() {}

    init(rawValue: Any?) {
        guard let object = rawValue as? [String: Any] else { return }

        exists = true
        creator = object["creator"] as? String
        started = (object["started"] as? Bool) ?? false

        if let rawSeed = object["seed"] as? NSNumber {
            let value = rawSeed.uint64Value
            if value <= UInt64(UInt32.max) { seed = UInt32(value) }
        }

        if let raw = object["difficulty"] as? String,
           let parsed = SudokuDifficulty(rawValue: raw) {
            difficulty = parsed
        }

        if let rawWinner = object["winner"] as? [String: Any],
           let name = rawWinner["name"] as? String {
            winner = Winner(name: name,
                            timestamp: Self.date(fromMilliseconds: rawWinner["timestamp"]))
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
        Date(timeIntervalSince1970: ((value as? NSNumber)?.doubleValue ?? 0) / 1000)
    }
}

/// Reads and writes shared Sudoku games under the `sudoku` root, leaving the
/// `games` root to Vibe Words. Every method is a no-op without a backend.
@MainActor
final class VibeSudokuService {

    static let shared = VibeSudokuService()
    private init() {}

    var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    private var database: Database? { FirebaseBootstrapper.database }

    private func gameReference(_ gameID: String) -> DatabaseReference? {
        database?.reference(withPath: "sudoku/\(gameID)")
    }

    // MARK: - Observing

    func observe(gameID: String, onChange: @escaping (SudokuSnapshot) -> Void) -> DatabaseHandleBox? {
        guard let reference = gameReference(gameID) else { return nil }
        let handle = reference.observe(.value) { snapshot in
            onChange(SudokuSnapshot(rawValue: snapshot.value))
        }
        return DatabaseHandleBox(gameID: gameID, handle: handle)
    }

    func stopObserving(_ box: DatabaseHandleBox?) {
        guard let box else { return }
        gameReference(box.gameID)?.removeObserver(withHandle: box.handle)
    }

    // MARK: - Writing

    func createGame(gameID: String,
                    seed: UInt32,
                    difficulty: SudokuDifficulty,
                    creatorName: String,
                    playerID: String) async throws {
        guard let reference = gameReference(gameID) else { return }

        try await reference.setValue([
            "seed": Int(seed),
            // The host picks; everyone in the game races the same board.
            "difficulty": difficulty.rawValue,
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

    func registerPresence(gameID: String, playerID: String) {
        gameReference(gameID)?.child("players").child(playerID).onDisconnectRemoveValue()
    }

    func startGame(gameID: String) async throws {
        try await gameReference(gameID)?.child("started").setValue(true)
    }

    func recordWinnerIfAbsent(gameID: String, name: String) async throws {
        guard let reference = gameReference(gameID)?.child("winner") else { return }
        let existing = try await reference.getData()
        guard !existing.exists() else { return }

        try await reference.setValue([
            "name": name,
            "timestamp": Self.milliseconds(Date())
        ])
    }

    func beginRestart(gameID: String,
                      seed: UInt32,
                      after seconds: TimeInterval = 10) async throws {
        guard let reference = gameReference(gameID) else { return }

        try await reference.child("seed").setValue(Int(seed))
        try await reference.child("winner").removeValue()
        try await reference.child("restartTime")
            .setValue(Self.milliseconds(Date().addingTimeInterval(seconds)))
    }

    func clearRestartTime(gameID: String) async throws {
        try await gameReference(gameID)?.child("restartTime").removeValue()
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}

/// Opaque observation token, so the model need not import FirebaseDatabase.
struct DatabaseHandleBox: Hashable {
    let gameID: String
    fileprivate let handle: DatabaseHandle
}
