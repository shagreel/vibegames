import Combine
import Foundation

/// Drives a game of Vibe Ten, solo or shared.
///
/// Solo play deals locally; a shared room stores one seed and each player's
/// score, so every device builds the identical board and the server never sees
/// which pairs anybody took.
@MainActor
final class VibeTenModel: ObservableObject {

    enum Session: Equatable {
        case lobby
        case solo
        case shared(gameID: String, isHost: Bool)
    }

    // MARK: Published state

    @Published private(set) var session: Session = .lobby
    @Published private(set) var playerName: String = PlayerIdentity.name ?? ""
    @Published private(set) var hasName: Bool = PlayerIdentity.name?.isEmpty == false

    @Published private(set) var board: VibeTenBoard?
    @Published private(set) var selected: VibeTenBoard.Position?
    /// Pairs taken this round. One point each.
    @Published private(set) var score = 0
    /// No pairs left, or the board is empty.
    @Published private(set) var finished = false
    @Published private(set) var cleared = false
    /// A refusal, said out loud for a moment.
    @Published private(set) var message: String?

    @Published private(set) var snapshot = VibeTenSnapshot()
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    // MARK: Private

    private let service = VibeTenService.shared
    private var observation: VibeTenObservation?
    private var previousSeed: UInt32?
    private var finishedAt: Date?
    private var scoreTask: Task<Void, Never>?

    private enum StoredKey {
        static let hostedGame = "vibeten.hostedGameID"
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
    var canPlay: Bool { board != nil && !finished && !isWaitingForHost }

    var remaining: Int { board?.remaining ?? 0 }
    var pairsLeft: Int { board?.availableMatches().count ?? 0 }

    var subtitle: String {
        if board == nil { return "Match the digits." }
        if let gameID = sharedGameID {
            return "\(snapshot.playerCount) \(snapshot.playerCount == 1 ? "player" : "players")"
                + " · code \(GameCode.display(gameID)) · \(score) \(score == 1 ? "pair" : "pairs")"
        }
        return "Solo · \(score) \(score == 1 ? "pair" : "pairs") · \(pairsLeft) left to take"
    }

    var backendUnavailableMessage: String? {
        guard !service.isAvailable else { return nil }
        return FirebaseBootstrapper.unavailableReason?.explanation
            ?? "Playing with friends needs a game service."
    }

    /// Everyone in the room, in the order the rule puts them.
    var standings: [VibeTenStanding] {
        snapshot.players.map { playerID, name in
            let record = snapshot.scores[playerID]
            return VibeTenStanding(id: playerID,
                                   name: name,
                                   score: record?.score ?? 0,
                                   finishedAt: record?.finishedAt)
        }
        .sorted(by: vibeTenRank)
    }

    /// The winner, once there is one: only settled when somebody has finished
    /// and nobody who is behind can still catch them, so it is only shown when
    /// the game is over for this player and for everybody else.
    var winners: [VibeTenStanding] {
        guard finished else { return [] }
        let ranked = standings
        guard let best = ranked.first else { return [] }
        // Everyone who can still score more than the leader keeps the game open.
        let caughtUp = ranked.contains { !$0.isFinished && $0.score > best.score }
        guard !caughtUp else { return [] }
        return ranked.filter { $0.score == best.score }
    }

    var isEveryoneFinished: Bool {
        !snapshot.players.isEmpty && snapshot.players.keys.allSatisfy { snapshot.scores[$0]?.finishedAt != nil }
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
        deal(seed: UInt32.random(in: 0...UInt32.max))
    }

    func createSharedGame() async {
        guard service.isAvailable, hasName else { return }
        isBusy = true
        defer { isBusy = false }

        let gameID = GameCode.make()
        let seed = UInt32.random(in: 0...UInt32.max)

        do {
            try await service.createGame(gameID: gameID,
                                         seed: seed,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            session = .shared(gameID: gameID, isHost: true)
            previousSeed = seed
            deal(seed: seed)
            beginObserving(gameID: gameID)
        } catch {
            FirebaseBootstrapper.record(error, during: "Could not create the game")
            errorMessage = "Could not create the game: \(error.localizedDescription)"
        }
    }

    func joinSharedGame(code: String) async {
        guard service.isAvailable, hasName else { return }

        let gameID = GameCode.normalise(code)
        guard !gameID.isEmpty else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            let isHost = UserDefaults.standard.string(forKey: StoredKey.hostedGame) == gameID
            try await service.joinGame(gameID: gameID,
                                       playerID: PlayerIdentity.id,
                                       name: playerName)
            session = .shared(gameID: gameID, isHost: isHost)
            beginObserving(gameID: gameID)
        } catch {
            FirebaseBootstrapper.record(error, during: "Could not join that game")
            errorMessage = "Could not join that game: \(error.localizedDescription)"
        }
    }

    func startSharedGame() async {
        guard let gameID = sharedGameID, isHost else { return }
        do {
            try await service.startGame(gameID: gameID)
        } catch {
            FirebaseBootstrapper.record(error, during: "Could not start the game")
            errorMessage = "Could not start the game: \(error.localizedDescription)"
        }
    }

    func leaveGame() {
        guard let gameID = sharedGameID else {
            session = .lobby
            board = nil
            selected = nil
            score = 0
            finished = false
            return
        }
        service.removePresence(gameID: gameID, playerID: PlayerIdentity.id)
        tearDownSharedGame()
        session = .lobby
        board = nil
        selected = nil
        score = 0
        finished = false
        errorMessage = nil
    }

    private func tearDownSharedGame() {
        service.stopObserving(observation)
        observation = nil
        snapshot = VibeTenSnapshot()
        previousSeed = nil
    }

    // MARK: - Shared game observation

    private func beginObserving(gameID: String) {
        service.stopObserving(observation)
        observation = service.observe(gameID: gameID, playerID: PlayerIdentity.id) { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    private func apply(_ newSnapshot: VibeTenSnapshot) {
        snapshot = newSnapshot
        guard let seed = newSnapshot.seed else { return }

        let changed = previousSeed != seed
        previousSeed = seed

        if changed {
            // A new seed is a new board for everybody, including whoever dealt it.
            deal(seed: seed)
        }
    }

    private func deal(seed: UInt32) {
        board = VibeTenBoard(seed: seed)
        selected = nil
        score = 0
        finished = false
        cleared = false
        finishedAt = nil
        message = nil
    }

    // MARK: - Playing

    func tap(_ position: VibeTenBoard.Position) {
        guard canPlay, var board else { return }

        guard let first = selected else {
            selected = position
            return
        }

        if first == position {
            selected = nil
            return
        }

        if board.remove(first, position) {
            self.board = board
            score += 1
            selected = nil
            message = nil
            reportScore()
            checkForFinish(board)
        } else {
            // The new tap becomes the selection, and the refusal is said once
            // rather than leaving a tap that appears to do nothing.
            selected = position
            message = "Those two don't pair."
        }
    }

    private func checkForFinish(_ board: VibeTenBoard) {
        if board.isCleared {
            cleared = true
            finished = true
        } else if !board.hasMoves {
            finished = true
        }
        guard finished else { return }
        finishedAt = Date()
        selected = nil
        reportScore()
    }

    /// Tells the room the score. Shared games only — a solo board is nobody
    /// else's business.
    private func reportScore() {
        guard let gameID = sharedGameID else { return }
        let score = score
        let finishedAt = finished ? (finishedAt ?? Date()) : nil
        scoreTask?.cancel()
        scoreTask = Task { [service] in
            try? await service.recordScore(gameID: gameID,
                                           playerID: PlayerIdentity.id,
                                           score: score,
                                           finishedAt: finishedAt)
        }
    }

    /// The screen has gone: stop listening and stop being here.
    func endSession() {
        guard let gameID = sharedGameID else { return }
        service.removePresence(gameID: gameID, playerID: PlayerIdentity.id)
        tearDownSharedGame()
    }

    /// Another round. Solo deals a fresh board; in a room whoever asks deals one
    /// for everybody, which is what clears the scores.
    func playAgain() async {
        if let gameID = sharedGameID {
            do {
                try await service.beginRestart(gameID: gameID, seed: UInt32.random(in: 0...UInt32.max))
            } catch {
                FirebaseBootstrapper.record(error, during: "Could not deal the next board")
                errorMessage = "Could not deal the next board: \(error.localizedDescription)"
            }
        } else {
            deal(seed: UInt32.random(in: 0...UInt32.max))
        }
    }
}
