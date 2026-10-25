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

    /// Bumped each time a board is dealt, so the screen can report a round
    /// starting without caring what the seed was.
    @Published private(set) var boardToken = 0
    @Published private(set) var lastRoundSeconds = 0

    /// How a taken pair leaves the board. A preference, not a room rule: every
    /// player takes pairs on their own copy, so each may play the way they like.
    @Published var mode: VibeTenMode {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey)
        }
    }

    static let modeKey = "vibeten.mode"

    /// Whether a solo board offers a new row once the top of the grid is free.
    /// Another preference rather than a room rule: a room's board has to be the
    /// same for everybody, so this one only applies when playing alone.
    @Published var addRowEnabled: Bool {
        didSet {
            guard addRowEnabled != oldValue else { return }
            UserDefaults.standard.set(addRowEnabled, forKey: Self.addRowKey)
        }
    }

    static let addRowKey = "vibeten.addRow"

    /// The board's shape, as the player likes it. A room's board is the shape
    /// the host dealt, so these apply to solo play and to the rooms this player
    /// creates; a joiner plays what they were given.
    @Published var columns: Int {
        didSet {
            guard columns != oldValue else { return }
            UserDefaults.standard.set(columns, forKey: Self.columnsKey)
        }
    }

    @Published var rows: Int {
        didSet {
            guard rows != oldValue else { return }
            UserDefaults.standard.set(rows, forKey: Self.rowsKey)
        }
    }

    static let columnsKey = "vibeten.columns"
    static let rowsKey = "vibeten.rows"

    /// How hard the next board is to take apart. Part of the deal, like the
    /// shape: the pairs are placed differently, so a room has one difficulty for
    /// everybody, chosen by the host.
    @Published var difficulty: VibeTenDifficulty {
        didSet {
            guard difficulty != oldValue else { return }
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
        }
    }

    static let difficultyKey = "vibeten.difficulty"

    /// How much of the grid a game starts with. A part-filled board is only
    /// offered with the new-row setting on, because the rows are what fills it.
    @Published var startFill: VibeTenStartFill {
        didSet {
            guard startFill != oldValue else { return }
            UserDefaults.standard.set(startFill.rawValue, forKey: Self.startFillKey)
        }
    }

    /// How many rows one press of the offer adds: one to four.
    @Published var rowsPerAdd: Int {
        didSet {
            let clamped = min(max(rowsPerAdd, VibeTenBoard.minimumRowsPerAdd),
                              VibeTenBoard.maximumRowsPerAdd)
            guard rowsPerAdd == clamped else {
                rowsPerAdd = clamped
                return
            }
            guard rowsPerAdd != oldValue else { return }
            UserDefaults.standard.set(rowsPerAdd, forKey: Self.rowsPerAddKey)
        }
    }

    /// Whether the rows read end to end: the last square of one row is next to
    /// the first of the row below it.
    @Published var wrapRows: Bool {
        didSet {
            guard wrapRows != oldValue else { return }
            UserDefaults.standard.set(wrapRows, forKey: Self.wrapRowsKey)
        }
    }

    static let startFillKey = "vibeten.startFill"
    static let rowsPerAddKey = "vibeten.rowsPerAdd"
    static let wrapRowsKey = "vibeten.wrapRows"

    @Published private(set) var snapshot = VibeTenSnapshot()
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    // MARK: Private

    private let service = VibeTenService.shared
    private var observation: VibeTenObservation?
    private var previousSeed: UInt32?
    private var finishedAt: Date?
    private var startedAt: Date?
    private var scoreTask: Task<Void, Never>?

    private enum StoredKey {
        static let hostedGame = "vibeten.hostedGameID"
    }

    // MARK: Derived

    var isShared: Bool {
        if case .shared = session { return true }
        return false
    }

    /// Whether the board's size can still be chosen. It is a property of a
    /// *new* game: once a board is in play — or a room exists — the shape is
    /// fixed, and the settings sheet says so rather than offering a choice that
    /// would do nothing. The start screen is the one place it is offered.
    var canChooseBoardShape: Bool {
        if case .lobby = session { return true }
        return false
    }

    /// Whether the pair setting can still be chosen, which is the same rule the
    /// owner asked for on the board's size: before the game starts, not during
    /// it. A board that has been dealt is being played one way, and one board
    /// played two ways is not the game.
    ///
    /// A room waiting for its host is not a game in play yet, so the choice is
    /// still there — the board is dealt, but nobody has taken a pair.
    var canChoosePairMode: Bool {
        !canPlay
    }

    /// Whether the board's fill and the rows a press adds can still be chosen:
    /// solo games only (a room starts full for everybody), before the game
    /// begins, and only while the new-row offer is on — the rows are what fills
    /// a part-filled board.
    var canChooseRowSupply: Bool {
        !isShared && canChoosePairMode && addRowEnabled
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

    init() {
        let defaults = UserDefaults.standard
        mode = VibeTenMode(rawValue: defaults.string(forKey: Self.modeKey) ?? "") ?? .remove
        // On unless it has been turned off: a solo player who has never opened
        // the settings should still get the extra row when the grid has room.
        // `bool(forKey:)` rather than a cast, so `-vibeten.addRow NO` in a launch
        // argument — a string, not a stored boolean — reads as the answer it is.
        addRowEnabled = defaults.object(forKey: Self.addRowKey) == nil
            ? true
            : defaults.bool(forKey: Self.addRowKey)
        // `integer(forKey:)` rather than a cast: a launch argument arrives as a
        // string, and a shape that is not one of the four is not a board.
        let savedColumns = defaults.integer(forKey: Self.columnsKey)
        columns = VibeTenBoard.columnOptions.contains(savedColumns)
            ? savedColumns
            : VibeTenBoard.defaultColumns
        let savedRows = defaults.integer(forKey: Self.rowsKey)
        rows = VibeTenBoard.rowOptions.contains(savedRows) ? savedRows : VibeTenBoard.defaultRows
        startFill = VibeTenStartFill(rawValue: defaults.string(forKey: Self.startFillKey) ?? "")
            ?? .full
        let savedPerAdd = defaults.integer(forKey: Self.rowsPerAddKey)
        rowsPerAdd = (VibeTenBoard.minimumRowsPerAdd...VibeTenBoard.maximumRowsPerAdd)
            .contains(savedPerAdd) ? savedPerAdd : VibeTenBoard.minimumRowsPerAdd
        wrapRows = defaults.bool(forKey: Self.wrapRowsKey)
        difficulty = VibeTenDifficulty(rawValue: defaults.string(forKey: Self.difficultyKey) ?? "")
            ?? .medium
    }

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
        SoloProgressStore.clear(game: Self.progressGame)
        session = .solo
        deal(seed: UInt32.random(in: 0...UInt32.max))
    }

    // MARK: - Left in progress

    /// Where this game's saved board lives.
    static let progressGame = "ten"

    /// What a solo board is, well enough to put it back exactly.
    struct Saved: Codable, Equatable {
        var seed: UInt32
        var columns: Int
        var rows: Int
        var wrapRows: Bool
        var difficulty: VibeTenDifficulty
        var mode: VibeTenMode
        var cells: [[VibeTenCell]]
        var score: Int
        var finished: Bool
        var cleared: Bool
        var elapsed: Int
    }

    /// The game as it stands, if it is a solo game worth coming back to.
    var savedSolo: Saved? {
        guard case .solo = session, let board else { return nil }
        return Saved(seed: board.seed,
                     columns: board.columns,
                     rows: board.rows,
                     wrapRows: board.wrapRows,
                     difficulty: board.difficulty,
                     mode: mode,
                     cells: board.stacks,
                     score: score,
                     finished: finished,
                     cleared: cleared,
                     elapsed: lastRoundSeconds)
    }

    /// The line the resume prompt shows.
    var savedSummary: String {
        guard let board else { return "A board is waiting." }
        let pairs = "\(score) \(score == 1 ? "pair" : "pairs")"
        if finished { return "\(pairs) taken, and the board is done." }
        return "\(pairs) taken · \(board.remaining) digits left"
    }

    /// Keeps the board so leaving the screen does not end the game.
    func saveSoloProgress() {
        guard case .solo = session, let saved = savedSolo else { return }
        // A finished round is not something to come back to.
        if saved.finished {
            SoloProgressStore.clear(game: Self.progressGame)
        } else {
            SoloProgressStore.save(saved, game: Self.progressGame, summary: savedSummary)
        }
    }

    /// Picks the saved board back up.
    @discardableResult
    func resumeSolo() -> Bool {
        guard let saved = SoloProgressStore.state(Saved.self, game: Self.progressGame) else {
            return false
        }
        tearDownSharedGame()
        session = .solo
        mode = saved.mode
        board = VibeTenBoard(cells: saved.cells,
                             seed: saved.seed,
                             columns: saved.columns,
                             rows: saved.rows,
                             wrapRows: saved.wrapRows,
                             difficulty: saved.difficulty)
        boardToken += 1
        score = saved.score
        finished = saved.finished
        cleared = saved.cleared
        selected = nil
        message = nil
        finishedAt = nil
        lastRoundSeconds = saved.elapsed
        startedAt = Date()
        return true
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
                                         columns: columns,
                                         rows: rows,
                                         difficulty: difficulty,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            session = .shared(gameID: gameID, isHost: true)
            previousSeed = seed
            // Dealt with the shape and difficulty this room was just made with:
            // the observer for the room arrives a moment later, and the first
            // board must not be the wrong size or level for a heartbeat.
            board = VibeTenBoard(seed: seed,
                                 columns: columns,
                                 rows: rows,
                                 startRows: rows,
                                 wrapRows: wrapRows,
                                 difficulty: difficulty)
            boardToken += 1
            startedAt = Date()
            selected = nil
            score = 0
            finished = false
            cleared = false
            finishedAt = nil
            message = nil
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
        saveSoloProgress()
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

    /// The shape the next board will be dealt with: the room's when playing in
    /// one, otherwise the player's own choice.
    var boardShape: (columns: Int, rows: Int) {
        if isShared { return (snapshot.columns, snapshot.rows) }
        return (columns, rows)
    }

    /// How many rows a board of this shape starts with.
    ///
    /// A part-filled board goes with the new-row setting — the rows are what
    /// fills it — and a room always starts full, so that everybody's board is
    /// the same shape and the same size.
    func startRows(for shape: (columns: Int, rows: Int)) -> Int {
        guard !isShared, addRowEnabled, startFill == .third else { return shape.rows }
        return max(1, shape.rows / 3)
    }

    var startingRows: Int { startRows(for: boardShape) }

    /// The difficulty the next board is dealt with: the room's when playing in
    /// one, otherwise the player's own choice.
    var boardDifficulty: VibeTenDifficulty {
        isShared ? snapshot.difficulty : difficulty
    }

    private func deal(seed: UInt32) {
        let shape = boardShape
        board = VibeTenBoard(seed: seed,
                             columns: shape.columns,
                             rows: shape.rows,
                             startRows: startRows(for: shape),
                             wrapRows: wrapRows,
                             difficulty: boardDifficulty)
        boardToken += 1
        startedAt = Date()
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

        if board.take(first, position, mode: mode) != nil {
            self.board = board
            score += 1
            selected = nil
            message = nil
            reportScore()
            checkForFinish(board)
            saveSoloProgress()
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
        if let startedAt {
            lastRoundSeconds = max(0, Int(Date().timeIntervalSince(startedAt)))
        }
        selected = nil
        reportScore()
    }

    /// Hangs fresh rows under a solo board: as many as one press deals, or as
    /// many as the grid still has room for.
    ///
    /// Only while the bottom row is free — the grid has a fixed number of rows
    /// and the board hangs from the top — and only solo, because a room's board
    /// is the same for everybody and one player dealing themselves new digits
    /// would be a very different game.
    func addRows() {
        guard canAddRow, var board else { return }
        let wanted = min(rowsPerAdd, board.roomForRows)
        for _ in 0..<max(0, wanted) {
            var digits: [Int] = []
            for _ in 0..<board.columns { digits.append(Int.random(in: 1...9)) }
            guard board.addRow(digits) else { break }
        }
        self.board = board
        selected = nil
        message = nil
        saveSoloProgress()
    }

    /// Whether the board should offer the new-row button: the setting is on,
    /// this is a solo game, and every column is clear of the top row.
    var canAddRow: Bool {
        addRowEnabled && !isShared && !finished && !isWaitingForHost
            && (board?.canAddRow ?? false)
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
        saveSoloProgress()
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
