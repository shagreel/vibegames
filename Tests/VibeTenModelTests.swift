import XCTest
@testable import VibeGames

/// The two Vibe Ten properties, from the side the screen sees them: what a
/// taken pair does to the board, and when the new-row offer is there.
@MainActor
final class VibeTenModelTests: XCTestCase {

    private var savedMode: Any?
    private var savedRow: Any?
    private var savedColumns: Any?
    private var savedRows: Any?
    private var savedFill: Any?
    private var savedPerAdd: Any?
    private var savedWrap: Any?

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        savedMode = defaults.object(forKey: VibeTenModel.modeKey)
        savedRow = defaults.object(forKey: VibeTenModel.addRowKey)
        savedColumns = defaults.object(forKey: VibeTenModel.columnsKey)
        savedRows = defaults.object(forKey: VibeTenModel.rowsKey)
        savedFill = defaults.object(forKey: VibeTenModel.startFillKey)
        savedPerAdd = defaults.object(forKey: VibeTenModel.rowsPerAddKey)
        savedWrap = defaults.object(forKey: VibeTenModel.wrapRowsKey)
        for key in [VibeTenModel.modeKey, VibeTenModel.addRowKey,
                    VibeTenModel.columnsKey, VibeTenModel.rowsKey,
                    VibeTenModel.startFillKey, VibeTenModel.rowsPerAddKey,
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
        defaults.set(savedRow, forKey: VibeTenModel.addRowKey)
        defaults.set(savedColumns, forKey: VibeTenModel.columnsKey)
        defaults.set(savedRows, forKey: VibeTenModel.rowsKey)
        SoloProgressStore.clear(game: VibeTenModel.progressGame)
        defaults.set(savedFill, forKey: VibeTenModel.startFillKey)
        defaults.set(savedPerAdd, forKey: VibeTenModel.rowsPerAddKey)
        defaults.set(savedWrap, forKey: VibeTenModel.wrapRowsKey)
        super.tearDown()
    }

    func testTheDefaultsAreToRemovePairsAndToOfferANewRow() {
        let model = VibeTenModel()
        XCTAssertEqual(model.mode, .remove)
        XCTAssertTrue(model.addRowEnabled, "solo players get the extra row unless they turn it off")
        XCTAssertEqual(model.columns, 9, "the board the game shipped with")
        XCTAssertEqual(model.rows, 18)
    }

    /// The shape is a setting, so a solo board is dealt the size it says — and a
    /// size that is not one of the four is not a board this game has.
    func testASoloBoardIsDealtTheChosenShape() {
        UserDefaults.standard.set(6, forKey: VibeTenModel.columnsKey)
        UserDefaults.standard.set(12, forKey: VibeTenModel.rowsKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertEqual(model.board?.columns, 6)
        XCTAssertEqual(model.board?.rows, 12)
        XCTAssertEqual(model.board?.remaining, 72)

        model.columns = 7
        model.rows = 14
        XCTAssertEqual(model.board?.columns, 6, "the board in play keeps the shape it was dealt")
        model.playSolo()
        XCTAssertEqual(model.board?.columns, 7, "and the next one follows the setting")
        XCTAssertEqual(model.board?.rows, 14)
    }

    /// The shape is a choice for a new game: the start screen offers it, and
    /// once a board is in play the sheet shows it without offering it.
    func testTheBoardShapeIsChosenBeforeTheGameStarts() {
        let model = VibeTenModel()
        XCTAssertTrue(model.canChooseBoardShape, "the start screen is where it is chosen")

        model.playSolo()
        XCTAssertFalse(model.canChooseBoardShape, "a dealt board keeps its shape")

        model.leaveGame()
        XCTAssertTrue(model.canChooseBoardShape, "and leaving the game offers it again")
    }

    func testAShapeThatIsNotOfferedIsIgnored() {
        UserDefaults.standard.set(12, forKey: VibeTenModel.columnsKey)
        UserDefaults.standard.set(20, forKey: VibeTenModel.rowsKey)
        let model = VibeTenModel()
        XCTAssertEqual(model.columns, 9)
        XCTAssertEqual(model.rows, 18)
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

    func testANewRowIsOfferedOnlyOnceTheBottomRowIsFree() {
        UserDefaults.standard.set(true, forKey: VibeTenModel.addRowKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertFalse(model.canAddRow, "the grid starts full, so there is nowhere to hang a row")

        XCTAssertTrue(playUntilTheBottomRowIsFree(model), "taking pairs should free the bottom row")
        XCTAssertTrue(model.canAddRow)

        let height = model.board?.height(ofColumn: 0) ?? 0
        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), height + 1,
                       "a row of digits arrives underneath, and the board grows")
    }

    func testTheSettingOffMeansNoNewRowIsEverOffered() {
        UserDefaults.standard.set(false, forKey: VibeTenModel.addRowKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertTrue(playUntilTheBottomRowIsFree(model), "taking pairs should free the bottom row")
        XCTAssertEqual(model.board?.canAddRow, true, "the grid itself has room")
        XCTAssertFalse(model.canAddRow, "but the player has asked for no new rows")

        let height = model.board?.height(ofColumn: 0) ?? 0
        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), height, "nothing moves")
    }

    /// Taking pairs until every column has lost a digit, which is what frees the
    /// bottom row of the grid.
    private func playUntilTheBottomRowIsFree(_ model: VibeTenModel) -> Bool {
        var takes = 0
        while !(model.board?.canAddRow ?? false), takes < 80 {
            guard let board = model.board, let pair = board.availableMatches().first else { return false }
            model.tap(pair.0)
            model.tap(pair.1)
            takes += 1
        }
        return model.board?.canAddRow ?? false
    }

    /// A press of the offer deals as many rows as the setting says, or as many
    /// as the grid still has room for.
    func testAPressDealsTheChosenNumberOfRows() {
        let model = VibeTenModel()
        model.startFill = .third
        model.rowsPerAdd = 3
        model.playSolo()

        XCTAssertEqual(model.board?.height(ofColumn: 0), model.rows / 3,
                       "a third-filled board hangs from the top")
        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), model.rows / 3 + 3,
                       "one press deals three rows")

        model.rowsPerAdd = 4
        model.addRows()
        XCTAssertEqual(model.board?.height(ofColumn: 0), model.rows / 3 + 7)
    }

    /// A third-filled board is only offered with the new-row setting on, and a
    /// room always starts full.
    func testThePartFilledStartNeedsTheNewRowOffer() {
        let model = VibeTenModel()
        model.startFill = .third
        model.addRowEnabled = false
        model.playSolo()
        XCTAssertEqual(model.board?.height(ofColumn: 0), model.rows,
                       "without the new-row offer the board starts full")

        model.leaveGame()
        model.addRowEnabled = true
        model.playSolo()
        XCTAssertEqual(model.board?.height(ofColumn: 0), model.rows / 3,
                       "with it, the board starts a third full")
        XCTAssertFalse(model.canChooseRowSupply, "and the choice is now for the next game")
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
        for key in [VibeTenModel.modeKey, VibeTenModel.addRowKey,
                    VibeTenModel.columnsKey, VibeTenModel.rowsKey,
                    VibeTenModel.startFillKey, VibeTenModel.rowsPerAddKey,
                    VibeTenModel.wrapRowsKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        SoloProgressStore.clear(game: VibeTenModel.progressGame)
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

    func testAFinishedBoardIsNotSomethingToComeBackTo() {
        let model = VibeTenModel()
        model.playSolo()
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        // Finish the round by playing it out.
        var guardCount = 0
        while !(model.finished), guardCount < 200 {
            guard let current = model.board, let next = current.availableMatches().first else { break }
            model.tap(next.0)
            model.tap(next.1)
            guardCount += 1
        }
        guard model.finished else {
            XCTFail("this board should run out of moves")
            return
        }
        model.leaveGame()
        XCTAssertNil(SoloProgressStore.saved(game: VibeTenModel.progressGame),
                     "a finished game is not a game in progress")
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
