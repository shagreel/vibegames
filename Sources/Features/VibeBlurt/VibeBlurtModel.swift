import Combine
import Foundation
import UIKit

/// Drives a game of Similar Vibe.
///
/// The database holds a seed, a roster, the teams and one `play` node. The words
/// themselves are never sent: every phone derives the same deck from the seed
/// and the round, so the only thing that has to travel is how far into it the
/// game has got. That is why the describer can be the only person who *sees* a
/// word without the word being hidden anywhere.
@MainActor
final class VibeBlurtModel: ObservableObject {

    enum Session: Equatable {
        case lobby
        case shared(gameID: String, isHost: Bool)
    }

    // MARK: Published state

    @Published private(set) var session: Session = .lobby
    @Published private(set) var playerName: String = PlayerIdentity.name ?? ""
    @Published private(set) var hasName: Bool = PlayerIdentity.name?.isEmpty == false
    @Published private(set) var snapshot = BlurtSnapshot()
    /// Ticks while a turn is running, so the clock and the timeout both come
    /// from one place.
    @Published private(set) var now = Date()
    @Published var errorMessage: String?
    /// Bumped when somebody catches *me* holding the word.
    ///
    /// A counter rather than a flag because being caught can happen more than
    /// once in a game, and a flag that has to be reset is a state machine waiting
    /// to get stuck. It is what makes the decision assertable — the haptic itself
    /// cannot be felt by a test, but this and the result on screen can.
    @Published private(set) var caughtCount = 0

    /// The buzz the phone gives when it has been caught.
    ///
    /// Fired from here rather than from a `.sensoryFeedback` trigger in the view,
    /// which is what it used to be. A caught round also replaces the whole screen
    /// in the same update, and a trigger watches for a value change across a body
    /// evaluation — a subtree being swapped underneath it is the case that
    /// mechanism is least reliable in. That was the first theory for why nobody
    /// felt it, and it was *not* the answer: haptics were switched off at the
    /// device level, which is also why Vibe Five's cue was missing. The rule that
    /// decides "that was me" is evaluated here anyway, so this stays where the
    /// cue is raised — one call, at the moment of the decision, into the type
    /// that owns the engine. See `Haptics`.
    ///
    /// The decision itself stays testable through `caughtCount`.
    var buzzWhenCaught: () -> Void = { Haptics.shared.buzz() }
    /// The host's own preference, remembered between games and written into the
    /// room when they make one. Not read from the room once a game exists — the
    /// room is the authority then, so everyone deals the same deck.
    @Published var preferredPacks: Set<BlurtPack> = BlurtModelSettings.loadPacks()

    private var observation: BlurtObservation?
    private var tickTask: Task<Void, Never>?
    private let ticker = BlurtTicker()
    /// Set while a timeout is in flight, so one phone does not fire it twice.
    private var endingTurn = false
    private var endedTurnNumber = -1
    /// Somebody who joined after the start asks for a team once, not on every
    /// snapshot that arrives.
    private var askedForTeam = false

    private var service: VibeBlurtService { .shared }

    /// Why the shared game is unavailable, if it is. Solo play does not exist
    /// here, so this is the difference between a game and a lonely lobby.
    var backendUnavailableMessage: String? {
        FirebaseBootstrapper.unavailableReason?.explanation
    }

    // MARK: Identity

    var isShared: Bool {
        if case .shared = session { return true }
        return false
    }

    var isHost: Bool {
        if case .shared(_, let isHost) = session { return isHost }
        return false
    }

    var sharedGameID: String? {
        if case .shared(let gameID, _) = session { return gameID }
        return nil
    }

    var myShortID: String? {
        guard let gameID = sharedGameID else { return nil }
        return VibeBlurtService.shortID(playerID: PlayerIdentity.id, gameID: gameID)
    }

    // MARK: The game

    var play: BlurtPlay? { snapshot.play }

    var myTeam: BlurtTeam? {
        guard let me = myShortID else { return nil }
        return snapshot.teams[me]
    }

    /// The room's deck — one per room, walked from start to finish across as
    /// many games as the table plays. Derived, never stored.
    var deck: [String] {
        guard let seed = snapshot.seed else { return [] }
        return BlurtDeck.shuffled(seed: seed, packs: snapshot.packs)
    }

    /// How close the round is to the end: 0 for the whole of the first 85% and 1
    /// at the buzzer. Drives both the hurrying tick and the colour of the bar.
    var urgency: Double {
        guard let play, play.state == .running,
              let start = play.startedAt, let end = play.endsAt else { return 0 }
        return BlurtTiming.urgency(remaining: end.timeIntervalSince(now),
                                   total: end.timeIntervalSince(start))
    }

    /// How much of the bar is filled. It reaches its end before the round does,
    /// deliberately, so the bar emptying is not the buzzer.
    var barFill: Double {
        guard let play, play.state == .running,
              let start = play.startedAt, let end = play.endsAt else { return 0 }
        return BlurtTiming.barFill(remaining: end.timeIntervalSince(now),
                                   total: end.timeIntervalSince(start))
    }

    /// Only the host sets the room up, and only before the start.
    var canChangeSettings: Bool { isHost && !hasStarted }

    /// The word in play. Only the describer's screen is allowed to render it.
    var currentWord: String {
        guard let play else { return "" }
        return BlurtDeck.word(at: play.word, in: deck)
    }

    var describingTeam: BlurtTeam? { play?.team }

    /// Who the word belongs to at this moment, by short id.
    ///
    /// The round writes down a describer when it starts, and a phone that leaves
    /// afterwards does not rewrite it — so the round can be pointing at somebody
    /// who is not in the room. Left at that, their own team-mates are told that
    /// person is describing to them and the other team is told to watch for them:
    /// a round nobody can play, with nothing to end it early but the clock.
    ///
    /// So the holder is resolved on every snapshot instead. The named describer
    /// keeps the word while they are here; once they have gone it moves to whoever
    /// the rotation names among the people still in the room, which is the same
    /// rule that walks the turn on at the end of a round — a missing player is
    /// taken out of the order rather than described around. `BlurtRules.holder`
    /// owns that rule, so the browser resolves it to the same person.
    ///
    /// Nil only when the whole of the describing side has gone, which is a room
    /// with one team in it and not a game.
    var holderID: String? { Self.holder(in: snapshot) }

    /// `holderID`, for any snapshot rather than the current one: the caught-buzz
    /// comparison looks back at the round as it stood a moment ago.
    nonisolated static func holder(in snapshot: BlurtSnapshot) -> String? {
        guard let play = snapshot.play else { return nil }
        // Without a seed the rotation cannot be walked, but the seed is written
        // when the room is made, so this is a waiting room with no round to hold.
        guard let seed = snapshot.seed else { return play.describer }

        return BlurtRules.holder(named: play.describer,
                                 team: play.team,
                                 turn: play.turn,
                                 teams: snapshot.teams,
                                 present: Set(snapshot.players.keys),
                                 seed: seed)
    }

    var isDescriber: Bool {
        guard let me = myShortID else { return false }
        return holderID == me
    }

    /// The team that is not holding the word.
    ///
    /// They are the ones who can see it and press BUZZ: the word is shown to
    /// them so calling a blurt is a judgement rather than a guess.
    var isOnBuzzTeam: Bool {
        guard let play, let mine = myTeam else { return false }
        return mine != play.team
    }

    /// They can only press it while the round is actually running.
    var canBuzz: Bool { isOnBuzzTeam && play?.state == .running }

    /// On the holding team, and not the one describing: guessing, and so the
    /// one person in the room who must not see the word.
    var isGuessing: Bool {
        guard let play, let mine = myTeam else { return false }
        return mine == play.team && !isDescriber
    }

    /// Who is allowed to see the word — the person describing it, and the team
    /// trying to catch them saying it. The guessers are not.
    var canSeeWord: Bool { isDescriber || isOnBuzzTeam }

    var scoreOne: Int { play?.one ?? 0 }
    var scoreTwo: Int { play?.two ?? 0 }

    var winner: BlurtTeam? { play?.winner }

    var hasStarted: Bool { snapshot.started }

    /// How the round ended, for the result line.
    ///
    /// A giveaway is the foul: the describer said the word, or part of it, and
    /// the other team buzzed them. The same term is in `GameInstructions.blurt`
    /// and in the web client's two copies — change them together.
    var lastRoundSummary: String {
        guard let play, let scorer = play.scorer else { return "Round over" }
        switch play.reason {
        case .blurt: return "\(scorer.title) takes the point — caught a giveaway"
        case .time, .none: return "\(scorer.title) takes the point — the clock ran out"
        }
    }

    /// Everyone on a team, by name, for the scoreboard and the handover.
    /// One team's players, by name, as they should be shown.
    ///
    /// Only the people who are actually in the room. `teams` deliberately
    /// outlives the players in it — that is what puts somebody back on their own
    /// side when they return — so the team list is not the roster, and this is
    /// the `compactMap` that keeps the difference out of the scoreboard. A slot
    /// with nobody in it has no name, and inventing one ("Someone") puts a line
    /// on the board for a person who is not there. The browser shipped exactly
    /// that bug; `namesOn` in `web/src/games/blurt/engine.ts` is its twin.
    func names(on team: BlurtTeam) -> [String] {
        BlurtRules.members(of: team, in: snapshot.teams).compactMap { snapshot.players[$0] }
    }

    func score(of team: BlurtTeam) -> Int {
        team == .one ? scoreOne : scoreTwo
    }

    /// What to call the person holding the word.
    ///
    /// Empty when the whole of their side has gone, so nothing gets named that is
    /// not in the room. The screens that use it are the ones shown to the other
    /// team and to the holder's own team-mates, both of which are looking at a
    /// person who is really there.
    var describerName: String {
        guard let holder = holderID else { return "" }
        return snapshot.players[holder] ?? ""
    }

    /// Whether this phone can start the round that is waiting: the describer's
    /// own, or — when they have gone — anybody still on their team.
    ///
    /// The turn is written down when the word moves, and a phone that leaves
    /// afterwards does not rewrite it, so the round can be pointing at somebody
    /// who is not there. Nothing is running yet in that state, so no clock will
    /// end it either — which is why the round has to be offered to somebody else
    /// rather than left waiting on a phone that has gone. Whoever takes it is
    /// written down as the describer, so the word lands on the phone that is
    /// actually in the room.
    var canStartThisRound: Bool {
        Self.canStartRound(play: play,
                           me: myShortID,
                           present: Set(snapshot.players.keys),
                           myTeam: myTeam)
    }

    /// Whether the room has enough people to make a game of it.
    ///
    /// Two is the floor, and the split is worked out at the start — so this
    /// cannot ask whether both teams have somebody in them yet, because before
    /// the start there are no teams to ask about.
    var canStart: Bool { snapshot.players.count >= BlurtRules.minimumPlayers }

    /// What to say when the room is too small, rather than leaving a dead button.
    var startHint: String {
        if canStart { return "Teams are picked at random, so nobody can argue." }
        let short = BlurtRules.minimumPlayers - snapshot.players.count
        return "You need \(BlurtRules.minimumPlayers) people — two on each team. "
             + "\(short) more to go."
    }

    // MARK: - Session control

    func createGame() async {
        guard service.isAvailable, hasName else { return }

        let gameID = GameCode.make()
        let seed = SudokuGenerator.randomSeed()

        do {
            try await service.createGame(gameID: gameID,
                                         seed: seed,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id,
                                         packs: preferredPacks)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            session = .shared(gameID: gameID, isHost: true)
            beginObserving(gameID: gameID)
        } catch {
            FirebaseBootstrapper.record(error, during: "Could not create the game")
            errorMessage = "Could not create the game: \(error.localizedDescription)"
        }
    }

    func joinGame(code: String) async {
        guard service.isAvailable, hasName else { return }

        // Forgiving on the way in: these arrive second-hand, heard across a
        // room and typed from memory.
        let gameID = GameCode.normalise(code)
        guard !gameID.isEmpty else { return }

        do {
            let isHost = UserDefaults.standard.string(forKey: StoredKey.hostedGame) == gameID
            try await service.joinGame(gameID: gameID, playerID: PlayerIdentity.id, name: playerName)
            session = .shared(gameID: gameID, isHost: isHost)
            beginObserving(gameID: gameID)
        } catch {
            FirebaseBootstrapper.record(error, during: "Could not join that game")
            errorMessage = "Could not join that game: \(error.localizedDescription)"
        }
    }

    /// Back to the lobby, leaving the room.
    func leaveGame() {
        stopClock()
        observation.map { service.stopObserving($0) }
        observation = nil
        session = .lobby
        snapshot = BlurtSnapshot()
        askedForTeam = false
    }

    func endSession() {
        stopClock()
        SoundEngine.shared.deactivate()
    }

    func submitName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        PlayerIdentity.name = trimmed
        playerName = trimmed
        hasName = true
    }

    // MARK: - Running the game

    /// Writes the room's settings, so the lobby shows everybody the same thing
    /// and the start does not have to carry them.
    func updateSettings(packs: Set<BlurtPack>) async {
        guard let gameID = sharedGameID, isHost, !hasStarted else { return }
        preferredPacks = packs
        BlurtModelSettings.save(packs: packs)
        try? await service.updateSettings(gameID: gameID, packs: packs)
    }

    /// Registers the room: splits it into teams and deals the first turn.
    func startGame() async {
        guard let gameID = sharedGameID, isHost, canStart else { return }
        do {
            try await service.startGame(gameID: gameID, seed: snapshot.seed ?? SudokuGenerator.randomSeed())
        } catch {
            FirebaseBootstrapper.record(error, during: "Could not start the game")
            errorMessage = "Could not start the game: \(error.localizedDescription)"
        }
    }

    /// Whether this player can start the round that is waiting.
    ///
    /// Pure and static so the rule can be read and tested in one place. It has
    /// to cover **both** states the handover screen appears in: `.ready` for the
    /// first round of a game, and `.ended` for every round after it, because
    /// ending a round leaves the result and the next round's rotation behind in
    /// the same state. Asking only for `.ready` — which this did — is why the
    /// first round started and no round after it did.
    ///
    /// `present` and `myTeam` cover the other way a round gets stuck: the phone
    /// that was up has left the room. Nothing is running yet, so no clock will
    /// end it, and nobody else can start it — the table would wait on a phone
    /// that is not there for the rest of the evening. When the named describer
    /// is gone, the next person on that team picks the round up instead.
    nonisolated static func canStartRound(play: BlurtPlay?,
                                          me: String?,
                                          present: Set<String>? = nil,
                                          myTeam: BlurtTeam? = nil) -> Bool {
        guard let play, let me, !play.finished, play.state != .running else { return false }
        if play.describer == me { return true }

        guard let present, !present.contains(play.describer) else { return false }
        return myTeam == play.team
    }

    /// The describer has the phone in their hand; start the clock.
    ///
    /// The length is drawn here, by the one phone that starts the round, and
    /// written into the end time. Every other phone reads it back out of
    /// `startedAt` and `endsAt` rather than being told, so there is nothing to
    /// agree on and nothing to go stale.
    ///
    /// Whoever starts it is written down as the describer, which is what makes
    /// standing in for somebody who has left stick: the word is on the screen of
    /// the phone that is actually in the room.
    func beginTurn() async {
        guard let gameID = sharedGameID, let me = myShortID,
              Self.canStartRound(play: play,
                                 me: me,
                                 present: Set(snapshot.players.keys),
                                 myTeam: myTeam) else { return }
        let seconds = TimeInterval(BlurtTiming.randomTurnSeconds())
        try? await service.beginTurn(gameID: gameID, seconds: seconds, describer: me)
    }

    /// The team got the word.
    ///
    /// This is what passes it to the other team, and it does not touch the
    /// clock: the round runs for as long as the timer says, however many words
    /// go past in that time.
    func gotIt() async {
        guard let gameID = sharedGameID, isDescriber, play?.state == .running else { return }
        await service.passWord(gameID: gameID)
    }

    /// Somebody on the other team says the word was said.
    ///
    /// Ends the round at once and pays the team that caught it. The service
    /// refuses the second press of two, so a room that all shouts at once still
    /// scores once.
    func buzz() async {
        guard let gameID = sharedGameID, canBuzz else { return }
        await service.endTurn(gameID: gameID, reason: .blurt)
    }

    func playAgain() async {
        guard let gameID = sharedGameID, let seed = snapshot.seed else { return }
        endingTurn = false
        endedTurnNumber = -1
        await service.playAgain(gameID: gameID, seed: seed)
    }

    // MARK: - Observing

    private func beginObserving(gameID: String) {
        observation.map { service.stopObserving($0) }

        observation = service.observe(gameID: gameID,
                                      presence: .init(playerID: PlayerIdentity.id, name: playerName)) { [weak self] snapshot in
            guard let self else { return }
            self.apply(snapshot)
        }
    }

    /// Whether a buzz just landed on me.
    ///
    /// Pure and static so it can be tested without a network, and so the rule is
    /// readable in one place: the round ended on a blurt, I was holding the word
    /// when it did, and it is news to me. The clock running out deliberately does
    /// *not* count — everybody can see the clock, but a buzz is the one thing the
    /// person mid-sentence is not looking at.
    ///
    /// `holder` is the resolved holder of the *previous* snapshot rather than
    /// `play.describer`, because the word can have moved to somebody else when the
    /// named describer left — and that person is the one who needs the buzz.
    nonisolated static func caughtMe(previous: BlurtPlay?, next: BlurtPlay?, holder: String?, me: String?) -> Bool {
        guard let me, previous?.state == .running, next?.state == .ended else { return false }
        guard next?.reason == .blurt else { return false }
        return holder == me
    }

    private func apply(_ newSnapshot: BlurtSnapshot) {
        let previous = snapshot
        if Self.caughtMe(previous: previous.play,
                         next: newSnapshot.play,
                         holder: Self.holder(in: previous),
                         me: myShortID) {
            caughtCount += 1
            buzzWhenCaught()
        }
        snapshot = newSnapshot

        // A turn that has moved on is not being ended any more.
        if previous.play?.turn != newSnapshot.play?.turn {
            endingTurn = false
        }

        let wasRunning = previous.play?.state == .running
        let isRunning = newSnapshot.play?.state == .running

        if isRunning {
            startClock()
            Haptics.shared.prepare()
            if !wasRunning {
                // Not for a phone that opened the app mid-round: nothing started
                // on this screen, so nothing should announce that it did.
                if previous.play != nil { SoundEngine.shared.play(.start) }
                startTicking()
            }
        } else {
            stopClock()
            if wasRunning { SoundEngine.shared.play(.buzzer) }
        }

        // Somebody who arrived after the start — a phone that slept through it,
        // or a spectator who picked the game up — has no team and cannot play
        // until they are given one.
        if newSnapshot.started, myTeam == nil, !askedForTeam, let gameID = sharedGameID {
            askedForTeam = true
            Task { [weak self] in
                try? await self?.service.assignTeam(gameID: gameID, playerID: PlayerIdentity.id)
            }
        }
    }

    // MARK: - The clock

    private func startClock() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func stopClock() {
        tickTask?.cancel()
        tickTask = nil
        ticker.stop()
    }

    /// Starts the hurrying tick from the round's own start and end times, so
    /// every phone lays out the same ticks and a late arrival joins the rhythm
    /// rather than beginning one.
    private func startTicking() {
        guard let play, let start = play.startedAt, let end = play.endsAt else { return }
        ticker.start(startedAt: start, total: end.timeIntervalSince(start))
    }

    private func tick() {
        now = Date()

        // Any phone can call time, and the transaction decides which of them
        // counted — so the turn still ends if the describer's app is asleep.
        guard let play, play.state == .running, let endsAt = play.endsAt else { return }
        guard now >= endsAt, !endingTurn, endedTurnNumber != play.turn else { return }
        guard let gameID = sharedGameID else { return }

        endingTurn = true
        endedTurnNumber = play.turn
        Task { [weak self] in
            await self?.service.endTurn(gameID: gameID, reason: .time)
        }
    }

    private enum StoredKey {
        static let hostedGame = "blurt.hostedGame"
    }
}

/// The host's own lobby choices, remembered between games.
enum BlurtModelSettings {
    private static let packsKey = "blurt.packs"

    static func loadPacks() -> Set<BlurtPack> {
        guard let stored = UserDefaults.standard.array(forKey: packsKey) as? [String] else {
            return Set(BlurtPack.allCases)
        }
        let packs = Set(stored.compactMap(BlurtPack.init(rawValue:)))
        // Unticking everything is not a choice anybody means; it would deal an
        // empty deck.
        return packs.isEmpty ? Set(BlurtPack.allCases) : packs
    }

    static func save(packs: Set<BlurtPack>) {
        UserDefaults.standard.set(packs.map(\.rawValue).sorted(), forKey: packsKey)
    }
}
