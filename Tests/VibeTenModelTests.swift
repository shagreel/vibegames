import XCTest
@testable import VibeGames

/// The two Vibe Ten properties, from the side the screen sees them: what a
/// taken pair does to the board, and when the new-row offer is there.
@MainActor
final class VibeTenModelTests: XCTestCase {

    private var savedMode: Any?
    private var savedRows: Any?
    private var savedPerAdd: Any?
    private var savedWrap: Any?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        savedMode = defaults.object(forKey: VibeTenModel.modeKey)
        savedRows = defaults.object(forKey: VibeTenModel.startRowsKey)
        savedPerAdd = defaults.object(forKey: VibeTenModel.rowsPerAddKey)
        savedWrap = defaults.object(forKey: VibeTenModel.wrapRowsKey)
        for key in [VibeTenModel.modeKey, VibeTenModel.startRowsKey,
                    VibeTenModel.legacyRowsKey, VibeTenModel.rowsPerAddKey,
                    VibeTenModel.wrapRowsKey] {
            defaults.removeObject(forKey: key)
        }
        SoloProgressStore.clear(game: VibeTenModel.progressGame)
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        // `set(nil, forKey:)` removes the key, which is what "there was nothing
        // here before" has to mean.
        defaults.set(savedMode, forKey: VibeTenModel.modeKey)
        defaults.set(savedRows, forKey: VibeTenModel.startRowsKey)
        SoloProgressStore.clear(game: VibeTenModel.progressGame)
        defaults.set(savedPerAdd, forKey: VibeTenModel.rowsPerAddKey)
        defaults.set(savedWrap, forKey: VibeTenModel.wrapRowsKey)
        super.tearDown()
    }

    func testTheDefaultsAreToRemovePairsAndToStartFull() {
        let model = VibeTenModel()
        XCTAssertEqual(model.mode, .remove)
        XCTAssertEqual(model.startRows, 18, "the board the game shipped with")
        XCTAssertEqual(model.rowsPerAdd, 2, "two rows a press unless it is chosen")
    }

    /// The starting rows are the setting, so a solo board starts that deep — the
    /// board itself always has room for eighteen.
    func testASoloBoardStartsWithTheChosenRows() {
        UserDefaults.standard.set(12, forKey: VibeTenModel.startRowsKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertEqual(model.board?.columns, 9, "the columns are always nine")
        XCTAssertEqual(model.board?.height(ofColumn: 0), 12)
        XCTAssertEqual(model.board?.rows, 18, "and room for eighteen underneath")
        XCTAssertEqual(model.board?.remaining, 108)
        XCTAssertEqual(model.board?.roomForRows, 6)

        model.startRows = 14
        XCTAssertEqual(model.board?.height(ofColumn: 0), 12,
                       "the board in play keeps the start it was dealt")
        model.playSolo()
        XCTAssertEqual(model.board?.height(ofColumn: 0), 14, "and the next one follows it")
    }

    /// The starting rows are a choice for a new game: the start screen offers
    /// them, and once a board is in play the sheet shows them without offering
    /// them.
    func testTheStartingRowsAreChosenBeforeTheGameStarts() {
        let model = VibeTenModel()
        XCTAssertTrue(model.canChooseStartRows, "the start screen is where it is chosen")

        model.playSolo()
        XCTAssertFalse(model.canChooseStartRows, "a dealt board keeps its start")

        model.leaveGame()
        XCTAssertTrue(model.canChooseStartRows, "and leaving the game offers it again")
    }

    func testAStartRowCountThatIsNotOfferedIsIgnored() {
        UserDefaults.standard.set(20, forKey: VibeTenModel.startRowsKey)
        let model = VibeTenModel()
        XCTAssertEqual(model.startRows, 18)
    }

    /// The old key was the board's whole height, and the four values are the
    /// same, so a player who had chosen twelve still starts with twelve.
    func testTheOldRowsSettingIsReadAsTheStart() {
        UserDefaults.standard.set(14, forKey: VibeTenModel.legacyRowsKey)
        let model = VibeTenModel()
        XCTAssertEqual(model.startRows, 14)
    }

    /// A pair that does not match is not refused out loud: the digits stay, and
    /// the highlight moves to the number just picked.
    func testAPairThatDoesNotMatchKeepsTheDigitsAndMovesTheHighlight() {
        var cells = [[VibeTenCell]](repeating: [], count: 9)
        cells[0] = [VibeTenCell(value: 1)]
        cells[1] = [VibeTenCell(value: 2)]
        cells[2] = [VibeTenCell(value: 3)]
        let saved = VibeTenModel.Saved(seed: 1, columns: 9, rows: 18, startRows: 18,
                                       wrapRows: false, mode: .remove, cells: cells,
                                       score: 0, finished: false, cleared: false,
                                       elapsed: 0)
        SoloProgressStore.save(saved, game: VibeTenModel.progressGame, summary: "three digits")

        let model = VibeTenModel()
        XCTAssertTrue(model.resumeSolo())
        let before = model.board
        let first = VibeTenBoard.Position(column: 0, row: 0)
        let second = VibeTenBoard.Position(column: 1, row: 0)

        model.tap(first)
        XCTAssertEqual(model.selected, first)
        model.tap(second)

        XCTAssertEqual(model.selected, second, "the highlight moves to the new number")
        XCTAssertEqual(model.board, before, "and nothing is taken")
        XCTAssertEqual(model.score, 0)
        XCTAssertTrue(model.canPlay, "the round goes on")
    }

    func testDimModeLeavesThePairOnTheBoard() {
        UserDefaults.standard.set(VibeTenMode.dim.rawValue, forKey: VibeTenModel.modeKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertEqual(model.mode, .dim, "the sheet's choice is read back")

        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)

        XCTAssertEqual(model.score, 1)
        XCTAssertEqual(model.board?.remaining, 160, "no digit leaves the board in dim mode")
        XCTAssertTrue(model.board?.isDimmed(at: pair.0) == true)
        XCTAssertTrue(model.board?.isDimmed(at: pair.1) == true)
    }

    func testTheModeChosenBeforeTheGameIsTheOnePlayed() {
        let model = VibeTenModel()
        model.mode = .dim
        model.playSolo()

        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertEqual(model.board?.remaining, 160, "in dim mode the digits stay, greyed out")
        XCTAssertTrue(model.board?.isDimmed(at: pair.0) == true)
    }

    /// The pair setting is a choice for a game that has not begun, like the
    /// board's size. A room waiting for its host has not begun yet, so it is
    /// still there to change.
    func testThePairModeIsChosenBeforeTheGameStarts() {
        let model = VibeTenModel()
        XCTAssertTrue(model.canChoosePairMode, "the start screen is where it is chosen")

        model.playSolo()
        XCTAssertFalse(model.canChoosePairMode, "a board in play is being played one way")

        model.leaveGame()
        XCTAssertTrue(model.canChoosePairMode, "and leaving the game offers it again")
    }

    /// The new-row offer is the rest of the deal: a sixteen-row start has two
    /// rows still face down, so the offer is there from the first moment and
    /// gone once the whole deal is on the board.
    func testTheNewRowOfferIsTheRestOfTheDeal() {
        let model = VibeTenModel()
        model.startRows = 16
        model.playSolo()

        XCTAssertEqual(model.board?.height(ofColumn: 0), 16)
        XCTAssertTrue(model.canAddRow, "two rows of the deal are still face down")
        XCTAssertEqual(model.rowsToAdd, 2)

        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), 18)
        XCTAssertEqual(model.board?.dealtRows, 18)
        XCTAssertFalse(model.canAddRow, "the whole deal is on the board")
    }

    /// A full eighteen-row start is the whole deal: taking pairs makes room
    /// underneath, but there are no rows left to reveal.
    func testAFullStartHasNoRowsLeftToReveal() {
        let model = VibeTenModel()
        model.playSolo()
        XCTAssertFalse(model.canAddRow)

        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertFalse(model.canAddRow, "the deal was already fully shown")
    }

    /// A press reveals four rows when four fit, and two when only two do: a
    /// press is never a single row, so the deal is never left half shown.
    func testAPressRevealsFourRowsOrTheEvenRowsThatFit() {
        let model = VibeTenModel()
        model.startRows = 12
        model.rowsPerAdd = 4
        model.playSolo()

        XCTAssertEqual(model.rowsToAdd, 4)
        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), 16)

        XCTAssertEqual(model.rowsToAdd, 2, "only two rows of the deal still fit")
        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), 18)
        XCTAssertEqual(model.rowsToAdd, 0, "no press fits a full grid")
        XCTAssertFalse(model.canAddRow)
    }

    func testTheRowsCanJoinEndToEnd() {
        let model = VibeTenModel()
        model.wrapRows = true
        model.playSolo()
        XCTAssertEqual(model.board?.wrapRows, true, "the rule reaches the board")
    }
}


/// Leaving a solo game and coming back to it.
@MainActor
final class VibeTenSoloProgressTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SoloProgressStore.clear(game: VibeTenModel.progressGame)
        for key in [VibeTenModel.modeKey, VibeTenModel.startRowsKey,
                    VibeTenModel.legacyRowsKey, VibeTenModel.rowsPerAddKey,
                    VibeTenModel.wrapRowsKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        SoloProgressStore.clear(game: VibeTenModel.progressGame)
        // The saved rules become the preferences when a game is resumed, and
        // these defaults are the app's: put them back so a UI test that runs
        // after this one is not handed somebody else's board.
        for key in [VibeTenModel.modeKey, VibeTenModel.startRowsKey,
                    VibeTenModel.legacyRowsKey, VibeTenModel.rowsPerAddKey,
                    VibeTenModel.wrapRowsKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testASoloGameLeftInProgressComesBack() {
        let model = VibeTenModel()
        model.playSolo()
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertEqual(model.score, 1)

        let before = model.board
        model.leaveGame()
        XCTAssertNotNil(SoloProgressStore.saved(game: VibeTenModel.progressGame),
                        "leaving keeps the board")

        let resumed = VibeTenModel()
        XCTAssertTrue(resumed.resumeSolo(), "and tapping play asks whether to carry on")
        XCTAssertEqual(resumed.score, 1)
        XCTAssertEqual(resumed.board, before, "the same digits in the same places")
        XCTAssertEqual(resumed.session, .solo)
    }

    func testStartingAgainClearsTheSavedGame() {
        let model = VibeTenModel()
        model.playSolo()
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        model.leaveGame()
        XCTAssertNotNil(SoloProgressStore.saved(game: VibeTenModel.progressGame))

        model.playSolo()
        XCTAssertNil(SoloProgressStore.saved(game: VibeTenModel.progressGame),
                     "a new game is a new game")
        XCTAssertEqual(model.score, 0)
    }

    /// A finished round is not something to come back to, whichever way it
    /// finished. This one is finished by clearing it: a two-digit board left in
    /// progress, resumed and taken.
    func testAFinishedBoardIsNotSomethingToComeBackTo() {
        var cells = [[VibeTenCell]](repeating: [], count: 9)
        cells[0] = [VibeTenCell(value: 3)]
        cells[1] = [VibeTenCell(value: 7)]
        let saved = VibeTenModel.Saved(seed: 1, columns: 9, rows: 18, startRows: 18,
                                       wrapRows: false, mode: .remove, cells: cells,
                                       score: 0, finished: false, cleared: false,
                                       elapsed: 0)
        SoloProgressStore.save(saved, game: VibeTenModel.progressGame, summary: "one pair left")

        let model = VibeTenModel()
        XCTAssertTrue(model.resumeSolo())
        guard let pair = model.board?.availableMatches().first else {
            return XCTFail("the saved board should have its last pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertTrue(model.cleared)
        XCTAssertTrue(model.finished)

        model.leaveGame()
        XCTAssertNil(SoloProgressStore.saved(game: VibeTenModel.progressGame),
                     "a finished game is not a game in progress")
    }

    /// Losing needs both: nothing left that pairs, and no room for a new row.
    func testNoMovesWithRoomForANewRowIsNotTheEnd() {
        var cells = [[VibeTenCell]](repeating: [], count: 9)
        // One column, alternating 1 and 2: neighbours never pair. Two rows
        // under it are still free, so there is room for a press.
        cells[0] = (0..<16).map { VibeTenCell(value: $0 % 2 == 0 ? 1 : 2) }
        let saved = VibeTenModel.Saved(seed: 1, columns: 9, rows: 18, startRows: 18,
                                       wrapRows: false, mode: .remove, cells: cells,
                                       score: 0, finished: false, cleared: false,
                                       elapsed: 0)
        SoloProgressStore.save(saved, game: VibeTenModel.progressGame, summary: "stuck")

        let model = VibeTenModel()
        XCTAssertTrue(model.resumeSolo())
        XCTAssertFalse(model.board?.hasMoves ?? true, "nothing pairs")
        XCTAssertTrue(model.canAddRow, "and the grid has room")
        XCTAssertFalse(model.finished, "so the round is not over: it can grow")
    }

    func testNoMovesAndNoRoomIsTheEnd() {
        var cells = [[VibeTenCell]](repeating: [], count: 9)
        cells[0] = (0..<18).map { VibeTenCell(value: $0 % 2 == 0 ? 1 : 2) }
        let saved = VibeTenModel.Saved(seed: 1, columns: 9, rows: 18, startRows: 18,
                                       wrapRows: false, mode: .remove, cells: cells,
                                       score: 0, finished: false, cleared: false,
                                       elapsed: 0)
        SoloProgressStore.save(saved, game: VibeTenModel.progressGame, summary: "stuck")

        let model = VibeTenModel()
        XCTAssertTrue(model.resumeSolo())
        XCTAssertFalse(model.board?.hasMoves ?? true, "nothing pairs")
        XCTAssertFalse(model.canAddRow, "and the grid is full")
        XCTAssertTrue(model.finished, "so the round is over")
        XCTAssertFalse(model.cleared, "and it was not a clear")
    }

    /// A resumed game is played by the rules it was dealt by, and those rules
    /// become the choices for the next game.
    func testTheResumedGameBringsItsRulesBack() {
        let model = VibeTenModel()
        model.startRows = 12
        model.wrapRows = true
        model.mode = .dim
        model.playSolo()
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        let dealt = model.board
        model.leaveGame()

        // A new model, with the preferences back at their defaults, as if the
        // game had been left on another day.
        for key in [VibeTenModel.startRowsKey, VibeTenModel.legacyRowsKey,
                    VibeTenModel.wrapRowsKey, VibeTenModel.modeKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let resumed = VibeTenModel()
        XCTAssertEqual(resumed.startRows, 18, "the defaults are the defaults")
        XCTAssertTrue(resumed.resumeSolo())
        XCTAssertEqual(resumed.board, dealt, "the same digits, and the same rules")
        XCTAssertEqual(resumed.startRows, 12, "the game comes back with its start")
        XCTAssertEqual(resumed.wrapRows, true)
        XCTAssertEqual(resumed.mode, .dim)
    }

    func testTheSummarySaysWhatIsWaiting() {
        let model = VibeTenModel()
        model.playSolo()
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertTrue(model.savedSummary.contains("1 pair"), model.savedSummary)
        XCTAssertTrue(model.savedSummary.contains("160 digits left"), model.savedSummary)
    }
}
