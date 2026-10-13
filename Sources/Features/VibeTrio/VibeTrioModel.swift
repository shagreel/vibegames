import Combine
import Foundation

/// One line of the end-of-game scoreboard.
struct TrioStanding: Identifiable, Equatable {
    let playerID: String
    let name: String
    let score: Int
    let isMe: Bool
    var id: String { playerID }
}

/// Drives a game of Vibe Pairings, solo or as a race.
///
/// The whole game state is one seed: the deck order, the opening twelve and the
/// order replacements arrive all derive from it, so a shared game stays in step
/// without sending any cards. The only thing a shared game sends is *which*
/// cards were taken, and in what order the server accepted them.
@MainActor
final class VibeTrioModel: ObservableObject {

    enum Session: Equatable {
        case lobby
        case solo
        case shared(gameID: String, isHost: Bool)
    }

    // MARK: Published state

    @Published private(set) var session: Session = .lobby
    @Published private(set) var playerName: String = PlayerIdentity.name ?? ""
    @Published private(set) var hasName: Bool = PlayerIdentity.name?.isEmpty == false

    @Published private(set) var table: TrioTable?
    /// Positions in `table.visible`. Remapped, never rebuilt, when the table
    /// changes underneath — a selection is a set of cards, not of slots.
    @Published private(set) var selected: [Int] = []
    /// Cards shown in red because the last three did not make a trio.
    @Published private(set) var rejected: Set<Int> = []
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var snapshot = TrioSnapshot()
    @Published private(set) var countdown: Int?
    /// Shown for a moment when a claim loses the race for the cards.
    @Published private(set) var conflictNotice: String?
    @Published var errorMessage: String?

    // MARK: Private

    private let service = VibeTrioService.shared
    private var observation: TrioObservation?
    private var countdownTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var conflictTask: Task<Void, Never>?
    private var currentSeed: UInt32?
    private var isResolving = false
    /// Trios taken on this device that the server has not confirmed yet. They
    /// are replayed on top of the confirmed takes so the board does not flicker
    /// back while the write is in flight.
    private var pendingTakes: [[Int]] = []

    private enum StoredKey {
        static let hostedGame = "vibetrio.hostedGameID"
    }

    // MARK: Derived

    var isShared: Bool {
        if case .shared = session { return true }
        return false
    }

    var sharedGameID: String? {
        if case .shared(let id, _) = session { return id }
        return nil
    }

    var isHost: Bool {
        if case .shared(_, let isHost) = session { return isHost }
        return false
    }

    var isWaitingForHost: Bool { isShared && !snapshot.started }

    /// How many people are here, whether or not they have scored.
    var playerCount: Int { isShared ? snapshot.playerCount : 1 }

    /// This player's score. Solo play is the table's own tally.
    var myScore: Int {
        guard isShared, let gameID = sharedGameID else { return table?.triosTaken ?? 0 }
        return snapshot.scores[myShortID(in: gameID)] ?? 0
    }

    var remainingInDeck: Int { table?.remaining.count ?? 0 }
    var cardCount: Int { table?.visible.count ?? 0 }

    /// Over when the deck is spent and nothing left on the table completes a
    /// trio. There is no target: the game ends when the cards run out.
    var isFinished: Bool { table?.isFinished ?? false }

    /// The scoreboard, best first. Only players who have taken something appear,
    /// because only a take carries a name.
    var standings: [TrioStanding] {
        guard isShared, let gameID = sharedGameID else {
            let score = table?.triosTaken ?? 0
            guard score > 0 else { return [] }
            return [TrioStanding(playerID: "solo", name: "You", score: score, isMe: true)]
        }
        let mine = myShortID(in: gameID)
        return snapshot.scores
            .map { playerID, score in
                TrioStanding(playerID: playerID,
                             name: snapshot.name(of: playerID) ?? "Player",
                             score: score,
                             isMe: playerID == mine)
            }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.name < $1.name }
    }

    /// Everyone level at the top — a race can be tied.
    var leaders: [TrioStanding] {
        guard let best = standings.first?.score else { return [] }
        return standings.filter { $0.score == best }
    }

    var canPlay: Bool {
        table != nil && !isFinished && !isWaitingForHost && !isResolving
    }

    private func myShortID(in gameID: String) -> String {
        VibeTrioService.shortID(playerID: PlayerIdentity.id, gameID: gameID)
    }

    var backendUnavailableMessage: String? {
        guard !service.isAvailable else { return nil }
        return FirebaseBootstrapper.unavailableReason?.explanation
            ?? "Playing with friends needs a game service."
    }

    var formattedElapsed: String {
        let total = Int(elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Name

    func submitName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playerName = trimmed
        PlayerIdentity.name = trimmed
        hasName = true
    }

    // MARK: - Session control

    func playSolo() {
        tearDownSharedGame()
        session = .solo
        start(seed: SudokuGenerator.randomSeed())
    }

    func createSharedGame() async {
        guard service.isAvailable, hasName else { return }

        let gameID = GameCode.make()
        let seed = SudokuGenerator.randomSeed()

        do {
            try await service.createGame(gameID: gameID,
                                         seed: seed,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            session = .shared(gameID: gameID, isHost: true)
            start(seed: seed)
            beginObserving(gameID: gameID)
        } catch {
            // Shown to the player, and recorded so it is findable later.
            FirebaseBootstrapper.record(error, during: "Could not create the game")
            errorMessage = "Could not create the game: \(error.localizedDescription)"
        }
    }

    func joinSharedGame(code: String) async {
        guard service.isAvailable, hasName else { return }

        // Forgiving on the way in: these arrive second-hand, heard across a
        // room and typed from memory.
        let gameID = GameCode.normalise(code)
        guard !gameID.isEmpty else { return }

        do {
            let isHost = UserDefaults.standard.string(forKey: StoredKey.hostedGame) == gameID
            try await service.joinGame(gameID: gameID, playerID: PlayerIdentity.id)
            session = .shared(gameID: gameID, isHost: isHost)
            beginObserving(gameID: gameID)
        } catch {
            // Shown to the player, and recorded so it is findable later.
            FirebaseBootstrapper.record(error, during: "Could not join that game")
            errorMessage = "Could not join that game: \(error.localizedDescription)"
        }
    }

    func startSharedGame() async {
        guard let gameID = sharedGameID, isHost else { return }
        do {
            try await service.startGame(gameID: gameID)
        } catch {
            // Shown to the player, and recorded so it is findable later.
            FirebaseBootstrapper.record(error, during: "Could not start the game")
            errorMessage = "Could not start the game: \(error.localizedDescription)"
        }
    }

    func leaveGame() {
        tearDownSharedGame()
        session = .lobby
        table = nil
        selected = []
        rejected = []
        errorMessage = nil
    }

    private func tearDownSharedGame() {
        countdownTask?.cancel(); countdownTask = nil
        clockTask?.cancel(); clockTask = nil
        conflictTask?.cancel(); conflictTask = nil
        countdown = nil
        conflictNotice = nil
        elapsed = 0

        service.stopObserving(observation)
        observation = nil
        snapshot = TrioSnapshot()
        pendingTakes = []
        currentSeed = nil
        isResolving = false
    }

    // MARK: - Shared game

    private func beginObserving(gameID: String) {
        service.stopObserving(observation)
        observation = service.observe(gameID: gameID) { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    private func apply(_ newSnapshot: TrioSnapshot) {
        snapshot = newSnapshot
        guard let seed = newSnapshot.seed else { return }

        if currentSeed != seed {
            // A fresh round — the board, the selection and the clock all restart.
            currentSeed = seed
            pendingTakes = []
            isResolving = false
            selected = []
            rejected = []
            conflictTask?.cancel(); conflictTask = nil
            conflictNotice = nil
            clockTask?.cancel(); clockTask = nil
            elapsed = 0
            startClock()

            // Every guest begins a round here rather than at any button: the
            // host's Start only writes a flag, and the seed arriving is what
            // actually deals a new table.
            AppAnalytics.gameStart(.trio, mode: .shared)
        }

        rebuildTable()
        updateCountdown()
    }

    /// Rebuilds the board from the seed and the takes the server has accepted.
    ///
    /// This is the whole of the shared table. Every device runs it over the same
    /// inputs and lands on the same twelve cards in the same places, so a take
    /// simply replaces three cards where they stand — nothing slides.
    private func rebuildTable() {
        guard let seed = currentSeed else { return }
        let previous = table

        let confirmed = Set(snapshot.takeIDs)
        pendingTakes.removeAll { confirmed.contains($0) }

        let rebuilt = TrioTable.replay(seed: seed, takes: snapshot.takeIDs + pendingTakes)
        table = rebuilt
        remapSelection(from: previous, to: rebuilt)

        if rebuilt.isFinished { stopClock() }
    }

    /// Carries a part-made selection across a table change.
    ///
    /// Indices are positions, so a take anywhere on the board renumbers them.
    /// Following the cards by id means someone else's take does not quietly turn
    /// your two chosen cards into two different ones.
    private func remapSelection(from previous: TrioTable?, to next: TrioTable) {
        guard let previous, !selected.isEmpty else { return }
        let ids = selected.compactMap { index -> Int? in
            previous.visible.indices.contains(index) ? previous.visible[index].id : nil
        }
        selected = ids.compactMap { id in next.visible.firstIndex { $0.id == id } }
        rejected = []
    }

    // MARK: - Game

    private func start(seed: UInt32) {
        currentSeed = seed
        table = TrioTable(seed: seed)
        selected = []
        rejected = []
        pendingTakes = []
        isResolving = false
        conflictNotice = nil
        startClock()

        AppAnalytics.gameStart(.trio, mode: .solo)
    }

    /// Tapping a card toggles it; the third tap judges the three.
    func tap(_ index: Int) {
        guard canPlay else { return }

        if let existing = selected.firstIndex(of: index) {
            selected.remove(at: existing)
            rejected = []
            return
        }

        guard selected.count < 3 else { return }
        selected.append(index)

        if selected.count == 3 { judge() }
    }

    private func judge() {
        let picked = selected
        guard let current = table, current.wouldFormTrio(picked) else {
            // Not a trio: flash the three red, then clear the selection.
            rejected = Set(picked)
            isResolving = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self else { return }
                self.rejected = []
                self.selected = []
                self.isResolving = false
            }
            return
        }

        guard isShared, let gameID = sharedGameID, let seed = currentSeed else {
            table?.takeTrio(at: picked)
            selected = []
            rejected = []
            if table?.isFinished == true { stopClock() }
            return
        }

        let ids = picked.compactMap { index -> Int? in
            current.visible.indices.contains(index) ? current.visible[index].id : nil
        }.sorted()
        guard ids.count == 3 else { return }

        // Take it here and now — the cards go the instant they are spotted, not
        // a round trip later — then let the server decide who really got them.
        pendingTakes.append(ids)
        rebuildTable()
        selected = []
        rejected = []
        isResolving = true

        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.service.claimTrio(gameID: gameID,
                                                       seed: seed,
                                                       cardIDs: ids,
                                                       playerID: PlayerIdentity.id,
                                                       name: self.playerName)
            self.finishClaim(ids, outcome: outcome)
        }
    }

    private func finishClaim(_ ids: [Int], outcome: TrioClaim) {
        isResolving = false

        switch outcome {
        case .won:
            // The next snapshot carries it. Until that lands the optimistic take
            // stands, so the board never blinks back to the old one.
            rebuildTable()

        case .takenBySomeoneElse:
            pendingTakes.removeAll { $0 == ids }
            rebuildTable()
            showConflict()

        case .failed:
            pendingTakes.removeAll { $0 == ids }
            rebuildTable()
            errorMessage = "Could not reach the game. Check your connection."
        }
    }

    private func showConflict() {
        conflictNotice = TrioRules.conflictMessage
        conflictTask?.cancel()
        conflictTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.conflictNotice = nil
        }
    }

    func playAgain() async {
        guard isFinished else { return }

        if let gameID = sharedGameID {
            do {
                try await service.beginRestart(gameID: gameID, seed: SudokuGenerator.randomSeed())
            } catch {
                // Shown to the player, and recorded so it is findable later.
                FirebaseBootstrapper.record(error, during: "Could not start the next game")
                errorMessage = "Could not start the next game: \(error.localizedDescription)"
            }
        } else {
            start(seed: SudokuGenerator.randomSeed())
        }
    }

    /// Lights up a single card that belongs to a trio — solo play only.
    ///
    /// One card, not the whole trio: the point is to narrow the search, and
    /// handing over all three would just be the answer. Racing is a test of who
    /// spots it first, so a hint there would be meaningless — the button is not
    /// shown in a shared game, and this refuses one anyway.
    @discardableResult
    func revealHint() -> Int? {
        guard canPlay, !isShared, let trio = table?.availableTrios.first else { return nil }
        rejected = []
        selected = [trio[0]]
        return trio[0]
    }

    // MARK: - Clock

    private func startClock() {
        clockTask?.cancel()
        elapsed = 0
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !self.isFinished else { return }
                self.elapsed += 0.5
            }
        }
    }

    private func stopClock() {
        clockTask?.cancel()
        clockTask = nil
    }

    // MARK: - Countdown

    private func updateCountdown() {
        guard snapshot.restartTime != nil else {
            countdownTask?.cancel()
            countdownTask = nil
            countdown = nil
            return
        }
        guard countdownTask == nil else { return }

        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let target = self.snapshot.restartTime else {
                    self.countdown = nil
                    self.countdownTask = nil
                    return
                }

                let secondsLeft = Int(ceil(target.timeIntervalSinceNow))
                if secondsLeft <= 0 {
                    self.countdown = nil
                    if let gameID = self.sharedGameID {
                        try? await self.service.clearRestartTime(gameID: gameID)
                    }
                    self.countdownTask = nil
                    return
                }
                self.countdown = secondsLeft
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func endSession() {
        countdownTask?.cancel(); countdownTask = nil
        clockTask?.cancel(); clockTask = nil
        conflictTask?.cancel(); conflictTask = nil
        service.stopObserving(observation)
        observation = nil
    }
}
