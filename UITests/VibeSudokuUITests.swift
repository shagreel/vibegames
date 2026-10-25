import XCTest

/// End-to-end checks for Number Vibe.
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
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Number Vibe should be on the hub")
        XCTAssertFalse(tile.label.contains("SOON"), "Number Vibe should be playable")
        attach(app, named: "30-sudoku-hub")
    }

    // MARK: - Solo play

    func testSoloPuzzleLoadsAndAcceptsADigit() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSudokuLobby(app)

        startSolo(app, button: "sudoku.playSolo")

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
        startSolo(app, button: "sudoku.playSolo")

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

    /// The marks-per-square choice is a setting, so it lives behind the settings
    /// button with the other games' settings — not on the keypad, where it used
    /// to change shape under your thumb while you were solving.
    func testNotesSettingLivesBehindTheSettingsButton() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSudokuLobby(app)
        startSolo(app, button: "sudoku.playSolo")

        let board = app.descendants(matching: .any)["sudoku.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10))

        XCTAssertFalse(app.buttons["sudoku.noteLimit"].exists,
                       "the limit should not be a keypad key any more")

        // Four first, which is idempotent whatever an earlier run left behind.
        XCTAssertTrue(setNineMarks(false, in: app).waitForExistence(timeout: 5),
                      "the sheet should offer the marks choice")
        app.buttons["sudokuSettings.done"].tap()

        let cell = try firstEmptyCell(in: app)
        cell.tap()
        app.buttons["sudoku.notes"].tap()
        for digit in 1...4 {
            app.buttons["sudoku.digit.\(digit)"].tap()
        }

        let fourMarks = expectation(for: NSPredicate(format: "label CONTAINS %@", "notes 1 2 3 4"),
                                    evaluatedWith: cell)
        wait(for: [fourMarks], timeout: 5)
        attach(app, named: "34-sudoku-notes-four")

        // A fifth is refused rather than silently dropped, so the cell still
        // holds four. Comparing the whole label is safe here: nothing else
        // about the cell changes, and the label also carries the row and
        // column, which a digit search could trip over.
        let withFourMarks = cell.label
        app.buttons["sudoku.digit.5"].tap()
        XCTAssertEqual(cell.label, withFourMarks,
                       "a fifth mark should be refused")

        // With nine chosen, five marks fit. One switch, not two rows.
        let marks = setNineMarks(true, in: app)
        XCTAssertEqual(marks.value as? String, "1", "the switch should be on for nine")
        attach(app, named: "35-sudoku-settings")
        app.buttons["sudokuSettings.done"].tap()

        app.buttons["sudoku.digit.5"].tap()

        let fiveMarks = expectation(for: NSPredicate(format: "label CONTAINS %@", "notes 1 2 3 4 5"),
                                    evaluatedWith: cell)
        wait(for: [fiveMarks], timeout: 5)

        // Put the setting back, so a later test starts where a new player would.
        setNineMarks(false, in: app)
        app.buttons["sudokuSettings.done"].tap()
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
        XCTAssertTrue(code.waitForExistence(timeout: backendTimeout),
                      "Should land in the waiting room after creating a game")
        XCTAssertTrue(code.label.uppercased().contains("CODE"),
                      "Expected a game code, got: \(code.label)")
        XCTAssertTrue(app.buttons["sudoku.startShared"].exists,
                      "The host should be offered a start button")
        attach(app, named: "33-sudoku-shared-host")
    }

    /// Somebody else finishing first is announced, and this player's grid stays
    /// theirs to finish.
    ///
    /// A room used to close for everyone the moment one board was solved: a late
    /// arrival, or anyone slower, got a "finished first" panel and a dead board.
    /// The win is news now, the way it is in Word Vibe.
    func testSomebodyElseWinningLeavesTheBoardPlayable() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSudokuLobby(app)

        let create = app.buttons["sudoku.createGame"]
        try XCTSkipUnless(create.exists && create.isEnabled,
                          "Multiplayer needs a configured Firebase project")
        create.tap()

        let badge = app.descendants(matching: .any)["sudoku.gameCode"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: backendTimeout),
                      "Should land in the waiting room after creating a game")
        let room = try XCTUnwrap(RoomSetup.code(from: badge.label),
                                 "Could not read a room code from: \(badge.label)")

        app.buttons["sudoku.startShared"].tap()

        let board = app.descendants(matching: .any)["sudoku.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: backendTimeout), "The grid should appear")

        XCTAssertTrue(RoomSetup.writeWinner(path: "sudoku", room: room, name: "Early Bird"),
                      "The database should accept the win")

        let banner = app.descendants(matching: .any)["sudoku.winner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: backendTimeout),
                      "A win by somebody else should be announced")
        XCTAssertTrue(banner.label.contains("Early Bird"),
                      "Expected the winner's name, got: \(banner.label)")
        XCTAssertFalse(app.buttons["sudoku.playAgain"].exists,
                       "The round-over panel belongs to this player's own board")

        // The half that was wrong: the grid still takes a digit.
        let empty = try firstEmptyCell(in: app)
        empty.tap()
        app.buttons["sudoku.digit.5"].tap()

        let accepted = expectation(
            for: NSPredicate(format: "label CONTAINS %@", "5"),
            evaluatedWith: empty
        )
        wait(for: [accepted], timeout: 5)
        XCTAssertFalse(empty.label.contains("empty"),
                       "The board should still accept a digit, label was: \(empty.label)")
        attach(app, named: "34-sudoku-someone-else-won")
    }

    // MARK: - Helpers

    private func openSudokuLobby(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-sudoku"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Number Vibe tile should exist")
        tile.tap()

        XCTAssertTrue(app.buttons["sudoku.playSolo"].waitForExistence(timeout: 5),
                      "Lobby should offer solo play")
        attach(app, named: "30-sudoku-lobby")
    }

    /// Opens the settings sheet and sets the marks switch, returning it. The
    /// sheet is left open: two callers photograph it, and every one of them
    /// closes it themselves.
    private func setNineMarks(_ on: Bool, in app: XCUIApplication) -> XCUIElement {
        app.buttons["sudoku.settings"].tap()
        let marks = app.switches["sudokuSettings.nineMarks"]
        XCTAssertTrue(marks.waitForExistence(timeout: 5),
                      "the sheet should offer the marks choice")
        // A value of "1" is on; tapping a switch that is already there would
        // turn it off, and every caller wants a particular state.
        if (marks.value as? String == "1") != on { marks.tap() }
        return marks
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
