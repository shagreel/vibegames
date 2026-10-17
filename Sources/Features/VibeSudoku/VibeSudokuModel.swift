import Combine
import Foundation

/// Drives a game of Number Vibe, solo or shared.
///
/// Solo play generates a puzzle locally. Shared play stores only a seed, so
/// every device builds the identical board and nobody can read the answer out
/// of the database.
@MainActor
final class VibeSudokuModel: ObservableObject {

    enum Session: Equatable {
        case lobby
        case solo
        case shared(gameID: String, isHost: Bool)
    }

    // MARK: Published state

    @Published private(set) var session: Session = .lobby
    @Published private(set) var playerName: String = PlayerIdentity.name ?? ""
    @Published private(set) var hasName: Bool = PlayerIdentity.name?.isEmpty == false

    /// Difficulty chosen in the lobby. Applies to a solo game, and to a shared
    /// game as the host's choice; guests follow whatever the host picked.
    @Published var difficulty: SudokuDifficulty = .easy

    @Published private(set) var puzzle: SudokuPuzzle?
    @Published private(set) var values = [Int](repeating: 0, count: SudokuPuzzle.cellCount)
    @Published private(set) var notes = [Set<Int>](repeating: [], count: SudokuPuzzle.cellCount)

    /// How many numbers a cell's notes hold: four, or nine.
    ///
    /// A setting rather than a rule, because the trade is real both ways. Four
    /// are shown big, two by two, which is what a phone-sized cell can carry;
    /// nine are every candidate, each in its own square, which is how pencil
    /// marks are read on paper — and four make a hard puzzle harder. Kept in
    /// `UserDefaults` so it survives the puzzle, the game and the launch.
    @Published private(set) var noteLimit = UserDefaults.standard.object(forKey: noteLimitKey) as? Int ?? 4

    static let noteLimitKey = "vibegames.sudoku.noteLimit"
    static let noteLimits = [4, 9]

    /// Set when a note is refused because the cell is full.
    ///
    /// A key that does nothing is worse than one that says why, and the notes
    /// are the one place in this game where a tap can be ignored.
    @Published private(set) var noteNotice: String?
    @Published private(set) var selectedCell: Int?
    @Published var isNoteMode = false
    @Published private(set) var solved = false

    @Published private(set) var snapshot = SudokuSnapshot()
    @Published private(set) var countdown: Int?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isBusy = false

    // MARK: Private

    private let service = VibeSudokuService.shared
    private var observation: DatabaseHandleBox?
    private var countdownTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var previousSeed: UInt32?

    private enum StoredKey {
        static let hostedGame = "vibesudoku.hostedGameID"
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
    var canPlay: Bool { puzzle != nil && !solved && !isWaitingForHost }

    var filledCount: Int { values.filter { $0 != 0 }.count }
    var progress: Double { Double(filledCount) / Double(SudokuPuzzle.cellCount) }

    /// Cells that clash with another in the same row, column or box.
    var conflictingCells: Set<Int> { SudokuSolver.conflicts(in: values) }

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
        loadPuzzle(seed: SudokuGenerator.randomSeed(), difficulty: difficulty)
    }

    func createSharedGame() async {
        guard service.isAvailable, hasName else { return }
        isBusy = true
        defer { isBusy = false }

        let gameID = GameCode.make()
        let seed = SudokuGenerator.randomSeed()

        do {
            try await service.createGame(gameID: gameID,
                                         seed: seed,
                                         difficulty: difficulty,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            session = .shared(gameID: gameID, isHost: true)
            previousSeed = seed
            loadPuzzle(seed: seed, difficulty: difficulty)
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
        puzzle = nil
        clearBoard()
        errorMessage = nil
    }

    @Published var errorMessage: String?

    private func tearDownSharedGame() {
        countdownTask?.cancel(); countdownTask = nil
        clockTask?.cancel(); clockTask = nil
        countdown = nil
        elapsed = 0

        service.stopObserving(observation)
        observation = nil
        snapshot = SudokuSnapshot()
        previousSeed = nil
    }

    // MARK: - Shared game observation

    private func beginObserving(gameID: String) {
        service.stopObserving(observation)
        observation = service.observe(gameID: gameID) { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    private func apply(_ newSnapshot: SudokuSnapshot) {
        snapshot = newSnapshot

        guard let seed = newSnapshot.seed else { return }

        // A new seed means the previous round finished and another began.
        if let previous = previousSeed, previous != seed {
            clearBoard()
            solved = false
        }
        previousSeed = seed
        loadPuzzle(seed: seed, difficulty: newSnapshot.difficulty)

        // The host started: the race has begun, so the clock begins now.
        if !isWaitingForHost, clockTask == nil, !solved {
            startClock()
        }
        updateCountdown()
    }

    // MARK: - Loading

    private func loadPuzzle(seed: UInt32, difficulty: SudokuDifficulty) {
        let generated = SudokuGenerator.puzzle(seed: seed, difficulty: difficulty)

        // Keep any digits the player has already entered that are still legal,
        // so a snapshot arriving mid-round does not wipe their work.
        let previous = values
        let previousPuzzle = puzzle
        let isSamePuzzle = previousPuzzle?.seed == seed

        puzzle = generated
        if isSamePuzzle {
            values = previous
        } else {
            values = generated.givens
            notes = [Set<Int>](repeating: [], count: SudokuPuzzle.cellCount)
            solved = false
            // A shared board is dealt the moment its seed arrives, but nobody
            // can play it until the host starts — so the clock should not start
            // either. The time is part of the race; a room that waits a minute
            // for a fourth player should not open with a minute on the board.
            if isWaitingForHost {
                clockTask?.cancel()
                clockTask = nil
                elapsed = 0
            } else {
                startClock()
            }
        }
    }

    private func clearBoard() {
        guard let puzzle else {
            values = [Int](repeating: 0, count: SudokuPuzzle.cellCount)
            notes = [Set<Int>](repeating: [], count: SudokuPuzzle.cellCount)
            return
        }
        values = puzzle.givens
        notes = [Set<Int>](repeating: [], count: SudokuPuzzle.cellCount)
        selectedCell = nil
    }

    // MARK: - Playing

    /// Four or nine, and everything that follows from changing it.
    ///
    /// Going from nine to four has to deal with cells that already hold more:
    /// the lowest marks are kept, because those are the ones written first.
    func setNoteLimit(_ limit: Int) {
        guard VibeSudokuModel.noteLimits.contains(limit), limit != noteLimit else { return }
        noteLimit = limit
        UserDefaults.standard.set(noteLimit, forKey: Self.noteLimitKey)
        notes = notes.map { Set($0.sorted().prefix(noteLimit)) }
        noteNotice = nil
    }

    func select(_ index: Int) {
        guard index >= 0, index < SudokuPuzzle.cellCount else { return }
        noteNotice = nil
        // Tapping the selected cell again clears the selection.
        selectedCell = (selectedCell == index) ? nil : index
    }

    func enter(_ digit: Int) {
        guard canPlay, let index = selectedCell, let puzzle else { return }
        guard !puzzle.isGiven(index) else { return }

        if isNoteMode {
            noteNotice = nil
            if notes[index].contains(digit) {
                notes[index].remove(digit)
            } else if notes[index].count < noteLimit {
                notes[index].insert(digit)
            } else {
                noteNotice = "Notes hold \(noteLimit) numbers."
                return
            }
            return
        }

        // Tapping the same digit again clears the cell, which is the quickest
        // way to undo a mistake.
        values[index] = (values[index] == digit) ? 0 : digit
        notes[index] = []

        if values[index] != 0 {
            // Filling a cell clears that digit from peers' notes only if the
            // player asked for notes; leave their marks alone otherwise.
            clearNotes(around: index, digit: digit)
        }

        checkForCompletion()
    }

    func erase() {
        guard canPlay, let index = selectedCell, let puzzle else { return }
        guard !puzzle.isGiven(index) else { return }
        values[index] = 0
        notes[index] = []
    }

    /// Removes a digit from the notes of the row, column and box around a cell.
    private func clearNotes(around index: Int, digit: Int) {
        let r = SudokuSolver.row(of: index)
        let c = SudokuSolver.column(of: index)
        let b = SudokuSolver.box(of: index)

        for other in 0..<SudokuPuzzle.cellCount
        where SudokuSolver.row(of: other) == r
            || SudokuSolver.column(of: other) == c
            || SudokuSolver.box(of: other) == b {
            notes[other].remove(digit)
        }
    }

    private func checkForCompletion() {
        guard SudokuSolver.isComplete(values) else { return }
        solved = true
        clockTask?.cancel()
        clockTask = nil
        recordWinIfShared()
    }

    private func recordWinIfShared() {
        guard let gameID = sharedGameID else { return }
        let name = playerName
        Task { try? await service.recordWinnerIfAbsent(gameID: gameID, name: name) }
    }

    /// Starts the next round. Solo reloads immediately; a shared game writes a
    /// fresh seed and gives everyone a countdown to see the result.
    func playAgain() async {
        guard solved || isRoundOver else { return }

        if let gameID = sharedGameID {
            let seed = SudokuGenerator.randomSeed()
            do {
                try await service.beginRestart(gameID: gameID, seed: seed)
            } catch {
                // Shown to the player, and recorded so it is findable later.
                FirebaseBootstrapper.record(error, during: "Could not start the next round")
                errorMessage = "Could not start the next round: \(error.localizedDescription)"
            }
        } else {
            loadPuzzle(seed: SudokuGenerator.randomSeed(), difficulty: difficulty)
        }
    }

    var isRoundOver: Bool {
        solved || (snapshot.winner != nil && snapshot.winner?.name != playerName)
    }

    // MARK: - Clock

    private func startClock() {
        clockTask?.cancel()
        elapsed = 0
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !self.solved else { return }
                self.elapsed += 0.5
            }
        }
    }

    // MARK: - Restart countdown

    private func updateCountdown() {
        guard let restartAt = snapshot.restartTime else {
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
                    self.solved = false
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
        service.stopObserving(observation)
        observation = nil
    }
}
