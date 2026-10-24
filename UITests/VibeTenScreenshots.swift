import XCTest

/// Screenshots of Vibe Ten for the landing page.
///
/// Three screens, one launch each: a board part-played, the same game in dim
/// mode with the taken digits still on it, and the new-row offer sitting in the
/// empty top row. The third one needs the grid's top row cleared, which is the
/// only way the offer appears — the same pairs a player would have to take.
///
/// These are the slow tests, so they are skipped by the default run and only
/// happen with `Tools/test.sh --all`, which is what to use before deploying the
/// site or after regenerating the pictures.
final class VibeTenScreenshots: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLightAppearance() throws {
        try capture(appearance: "light")
    }

    func testDarkAppearance() throws {
        try capture(appearance: "dark")
    }

    private func capture(appearance: String) throws {
        try partlyPlayedBoard(appearance: appearance)
        try dimmedBoard(appearance: appearance)
        try newRowOffer(appearance: appearance)
    }

    /// A board with a few pairs taken: the number that matters is the score in
    /// the header, so the screenshot shows a game under way rather than a fresh
    /// grid that looks the same every time.
    private func partlyPlayedBoard(appearance: String) throws {
        let app = launch(appearance: appearance)
        openSoloBoard(app)
        var plan = TenPlan(cells: app.tenCells)
        for _ in 0..<4 {
            guard let pair = plan.firstPair(), plan.take(pair.0, pair.1) else { break }
            app.tenTap(pair.0)
            app.tenTap(pair.1)
        }
        tenAttach(app, named: "ten-solo")
        app.terminate()
    }

    /// Dim mode: taken digits stay where they are, greyed out.
    private func dimmedBoard(appearance: String) throws {
        let app = launch(appearance: appearance, extra: ["-vibeten.mode", "dim"])
        openSoloBoard(app)
        // In dim mode nothing moves, so a set of pairs that was legal on the
        // untouched board stays legal all the way through.
        let pairs = TenPlan(cells: app.tenCells).pairsForDimming(7)
        for pair in pairs { app.tenTap(pair) }
        XCTAssertGreaterThan(app.tenAllCells.filter(\.taken).count, 0,
                            "dim mode should leave digits behind for the picture")
        tenAttach(app, named: "ten-dim")
        app.terminate()
    }

    /// The offer of a new row, on the row it pushes up into.
    private func newRowOffer(appearance: String) throws {
        let app = launch(appearance: appearance, extra: ["-vibeten.addRow", "YES"])
        openSoloBoard(app)

        let addRow = app.buttons["ten.addRow"]
        let takes = try XCTUnwrap(TenPlan.takesFreeingTheTopRow(startingFrom: app.tenCells),
                                  "this deal offers no way to clear the top row")
        for pair in takes { app.tenTap(pair) }
        XCTAssertTrue(addRow.waitForExistence(timeout: 3),
                      "the top row should be free after \(takes.count) pairs")
        tenAttach(app, named: "ten-new-row")
        app.terminate()
    }

    private func launch(appearance: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // The full board, whatever shape a previous run left in the defaults.
        app.launchArguments += ["-vibegames.appearance", appearance,
                                "-vibeten.columns", "9", "-vibeten.rows", "18"] + extra
        app.launch(withName: "Tester")
        return app
    }

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
