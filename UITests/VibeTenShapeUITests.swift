import XCTest

/// Vibe Ten's board shape, end to end: nine columns always, and the rows the
/// settings name.
final class VibeTenShapeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAShorterBoardIsDealtWithFewerRows() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.startRows", "12"]
        app.launch(withName: "Tester")
        openSoloBoard(app)

        let cells = app.tenCells
        XCTAssertEqual(cells.count, 108, "nine columns of twelve, not nine of eighteen")
        XCTAssertEqual(cells.map(\.column).max(), 8, "nine columns, numbered from zero")
        XCTAssertEqual(cells.map(\.row).max(), 11, "twelve rows")
        tenAttach(app, named: "49d-ten-nine-by-twelve")
    }

    /// The rows belong to a new game: they are chosen on the start screen, and
    /// once a board is in play the sheet shows the choice without offering it.
    func testTheRowsAreChosenBeforeTheGameAndLockedOnceItStarts() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.startRows", "18"]
        app.launch(withName: "Tester")
        openLobby(app)

        // On the start screen, the choice is live; the columns are not a choice.
        app.buttons["ten.settings"].tap()
        let rows = app.segmentedControls["tenSettings.rows"].firstMatch
        XCTAssertTrue(rows.waitForExistence(timeout: 5), "the sheet should offer the rows")
        for count in [12, 14, 16, 18] {
            XCTAssertTrue(rows.buttons["\(count)"].exists, "\(count) rows should be on offer")
        }
        XCTAssertTrue(rows.isEnabled, "before a game starts the rows can be chosen")
        XCTAssertFalse(app.segmentedControls["tenSettings.columns"].firstMatch.exists,
                       "the columns are always nine")
        XCTAssertFalse(app.segmentedControls["tenSettings.difficulty"].firstMatch.exists,
                       "there are no levels")

        rows.buttons["12"].tap()
        tenAttach(app, named: "49e-ten-row-settings")
        app.buttons["tenSettings.done"].tap()

        // The board it deals is the shape that was chosen.
        let solo = app.buttons["ten.playSolo"]
        XCTAssertTrue(solo.waitForExistence(timeout: 5))
        solo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        XCTAssertEqual(app.tenCells.count, 108, "nine columns of twelve")

        // Once the game is under way, the same choice is there and inert.
        app.buttons["ten.settings"].tap()
        let lockedRows = app.segmentedControls["tenSettings.rows"].firstMatch
        XCTAssertTrue(lockedRows.waitForExistence(timeout: 5))
        XCTAssertFalse(lockedRows.isEnabled, "a started game keeps its board")
        XCTAssertTrue(app.staticTexts["The board is set for this game. Start a new game to change the starting rows."]
                        .waitForExistence(timeout: 3),
                      "and the sheet says why")
        tenAttach(app, named: "49f-ten-rows-locked")
        // A tap that the picker refuses changes nothing.
        lockedRows.buttons["18"].tap()
        XCTAssertEqual(app.tenCells.count, 108, "the board in play is still nine by twelve")
        app.buttons["tenSettings.done"].tap()

        // Put the simulator back on the full board, from the start screen.
        app.buttons["ten.back"].tap()
        XCTAssertTrue(app.buttons["ten.playSolo"].waitForExistence(timeout: 5))
        app.buttons["ten.settings"].tap()
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
