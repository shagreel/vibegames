import Combine
import Foundation

/// Drives a game of Vibe Blurt.
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
    /// A counter rather than a flag, because SwiftUI's `.sensoryFeedback` fires
    /// on a change and a flag that has to be reset is a state machine waiting to
    /// get stuck. The view watches this and buzzes the phone.
    @Published private(set) var caughtCount = 0
    /// The host's own preference, remembered between games and written into the
    /// room when they make one. Not read from the room once a game exists — the
    /// room is the authority then, so everyone deals the same deck.
    @Published var preferredPacks: Set<BlurtPack> = BlurtModelSettings.loadPacks()
    @Published var preferredSeconds: Int = BlurtModelSettings.loadSeconds()

    private var observation: BlurtObservation?
    private var tickTask: Task<Void, Never>?
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

    var duration: BlurtDuration { snapshot.duration }

    /// Only the host sets the room up, and only before the start.
    var canChangeSettings: Bool { isHost && !hasStarted }

    /// The word in play. Only the describer's screen is allowed to render it.
    var currentWord: String {
        guard let play else { return "" }
        return BlurtDeck.word(at: play.word, in: deck)
    }

    var describingTeam: BlurtTeam? { play?.team }

    var isDescriber: Bool {
        guard let play, let me = myShortID else { return false }
        return play.describer == me
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
    var lastRoundSummary: String {
        guard let play, let scorer = play.scorer else { return "Round over" }
        switch play.reason {
        case .blurt: return "\(scorer.title) takes the point — caught a blurt"
        case .time, .none: return "\(scorer.title) takes the point — the clock ran out"
        }
    }

    /// Everyone on a team, by name, for the scoreboard and the handover.
    func names(on team: BlurtTeam) -> [String] {
        BlurtRules.members(of: team, in: snapshot.teams).compactMap { snapshot.players[$0] }
    }

    func score(of team: BlurtTeam) -> Int {
        team == .one ? scoreOne : scoreTwo
    }

    var describerName: String {
        guard let play else { return "" }
        return snapshot.players[play.describer] ?? "Someone"
    }

    /// Seconds left in the turn, or nil when it is not running.
    var secondsLeft: Int? {
        guard let play, play.state == .running, let endsAt = play.endsAt else { return nil }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    /// How far through the turn, for the bar. 1 at the start, 0 at the buzzer.
    var turnProgress: Double {
        guard let play, play.state == .running,
              let start = play.startedAt, let end = play.endsAt else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return max(0, min(1, end.timeIntervalSince(now) / total))
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

        let gameID = VibeWordsModel.makeGameID()
        let seed = SudokuGenerator.randomSeed()

        do {
            try await service.createGame(gameID: gameID,
                                         seed: seed,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id,
                                         packs: preferredPacks,
                                         turnSeconds: preferredSeconds)
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

        let gameID = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
    func updateSettings(packs: Set<BlurtPack>, seconds: Int) async {
        guard let gameID = sharedGameID, isHost, !hasStarted else { return }
        preferredPacks = packs
        preferredSeconds = seconds
        BlurtModelSettings.save(packs: packs, seconds: seconds)
        try? await service.updateSettings(gameID: gameID, packs: packs, turnSeconds: seconds)
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

    /// The describer has the phone in their hand; start the clock.
    func beginTurn() async {
        guard let gameID = sharedGameID, isDescriber, play?.state == .ready else { return }
        let seconds = TimeInterval(snapshot.turnSeconds)
        try? await service.beginTurn(gameID: gameID, seconds: seconds)
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

        observation = service.observe(gameID: gameID) { [weak self] snapshot in
            guard let self else { return }
            self.apply(snapshot)
        }
    }

    /// Whether a buzz just landed on me.
    ///
    /// Pure and static so it can be tested without a network, and so the rule is
    /// readable in one place: the round ended on a blurt, I had the word when it
    /// did, and it is news to me. The clock running out deliberately does *not*
    /// count — everybody can see the clock, but a buzz is the one thing the
    /// person mid-sentence is not looking at.
    nonisolated static func caughtMe(previous: BlurtPlay?, next: BlurtPlay?, me: String?) -> Bool {
        guard let me, previous?.state == .running, next?.state == .ended else { return false }
        guard next?.reason == .blurt else { return false }
        return previous?.describer == me
    }

    private func apply(_ newSnapshot: BlurtSnapshot) {
        let previous = snapshot
        if Self.caughtMe(previous: previous.play, next: newSnapshot.play, me: myShortID) {
            caughtCount += 1
        }
        snapshot = newSnapshot

        // A turn that has moved on is not being ended any more.
        if previous.play?.turn != newSnapshot.play?.turn {
            endingTurn = false
        }

        if newSnapshot.play?.state == .running {
            startClock()
        } else {
            stopClock()
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
    private static let secondsKey = "blurt.seconds"

    static func loadPacks() -> Set<BlurtPack> {
        guard let stored = UserDefaults.standard.array(forKey: packsKey) as? [String] else {
            return Set(BlurtPack.allCases)
        }
        let packs = Set(stored.compactMap(BlurtPack.init(rawValue:)))
        // Unticking everything is not a choice anybody means; it would deal an
        // empty deck.
        return packs.isEmpty ? Set(BlurtPack.allCases) : packs
    }

    static func loadSeconds() -> Int {
        let stored = UserDefaults.standard.integer(forKey: secondsKey)
        guard stored > 0 else { return BlurtDuration.default.rawValue }
        return BlurtDuration.nearest(to: stored).rawValue
    }

    static func save(packs: Set<BlurtPack>, seconds: Int) {
        UserDefaults.standard.set(packs.map(\.rawValue).sorted(), forKey: packsKey)
        UserDefaults.standard.set(seconds, forKey: secondsKey)
    }
}
