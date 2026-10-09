import XCTest

/// End-to-end checks for Vibe Sudoku.
///
/// The puzzle generator is covered exhaustively by the unit tests; these drive
/// the screens, and one of them talks to the real backend.
final class VibeSudokuUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Hub

    func testHubOffersSudokuAsPlayable() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let tile = app.descendants(matching: .any)["game.vibe-sudoku"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Sudoku should be on the hub")
        XCTAssertFalse(tile.label.contains("SOON"), "Vibe Sudoku should be playable")
        attach(app, named: "30-sudoku-hub")
    }

    // MARK: - Solo play

    func testSoloPuzzleLoadsAndAcceptsADigit() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSudokuLobby(app)

        app.buttons["sudoku.playSolo"].tap()

        let board = app.descendants(matching: .any)["sudoku.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10), "The grid should appear")
        XCTAssertTrue(app.descendants(matching: .any)["sudoku.keypad"].exists,
                      "The keypad should appear")
        attach(app, named: "31-sudoku-solo")

        // Find an empty cell rather than assuming one, since the givens depend
        // on a random seed.
        let empty = try firstEmptyCell(in: app)

        empty.tap()
        XCTAssertTrue((empty.label).contains("selected"),
                      "Tapping a cell should select it, label was: \(empty.label)")

        app.buttons["sudoku.digit.5"].tap()

        let accepted = expectation(
            for: NSPredicate(format: "label CONTAINS %@", "5"),
            evaluatedWith: empty
        )
        wait(for: [accepted], timeout: 5)
        XCTAssertFalse(empty.label.contains("empty"),
                       "The cell should no longer be empty, label was: \(empty.label)")
        attach(app, named: "32-sudoku-filled")
    }

    func testEraseClearsAnEnteredDigit() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSudokuLobby(app)
        app.buttons["sudoku.playSolo"].tap()

        let board = app.descendants(matching: .any)["sudoku.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10))

        let cell = try firstEmptyCell(in: app)
        cell.tap()
        app.buttons["sudoku.digit.7"].tap()

        let filled = expectation(for: NSPredicate(format: "label CONTAINS %@", "7"),
                                 evaluatedWith: cell)
        wait(for: [filled], timeout: 5)

        app.buttons["sudoku.erase"].tap()

        let cleared = expectation(for: NSPredicate(format: "label CONTAINS %@", "empty"),
                                  evaluatedWith: cell)
        wait(for: [cleared], timeout: 5)
    }

    // MARK: - Shared play

    /// The only Sudoku test that touches the backend. Skips itself when Firebase
    /// is not configured, so a checkout without the config file stays green.
    func testCreatingASharedGameShowsACode() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSudokuLobby(app)

        let create = app.buttons["sudoku.createGame"]
        XCTAssertTrue(create.exists, "The race option should be listed")
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")

        create.tap()

        // The waiting room only appears once the game has been written and read
        // back, so this covers both directions of the round trip.
        let code = app.descendants(matching: .any)["sudoku.gameCode"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 25),
                      "Should land in the waiting room after creating a game")
        XCTAssertTrue(code.label.uppercased().contains("CODE"),
                      "Expected a game code, got: \(code.label)")
        XCTAssertTrue(app.buttons["sudoku.startShared"].exists,
                      "The host should be offered a start button")
        attach(app, named: "33-sudoku-shared-host")
    }

    // MARK: - Helpers

    private func openSudokuLobby(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-sudoku"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Sudoku tile should exist")
        tile.tap()

        XCTAssertTrue(app.buttons["sudoku.playSolo"].waitForExistence(timeout: 5),
                      "Lobby should offer solo play")
        attach(app, named: "30-sudoku-lobby")
    }

    /// Scans a window of cells for one the puzzle left blank.
    private func firstEmptyCell(in app: XCUIApplication) throws -> XCUIElement {
        for index in 0..<40 {
            let cell = app.buttons["sudoku.cell.\(index)"]
            if cell.exists, cell.label.contains("empty") { return cell }
        }
        throw XCTSkip("No empty cell found near the start of the grid")
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
