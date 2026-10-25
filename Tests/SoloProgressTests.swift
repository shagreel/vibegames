import XCTest
@testable import VibeGames

/// Solo games left in progress: what is kept, what is dropped, and what a game
/// looks like when it is picked back up.
final class SoloProgressStoreTests: XCTestCase {

    private struct State: Codable, Equatable {
        var seed: UInt32
        var score: Int
    }

    override func tearDown() {
        SoloProgressStore.clear(game: "test")
        super.tearDown()
    }

    func testAStateComesBackExactly() {
        let state = State(seed: 42, score: 7)
        SoloProgressStore.save(state, game: "test", summary: "7 pairs")

        let saved = SoloProgressStore.saved(game: "test")
        XCTAssertEqual(saved?.summary, "7 pairs")
        XCTAssertNotNil(saved?.savedAt)
        XCTAssertEqual(SoloProgressStore.state(State.self, game: "test"), state)
    }

    func testStartingAgainForgetsTheGame() {
        SoloProgressStore.save(State(seed: 1, score: 2), game: "test", summary: "2 pairs")
        SoloProgressStore.clear(game: "test")
        XCTAssertNil(SoloProgressStore.saved(game: "test"))
        XCTAssertNil(SoloProgressStore.state(State.self, game: "test"))
    }

    func testAStateFromAnOlderGameIsNotHalfRead() {
        // A payload this version cannot read is a game it cannot resume, so the
        // record goes rather than a board arriving half restored.
        SoloProgressStore.save(["legacy": true], game: "test", summary: "old")
        XCTAssertNil(SoloProgressStore.state(State.self, game: "test"))
        XCTAssertNil(SoloProgressStore.saved(game: "test"))
    }

    func testOneGameDoesNotDisturbAnother() {
        SoloProgressStore.save(State(seed: 1, score: 1), game: "test", summary: "one")
        SoloProgressStore.clear(game: "other")
        XCTAssertNotNil(SoloProgressStore.saved(game: "test"))
    }
}

/// Word Vibe: the word, the guesses and the half-typed letters.
@MainActor
final class WordsSoloProgressTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SoloProgressStore.clear(game: VibeWordsModel.progressGame)
    }

    override func tearDown() {
        SoloProgressStore.clear(game: VibeWordsModel.progressGame)
        super.tearDown()
    }

    func testARoundLeftInProgressComesBack() throws {
        let model = VibeWordsModel()
        model.playSolo()
        let answer = try XCTUnwrap(model.answer.isEmpty ? nil : model.answer)
        XCTAssertFalse(answer.isEmpty)

        for character in "ABC" { model.press(.letter(character)) }
        model.leaveGame()
        XCTAssertNotNil(SoloProgressStore.saved(game: VibeWordsModel.progressGame))

        let resumed = VibeWordsModel()
        XCTAssertTrue(resumed.resumeSolo())
        XCTAssertEqual(resumed.answer, answer, "the same word, not a new one")
        XCTAssertEqual(resumed.currentGuess, "ABC", "and the letters half typed")
        XCTAssertEqual(resumed.session, .solo)
    }

    func testAFinishedRoundIsNotKept() throws {
        let model = VibeWordsModel()
        model.playSolo()
        let answer = try XCTUnwrap(model.answer.isEmpty ? nil : model.answer)

        for character in answer { model.press(.letter(character)) }
        model.press(.enter)
        XCTAssertTrue(model.won)
        model.leaveGame()
        XCTAssertNil(SoloProgressStore.saved(game: VibeWordsModel.progressGame),
                     "a solved word is not a game in progress")
    }

    func testStartingAgainForgetsTheSavedRound() {
        let model = VibeWordsModel()
        model.playSolo()
        model.press(.letter("A"))
        model.leaveGame()
        XCTAssertNotNil(SoloProgressStore.saved(game: VibeWordsModel.progressGame))

        model.playSolo()
        XCTAssertNil(SoloProgressStore.saved(game: VibeWordsModel.progressGame))
        XCTAssertEqual(model.currentGuess, "")
    }
}

/// Number Vibe: the puzzle's seed, the digits and the pencil marks.
@MainActor
final class SudokuSoloProgressTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SoloProgressStore.clear(game: VibeSudokuModel.progressGame)
    }

    override func tearDown() {
        SoloProgressStore.clear(game: VibeSudokuModel.progressGame)
        super.tearDown()
    }

    func testAPuzzleLeftInProgressComesBack() throws {
        let model = VibeSudokuModel()
        model.playSolo()
        let puzzle = try XCTUnwrap(model.puzzle)

        let empty = try XCTUnwrap((0..<SudokuPuzzle.cellCount).first { !puzzle.isGiven($0) })
        model.select(empty)
        let digit = try XCTUnwrap((1...9).first { !puzzle.givens.contains($0) } ?? 1)
        model.enter(digit)
        model.leaveGame()

        let resumed = VibeSudokuModel()
        XCTAssertTrue(resumed.resumeSolo())
        XCTAssertEqual(resumed.puzzle?.seed, puzzle.seed, "the same puzzle")
        XCTAssertEqual(resumed.values[empty], digit, "with the digit that was put in")
        XCTAssertEqual(resumed.session, .solo)
    }

    func testStartingAgainForgetsTheSavedPuzzle() {
        let model = VibeSudokuModel()
        model.playSolo()
        model.leaveGame()
        XCTAssertNotNil(SoloProgressStore.saved(game: VibeSudokuModel.progressGame))

        model.playSolo()
        XCTAssertNil(SoloProgressStore.saved(game: VibeSudokuModel.progressGame))
    }
}

/// Vibe Pairings: the cards on the table, the deck behind them, and the count.
@MainActor
final class TrioSoloProgressTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SoloProgressStore.clear(game: VibeTrioModel.progressGame)
    }

    override func tearDown() {
        SoloProgressStore.clear(game: VibeTrioModel.progressGame)
        super.tearDown()
    }

    func testATableLeftInProgressComesBack() throws {
        let model = VibeTrioModel()
        model.playSolo()
        let table = try XCTUnwrap(model.table)
        let trio = try XCTUnwrap(table.availableTrios.first,
                                 "a fresh table always has a trio")
        for index in trio { model.tap(index) }
        XCTAssertEqual(model.table?.triosTaken, 1)

        let visible = model.table?.visible.map(\.id)
        model.leaveGame()

        let resumed = VibeTrioModel()
        XCTAssertTrue(resumed.resumeSolo())
        XCTAssertEqual(resumed.table?.visible.map(\.id), visible, "the same cards in the same seats")
        XCTAssertEqual(resumed.table?.triosTaken, 1, "and the trio already taken counts")
        XCTAssertEqual(resumed.session, .solo)
    }

    func testStartingAgainForgetsTheSavedTable() {
        let model = VibeTrioModel()
        model.playSolo()
        model.leaveGame()
        XCTAssertNotNil(SoloProgressStore.saved(game: VibeTrioModel.progressGame))

        model.playSolo()
        XCTAssertNil(SoloProgressStore.saved(game: VibeTrioModel.progressGame))
    }
}
