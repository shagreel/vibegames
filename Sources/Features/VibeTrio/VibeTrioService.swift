import Foundation
import FirebaseDatabase

/// One accepted take: three cards claimed together, with the sequence number the
/// server gave them.
struct TrioTake: Equatable {
    let seq: Int
    let by: String
    let name: String
    let cardIDs: [Int]
}

/// A shared Vibe Pairings game.
///
///     trio/{gameId}
///       meta/
///         seed        1234567890
///         creator     "Alex"
///         createdAt   1737052800000
///         started     true
///         restartTime 1737052810000
///         hints       false
///       players/{shortID}          true while that player is here
///       taken/{cardID}             { seq, by, name }
///
/// The board itself is never stored. It is a pure function of the seed and the
/// takes, so each device rebuilds the identical table by replaying them in
/// sequence order.
///
/// The three children are observed separately and deliberately: `meta` changes
/// about four times a game, while `players` and `taken` only ever grow. A single
/// `.value` observer on the game node would re-send all of it on every take,
/// which at a hundred players is the difference between a fraction of a
/// megabyte and several.
struct TrioSnapshot: Equatable {
    var exists = false
    var seed: UInt32?
    var creator: String?
    var started = false
    var restartTime: Date?
    /// Whether this room plays with hints. A race with a hint button is a
    /// different game, so it is the host's choice for everybody.
    var hints = false
    /// How many people are here. Only the number is wanted — never a list.
    var playerCount = 0
    /// Accepted takes, oldest first.
    var takes: [TrioTake] = []

    /// The card ids in the order the server accepted them.
    var takeIDs: [[Int]] { takes.map(\.cardIDs) }

    /// Every player's score: the takes that actually happened.
    ///
    /// Not every recorded take is one — a claim that lost a race is written too
    /// — and counting those made the scoreboard disagree with the deck.
    var scores: [String: Int] {
        guard let seed else { return [:] }
        let applied = TrioTable.appliedTakeIndices(seed: seed, takes: takeIDs)
        return takes.enumerated().reduce(into: [:]) { scores, pair in
            guard applied.contains(pair.offset) else { return }
            scores[pair.element.by, default: 0] += 1
        }
    }

    /// The name a player took with, for labelling the scoreboard.
    func name(of playerID: String) -> String? {
        takes.last { $0.by == playerID }?.name
    }

    init() {}

    init(meta: Any?, players: [String: Any]?, taken: [String: Any]?) {
        if let object = meta as? [String: Any] {
            exists = true
            creator = object["creator"] as? String
            started = (object["started"] as? Bool) ?? false
            hints = (object["hints"] as? Bool) ?? false

            if let rawSeed = object["seed"] as? NSNumber {
                let value = rawSeed.uint64Value
                if value <= UInt64(UInt32.max) { seed = UInt32(value) }
            }
            if let rawRestart = object["restartTime"] as? NSNumber {
                restartTime = Date(timeIntervalSince1970: rawRestart.doubleValue / 1000)
            }
        }

        playerCount = players?.count ?? 0

        // Group the entries by the sequence number that claimed them. Three
        // cards sharing a sequence are one take.
        var grouped: [Int: (by: String, name: String, cards: [Int])] = [:]
        for (key, value) in taken ?? [:] {
            guard let cardID = Int(key),
                  let entry = value as? [String: Any],
                  let seq = (entry["seq"] as? NSNumber)?.intValue,
                  let by = entry["by"] as? String,
                  let name = entry["name"] as? String else { continue }
            var group = grouped[seq] ?? (by: by, name: name, cards: [])
            group.cards.append(cardID)
            grouped[seq] = group
        }

        takes = grouped
            .map { TrioTake(seq: $0.key, by: $0.value.by, name: $0.value.name,
                            cardIDs: $0.value.cards.sorted()) }
            .sorted { $0.seq < $1.seq }
    }
}

enum TrioRules {
    /// A claim failed because another card in it had already gone.
    static let conflictMessage = "Someone got there first!"
}

/// A live game, held open by three observers.
///
/// The service hands one of these back rather than a bare handle, because the
/// snapshot has to be assembled from parts that arrive separately.
final class TrioObservation {
    fileprivate var handles: [(query: DatabaseQuery, handle: DatabaseHandle)] = []
    fileprivate var meta: Any?
    fileprivate var players: [String: Any] = [:]
    fileprivate var taken: [String: Any] = [:]
    fileprivate var onChange: ((TrioSnapshot) -> Void)?

    fileprivate func emit() {
        onChange?(TrioSnapshot(meta: meta, players: players, taken: taken))
    }
}

@MainActor
final class VibeTrioService {

    static let shared = VibeTrioService()
    private init() {}

    var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    private var database: Database? { FirebaseBootstrapper.database }

    private func gameReference(_ gameID: String) -> DatabaseReference? {
        database?.reference(withPath: "trio/\(gameID)")
    }

    // MARK: - Player identity

    /// A short, game-scoped id. See `ShortID`.
    static func shortID(playerID: String, gameID: String) -> String {
        ShortID.of(playerID: playerID, gameID: gameID)
    }

    // MARK: - Observing

    /// Watches a game.
    ///
    /// The player id is here for presence: `onDisconnect` takes a player off the
    /// roster when the socket drops, and a phone that goes into a tunnel comes
    /// back without one, so every reconnect puts them back.
    func observe(gameID: String,
                 playerID: String?,
                 onChange: @escaping (TrioSnapshot) -> Void) -> TrioObservation? {
        guard let reference = gameReference(gameID) else { return nil }

        let observation = TrioObservation()
        observation.onChange = onChange

        let meta = reference.child("meta")
        observation.handles.append((meta, meta.observe(.value) { [weak observation] snapshot in
            observation?.meta = snapshot.value
            observation?.emit()
        }))

        let players = reference.child("players")
        observation.handles.append((players, players.observe(.childAdded) { [weak observation] snapshot in
            observation?.players[snapshot.key] = true
            observation?.emit()
        }))
        observation.handles.append((players, players.observe(.childRemoved) { [weak observation] snapshot in
            observation?.players.removeValue(forKey: snapshot.key)
            observation?.emit()
        }))

        let taken = reference.child("taken")
        observation.handles.append((taken, taken.observe(.childAdded) { [weak observation] snapshot in
            observation?.taken[snapshot.key] = snapshot.value
            observation?.emit()
        }))
        // Only a restart removes entries, but the table has to empty when it does.
        observation.handles.append((taken, taken.observe(.childRemoved) { [weak observation] snapshot in
            observation?.taken.removeValue(forKey: snapshot.key)
            observation?.emit()
        }))

        // Presence again on every reconnect: a dropped socket has just taken
        // this player off the roster, and nothing else puts them back.
        if let playerID, let database {
            let connected = database.reference(withPath: ".info/connected")
            observation.handles.append((connected, connected.observe(.value) { [weak self] snapshot in
                guard snapshot.value as? Bool == true else { return }
                Task { try? await self?.markPresent(gameID: gameID, playerID: playerID) }
            }))
        }

        return observation
    }

    func stopObserving(_ observation: TrioObservation?) {
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
            "started": false,
            // Off, which is what a race has always been. The host can turn it on
            // before the table is started.
            "hints": false,
        ])
        try await markPresent(gameID: gameID, playerID: playerID)
    }

    func joinGame(gameID: String, playerID: String) async throws {
        try await markPresent(gameID: gameID, playerID: playerID)
    }

    /// Presence, and the disconnect that clears it.
    ///
    /// RTDB has no increment and `onDisconnect` can only set or remove, so a
    /// plain counter could never come down when a phone dies. That is why the
    /// count is the number of live entries rather than a number.
    private func markPresent(gameID: String, playerID: String) async throws {
        guard let reference = gameReference(gameID)?.child("players").child(playerID) else { return }
        try await reference.setValue(true)
        try await reference.onDisconnectRemoveValue()
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
        try await gameReference(gameID)?.child("meta/started").setValue(true)
    }

    /// Turns hints on or off for the whole room. The host's to write, before the
    /// start — the same rule the web client follows.
    func setHints(gameID: String, enabled: Bool) async throws {
        try await gameReference(gameID)?.child("meta/hints").setValue(enabled)
    }

    /// Claims three cards, if they are still there.
    ///
    /// This is the whole of the shared table. The block runs on this device —
    /// there is no backend service — but the server decides whether to keep the
    /// result: it accepts only if the value it handed the block is still
    /// current, and makes everyone else run again against the new one. So the
    /// order takes are accepted in is the server's, not a phone clock's.
    ///
    /// The block replays the game to check the claim properly — the three cards
    /// must still be on the table and must really form a trio — so a claim that
    /// lost the race, or names cards that are no longer together, is aborted.
    func claimTrio(gameID: String,
                   seed: UInt32,
                   cardIDs: [Int],
                   playerID: String,
                   name: String) async -> TrioClaim {
        guard let reference = gameReference(gameID)?.child("taken") else { return .failed }
        let short = Self.shortID(playerID: playerID, gameID: gameID)

        // A board rebuilt from an old round would validate its cards against
        // that round's table and write them into this one — a take nobody can
        // see, which then counts on the scoreboard. Check the room is still the
        // round this board was dealt for.
        if let current = try? await gameReference(gameID)?.child("meta/seed").getData(),
           let value = current.value as? NSNumber,
           value.uint32Value != seed {
            return .staleRound
        }

        return await withCheckedContinuation { continuation in
            reference.runTransactionBlock({ current in
                let entries = (current.value as? [String: Any]) ?? [:]
                let seen = TrioSnapshot(meta: ["seed": Int(seed)],
                                        players: nil,
                                        taken: entries)
                let table = TrioTable.replay(seed: seed, takes: seen.takeIDs)

                guard table.wouldFormTrio(ids: cardIDs) else {
                    return TransactionResult.abort()
                }

                let next = (seen.takes.map(\.seq).max() ?? 0) + 1
                var updated = entries
                for id in cardIDs {
                    updated[String(id)] = ["seq": next, "by": short, "name": name]
                }
                current.value = updated
                return TransactionResult.success(withValue: current)
            }, andCompletionBlock: { error, committed, _ in
                if let error {
                    print("Trio claim failed: \(error.localizedDescription)")
                    continuation.resume(returning: .failed)
                } else {
                    continuation.resume(returning: committed ? .won : .takenBySomeoneElse)
                }
            })
        }
    }

    func beginRestart(gameID: String, seed: UInt32, after seconds: TimeInterval = 10) async throws {
        guard let reference = gameReference(gameID) else { return }
        try await reference.child("taken").removeValue()
        try await reference.child("meta/seed").setValue(Int(seed))
        try await reference.child("meta/restartTime")
            .setValue(Self.milliseconds(Date().addingTimeInterval(seconds)))
    }

    func clearRestartTime(gameID: String) async throws {
        try await gameReference(gameID)?.child("meta/restartTime").removeValue()
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}

/// What happened to a claim.
enum TrioClaim: Equatable {
    case won
    /// Another card in the claim had already gone.
    case takenBySomeoneElse
    /// The board was dealt for a round that has since been replaced.
    case staleRound
    /// The write did not reach the server.
    case failed
}
