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

    func testANewRowIsOfferedInTheEmptyBottomRowAndHangsOne() throws {
        // Stated rather than inherited: the settings outlive the app, and one
        // earlier test turning the new row off, or dealing itself a smaller
        // board, would make this one fail for no reason.
        let app = fullBoardApp(extra: ["-vibeten.addRow", "YES"])
        openSoloBoard(app)

        let addRow = app.buttons["ten.addRow"]
        XCTAssertFalse(addRow.exists, "a full grid has nowhere to put a new row")

        // Every column has to lose its top digit before the top row of the grid
        // is free, so the takes are worked out from one look at the board and
        // then replayed — reading all 162 cells between takes is what makes this
        // test slow, and what made it flaky when a deal had no pair worth taking.
        let takes = try XCTUnwrap(TenPlan.takesFreeingTheBottomRow(startingFrom: app.tenCells),
                                  "this deal offers no way to clear the bottom row")
        for pair in takes {
            app.tenTap(pair.0)
            app.tenTap(pair.1)
        }

        XCTAssertTrue(addRow.waitForExistence(timeout: 3),
                      "the offer belongs on the row the new rows drop into")

        // It sits on the bottom edge of the grid, under the digits.
        let board = app.descendants(matching: .any)["ten.board"].firstMatch
        XCTAssertLessThan(board.frame.maxY - addRow.frame.maxY, 12,
                          "the offer is at the bottom of the board")

        let before = app.tenCells.count
        addRow.tap()
        XCTAssertEqual(app.tenCells.count, before + 9, "nine new digits arrive underneath")
        // A column that was two squares short needs two presses before the grid
        // is full again.
        for _ in 0..<6 where addRow.exists { addRow.tap() }
        XCTAssertEqual(app.tenCells.count, 162, "and the board fills to the full grid")
        XCTAssertFalse(addRow.exists, "the grid is full again, so the offer goes")
        tenAttach(app, named: "49c-ten-new-row")
    }

    /// The pair setting is a choice for before the game, like the board's size.
    /// The new-row switch is not: it is an offer that comes and goes during
    /// play, so its setting stays live.
    func testThePairSettingIsLockedOnceTheGameStarts() throws {
        let app = fullBoardApp(extra: ["-vibeten.addRow", "YES", "-vibeten.mode", "remove"])
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
        // The offer of a new row is a different thing: it is for during play.
        XCTAssertTrue(app.switches["tenSettings.addRow"].firstMatch.isEnabled,
                      "the new-row setting stays live")
        tenAttach(app, named: "49g-ten-pair-locked")
        app.buttons["tenSettings.done"].tap()
    }

    /// The owner's new rules: a board that starts a third full hangs from the
    /// top, and one press of the offer adds as many rows as the setting says.
    func testAPartFilledBoardHangsFromTheTopAndGrowsByTheChosenRows() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.columns", "9", "-vibeten.rows", "18",
                                "-vibeten.addRow", "YES",
                                "-vibeten.startFill", "third",
                                "-vibeten.rowsPerAdd", "2",
                                "-vibeten.mode", "remove"]
        app.launch(withName: "Tester")
        openSoloBoard(app)

        let cells = app.tenCells
        XCTAssertEqual(cells.count, 54, "a third of the board: six rows of nine")
        XCTAssertEqual(cells.map(\.row).min(), 0, "the top row is the first row")
        XCTAssertEqual(cells.map(\.row).max(), 5, "six rows, hanging from the top")
        tenAttach(app, named: "49h-ten-third-full")

        let addRow = app.buttons["ten.addRow"]
        XCTAssertTrue(addRow.exists, "the bottom of the grid is free, so the offer is there")
        XCTAssertEqual(addRow.label, "Add 2 rows at the bottom",
                       "the offer says how many rows a press deals")
        addRow.tap()
        XCTAssertEqual(app.tenCells.count, 72, "two rows more: eight rows of nine")
        XCTAssertEqual(app.tenCells.map(\.row).max(), 7)
        tenAttach(app, named: "49i-ten-two-rows-more")
    }

    /// The new rules are the sheet's, and they are for a game that has not begun.
    func testTheNewRulesAreOnTheSheetAndLockedInAGame() throws {
        let app = fullBoardApp(extra: ["-vibeten.addRow", "YES", "-vibeten.startFill", "full",
                                       "-vibeten.rowsPerAdd", "1", "-vibeten.wrapRows", "NO"])
        openLobby(app)
        app.buttons["ten.settings"].tap()

        let fill = app.segmentedControls["tenSettings.startFill"].firstMatch
        XCTAssertTrue(fill.waitForExistence(timeout: 5), "the sheet offers the starting board")
        XCTAssertTrue(fill.isEnabled, "and on the start screen it can be chosen")
        XCTAssertTrue(fill.buttons["Full"].exists)
        XCTAssertTrue(fill.buttons["One third"].exists)

        let perPress = app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch
        XCTAssertTrue(perPress.exists, "and how many rows a press deals")
        for count in [1, 2, 3, 4] {
            XCTAssertTrue(perPress.buttons["\(count)"].exists, "\(count) rows should be on offer")
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
        XCTAssertTrue(app.segmentedControls["tenSettings.startFill"].firstMatch
                        .waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["tenSettings.startFill"].firstMatch.isEnabled,
                       "a game in play keeps the board it started with")
        XCTAssertFalse(app.segmentedControls["tenSettings.rowsPerAdd"].firstMatch.isEnabled)
        XCTAssertFalse(app.switches["tenSettings.wrapRows"].firstMatch.isEnabled,
                       "and how pairs are found is part of the game")
        app.buttons["tenSettings.done"].tap()
    }

    func testTheNewRowSettingIsInTheSettingsSheet() throws {
        let app = fullBoardApp(extra: ["-vibeten.addRow", "YES"])
        openSoloBoard(app)

        app.buttons["ten.settings"].tap()
        let toggle = app.switches["tenSettings.addRow"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "the new row is a property of the game")
        XCTAssertEqual(toggle.value as? String, "1", "it is on until it is turned off")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0", "and the switch is the setting")
        // Put it back, so a later run on this simulator starts where this one did.
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["tenSettings.done"].tap()
    }

    // MARK: - Helpers

    /// An app launched on the full nine-by-eighteen board, whatever the last
    /// run on this simulator left behind.
    private func fullBoardApp(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-vibeten.columns", "9", "-vibeten.rows", "18"] + extra
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
