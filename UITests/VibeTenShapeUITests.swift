import XCTest

/// Vibe Ten's board shape, end to end: the settings that choose it, and a board
/// that is dealt with the columns and rows those settings name.
final class VibeTenShapeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testASmallerBoardIsDealtWithFewerColumnsAndRows() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.columns", "6", "-vibeten.rows", "12"]
        app.launch(withName: "Tester")
        openSoloBoard(app)

        let cells = app.tenCells
        XCTAssertEqual(cells.count, 72, "six columns of twelve, not nine of eighteen")
        XCTAssertEqual(cells.map(\.column).max(), 5, "six columns, numbered from zero")
        XCTAssertEqual(cells.map(\.row).max(), 11, "twelve rows")
        tenAttach(app, named: "49d-ten-six-by-twelve")
    }

    /// The shape belongs to a new game: it is chosen on the start screen, and
    /// once a board is in play the sheet shows the choice without offering it.
    func testTheShapeIsChosenBeforeTheGameAndLockedOnceItStarts() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.columns", "9", "-vibeten.rows", "18"]
        app.launch(withName: "Tester")
        openLobby(app)

        // On the start screen, the choice is live.
        app.buttons["ten.settings"].tap()
        let columns = app.segmentedControls["tenSettings.columns"].firstMatch
        XCTAssertTrue(columns.waitForExistence(timeout: 5), "the sheet should offer the columns")
        for count in [6, 7, 8, 9] {
            XCTAssertTrue(columns.buttons["\(count)"].exists, "\(count) columns should be on offer")
        }
        let rows = app.segmentedControls["tenSettings.rows"].firstMatch
        XCTAssertTrue(rows.exists, "and the rows")
        for count in [12, 14, 16, 18] {
            XCTAssertTrue(rows.buttons["\(count)"].exists, "\(count) rows should be on offer")
        }
        XCTAssertTrue(columns.isEnabled, "before a game starts the shape can be chosen")
        XCTAssertTrue(rows.isEnabled)

        columns.buttons["6"].tap()
        rows.buttons["12"].tap()
        tenAttach(app, named: "49e-ten-shape-settings")
        app.buttons["tenSettings.done"].tap()

        // The board it deals is the shape that was chosen.
        let solo = app.buttons["ten.playSolo"]
        XCTAssertTrue(solo.waitForExistence(timeout: 5))
        solo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        XCTAssertEqual(app.tenCells.count, 72, "six columns of twelve")

        // Once the game is under way, the same choices are there and inert.
        app.buttons["ten.settings"].tap()
        let lockedColumns = app.segmentedControls["tenSettings.columns"].firstMatch
        XCTAssertTrue(lockedColumns.waitForExistence(timeout: 5))
        XCTAssertFalse(lockedColumns.isEnabled, "a started game keeps its board")
        XCTAssertFalse(app.segmentedControls["tenSettings.rows"].firstMatch.isEnabled)
        XCTAssertTrue(app.staticTexts["The board is set for this game. Leave it, and choose a size on the start screen before the next one."]
                        .waitForExistence(timeout: 3),
                      "and the sheet says why")
        tenAttach(app, named: "49f-ten-shape-locked")
        // A tap that the picker refuses changes nothing.
        lockedColumns.buttons["9"].tap()
        XCTAssertEqual(app.tenCells.count, 72, "the board in play is still six by twelve")
        app.buttons["tenSettings.done"].tap()

        // Put the simulator back on the full board, from the start screen.
        app.buttons["ten.back"].tap()
        XCTAssertTrue(app.buttons["ten.playSolo"].waitForExistence(timeout: 5))
        app.buttons["ten.settings"].tap()
        app.segmentedControls["tenSettings.columns"].buttons["9"].tap()
        app.segmentedControls["tenSettings.rows"].buttons["18"].tap()
        app.buttons["tenSettings.done"].tap()
    }

    // MARK: - Helpers

    private func openLobby(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-ten"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Ten tile should exist")
        tile.tap()
        XCTAssertTrue(app.buttons["ten.playSolo"].waitForExistence(timeout: 5),
                      "the lobby should offer solo play")
    }

    private func openSoloBoard(_ app: XCUIApplication) {
        openLobby(app)
        startSolo(app, button: "ten.playSolo")
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10), "the board should appear")
    }
}
