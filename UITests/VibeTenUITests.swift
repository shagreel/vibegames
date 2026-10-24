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

        // The score in the header is the report of a pair taken.
        // Two digits gone, and nothing else moved: the pair really was taken.
        let after = app.tenCells
        XCTAssertEqual(after.count, 160, "taking a pair should remove exactly two digits")
        XCTAssertFalse(after.contains { $0.column == firstDigit.column && $0.row == firstDigit.row
            && $0.value == firstDigit.value }, "the first digit is gone")
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

    func testANewRowIsOfferedInTheEmptyTopRowAndPushesOne() throws {
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
        let takes = try XCTUnwrap(TenPlan.takesFreeingTheTopRow(startingFrom: app.tenCells),
                                  "this deal offers no way to clear the top row")
        for pair in takes {
            app.tenTap(pair.0)
            app.tenTap(pair.1)
        }

        XCTAssertTrue(addRow.waitForExistence(timeout: 3),
                      "the offer belongs on the row it pushes into")

        let before = app.tenCells.count
        addRow.tap()
        XCTAssertEqual(app.tenCells.count, before + 9, "nine new digits arrive at the bottom")
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
        app.buttons["ten.playSolo"].tap()
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
        app.buttons["ten.playSolo"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10), "the board should appear")
    }
}
