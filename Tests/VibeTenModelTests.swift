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

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        savedMode = defaults.object(forKey: VibeTenModel.modeKey)
        savedRow = defaults.object(forKey: VibeTenModel.addRowKey)
        savedColumns = defaults.object(forKey: VibeTenModel.columnsKey)
        savedRows = defaults.object(forKey: VibeTenModel.rowsKey)
        defaults.removeObject(forKey: VibeTenModel.modeKey)
        defaults.removeObject(forKey: VibeTenModel.addRowKey)
        defaults.removeObject(forKey: VibeTenModel.columnsKey)
        defaults.removeObject(forKey: VibeTenModel.rowsKey)
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        // `set(nil, forKey:)` removes the key, which is what "there was nothing
        // here before" has to mean.
        defaults.set(savedMode, forKey: VibeTenModel.modeKey)
        defaults.set(savedRow, forKey: VibeTenModel.addRowKey)
        defaults.set(savedColumns, forKey: VibeTenModel.columnsKey)
        defaults.set(savedRows, forKey: VibeTenModel.rowsKey)
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

    func testTheModeInForceIsTheOneInTheSettings() {
        let model = VibeTenModel()
        model.playSolo()
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("a full board should have a pair")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertEqual(model.board?.remaining, 160, "remove mode takes the digits off the board")

        // Switching the property applies to the next pair, not the next board:
        // a solo player who turns it on should see it.
        model.mode = .dim
        guard let board = model.board, let pair = board.availableMatches().first else {
            return XCTFail("the board should still have moves")
        }
        model.tap(pair.0)
        model.tap(pair.1)
        XCTAssertEqual(model.board?.remaining, 158, "the digits stay, greyed out")
    }

    func testANewRowIsOfferedOnlyOnceEveryColumnHasClearedTheTopRow() {
        UserDefaults.standard.set(true, forKey: VibeTenModel.addRowKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertFalse(model.canAddRow, "the grid starts full, so there is nowhere to push")

        XCTAssertTrue(playUntilTheTopRowIsFree(model), "taking pairs should free the top row")
        XCTAssertTrue(model.canAddRow)

        let height = model.board?.height(ofColumn: 0) ?? 0
        model.addRow()
        XCTAssertEqual(model.board?.height(ofColumn: 0), height + 1,
                       "a row of nine digits arrives under everything else")
    }

    func testTheSettingOffMeansNoNewRowIsEverOffered() {
        UserDefaults.standard.set(false, forKey: VibeTenModel.addRowKey)
        let model = VibeTenModel()
        model.playSolo()

        XCTAssertTrue(playUntilTheTopRowIsFree(model), "taking pairs should free the top row")
        XCTAssertEqual(model.board?.canAddRow, true, "the grid itself has room")
        XCTAssertFalse(model.canAddRow, "but the player has asked for no new rows")

        let height = model.board?.height(ofColumn: 0) ?? 0
        model.addRow()
        XCTAssertEqual(model.board?.height(ofColumn: 0), height, "nothing moves")
    }

    /// Takes the first pair on offer until the grid's top row is clear, or the
    /// board runs out of moves.
    private func playUntilTheTopRowIsFree(_ model: VibeTenModel) -> Bool {
        var takes = 0
        while !(model.board?.canAddRow ?? false), takes < 80 {
            guard let board = model.board, let pair = board.availableMatches().first else { return false }
            model.tap(pair.0)
            model.tap(pair.1)
            takes += 1
        }
        return model.board?.canAddRow ?? false
    }
}
