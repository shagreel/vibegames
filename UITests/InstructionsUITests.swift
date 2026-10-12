import XCTest

/// Every game shows its instructions the same way now: one "How to play"
/// control on the main page, one page behind it, one way back.
///
/// The five pages are drawn from a single shell, so this checks the parts that
/// are meant to be identical — that the control is there, that it opens
/// something, and that closing it comes back — rather than the words on each
/// page, which are that game's business.
final class InstructionsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testVibeFive() throws {
        check(game: "game.vibe-five", opener: "five.instructions.open", page: "five.instructions")
    }

    func testVibeWords() throws {
        check(game: "game.vibe-words", opener: "words.instructions.open", page: "words.instructions")
    }

    func testVibeSudoku() throws {
        check(game: "game.vibe-sudoku", opener: "sudoku.instructions.open", page: "sudoku.instructions")
    }

    func testVibeTrio() throws {
        check(game: "game.vibe-trio", opener: "trio.instructions.open", page: "trio.instructions")
    }

    func testVibeBlurt() throws {
        check(game: "game.vibe-blurt", opener: "blurt.instructions.open", page: "blurt.instructions")
    }

    /// Walks the same path in every game. The opener's identifier and the page's
    /// are built from one prefix, which is what makes this loop possible — and
    /// if a game stops following that convention, the test stops compiling with
    /// the identifier rather than quietly testing nothing.
    private func check(game tileIdentifier: String,
                       opener: String,
                       page: String,
                       file: StaticString = #filePath,
                       line: UInt = #line) {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let tile = app.descendants(matching: .any)[tileIdentifier].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15),
                      "\(tileIdentifier) should be on the hub", file: file, line: line)
        tile.tap()

        let open = app.buttons[opener]
        XCTAssertTrue(open.waitForExistence(timeout: 10),
                      "\(opener) should be offered on the main page", file: file, line: line)
        open.tap()

        XCTAssertTrue(app.descendants(matching: .any)[page].waitForExistence(timeout: 5),
                      "\(page) should open", file: file, line: line)

        let back = app.buttons["\(page).back"]
        XCTAssertTrue(back.exists, "\(page) should offer a way back", file: file, line: line)
        back.tap()

        XCTAssertTrue(open.waitForExistence(timeout: 5),
                      "back should land on the page the instructions were opened from",
                      file: file, line: line)
    }
}
