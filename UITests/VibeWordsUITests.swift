import XCTest

/// End-to-end checks for Vibe Words, driving the real UI and attaching a
/// screenshot at each step so the run doubles as a visual pass.
///
/// These exercise the solo path, which needs no backend. Shared play needs a
/// configured Firebase project and is covered by the unit tests plus manual
/// testing against a real project.
final class VibeWordsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Solo play

    func testSoloGameAcceptsAndScoresAGuess() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        openSoloGame(app)

        let board = app.descendants(matching: .any)["words.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5), "The board should appear")
        XCTAssertEqual(board.value as? String, "0 of 6 guesses used")
        attach(app, named: "20-words-board-empty")

        // CRANE is in the bundled dictionary, so this must be accepted.
        type("CRANE", in: app)
        attach(app, named: "21-words-typed")

        app.buttons["words.key.enter"].tap()

        let accepted = expectation(
            for: NSPredicate(format: "value == %@", "1 of 6 guesses used"),
            evaluatedWith: board
        )
        wait(for: [accepted], timeout: 5)
        attach(app, named: "22-words-scored")
    }

    func testShortGuessIsRejectedAndNotScored() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        openSoloGame(app)

        let board = app.descendants(matching: .any)["words.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5))

        type("AB", in: app)
        app.buttons["words.key.enter"].tap()

        let status = app.descendants(matching: .any)["words.status"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 3), "A rejection message should appear")
        XCTAssertTrue(status.label.contains("Not enough letters"),
                      "Unexpected message: \(status.label)")

        XCTAssertEqual(board.value as? String, "0 of 6 guesses used",
                       "A rejected guess must not be counted")
        attach(app, named: "23-words-rejected")
    }

    func testUnknownWordIsRejected() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        openSoloGame(app)

        let board = app.descendants(matching: .any)["words.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5))

        // Five letters, but not a real word.
        type("ZZZZZ", in: app)
        app.buttons["words.key.enter"].tap()

        let status = app.descendants(matching: .any)["words.status"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(status.label.contains("Not in word list"),
                      "Unexpected message: \(status.label)")

        XCTAssertEqual(board.value as? String, "0 of 6 guesses used")
    }

    // MARK: - Hub integration

    func testHubOffersVibeWordsAsPlayable() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let tile = app.descendants(matching: .any)["game.vibe-words"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Words should be on the hub")
        XCTAssertFalse(tile.label.contains("SOON"), "Vibe Words should be playable")

        attach(app, named: "19-words-hub")
    }

    /// Guards the keyboard's colour feedback at the data level. The answer is
    /// random, so this cannot assert *which* verdict a letter gets — only that
    /// every guessed letter gets one. That is enough to catch the bug where
    /// "not in the word" was rendered in a grey indistinguishable from
    /// "not tried", which made the keyboard look inert.
    func testKeyboardReflectsAGuess() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSoloGame(app)

        let board = app.descendants(matching: .any)["words.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5))

        for letter in "CRANE" {
            let key = app.buttons["words.key.\(letter)"]
            XCTAssertTrue(key.waitForExistence(timeout: 2), "Missing key \(letter)")
            XCTAssertEqual(key.value as? String, "not tried",
                           "\(letter) should start untried")
        }

        type("CRANE", in: app)
        app.buttons["words.key.enter"].tap()

        let scored = expectation(for: NSPredicate(format: "value == %@", "1 of 6 guesses used"),
                                 evaluatedWith: board)
        wait(for: [scored], timeout: 5)

        for letter in "CRANE" {
            let state = app.buttons["words.key.\(letter)"].value as? String
            XCTAssertNotEqual(state, "not tried",
                              "\(letter) should have a verdict after being guessed")
        }

        attach(app, named: "25-words-keyboard-state")
    }

    // MARK: - Shared play

    /// The only test that talks to the real backend. It skips itself when
    /// Firebase is not configured, so a checkout without the config file still
    /// gets a green suite.
    func testCreatingASharedGameShowsACode() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openWordsLobby(app)

        let create = app.buttons["words.createGame"]
        XCTAssertTrue(create.exists, "The create option should be listed")
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")

        create.tap()

        // The waiting room appears only after the game has been written to the
        // database *and* read back by the observer, so this covers both
        // directions of the round trip.
        let code = app.descendants(matching: .any)["words.gameCode"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 25),
                      "Should land in the waiting room after creating a game")
        XCTAssertTrue(code.label.uppercased().contains("CODE"),
                      "Expected the game code to be shown, got: \(code.label)")

        XCTAssertTrue(app.buttons["words.startShared"].exists,
                      "The host should be offered a start button")
        attach(app, named: "24-words-shared-host")
    }

    // MARK: - Helpers

    /// Walks from launch to the Vibe Words lobby, dealing with the name prompt
    /// only if this install has not stored a name yet.
    private func openWordsLobby(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-words"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Words tile should exist")
        tile.tap()

        // The lobby is no longer behind a name gate — a name is only asked for
        // when a shared game is actually started.
        XCTAssertTrue(app.buttons["words.playSolo"].waitForExistence(timeout: 5),
                      "Lobby should offer solo play")
        attach(app, named: "19-words-lobby")
    }

    /// Walks from launch to a solo board.
    private func openSoloGame(_ app: XCUIApplication) {
        openWordsLobby(app)
        app.buttons["words.playSolo"].tap()
    }

    private func type(_ word: String, in app: XCUIApplication) {
        for letter in word.uppercased() {
            let key = app.buttons["words.key.\(letter)"]
            XCTAssertTrue(key.waitForExistence(timeout: 2), "Missing key \(letter)")
            key.tap()
        }
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
