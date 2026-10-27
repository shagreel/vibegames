import XCTest

/// Vibe Ten, end to end: the board, taking a pair, and the room.
final class VibeTenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHubOffersVibeTenAsPlayable() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let tile = app.descendants(matching: .any)["game.vibe-ten"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Ten should be on the hub")
        XCTAssertFalse(tile.label.contains("SOON"), "Vibe Ten should be playable")
        tenAttach(app, named: "48-ten-hub")
    }

    func testSoloBoardAndTakingAPair() throws {
        let app = fullBoardApp()
        openSoloBoard(app)

        let board = app.descendants(matching: .any)["ten.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10), "the board should appear")

        let cells = app.tenCells
        XCTAssertEqual(cells.count, 162, "nine wide and eighteen tall")

        let pair = try XCTUnwrap(TenPlan(cells: cells).firstPair(),
                                 "a board of 162 digits should have a pair")
        let firstDigit = try XCTUnwrap(cells.first {
            $0.column == pair.0.column && $0.row == pair.0.row
        })
        app.tenTap(pair.0)
        app.tenTap(pair.1)

        // The score in the header is the report of a pair taken. The digits
        // below rise into the gaps, so what proves the pair went is the count
        // and the two columns being a square shorter.
        let after = app.tenCells
        XCTAssertEqual(after.count, 160, "taking a pair should remove exactly two digits")
        let heightsBefore = Dictionary(grouping: cells, by: \.column).mapValues { $0.count }
        let heightsAfter = Dictionary(grouping: after, by: \.column).mapValues { $0.count }
        // A pair can be two columns, or two squares in one column, so the
        // expectation is per column: as many squares gone as were taken there.
        var taken: [Int: Int] = [:]
        for cell in [pair.0, pair.1] { taken[cell.column, default: 0] += 1 }
        for (column, count) in taken {
            XCTAssertEqual(heightsAfter[column] ?? 0, (heightsBefore[column] ?? 0) - count,
                           "column \(column) is \(count) square(s) shorter")
        }
        tenAttach(app, named: "49-ten-solo")
    }

    func testCreatingARoomShowsACode() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openLobby(app)

        let create = app.buttons["ten.createGame"]
        XCTAssertTrue(create.exists, "the race option should be listed")
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")
        create.tap()

        let code = app.descendants(matching: .any)["ten.gameCode"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: backendTimeout),
                      "should land in the waiting room after creating a game")
        XCTAssertTrue(app.buttons["ten.startShared"].exists,
                      "the host should be offered a start button")
        tenAttach(app, named: "50-ten-room")
    }

    func testDimModeLeavesATakenPairOnTheBoard() throws {
        let app = fullBoardApp(extra: ["-vibeten.mode", "dim"])
        openSoloBoard(app)

        let cells = app.tenCells
        let pair = try XCTUnwrap(TenPlan(cells: cells).firstPair(),
                                 "a board of 162 digits should have a pair")
        app.tenTap(pair.0)
        app.tenTap(pair.1)

        let after = app.tenAllCells
        XCTAssertEqual(after.count, 162, "nothing leaves the board in dim mode")
        let taken = after.filter(\.taken)
        XCTAssertEqual(taken.count, 2, "and the pair that was taken says so")
        XCTAssertTrue(taken.contains { $0.column == pair.0.column && $0.row == pair.0.row })
        XCTAssertTrue(taken.contains { $0.column == pair.1.column && $0.row == pair.1.row })
        // One pair fewer to take, even though every digit is still drawn.
        XCTAssertEqual(app.tenCells.count, 160)
        tenAttach(app, named: "49b-ten-dim")
    }

    func testAFullGridHasNoNewRowOffer() throws {
        let app = fullBoardApp()
        openSoloBoard(app)

        XCTAssertFalse(app.buttons["ten.addRow"].exists,
                       "a full grid has nowhere to reveal a row")
    }

    func testTheNewRowOfferSitsUnderTheDigitsAndRevealsTwoRows() throws {
        // A sixteen-row start: two rows of the deal are still face down, so the
        // offer is there from the first moment.
        let app = boardApp(startRows: 16)
        openSoloBoard(app)
        XCTAssertEqual(app.tenCells.count, 144, "nine wide and sixteen tall")

        let addRow = app.buttons["ten.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 3),
                      "the offer belongs on the row the new rows drop into")
        XCTAssertTrue(addRow.label.contains("2"), "a press reveals two rows, never one")

        // It sits on the first empty row, directly under the digits.
        XCTAssertEqual(addRow.frame.minY, app.tenDeepestCellBottom + 2, accuracy: 8,
                       "the offer is on the row under the digits")

        addRow.tap()
        XCTAssertTrue(waitForCellCount(app, 162, timeout: 3),
                      "two rows of nine arrive underneath")
        XCTAssertFalse(addRow.exists, "eighteen rows is the whole grid")
        tenAttach(app, named: "49c-ten-new-row")
    }

    func testAPressRevealsTheRowsTheSettingsChoose() throws {
        let app = boardApp(startRows: 12, extra: ["-vibeten.rowsPerAdd", "4"])
        openSoloBoard(app)

        let addRow = app.buttons["ten.addRow"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 3))
        XCTAssertTrue(addRow.label.contains("4"), "four rows a press, as chosen")
        addRow.tap()
        XCTAssertTrue(waitForCellCount(app, 144, timeout: 3),
                      "four rows arrive: sixteen rows of digits")

        // Only two rows of the deal are left, so the offer shrinks to a whole
        // press of two rather than showing one stranded row.
        XCTAssertTrue(addRow.waitForExistence(timeout: 3))
        XCTAssertTrue(addRow.label.contains("2"), "two rows, the last whole press")
        addRow.tap()
        XCTAssertTrue(waitForCellCount(app, 162, timeout: 3))
        XCTAssertFalse(addRow.exists, "the deal is fully shown")
    }

    /// The pair setting is a choice for before the game, like the board's size.
    /// How many rows a press adds belongs to the start too, and the new-row
    /// offer itself has no switch: it is always there when the grid has room.
    func testThePairSettingIsLockedOnceTheGameStarts() throws {
        let app = fullBoardApp(extra: ["-vibeten.mode", "remove"])
        openLobby(app)

        // On the start screen it can be changed.
        app.buttons["ten.settings"].tap()
        let mode = app.segmentedControls["tenSettings.mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5), "the sheet should offer the pair setting")
        XCTAssertTrue(mode.isEnabled, "before the game starts it can be chosen")
        mode.buttons["Dim"].tap()
        XCTAssertTrue(mode.buttons["Dim"].isSelected)
        mode.buttons["Remove"].tap()
        app.buttons["tenSettings.done"].tap()

        // In the game it cannot, and the sheet says so.
        startSolo(app, button: "ten.playSolo")
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        app.buttons["ten.settings"].tap()
        let locked = app.segmentedControls["tenSettings.mode"].firstMatch
        XCTAssertTrue(locked.waitForExistence(timeout: 5))
        XCTAssertFalse(locked.isEnabled, "a board in play is being played one way")
        XCTAssertTrue(app.staticTexts["This game is using the setting it started with. Leave it to choose again."]
                        .waitForExistence(timeout: 3), "and the sheet says why")
        // How many rows a press adds belongs to the game too.
        XCTAssertFalse(app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch.isEnabled,
                       "the rows a press adds are part of the game's start")
        XCTAssertFalse(app.switches["tenSettings.addRow"].firstMatch.exists,
                       "there is no switch to turn the new-row offer off")
        tenAttach(app, named: "49g-ten-pair-locked")
        app.buttons["tenSettings.done"].tap()
    }

    /// The settings that remain are the sheet's, and they are for a game that
    /// has not begun.
    func testTheNewRulesAreOnTheSheetAndLockedInAGame() throws {
        let app = fullBoardApp(extra: ["-vibeten.rowsPerAdd", "2", "-vibeten.wrapRows", "NO"])
        openLobby(app)
        app.buttons["ten.settings"].tap()

        let rows = app.segmentedControls["tenSettings.rows"].firstMatch
        XCTAssertTrue(rows.waitForExistence(timeout: 5), "the sheet offers the rows")
        XCTAssertTrue(rows.isEnabled, "and on the start screen it can be chosen")
        for count in [12, 14, 16, 18] {
            XCTAssertTrue(rows.buttons["\(count)"].exists, "\(count) rows should be on offer")
        }
        XCTAssertFalse(app.segmentedControls["tenSettings.difficulty"].firstMatch.exists,
                       "there are no levels any more")
        XCTAssertFalse(app.segmentedControls["tenSettings.columns"].firstMatch.exists,
                       "the columns are always nine")
        XCTAssertFalse(app.segmentedControls["tenSettings.startFill"].firstMatch.exists,
                       "a board always starts full")

        let perPress = app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch
        XCTAssertTrue(perPress.exists, "and how many rows a press reveals")
        for count in [2, 4] {
            XCTAssertTrue(perPress.buttons["\(count)"].exists, "\(count) rows should be on offer")
        }
        for count in [1, 3] {
            XCTAssertFalse(perPress.buttons["\(count)"].exists,
                           "\(count) rows would strand a digit in its own row")
        }

        let wrap = app.switches["tenSettings.wrapRows"].firstMatch
        XCTAssertTrue(wrap.exists, "and whether the rows join end to end")
        XCTAssertEqual(wrap.value as? String, "0", "off until it is turned on")
        wrap.tap()
        XCTAssertEqual(wrap.value as? String, "1")
        wrap.tap()
        app.buttons["tenSettings.done"].tap()

        startSolo(app, button: "ten.playSolo")
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        app.buttons["ten.settings"].tap()
        XCTAssertTrue(app.segmentedControls["tenSettings.rows"].firstMatch
                        .waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["tenSettings.rows"].firstMatch.isEnabled,
                       "a game in play keeps the rows it started with")
        XCTAssertFalse(app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch.isEnabled)
        XCTAssertFalse(app.switches["tenSettings.wrapRows"].firstMatch.isEnabled,
                       "and how pairs are found is part of the game")
        app.buttons["tenSettings.done"].tap()
    }

    /// How many rows a press adds is a start-screen choice, locked in play.
    func testTheRowsPerPressIsChosenBeforeTheGameAndLockedOnceItStarts() throws {
        let app = fullBoardApp(extra: ["-vibeten.rowsPerAdd", "2"])
        openLobby(app)

        app.buttons["ten.settings"].tap()
        let perPress = app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch
        XCTAssertTrue(perPress.waitForExistence(timeout: 5),
                      "the sheet offers how many rows a press reveals")
        for count in [2, 4] {
            XCTAssertTrue(perPress.buttons["\(count)"].exists, "\(count) rows should be on offer")
        }
        XCTAssertTrue(perPress.isEnabled, "on the start screen it can be chosen")
        XCTAssertTrue(perPress.buttons["2"].isSelected)
        perPress.buttons["4"].tap()
        XCTAssertTrue(perPress.buttons["4"].isSelected)
        app.buttons["tenSettings.done"].tap()

        startSolo(app, button: "ten.playSolo")
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10))
        app.buttons["ten.settings"].tap()
        XCTAssertTrue(app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch
                        .waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch.isEnabled,
                       "a game in play keeps the number it started with")
        // Put it back for the tests that run after this one.
        app.buttons["tenSettings.done"].tap()
        app.buttons["ten.back"].tap()
        XCTAssertTrue(app.buttons["ten.playSolo"].waitForExistence(timeout: 5))
        app.buttons["ten.settings"].tap()
        app.segmentedControls["tenSettings.rowsPerAdd"].buttons["2"].tap()
        app.buttons["tenSettings.done"].tap()
    }

    // MARK: - Helpers

    /// Waits for the board to show a number of digits: a tap returns before the
    /// screen has finished redrawing, so a count taken straight after it can be
    /// one square short.
    private func waitForCellCount(_ app: XCUIApplication, _ expected: Int,
                                  timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.tenCells.count == expected { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return app.tenCells.count == expected
    }

    /// An app launched on the full nine-by-eighteen board, whatever the last
    /// run on this simulator left behind.
    private func fullBoardApp(extra: [String] = []) -> XCUIApplication {
        boardApp(extra: extra)
    }

    /// An app launched on a board of a stated starting size, so a test does not
    /// depend on what an earlier run left in the defaults.
    private func boardApp(startRows: Int = 18, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.startRows", "\(startRows)"] + extra
        app.launch(withName: "Tester")
        return app
    }

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
