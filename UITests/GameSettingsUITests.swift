import XCTest

/// Every game opens its settings the same way, and every one of them has the two
/// settings that belong to the player rather than to the game: what they are
/// called, and whether the games are light or dark.
///
/// It is one test over the five of them rather than five tests, because the
/// point *is* that they are the same — a game that drifts would be the odd one
/// out and this is what would notice.
final class GameSettingsUITests: XCTestCase {

    /// The five games, by the prefixes their own controls use.
    private let games = [
        (title: "Vibe Five", tile: "game.vibe-five", prefix: "vibeFive"),
        (title: "Word Vibe", tile: "game.vibe-words", prefix: "words"),
        (title: "Number Vibe", tile: "game.vibe-sudoku", prefix: "sudoku"),
        (title: "Vibe Pairings", tile: "game.vibe-trio", prefix: "trio"),
        (title: "Similar Vibe", tile: "game.vibe-blurt", prefix: "blurt"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEveryGameOffersTheSameSettings() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        for game in games {
            let tile = app.descendants(matching: .any)[game.tile].firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout: 15), "\(game.title) should be on the hub")
            tile.tap()

            let button = app.buttons["\(game.prefix).settings"]
            XCTAssertTrue(button.waitForExistence(timeout: 10),
                          "\(game.title) should have a settings button in its header")
            button.tap()

            XCTAssertTrue(app.textFields["gameSettings.nameField"].waitForExistence(timeout: 5),
                          "\(game.title)'s settings should offer the player's name")
            XCTAssertTrue(app.segmentedControls["gameSettings.appearance"].exists,
                          "\(game.title)'s settings should offer the appearance")

            // The sheet is scrollable and the Done button is at the bottom of
            // it, so on the two sheets with a long list it is off-screen.
            let done = app.buttons["\(game.prefix).settings.done"]
            if done.exists {
                done.tap()
            } else {
                app.swipeUp()
                if done.exists { done.tap() } else { app.buttons["Done"].firstMatch.tap() }
            }

            // Back to the hub, ready for the next game.
            app.buttons["\(game.prefix).back"].firstMatch.tap()
        }
    }

    /// Both settings are kept: the name as it is typed, the appearance as soon
    /// as it is chosen, and both are still there the next time the sheet opens.
    ///
    /// Launched without a name on purpose. A launch argument lands in
    /// `UserDefaults`' argument domain and wins over anything written there, so a
    /// test that launched with one could not tell a remembered name from the
    /// argument it was launched with.
    func testTheNameAndAppearanceAreRemembered() throws {
        let app = XCUIApplication()
        app.launch(withName: nil)
        dismissNamePromptIfPresent(app)

        openNumberVibeSettings(app)

        let field = app.textFields["gameSettings.nameField"]
        replaceText(in: field, with: "Renamed Player")

        let appearance = app.segmentedControls["gameSettings.appearance"]
        appearance.buttons["Light"].tap()
        XCTAssertTrue(appearance.buttons["Light"].isSelected, "choosing Light should select it")

        app.buttons["sudokuSettings.done"].tap()

        // Open it again: both should have been kept.
        XCTAssertTrue(app.buttons["sudoku.settings"].waitForExistence(timeout: 5))
        app.buttons["sudoku.settings"].tap()
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        XCTAssertTrue(appearance.buttons["Light"].isSelected,
                      "the appearance should still be Light when the sheet is opened again")
        XCTAssertEqual(field.value as? String, "Renamed Player",
                       "the name should still be there when the sheet is opened again")

        // Leave the appearance as it was found, so the rest of the suite is not
        // run in light mode.
        appearance.buttons["System"].tap()
        app.buttons["sudokuSettings.done"].tap()
    }

    private func openNumberVibeSettings(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-sudoku"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15))
        tile.tap()

        let settings = app.buttons["sudoku.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        XCTAssertTrue(app.textFields["gameSettings.nameField"].waitForExistence(timeout: 5))
    }
}
