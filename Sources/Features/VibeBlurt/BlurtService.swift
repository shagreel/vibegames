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
    /// Which packs the room is playing from. Held in the room, not on each
    /// phone: the deck is derived from the seed *and* these, so two devices
    /// disagreeing about them would deal two different decks.
    var packs: Set<BlurtPack> = Set(BlurtPack.allCases)

    var allPacksOn: Bool { packs.count == BlurtPack.allCases.count }

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
    /// Which of the four parts have reported at least once. They arrive
    /// separately, and a snapshot assembled from half of them would show a room
    /// with people in it, no teams, and a Start button that does nothing — so
    /// nothing is handed over until all four have been heard from.
    fileprivate var heard: Set<String> = []

    fileprivate func emit() {
        guard heard.count == 4 else { return }

        var snapshot = BlurtSnapshot()
        if let meta = meta as? [String: Any] {
            snapshot.seed = (meta["seed"] as? NSNumber).map { UInt32(truncating: $0) }
            snapshot.started = meta["started"] as? Bool ?? false
            snapshot.creator = meta["creator"] as? String
            if let packs = meta["packs"] as? [String: Any] {
                snapshot.packs = Set(packs.keys.compactMap(BlurtPack.init(rawValue:)))
            }
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

    var isAvailable: Bool { FirebaseBootstrapper.database != nil }

    private var database: Database? { FirebaseBootstrapper.database }

    private func gameReference(_ gameID: String) -> DatabaseReference? {
        database?.reference(withPath: "blurt/\(gameID)")
    }

    /// Pure, so it does not need the main actor — which lets it be called from
    /// anywhere, including the tests.
    nonisolated static func shortID(playerID: String, gameID: String) -> String {
        ShortID.of(playerID: playerID, gameID: gameID)
    }

    nonisolated static func milliseconds(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

    // MARK: - Observing

    func observe(gameID: String, onChange: @escaping (BlurtSnapshot) -> Void) -> BlurtObservation? {
        guard let reference = gameReference(gameID) else { return nil }

        let observation = BlurtObservation()
        observation.onChange = onChange

        let meta = reference.child("meta")
        observation.handles.append((meta, meta.observe(.value) { [weak observation] snapshot in
            observation?.meta = snapshot.value
            observation?.heard.insert("meta")
            observation?.emit()
        }))

        let players = reference.child("players")
        observation.handles.append((players, players.observe(.childAdded) { [weak observation] snapshot in
            // The value, not `true`: a roster entry is the player's name, and
            // storing a flag here left `snapshot.players` empty, which is why
            // the room always looked empty and Start never became enabled.
            observation?.players[snapshot.key] = snapshot.value
            observation?.heard.insert("players")
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
            observation?.heard.insert("teams")
            observation?.emit()
        }))

        // Rewritten whole on every turn and every word, so value rather than
        // child events.
        let play = reference.child("play")
        observation.handles.append((play, play.observe(.value) { [weak observation] snapshot in
            observation?.play = snapshot.value
            observation?.heard.insert("play")
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
                    playerID: String,
                    packs: Set<BlurtPack>) async throws {
        guard let reference = gameReference(gameID) else { return }

        try await reference.child("meta").setValue([
            "seed": Int(seed),
            "creator": creatorName,
            "createdAt": Self.milliseconds(Date()),
            "started": false,
            "packs": Self.packValue(packs),
        ])
        try await markPresent(gameID: gameID, playerID: playerID, name: creatorName)
    }

    /// Which packs are in play.
    ///
    /// Held in the room so the lobby shows everyone the same thing, and so the
    /// choice cannot drift per device between the lobby and the start.
    func updateSettings(gameID: String, packs: Set<BlurtPack>) async throws {
        guard let reference = gameReference(gameID) else { return }
        try await reference.child("meta").updateChildValues([
            "packs": Self.packValue(packs),
        ])
    }

    nonisolated static func packValue(_ packs: Set<BlurtPack>) -> [String: Bool] {
        var value: [String: Bool] = [:]
        for pack in packs { value[pack.rawValue] = true }
        return value
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

    /// Splits the room and deals the first word.
    ///
    /// Refuses a room that cannot field two teams: with one person a side there
    /// is nobody to describe to, and no other team to catch you saying it.
    func startGame(gameID: String, seed: UInt32) async throws {
        guard let reference = gameReference(gameID) else { return }

        let roster = try await reference.child("players").getData().value as? [String: Any] ?? [:]
        guard roster.count >= BlurtRules.minimumPlayers else { return }
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

    /// Starts the round's clock.
    ///
    /// One clock per round, not per word: the whole point is that the timer
    /// keeps running while the word goes back and forth, so the last few seconds
    /// are spent trying to get rid of it.
    func beginTurn(gameID: String, seconds: TimeInterval) async throws {
        guard let reference = gameReference(gameID)?.child("play") else { return }
        let now = Date()
        try await reference.updateChildValues([
            "state": BlurtState.running.rawValue,
            "startedAt": Self.milliseconds(now),
            "endsAt": Self.milliseconds(now.addingTimeInterval(seconds)),
        ])
    }

    /// Reads what the rotation needs: who is on each team, and the seed the
    /// starting positions come from. Read before the transaction rather than
    /// inside it, because the block has to be pure.
    private func rotation(gameID: String) async -> (one: [String], two: [String], offsets: (one: Int, two: Int))? {
        guard let reference = gameReference(gameID) else { return nil }

        // Read `meta` and take the seed out of it, rather than reading
        // `meta/seed` directly. Asking `getData()` for a leaf two segments down
        // hands back the *parent* dictionary on iOS — the snapshot's key is
        // "seed" but its value is all of `meta` — so the cast to a number failed
        // and this returned nil, which silently refused every pass and every
        // buzz on the phone while the browser was fine.
        guard let meta = (try? await reference.child("meta").getData().value) as? [String: Any],
              let seed = (meta["seed"] as? NSNumber).map({ UInt32(truncating: $0) }) else {
            return nil
        }
        let raw = (try? await reference.child("teams").getData().value) as? [String: Any] ?? [:]
        var teams: [String: BlurtTeam] = [:]
        for (player, value) in raw {
            if let n = value as? Int, let team = BlurtTeam(rawValue: n) { teams[player] = team }
        }
        let one = BlurtRules.members(of: .one, in: teams)
        let two = BlurtRules.members(of: .two, in: teams)
        let offsets = BlurtRules.describerOffsets(oneMembers: one.count,
                                                  twoMembers: two.count,
                                                  seed: seed)
        return (one, two, offsets)
    }

    /// Moves the word on by one: the next person in the rotation, which is
    /// always somebody on the other team, with the next word.
    ///
    /// The rotation is the game's spine — one member to the next, alternating
    /// sides, in the same order every time round — so this is the only thing
    /// that decides whose turn it is.
    private static func advance(_ play: inout BlurtPlay, one: [String], two: [String], offsets: (one: Int, two: Int)) {
        play.turn += 1
        play.team = BlurtRules.describingTeam(turn: play.turn)
        play.word += 1
        let members = play.team == .one ? one : two
        let offset = play.team == .one ? offsets.one : offsets.two
        play.describer = BlurtRules.describer(for: play.team,
                                              members: members,
                                              turn: play.turn,
                                              offset: offset) ?? ""
    }

    /// The team got the word and taps for the next one.
    ///
    /// This is what passes the word to the other team, and it deliberately does
    /// **not** touch the clock: the timer belongs to the round, and a round is
    /// however many words both teams get through before it stops.
    ///
    /// A transaction, so two taps landing together cannot skip a player.
    @discardableResult
    func passWord(gameID: String) async -> Bool {
        guard let reference = gameReference(gameID)?.child("play"),
              let rotation = await rotation(gameID: gameID) else { return false }

        return await withCheckedContinuation { continuation in
            reference.runTransactionBlock({ current in
                guard var play = BlurtPlay(value: current.value), play.state == .running else {
                    return TransactionResult.abort()
                }
                Self.advance(&play, one: rotation.one, two: rotation.two, offsets: rotation.offsets)
                current.value = play.value
                return TransactionResult.success(withValue: current)
            }, andCompletionBlock: { error, committed, _ in
                if error != nil || !committed {
                    // A refusal used to be completely silent, which is what made
                    // the phone's dead "got it" button take so long to find.
                    print("Blurt pass refused: \(error?.localizedDescription ?? "not committed")")
                }
                continuation.resume(returning: error == nil && committed)
            })
        }
    }

    /// Ends the round, once, whoever gets there first.
    ///
    /// The clock running out and somebody pressing BUZZ pay exactly the same
    /// way: the team *not* holding the word takes the point. The transaction is
    /// what makes that fair — a room that all shouts at once still scores once —
    /// and it also sets the next round's rotation up behind the result.
    @discardableResult
    func endTurn(gameID: String, reason: BlurtEnd) async -> Bool {
        guard let reference = gameReference(gameID)?.child("play"),
              let rotation = await rotation(gameID: gameID) else { return false }

        return await withCheckedContinuation { continuation in
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
                play.startedAt = nil
                play.endsAt = nil

                // The next round starts one further round the rotation, so the
                // order keeps moving rather than the same person being caught
                // twice. A finished game keeps the last round's shape; nobody
                // plays it.
                if !play.finished {
                    Self.advance(&play, one: rotation.one, two: rotation.two, offsets: rotation.offsets)
                }

                current.value = play.value
                return TransactionResult.success(withValue: current)
            }, andCompletionBlock: { error, committed, _ in
                if error != nil || !committed {
                    print("Blurt buzz refused: \(error?.localizedDescription ?? "not committed")")
                }
                continuation.resume(returning: error == nil && committed)
            })
        }
    }

    /// Same room, same teams, scoreboard back to nil — and **the next word**,
    /// not the first one again.
    ///
    /// The deck belongs to the room and is walked from end to end, so a table
    /// playing several games in a sitting never sees a word twice. The rotation
    /// carries on too, which also means the next person to describe is the one
    /// after whoever was holding it when the last game ended.
    @discardableResult
    func playAgain(gameID: String, seed: UInt32) async -> Bool {
        guard let reference = gameReference(gameID),
              let rotation = await rotation(gameID: gameID) else { return false }

        return await withCheckedContinuation { continuation in
            reference.child("play").runTransactionBlock({ current in
                guard let existing = BlurtPlay(value: current.value) else {
                    return TransactionResult.abort()
                }

                var next = BlurtPlay()
                next.round = existing.round + 1
                next.state = .ready
                next.turn = existing.turn + 1
                next.word = existing.word + 1
                next.team = BlurtRules.describingTeam(turn: next.turn)
                let members = next.team == .one ? rotation.one : rotation.two
                let offset = next.team == .one ? rotation.offsets.one : rotation.offsets.two
                next.describer = BlurtRules.describer(for: next.team,
                                                      members: members,
                                                      turn: next.turn,
                                                      offset: offset) ?? ""

                current.value = next.value
                return TransactionResult.success(withValue: current)
            }, andCompletionBlock: { error, committed, _ in
                if error != nil || !committed {
                    print("Blurt play again refused: \(error?.localizedDescription ?? "not committed")")
                }
                continuation.resume(returning: error == nil && committed)
            })
        }
    }
}
