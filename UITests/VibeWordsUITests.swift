import XCTest

/// End-to-end checks for Word Vibe, driving the real UI and attaching a
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
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Word Vibe should be on the hub")
        XCTAssertFalse(tile.label.contains("SOON"), "Word Vibe should be playable")

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

    /// A new word starts with a clean keyboard.
    ///
    /// The keyboard takes its colours from a closure rather than from a value,
    /// and SwiftUI could not tell that a new round had changed anything — the
    /// board cleared and the keyboard kept last round's tint, which is exactly
    /// what "the keyboard is not clearing when a new word starts" described.
    func testTheKeyboardClearsWhenANewWordStarts() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openWordsLobby(app)
        startSolo(app, button: "words.playSolo")

        XCTAssertTrue(app.descendants(matching: .any)["words.board"].waitForExistence(timeout: 10))
        try playFullRound(app)

        let tintedBefore = tintedKeys(app)
        XCTAssertGreaterThan(tintedBefore, 0, "the guesses should have tinted the keyboard")

        let playAgain = app.buttons["words.playAgain"]
        XCTAssertTrue(playAgain.waitForExistence(timeout: 5), "the round should be over")
        playAgain.tap()

        let cleared = expectation(for: NSPredicate(format: "value == %@", "not tried"),
                                  evaluatedWith: app.buttons["words.key.Q"])
        wait(for: [cleared], timeout: 5)
        XCTAssertEqual(tintedKeys(app), 0, "a new word starts with a clean keyboard")
        XCTAssertEqual(app.descendants(matching: .any)["words.board"].value as? String,
                       "0 of 6 guesses used")
    }

    /// Six guesses, all of them real words, so the round ends however it ends.
    private func playFullRound(_ app: XCUIApplication) throws {
        for word in ["crane", "slate", "audio", "pious", "mound", "fiery"] {
            for letter in word.uppercased() {
                app.buttons["words.key.\(letter)"].tap()
            }
            app.buttons["words.key.enter"].tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Keys whose colour says something has been learned about that letter.
    private func tintedKeys(_ app: XCUIApplication) -> Int {
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ".reduce(0) { total, letter in
            let key = app.buttons["words.key.\(letter)"]
            guard key.exists, let value = key.value as? String else { return total }
            return value == "not tried" ? total : total + 1
        }
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
        XCTAssertTrue(code.waitForExistence(timeout: backendTimeout),
                      "Should land in the waiting room after creating a game")
        XCTAssertTrue(code.label.uppercased().contains("CODE"),
                      "Expected the game code to be shown, got: \(code.label)")

        XCTAssertTrue(app.buttons["words.startShared"].exists,
                      "The host should be offered a start button")
        attach(app, named: "24-words-shared-host")
    }

    /// A win by somebody else is announced as it happens, whether or not this
    /// player has finished their own word.
    ///
    /// This is what went wrong in feedback #145: the notice was tied to this
    /// device's own round being over, so anyone still guessing — and in
    /// particular anyone who joined after the word was solved — saw nothing.
    /// The winning write comes from the test because XCUITest drives one device;
    /// everything else is the real app talking to the real room.
    func testAWinIsAnnouncedWhileYourOwnWordIsUnfinished() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openWordsLobby(app)

        let create = app.buttons["words.createGame"]
        try XCTSkipUnless(create.exists && create.isEnabled,
                          "Multiplayer needs a configured Firebase project")
        create.tap()

        let badge = app.descendants(matching: .any)["words.gameCode"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: backendTimeout),
                      "Should land in the waiting room after creating a game")
        let room = try XCTUnwrap(RoomSetup.code(from: badge.label),
                                 "Could not read a room code from: \(badge.label)")

        app.buttons["words.startShared"].tap()

        let board = app.descendants(matching: .any)["words.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: backendTimeout), "The board should appear")

        XCTAssertTrue(RoomSetup.writeWinner(path: "games", room: room, name: "Early Bird"),
                      "The database should accept the win")

        let banner = app.descendants(matching: .any)["words.winner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: backendTimeout),
                      "A win by somebody else should be announced straight away")
        XCTAssertTrue(banner.label.contains("Early Bird"),
                      "Expected the winner's name, got: \(banner.label)")
        XCTAssertEqual(board.value as? String, "0 of 6 guesses used",
                       "The notice must not wait for this player's word to be finished")
        attach(app, named: "25-words-someone-else-won")
    }

    /// Solving a shared word in the app has to land in the room, because that is
    /// the only way the browsers watching it can be told.
    ///
    /// Reported after a real game: the phone finished the word and the two web
    /// players got nothing. Reading the room back is the assertion the screen
    /// cannot make — "Solved!" on this phone says nothing about what was written.
    func testSolvingASharedWordRecordsTheWinInTheRoom() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openWordsLobby(app)

        let create = app.buttons["words.createGame"]
        try XCTSkipUnless(create.exists && create.isEnabled,
                          "Multiplayer needs a configured Firebase project")
        create.tap()

        let badge = app.descendants(matching: .any)["words.gameCode"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: backendTimeout),
                      "Should land in the waiting room after creating a game")
        let room = try XCTUnwrap(RoomSetup.code(from: badge.label),
                                 "Could not read a room code from: \(badge.label)")

        app.buttons["words.startShared"].tap()

        let board = app.descendants(matching: .any)["words.board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: backendTimeout), "The board should appear")

        let word = try XCTUnwrap(RoomSetup.read(path: "games/\(room)/word") as? String,
                                 "The room should have a word to solve")

        type(word, in: app)
        app.buttons["words.key.enter"].tap()

        let board2 = app.descendants(matching: .any)["words.board"].firstMatch
        let scored = expectation(for: NSPredicate(format: "value == %@", "1 of 6 guesses used"),
                                 evaluatedWith: board2)
        wait(for: [scored], timeout: 10)

        let recorded = RoomSetup.waitFor(path: "games/\(room)/winner",
                                         until: { ($0 as? [String: Any])?["name"] != nil })
        XCTAssertEqual((recorded as? [String: Any])?["name"] as? String, "Tester",
                       "The room should record this player as the winner, got: \(String(describing: recorded))")
        attach(app, named: "26-words-shared-solved")
    }

    // MARK: - Helpers

    /// Walks from launch to the Word Vibe lobby, dealing with the name prompt
    /// only if this install has not stored a name yet.
    private func openWordsLobby(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-words"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Word Vibe tile should exist")
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
        startSolo(app, button: "words.playSolo")
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
