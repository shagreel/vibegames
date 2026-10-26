import XCTest

/// A solo game left in progress: leaving it should keep it, and coming back
/// should ask whether to carry on or start again.
///
/// Vibe Ten is the game the note came from, and the one with the most to put
/// back — the digits, the taken pairs and the rules it was dealt. The other
/// games' restores are pinned by `Tests/SoloProgressTests.swift`; the question
/// itself is the same sheet everywhere.
final class SoloProgressUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVibeTenRemembersTheBoardAndAsksBeforeStartingAgain() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.startRows", "18", "-vibeten.mode", "remove"]
        app.launch(withName: "Tester")

        openSoloBoard(app)

        let cells = app.tenCells
        let pair = try XCTUnwrap(TenPlan(cells: cells).firstPair())
        app.tenTap(pair.0)
        app.tenTap(pair.1)
        XCTAssertEqual(app.tenCells.count, 160)

        // Leaving through the back button keeps the board rather than ending it.
        app.buttons["ten.back"].tap()
        XCTAssertTrue(app.buttons["ten.playSolo"].waitForExistence(timeout: 5),
                      "back returns to the start screen")

        // Coming back asks, and continuing puts the board back.
        app.buttons["ten.playSolo"].tap()
        let alert = app.alerts["A game is in progress"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "a saved game should be announced")
        XCTAssertTrue(alert.staticTexts.element(boundBy: 1).label.contains("pair"),
                      "and say what is waiting")
        tenAttach(app, named: "52-ten-resume-asked")
        alert.buttons["Continue"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        XCTAssertEqual(app.tenCells.count, 160, "the same board, one pair down")

        // And starting again replaces it.
        app.buttons["ten.back"].tap()
        app.buttons["ten.playSolo"].tap()
        let again = app.alerts["A game is in progress"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.buttons["New game"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        XCTAssertEqual(app.tenCells.count, 162, "a new board, full again")

        // Leaving a fresh game saves that one, so the question is back next time.
        app.buttons["ten.back"].tap()
        app.buttons["ten.playSolo"].tap()
        XCTAssertTrue(app.alerts["A game is in progress"].waitForExistence(timeout: 5))
        app.alerts["A game is in progress"].buttons["Cancel"].tap()
    }

    // MARK: - Helpers

    /// The hub, the Vibe Ten tile and a board — dealing with a game left behind
    /// by an earlier run if there is one.
    private func openSoloBoard(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-ten"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "the hub should offer Vibe Ten")
        tile.tap()
        XCTAssertTrue(app.buttons["ten.playSolo"].waitForExistence(timeout: 5))
        startSolo(app, button: "ten.playSolo")
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
    }
}
