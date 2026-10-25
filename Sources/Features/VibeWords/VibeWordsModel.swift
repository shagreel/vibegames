import Combine
import Foundation

/// Drives a game of Word Vibe, solo or shared.
///
/// Solo play needs no backend. Shared play uses the same Realtime Database
/// schema the web client has always used, so the two can sit in one game.
@MainActor
final class VibeWordsModel: ObservableObject {

    // MARK: Where the player is

    enum Session: Equatable {
        case lobby
        /// Local game on this device, no network.
        case solo
        /// A game in the shared database. `isHost` controls who can start it.
        case shared(gameID: String, isHost: Bool)
    }

    enum Key: Hashable {
        case letter(Character)
        case enter
        case delete
    }

    // MARK: Published state

    @Published private(set) var session: Session = .lobby
    @Published private(set) var playerName: String = PlayerIdentity.name ?? ""
    @Published private(set) var hasName: Bool = PlayerIdentity.name?.isEmpty == false

    @Published private(set) var answer = ""
    @Published private(set) var guesses: [String] = []
    @Published private(set) var currentGuess = ""
    @Published private(set) var won = false
    @Published private(set) var lost = false
    @Published private(set) var message: String?
    /// Bumped to trigger the "invalid guess" shake.
    @Published private(set) var rejectionCount = 0

    @Published private(set) var snapshot = GameSnapshot()
    @Published private(set) var countdown: Int?
    @Published private(set) var isBusy = false

    // MARK: Private

    private let service = VibeWordsService.shared
    private var observation: GameObservation?
    private var countdownTask: Task<Void, Never>?
    private var previousSharedWord: String?

    private enum StoredKey {
        static let hostedGame = "vibewords.hostedGameID"
    }

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

    /// Shared games wait for the host to press start.
    var isWaitingForHost: Bool {
        isShared && !snapshot.started
    }

    /// Over when this player is done.
    ///
    /// Somebody else's win does not end the round for everybody: the owner asked
    /// to be able to finish the word for fun, and a win is recorded against the
    /// first person regardless. It *is* announced — that was the other half of
    /// the report, and it went wrong because the notice only appeared once this
    /// player's own round was over, which is to say never for a late joiner.
    var isRoundOver: Bool { won || lost }

    /// The stored winner, when it is not this player.
    var someoneElseWon: Bool {
        guard let winner = snapshot.winner else { return false }
        return winner.name != playerName
    }

    /// Whether the board takes input at all.
    ///
    /// The rule itself is a pure function below, so the awkward part — that a
    /// countdown blocks input — can be tested without a database and a clock.
    var canPlay: Bool {
        Self.canPlay(isRoundOver: isRoundOver,
                     isWaitingForHost: isWaitingForHost,
                     hasAnswer: !answer.isEmpty,
                     isCountingDown: countdown != nil)
    }

    /// The four ways the board is not taking input.
    ///
    /// `isCountingDown` matters as much as the rest: a restart deals the next
    /// word *before* the countdown to it has finished, so a guess sent during
    /// those seconds is scored against a word the round has not started on —
    /// free colours, and the answer a few guesses later. The web client had the
    /// same hole; both were reported from the same game.
    static func canPlay(isRoundOver: Bool,
                        isWaitingForHost: Bool,
                        hasAnswer: Bool,
                        isCountingDown: Bool) -> Bool {
        !isRoundOver && !isWaitingForHost && hasAnswer && !isCountingDown
    }

    /// True when shared play is impossible because Firebase is not set up.
    var backendUnavailableMessage: String? {
        guard !service.isAvailable else { return nil }
        return FirebaseBootstrapper.unavailableReason?.explanation
            ?? "Playing with friends needs a game service."
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
        startLocalRound()
    }

    // MARK: - Left in progress

    /// Where this game's saved round lives.
    static let progressGame = "words"

    /// A solo round, well enough to put it back exactly: the word, the guesses
    /// already made and the letters half-typed.
    struct Saved: Codable, Equatable {
        var answer: String
        var guesses: [String]
        var currentGuess: String
        var won: Bool
        var lost: Bool
    }

    var savedSolo: Saved? {
        guard case .solo = session, !answer.isEmpty else { return nil }
        return Saved(answer: answer,
                     guesses: guesses,
                     currentGuess: currentGuess,
                     won: won,
                     lost: lost)
    }

    var savedSummary: String {
        let used = guesses.count
        if used == 0 { return "A word is waiting, with every guess left." }
        return "\(used) of \(WordGameEngine.maxGuesses) guesses used"
    }

    /// Keeps the round so leaving the screen does not end it.
    func saveSoloProgress() {
        guard case .solo = session, let saved = savedSolo else { return }
        if saved.won || saved.lost {
            SoloProgressStore.clear(game: Self.progressGame)
        } else {
            SoloProgressStore.save(saved, game: Self.progressGame, summary: savedSummary)
        }
    }

    /// Picks the saved round back up.
    @discardableResult
    func resumeSolo() -> Bool {
        guard let saved = SoloProgressStore.state(Saved.self, game: Self.progressGame) else {
            return false
        }
        tearDownSharedGame()
        session = .solo
        answer = saved.answer
        guesses = saved.guesses
        currentGuess = saved.currentGuess
        won = saved.won
        lost = saved.lost
        message = nil
        return true
    }

    func createSharedGame() async {
        guard service.isAvailable, hasName else { return }
        isBusy = true
        defer { isBusy = false }

        let gameID = GameCode.make()
        let word = WordLists.randomAnswer()

        do {
            try await service.createGame(gameID: gameID,
                                         word: word,
                                         creatorName: playerName,
                                         playerID: PlayerIdentity.id)
            UserDefaults.standard.set(gameID, forKey: StoredKey.hostedGame)
            answer = word
            clearBoard()
            previousSharedWord = word
            session = .shared(gameID: gameID, isHost: true)
            beginObserving(gameID: gameID)
        } catch {
            // Shown to the player, and recorded so it is findable later.
            FirebaseBootstrapper.record(error, during: "Could not create the game")
            message = "Could not create the game: \(error.localizedDescription)"
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
            message = "Could not join that game: \(error.localizedDescription)"
        }
    }

    func startSharedGame() async {
        guard let gameID = sharedGameID, isHost else { return }
        do {
            try await service.startGame(gameID: gameID)
        } catch {
            // Shown to the player, and recorded so it is findable later.
            FirebaseBootstrapper.record(error, during: "Could not start the game")
            message = "Could not start the game: \(error.localizedDescription)"
        }
    }

    func leaveGame() {
        saveSoloProgress()
        dropPresence()
        tearDownSharedGame()
        session = .lobby
        clearBoard()
        answer = ""
        message = nil
    }

    /// Coming off the roster is part of leaving, not of disconnecting.
    ///
    /// Anyone can leave at any time, and the room should say so straight away
    /// rather than waiting for the socket to drop.
    private func dropPresence() {
        guard let gameID = sharedGameID else { return }
        service.removePresence(gameID: gameID, playerID: PlayerIdentity.id)
    }

    private func tearDownSharedGame() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil

        service.stopObserving(observation)
        observation = nil
        snapshot = GameSnapshot()
        previousSharedWord = nil
    }

    // MARK: - Shared game observation

    private func beginObserving(gameID: String) {
        service.stopObserving(observation)
        observation = service.observe(gameID: gameID) { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    private func apply(_ newSnapshot: GameSnapshot) {
        snapshot = newSnapshot

        guard let word = newSnapshot.word else { return }

        // A different word means the previous round ended and a new one began,
        // so wipe the board rather than showing stale guesses against new hints.
        if let previous = previousSharedWord, previous != word {
            clearBoard()
        }
        previousSharedWord = word
        answer = word

        updateCountdown()
    }

    // MARK: - Solo round

    private func startLocalRound() {
        answer = WordLists.randomAnswer()
        clearBoard()
    }

    private func clearBoard() {
        guesses = []
        currentGuess = ""
        won = false
        lost = false
        message = nil
    }

    // MARK: - Playing

    func press(_ key: Key) {
        guard canPlay else { return }

        switch key {
        case .letter(let character):
            guard currentGuess.count < WordGameEngine.wordSize else { return }
            currentGuess.append(character)
            message = nil

        case .delete:
            guard !currentGuess.isEmpty else { return }
            currentGuess.removeLast()
            message = nil

        case .enter:
            submitGuess()
        }
        saveSoloProgress()
    }

    private func submitGuess() {
        switch WordGameEngine.validate(currentGuess, against: WordLists.valid) {
        case .tooShort:
            reject("Not enough letters")
        case .notAWord:
            reject("Not in word list")
        case nil:
            commitGuess()
        }
    }

    private func reject(_ reason: String) {
        message = reason
        rejectionCount += 1
    }

    private func commitGuess() {
        let guess = currentGuess.uppercased()
        guesses.append(guess)
        currentGuess = ""
        message = nil

        if guess == answer {
            won = true
            message = "Solved it!"
            recordWin()
        } else if guesses.count >= WordGameEngine.maxGuesses {
            lost = true
            message = "Out of guesses. The word was \(answer)."
        }
    }

    /// Tells the room, or says that it could not.
    ///
    /// This write is the only way the browsers watching the game learn that
    /// somebody has won, so a failure here is not cosmetic: the error used to be
    /// swallowed, and two web players were left looking at an unsolved word
    /// while the phone had finished it. The usual failure is a connection
    /// turning over, so it is worth one retry; after that the player is told
    /// rather than left believing the win was shared.
    private func recordWin() {
        guard let gameID = sharedGameID else { return }
        let name = playerName
        Task {
            for attempt in 0..<2 {
                do {
                    try await service.recordWinnerIfAbsent(gameID: gameID, name: name)
                    return
                } catch {
                    FirebaseBootstrapper.record(error, during: "Could not record the win")
                    if attempt == 1 {
                        message = "Solved — but the room could not be told."
                    } else {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                    }
                }
            }
        }
    }

    /// Starts the next round. Solo restarts immediately; a shared game writes a
    /// new word and gives everyone a short countdown to see the result.
    func playAgain() async {
        guard isRoundOver else { return }

        if let gameID = sharedGameID {
            let word = WordLists.randomAnswer()
            do {
                try await service.beginRestart(gameID: gameID, word: word)
            } catch {
                // Shown to the player, and recorded so it is findable later.
                FirebaseBootstrapper.record(error, during: "Could not start the next round")
                message = "Could not start the next round: \(error.localizedDescription)"
            }
        } else {
            startLocalRound()
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
                    self.clearBoard()
                    // Only one client needs to clear it; the write is idempotent.
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

    // MARK: - Board rendering

    func feedback(forRow row: Int) -> [LetterFeedback] {
        guard row < guesses.count else { return [] }
        return WordGameEngine.score(guess: guesses[row], answer: answer)
    }

    func keyboardFeedback(for letter: Character) -> LetterFeedback? {
        WordGameEngine.keyboardFeedback(for: letter, guesses: guesses, answer: answer)
    }

    func endSession() {
        saveSoloProgress()
        dropPresence()
        countdownTask?.cancel()
        countdownTask = nil
        service.stopObserving(observation)
        observation = nil
    }
}
