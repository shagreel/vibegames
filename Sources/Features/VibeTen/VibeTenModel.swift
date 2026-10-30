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

    /// How many rows the next board starts with. The board always has room for
    /// eighteen; the rest is space the new-row offer grows into. A room's board
    /// is the starting rows the host dealt, so this applies to solo play and to
    /// the rooms this player creates; a joiner plays what they were given. The
    /// columns are always nine.
    @Published var startRows: Int {
        didSet {
            guard startRows != oldValue else { return }
            UserDefaults.standard.set(startRows, forKey: Self.startRowsKey)
        }
    }

    static let startRowsKey = "vibeten.startRows"
    /// The key the setting lived under when it was the board's whole height.
    static let legacyRowsKey = "vibeten.rows"

    /// How many rows one press of the new-row offer adds: two or four, so a
    /// press always adds a whole number of pairs.
    @Published var rowsPerAdd: Int {
        didSet {
            guard VibeTenBoard.rowsPerAddOptions.contains(rowsPerAdd) else {
                rowsPerAdd = VibeTenBoard.minimumRowsPerAdd
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

    /// Whether the starting rows can still be chosen. They are a property of a
    /// *new* game: once a board is in play — or a room exists — they are fixed,
    /// and the settings sheet says so rather than offering a choice that would
    /// do nothing. The start screen is the one place they are offered.
    var canChooseStartRows: Bool {
        if case .lobby = session { return true }
        return false
    }

    /// Whether the pair setting can still be chosen, which is the same rule the
    /// owner asked for on the board's size: before the game starts, not during
    /// it. A board that has been dealt is being played one way, and one board
    /// played two ways is not the game.
    ///
    /// A room's rules belong to the host, so once a room exists they are not
    /// this player's to change — the same reason the shape is fixed. They are
    /// chosen on the start screen, before the room is made.
    var canChoosePairMode: Bool {
        !isShared && !canPlay
    }

    /// Whether how many rows a press adds can still be chosen: before the game
    /// begins. A room's rules belong to the host, so once a room exists it is
    /// not this player's to change.
    var canChooseRowsPerAdd: Bool {
        canChoosePairMode
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
        // `integer(forKey:)` rather than a cast: a launch argument arrives as a
        // string, and a row count that is not one of the four is not a start.
        // The old key held the same four values while it meant the whole board.
        var savedStartRows = defaults.integer(forKey: Self.startRowsKey)
        if savedStartRows == 0 {
            savedStartRows = defaults.integer(forKey: Self.legacyRowsKey)
        }
        startRows = VibeTenBoard.rowOptions.contains(savedStartRows)
            ? savedStartRows
            : VibeTenBoard.defaultStartRows
        let savedPerAdd = defaults.integer(forKey: Self.rowsPerAddKey)
        rowsPerAdd = VibeTenBoard.rowsPerAddOptions.contains(savedPerAdd)
            ? savedPerAdd
            : VibeTenBoard.minimumRowsPerAdd
        wrapRows = defaults.bool(forKey: Self.wrapRowsKey)
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
                                   finishedAt: record?.finishedAt,
                                   clearedAt: record?.clearedAt)
        }
        .sorted(by: vibeTenRank)
    }

    /// The winner: the first player to clear the board. Empty while nobody has
    /// cleared yet — the round is not decided by running out of moves.
    var winners: [VibeTenStanding] {
        let cleared = standings.filter(\.hasCleared)
        guard let first = cleared.compactMap(\.clearedAt).min() else { return [] }
        return cleared.filter { $0.clearedAt == first }
    }

    /// The first player to clear the board, once there is one.
    var roomWinner: VibeTenStanding? { winners.first }

    /// Whether this player is the one who cleared first.
    var amITheWinner: Bool {
        guard let roomWinner else { return false }
        return roomWinner.id == PlayerIdentity.id
    }

    /// Whether every player has either cleared the board or run out of moves.
    var isEveryoneFinished: Bool {
        !snapshot.players.isEmpty && snapshot.players.keys.allSatisfy {
            let record = snapshot.scores[$0]
            return record?.finishedAt != nil || record?.clearedAt != nil
        }
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
        /// Kept for a game saved before the board became always nine columns.
        var columns: Int
        /// The board's capacity, which is always eighteen now.
        var rows: Int
        /// The rows the game started with. Absent from a save made before the
        /// board could grow, where `rows` was the start.
        var startRows: Int?
        /// How many rows of the board's stream had been shown. Absent from
        /// older saves; the board falls back to its tallest column.
        var dealtRows: Int?
        var wrapRows: Bool
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
                     startRows: startRows,
                     dealtRows: board.dealtRows,
                     wrapRows: board.wrapRows,
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
        // The saved board comes with the rules it was dealt by, and they become
        // the choices for the next one: a resumed game is played the way it
        // started, and so is the game after it.
        mode = saved.mode
        wrapRows = saved.wrapRows
        let fallbackStart = VibeTenBoard.rowOptions.contains(saved.rows)
            ? saved.rows
            : VibeTenBoard.defaultStartRows
        startRows = saved.startRows ?? fallbackStart
        board = VibeTenBoard(cells: saved.cells,
                             seed: saved.seed,
                             columns: saved.columns,
                             rows: VibeTenBoard.maximumRows,
                             wrapRows: saved.wrapRows,
                             dealtRows: saved.dealtRows)
        boardToken += 1
        score = saved.score
        finished = saved.finished
        cleared = saved.cleared
        selected = nil
        finishedAt = nil
        lastRoundSeconds = saved.elapsed
        startedAt = Date()
        // A saved board is normally one still in play, but a round that ended
        // while the app was away — or a save from an older build — has to be
        // judged by the rule as it stands now.
        refreshRoundState()
        return true
    }

    /// Re-checks the end of the round against the board as it is, without
    /// waiting for a tap. Only a board that is already a dead end changes.
    func refreshRoundState() {
        guard let board, !finished else { return }
        checkForFinish(board)
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
                                         rows: startRows,
                                         rowsPerAdd: rowsPerAdd,
                                         wrapRows: wrapRows,
                                         mode: mode,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            session = .shared(gameID: gameID, isHost: true)
            previousSeed = seed
            // Dealt with the rows and rules this room was just made with: the
            // observer for the room arrives a moment later, and the first board
            // must not be the wrong size for a heartbeat.
            board = VibeTenBoard(seed: seed,
                                 columns: VibeTenBoard.defaultColumns,
                                 startRows: startRows,
                                 wrapRows: wrapRows)
            boardToken += 1
            startedAt = Date()
            selected = nil
            score = 0
            finished = false
            cleared = false
            finishedAt = nil
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

        // The first clear wins, so once somebody has cleared it the round is
        // over for this player too: their board stops, and the result panel
        // says who won.
        if isShared, let winner = winners.first,
           winner.id != PlayerIdentity.id, !finished {
            finished = true
            finishedAt = Date()
            selected = nil
            // The room should know this player is out of the round too, not
            // still "playing" in the standings.
            reportScore()
        }
    }

    /// The starting rows the next board will be dealt with: the room's when
    /// playing in one, otherwise the player's own choice. The columns are always
    /// nine and the board always has room for eighteen rows.
    var boardStartRows: Int {
        isShared ? snapshot.rows : startRows
    }

    /// How many rows a press adds in play: the room's when playing in one.
    var boardRowsPerAdd: Int {
        isShared ? snapshot.rowsPerAdd : rowsPerAdd
    }

    /// How a taken pair leaves the board in play: the room's when playing in
    /// one, otherwise this device's choice. One room is played one way, because
    /// the pairs are on everybody's board and the boards have to agree.
    var effectiveMode: VibeTenMode {
        isShared ? snapshot.mode : mode
    }

    /// Whether the rows join end to end in play, the room's when playing in one.
    /// The rule is part of a room, not a local preference.
    var effectiveWrapRows: Bool {
        isShared ? snapshot.wrapRows : wrapRows
    }

    private func deal(seed: UInt32) {
        board = VibeTenBoard(seed: seed,
                             columns: VibeTenBoard.defaultColumns,
                             startRows: boardStartRows,
                             wrapRows: effectiveWrapRows)
        boardToken += 1
        startedAt = Date()
        selected = nil
        score = 0
        finished = false
        cleared = false
        finishedAt = nil
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

        if board.take(first, position, mode: effectiveMode) != nil {
            self.board = board
            score += 1
            selected = nil
                reportScore()
            checkForFinish(board)
            saveSoloProgress()
        } else {
            // No message: the digits stay, and the highlight moves to the
            // number just picked, ready to try it with another.
            selected = position
        }
    }

    /// Clearing the board wins. Running out of moves only loses once there is
    /// no way to add a row either: while the grid has room, a board with no
    /// pairs on it is a board to grow, not the end of the round.
    private func checkForFinish(_ board: VibeTenBoard) {
        if board.isCleared {
            cleared = true
            finished = true
        } else if !board.hasMoves && !board.canAddRow {
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

    /// How many rows a press would reveal right now: the rule's two or four,
    /// capped at the even number of rows that still fit. Zero when there is no
    /// room for the smallest press.
    var rowsToAdd: Int {
        guard let board else { return 0 }
        let cap = min(boardRowsPerAdd, board.roomForRows)
        guard cap >= VibeTenBoard.minimumRowsPerAdd else { return 0 }
        return cap % 2 == 0 ? cap : cap - 1
    }

    /// Reveals the next rows of the same deal under the board: two or four at a
    /// press. Solo or in a room — each player's board grows on their own device
    /// — and the digits are the deal's, not freshly drawn, so everybody who has
    /// revealed the same row sees the same digits.
    func addRows() {
        guard canAddRow, var board else { return }
        for _ in 0..<rowsToAdd {
            guard board.addRow() else { break }
        }
        self.board = board
        selected = nil
        checkForFinish(board)
        saveSoloProgress()
    }

    /// Whether the board should offer the new-row button: the round is still
    /// going and there is room for a press of two or four rows.
    var canAddRow: Bool {
        !finished && !isWaitingForHost && rowsToAdd >= VibeTenBoard.minimumRowsPerAdd
    }

    /// Tells the room the score. Shared games only — a solo board is nobody
    /// else's business.
    private func reportScore() {
        guard let gameID = sharedGameID else { return }
        let score = score
        let finishedAt = finished ? (finishedAt ?? Date()) : nil
        let clearedAt = cleared ? (finishedAt ?? Date()) : nil
        scoreTask?.cancel()
        scoreTask = Task { [service] in
            try? await service.recordScore(gameID: gameID,
                                           playerID: PlayerIdentity.id,
                                           score: score,
                                           finishedAt: finishedAt,
                                           clearedAt: clearedAt)
        }
    }

    /// The screen has gone: stop listening and stop being here.
    func endSession() {
        saveSoloProgress()
        guard let gameID = sharedGameID else { return }
        service.removePresence(gameID: gameID, playerID: PlayerIdentity.id)
        tearDownSharedGame()
    }

    /// Deals the same board again — the same seed and starting rows — so a solo
    /// player who ran out of moves can try a different order. A room is left
    /// alone: its board is everybody's, and only a fresh one moves it on.
    func retryBoard() {
        guard case .solo = session, let board else { return }
        deal(seed: board.seed)
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
