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

    func testTheShapeIsChosenInTheSettingsSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.columns", "9", "-vibeten.rows", "18"]
        app.launch(withName: "Tester")
        openSoloBoard(app)

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
        tenAttach(app, named: "49e-ten-shape-settings")

        columns.buttons["6"].tap()
        rows.buttons["12"].tap()
        app.buttons["tenSettings.done"].tap()

        // The board in play keeps its shape; the next one dealt follows the
        // setting, which is what the note under the choices says.
        XCTAssertEqual(app.tenCells.count, 162, "the board in play is still the full board")
        app.buttons["ten.settings"].tap()
        XCTAssertTrue(app.segmentedControls["tenSettings.columns"].buttons["6"]
                        .isSelected, "the choice stuck")
        // Put the full board back: a shape outlives the app, and leaving the
        // simulator on six columns would make the next run's counts wrong.
        app.segmentedControls["tenSettings.columns"].buttons["9"].tap()
        app.segmentedControls["tenSettings.rows"].buttons["18"].tap()
        app.buttons["tenSettings.done"].tap()
    }

    // MARK: - Helpers

    private func openSoloBoard(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-ten"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Ten tile should exist")
        tile.tap()
        let solo = app.buttons["ten.playSolo"]
        XCTAssertTrue(solo.waitForExistence(timeout: 5), "the lobby should offer solo play")
        solo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10), "the board should appear")
    }
}
