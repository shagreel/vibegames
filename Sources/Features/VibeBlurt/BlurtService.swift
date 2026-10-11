import Foundation
import FirebaseDatabase

/// Where a turn is up to.
enum BlurtState: String, Equatable, Sendable {
    /// The handover screen: everyone can see whose turn it is, and the clock has
    /// not started. The describer taps when they have the phone in their hand,
    /// so the turn never begins while they are still passing it across.
    case ready
    case running
    /// The turn just finished. `reason` and `scorer` say how it went, and the
    /// next turn is already set up behind it.
    case ended
}

/// The whole of the mutable game, in one node.
///
/// One node rather than several, because ending a turn does three things at once
/// — awards a point, checks for a winner, and sets up the next turn — and they
/// have to happen together or two people pressing at the same moment could both
/// score. The transaction that ends a turn writes all of it, so the server
/// decides which press counted.
///
/// `turn`, `team`, `describer` and `word` always describe the turn that is
/// current or coming; `reason` and `scorer` look back at the one that just
/// finished.
struct BlurtPlay: Equatable {
    /// Bumped by "play again", which reseeds the deck without touching the room.
    var round: Int = 0
    var turn: Int = 0
    var team: BlurtTeam = .one
    var describer: String = ""
    var word: Int = 0
    var state: BlurtState = .ready
    var startedAt: Date?
    var endsAt: Date?
    var reason: BlurtEnd?
    var scorer: BlurtTeam?
    var one: Int = 0
    var two: Int = 0
    var finished: Bool = false

    var score: (one: Int, two: Int) { (one, two) }

    func score(of team: BlurtTeam) -> Int {
        team == .one ? one : two
    }

    /// The team that won, once somebody has reached the target.
    var winner: BlurtTeam? {
        BlurtRules.winner(one: one, two: two, target: BlurtRules.target)
    }

    // MARK: - Wire format

    init() {}

    init?(value: Any?) {
        guard let dict = value as? [String: Any],
              let turn = dict["turn"] as? Int,
              let teamRaw = dict["team"] as? Int,
              let team = BlurtTeam(rawValue: teamRaw),
              let describer = dict["describer"] as? String,
              let word = dict["word"] as? Int,
              let stateRaw = dict["state"] as? String,
              let state = BlurtState(rawValue: stateRaw) else { return nil }

        self.round = dict["round"] as? Int ?? 0
        self.turn = turn
        self.team = team
        self.describer = describer
        self.word = word
        self.state = state
        self.one = dict["one"] as? Int ?? 0
        self.two = dict["two"] as? Int ?? 0
        self.finished = dict["finished"] as? Bool ?? false
        self.startedAt = (dict["startedAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        self.endsAt = (dict["endsAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        self.reason = (dict["reason"] as? String).flatMap(BlurtEnd.init(rawValue:))
        self.scorer = (dict["scorer"] as? Int).flatMap(BlurtTeam.init(rawValue:))
    }

    var value: [String: Any] {
        var dict: [String: Any] = [
            "round": round,
            "turn": turn,
            "team": team.rawValue,
            "describer": describer,
            "word": word,
            "state": state.rawValue,
            "one": one,
            "two": two,
            "finished": finished,
        ]
        // Absent rather than null: the rules treat a missing key and an explicit
        // null the same way, and a missing one is what `hasChildren` expects.
        if let startedAt { dict["startedAt"] = Int(startedAt.timeIntervalSince1970 * 1000) }
        if let endsAt { dict["endsAt"] = Int(endsAt.timeIntervalSince1970 * 1000) }
        if let reason { dict["reason"] = reason.rawValue }
        if let scorer { dict["scorer"] = scorer.rawValue }
        return dict
    }
}

/// What every phone is looking at.
struct BlurtSnapshot: Equatable {
    var seed: UInt32?
    var started = false
    var creator: String?
    /// Short id to the name they are playing under.
    var players: [String: String] = [:]
    var teams: [String: BlurtTeam] = [:]
    var play: BlurtPlay?

    /// A room that has been created but not started.
    var isWaiting: Bool { !started }

    func team(of shortID: String) -> BlurtTeam? { teams[shortID] }

    var members: (one: [String], two: [String]) {
        (BlurtRules.members(of: .one, in: teams), BlurtRules.members(of: .two, in: teams))
    }
}

/// A live game, held open by three observers.
final class BlurtObservation {
    fileprivate var handles: [(query: DatabaseQuery, handle: DatabaseHandle)] = []
    fileprivate var meta: Any?
    fileprivate var players: [String: Any] = [:]
    fileprivate var teams: Any?
    fileprivate var play: Any?
    fileprivate var onChange: ((BlurtSnapshot) -> Void)?

    fileprivate func emit() {
        var snapshot = BlurtSnapshot()
        if let meta = meta as? [String: Any] {
            snapshot.seed = (meta["seed"] as? NSNumber).map { UInt32(truncating: $0) }
            snapshot.started = meta["started"] as? Bool ?? false
            snapshot.creator = meta["creator"] as? String
        }
        for (player, value) in players {
            if let name = value as? String { snapshot.players[player] = name }
        }
        if let teams = teams as? [String: Any] {
            for (player, raw) in teams {
                if let n = raw as? Int, let team = BlurtTeam(rawValue: n) { snapshot.teams[player] = team }
            }
        }
        snapshot.play = BlurtPlay(value: play)
        onChange?(snapshot)
    }
}

@MainActor
final class VibeBlurtService {

    static let shared = VibeBlurtService()
    private init() {}

    /// How long a turn lasts. Fixed rather than random: the phone shows the
    /// clock, so a hidden one would only be a lie about how much time is left.
    static let turnSeconds: TimeInterval = 60

    var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    private var database: Database? { FirebaseBootstrapper.database }

    private func gameReference(_ gameID: String) -> DatabaseReference? {
        database?.reference(withPath: "blurt/\(gameID)")
    }

    static func shortID(playerID: String, gameID: String) -> String {
        ShortID.of(playerID: playerID, gameID: gameID)
    }

    static func milliseconds(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

    // MARK: - Observing

    func observe(gameID: String, onChange: @escaping (BlurtSnapshot) -> Void) -> BlurtObservation? {
        guard let reference = gameReference(gameID) else { return nil }

        let observation = BlurtObservation()
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

        // Written once, at the start, so a plain value observer is enough.
        let teams = reference.child("teams")
        observation.handles.append((teams, teams.observe(.value) { [weak observation] snapshot in
            observation?.teams = snapshot.value
            observation?.emit()
        }))

        // Rewritten whole on every turn and every word, so value rather than
        // child events.
        let play = reference.child("play")
        observation.handles.append((play, play.observe(.value) { [weak observation] snapshot in
            observation?.play = snapshot.value
            observation?.emit()
        }))

        return observation
    }

    func stopObserving(_ observation: BlurtObservation?) {
        guard let observation else { return }
        for (query, handle) in observation.handles {
            query.removeObserver(withHandle: handle)
        }
        observation.handles = []
        observation.onChange = nil
    }

    // MARK: - Setting up

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
        ])
        try await markPresent(gameID: gameID, playerID: playerID, name: creatorName)
    }

    func joinGame(gameID: String, playerID: String, name: String) async throws {
        try await markPresent(gameID: gameID, playerID: playerID, name: name)
    }

    /// Presence and name in one entry.
    ///
    /// The roster is keyed by the *short* id — the same one the teams and the
    /// turn use — so a player has one identity in this game rather than two.
    /// RTDB has no increment and `onDisconnect` can only set or remove, so
    /// presence is the set of live entries rather than a counter.
    private func markPresent(gameID: String, playerID: String, name: String) async throws {
        let short = Self.shortID(playerID: playerID, gameID: gameID)
        guard let reference = gameReference(gameID)?.child("players").child(short) else { return }
        try await reference.setValue(name)
        try await reference.onDisconnectRemoveValue()
    }

    /// Somebody who arrives after the start goes on the smaller team.
    ///
    /// Read from the roster rather than tracked, so a phone that slept through
    /// the start still lands somewhere sensible. Two people arriving at once
    /// could both pick the same team; at this scale that is a fair trade for not
    /// needing a transaction.
    func assignTeam(gameID: String, playerID: String) async throws {
        guard let reference = gameReference(gameID) else { return }
        let short = Self.shortID(playerID: playerID, gameID: gameID)

        let teamsValue = try await reference.child("teams").getData().value as? [String: Any] ?? [:]
        var one = 0, two = 0
        for raw in teamsValue.values {
            if let n = raw as? Int, let team = BlurtTeam(rawValue: n) {
                if team == .one { one += 1 } else { two += 1 }
            }
        }
        try await reference.child("teams").child(short).setValue(one <= two ? 1 : 2)
    }

    /// Splits the room and deals the first turn.
    func startGame(gameID: String, seed: UInt32) async throws {
        guard let reference = gameReference(gameID) else { return }

        let roster = try await reference.child("players").getData().value as? [String: Any] ?? [:]
        let teams = BlurtRules.split(players: Array(roster.keys), seed: seed)

        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)
        let offsets = BlurtRules.describerOffsets(oneMembers: one.count, twoMembers: two.count, seed: seed)

        var play = BlurtPlay()
        play.team = BlurtRules.describingTeam(turn: 0)
        play.describer = BlurtRules.describer(for: play.team, members: one, turn: 0, offset: offsets.one) ?? ""
        play.state = .ready

        // The teams first, then the flag: a phone that sees `started` before the
        // teams exist would have nobody to describe and show an empty screen.
        try await reference.child("teams").setValue(teams.mapValues { $0.rawValue })
        try await reference.child("play").setValue(play.value)
        try await reference.child("meta/started").setValue(true)
    }

    // MARK: - Playing

    /// Starts the clock, when the describer has the phone in their hand.
    func beginTurn(gameID: String) async throws {
        guard let reference = gameReference(gameID)?.child("play") else { return }
        let now = Date()
        try await reference.updateChildValues([
            "state": BlurtState.running.rawValue,
            "startedAt": Self.milliseconds(now),
            "endsAt": Self.milliseconds(now.addingTimeInterval(Self.turnSeconds)),
        ])
    }

    /// The team got the word and wants the next one. No score: describing earns
    /// nothing, it only passes the risk on. A transaction, so the count cannot
    /// be rewound by two taps arriving out of order.
    func advanceWord(gameID: String) async {
        guard let reference = gameReference(gameID)?.child("play/word") else { return }
        _ = try? await reference.runTransactionBlock { mutable in
            mutable.value = (mutable.value as? Int ?? 0) + 1
            return TransactionResult.success(withValue: mutable)
        }
    }

    /// Ends the turn, once, whoever gets there first.
    ///
    /// Both endings pay the same way — the team that was *not* describing takes
    /// the point — whether the clock ran out or the other team called a blurt.
    /// The transaction is what makes that fair: two people pressing "they said
    /// it" at the same moment score once, not twice.
    @discardableResult
    func endTurn(gameID: String, reason: BlurtEnd) async -> Bool {
        guard let reference = gameReference(gameID)?.child("play") else { return false }

        let result = await withCheckedContinuation { continuation in
            reference.runTransactionBlock({ current in
                guard var play = BlurtPlay(value: current.value), play.state != .ended else {
                    return TransactionResult.abort()
                }

                let scorer = BlurtRules.scoringTeam(describing: play.team)
                play.scorer = scorer
                play.reason = reason
                if scorer == .one { play.one += 1 } else { play.two += 1 }
                play.finished = BlurtRules.winner(one: play.one,
                                                  two: play.two,
                                                  target: BlurtRules.target) != nil
                play.state = .ended

                // Set the next turn up behind the result, so the handover screen
                // already knows whose phone to point at. A finished game keeps
                // the last turn's shape; nobody plays it.
                if !play.finished {
                    play.turn += 1
                    play.team = BlurtRules.describingTeam(turn: play.turn)
                    play.word += 1
                    play.startedAt = nil
                    play.endsAt = nil
                }

                current.value = play.value
                return TransactionResult.success(withValue: current)
            }, andCompletionBlock: { error, committed, _ in
                continuation.resume(returning: error == nil && committed)
            })
        }
        return result
    }

    /// Same room, same teams, fresh deck and scoreboard.
    ///
    /// The round number, not a new seed, is what makes the words different: the
    /// deck is derived from the room's seed advanced by the round, so nothing
    /// has to be written to `meta` and the reset stays a single transaction.
    @discardableResult
    func playAgain(gameID: String, seed: UInt32) async -> Bool {
        guard let reference = gameReference(gameID) else { return false }

        // Read what the reset needs first, so the transaction only has to swap
        // one node. Teams do not change between rounds.
        let teamsValue = (try? await reference.child("teams").getData().value) as? [String: Any] ?? [:]
        var teams: [String: BlurtTeam] = [:]
        for (player, raw) in teamsValue {
            if let n = raw as? Int, let team = BlurtTeam(rawValue: n) { teams[player] = team }
        }
        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)

        return await withCheckedContinuation { continuation in
            reference.child("play").runTransactionBlock({ current in
                guard let existing = BlurtPlay(value: current.value) else { return TransactionResult.abort() }

                let round = existing.round + 1
                let roundSeed = seed &+ UInt32(truncatingIfNeeded: round)
                let offsets = BlurtRules.describerOffsets(oneMembers: one.count,
                                                          twoMembers: two.count,
                                                          seed: roundSeed)

                var next = BlurtPlay()
                next.round = round
                next.turn = 0
                next.team = BlurtRules.describingTeam(turn: 0)
                let members = next.team == .one ? one : two
                let offset = next.team == .one ? offsets.one : offsets.two
                next.describer = BlurtRules.describer(for: next.team,
                                                      members: members,
                                                      turn: 0,
                                                      offset: offset) ?? ""
                next.state = .ready

                current.value = next.value
                return TransactionResult.success(withValue: current)
            }, andCompletionBlock: { error, committed, _ in
                continuation.resume(returning: error == nil && committed)
            })
        }
    }
}
