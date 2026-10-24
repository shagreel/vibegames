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
        attach(app, named: "48-ten-hub")
    }

    func testSoloBoardAndTakingAPair() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSoloBoard(app)

        let board = app.descendants(matching: .any)["ten.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10), "the board should appear")

        let cells = readCells(app)
        XCTAssertEqual(cells.count, 162, "nine wide and eighteen tall")

        let pair = try XCTUnwrap(firstPair(in: cells), "a board of 162 digits should have a pair")
        tap(pair.0, in: app)
        tap(pair.1, in: app)

        // The score in the header is the report of a pair taken.
        // Two digits gone, and nothing else moved: the pair really was taken.
        let after = readCells(app)
        XCTAssertEqual(after.count, 160, "taking a pair should remove exactly two digits")
        XCTAssertFalse(after.contains { $0.column == pair.0.column && $0.row == pair.0.row
            && $0.value == pair.0.value }, "the first digit is gone")
        attach(app, named: "49-ten-solo")
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
        attach(app, named: "50-ten-room")
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
        app.buttons["ten.playSolo"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ten.board"].firstMatch
                        .waitForExistence(timeout: 10), "the board should appear")
    }

    /// Every cell, read from its accessibility label: "Column 2 row 5: 7".
    private func readCells(_ app: XCUIApplication) -> [(column: Int, row: Int, value: Int)] {
        let elements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ten.cell."))
            .allElementsBoundByIndex
        return elements.compactMap { element in
            let label = element.label
            guard let colon = label.lastIndex(of: ":"),
                  let value = Int(label[label.index(after: colon)...]
                      .trimmingCharacters(in: .whitespaces)) else { return nil }
            let parts = label[..<colon].split(separator: " ")
            guard parts.count >= 4,
                  let column = Int(parts[1]), let row = Int(parts[3]) else { return nil }
            return (column - 1, row - 1, value)
        }
    }

    /// A pair that can be taken: next to each other, and equal or adding to ten.
    private func firstPair(in cells: [(column: Int, row: Int, value: Int)])
        -> ((column: Int, row: Int, value: Int), (column: Int, row: Int, value: Int))? {
        for first in cells {
            for second in cells where second.row > first.row || (second.row == first.row && second.column > first.column) {
                let paired = first.value == second.value || first.value + second.value == 10
                let touching = abs(first.column - second.column) <= 1 && abs(first.row - second.row) <= 1
                if paired && touching { return (first, second) }
            }
        }
        return nil
    }

    private func tap(_ cell: (column: Int, row: Int, value: Int), in app: XCUIApplication) {
        let element = app.descendants(matching: .any)["ten.cell.\(cell.column).\(cell.row)"].firstMatch
        XCTAssertTrue(element.exists, "cell \(cell.column),\(cell.row) should exist")
        element.tap()
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
