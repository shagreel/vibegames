import XCTest

/// The hub owns the two things that belong to the whole suite rather than to one
/// game: what you are called, and how the app looks.
final class HomeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The name used to be asked for inside each game that wanted one, so
    /// choosing Vibe Trio to play solo put a form in front of you that the game
    /// did not need. It is asked once now, before any game is opened.
    func testFirstRunAsksForANameBeforeAnyGameDoes() throws {
        let app = XCUIApplication()
        // Both halves of the first-run test are forced through the argument
        // domain — a name that is not there, and a prompt that has not been
        // answered — so this is a first run whatever earlier tests left behind.
        app.launchArguments += ["-vibegames.playerName", "",
                                "-vibegames.namePromptAnswered", ""]
        app.launch()

        let field = app.textFields["firstRun.nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15),
                      "the app should ask for a name the first time it is opened")
        XCTAssertTrue(app.buttons["firstRun.nameSave"].exists)
        attach(app, named: "67-first-run-name")

        // Waving it away has to leave the hub usable — Vibe Five never needs a
        // name, and neither does solo play in the others.
        app.buttons["firstRun.nameSkip"].tap()

        let tile = app.descendants(matching: .any)["game.vibe-five"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "the hub should be usable after a skip")
        XCTAssertFalse(field.exists, "and the prompt should be gone")
    }

    /// The name is the app's, not a game's, so setting it once sets it
    /// everywhere — and the hub says who it thinks you are.
    func testPreferencesSetsTheNameTheGamesWillUse() throws {
        let app = XCUIApplication()
        // Deliberately no name in the argument domain: this test writes one, and
        // an argument-domain value would shadow the write on the way back out.
        app.launch(withName: nil)
        dismissNamePromptIfPresent(app)

        let chip = app.buttons["hub.playerName"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "Hub should load")

        attach(app, named: "69-hub-with-name")
        app.buttons["hub.preferences"].tap()

        let field = app.textFields["preferences.nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Preferences should open")
        replaceText(in: field, with: "Alex")
        app.buttons["preferences.done"].tap()

        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Playing as Alex",
                       "the hub should show the name that was just set")

        // And the game agrees, without asking again.
        app.descendants(matching: .any)["game.vibe-trio"].firstMatch.tap()
        XCTAssertTrue(app.buttons["trio.playSolo"].waitForExistence(timeout: 10),
                      "Vibe Trio should open straight to its lobby")
        XCTAssertFalse(app.textFields["trio.nameField"].exists,
                       "it should not ask for a name a second time")
    }

    /// Appearance moved in with the name, so the button is a preferences button
    /// rather than a light/dark switch.
    func testPreferencesChangesTheAppearance() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        dismissNamePromptIfPresent(app)

        let preferences = app.buttons["hub.preferences"]
        XCTAssertTrue(preferences.waitForExistence(timeout: 15), "Hub should load")
        preferences.tap()

        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Preferences should offer appearance")
        attach(app, named: "68-preferences")

        let dark = picker.buttons["Dark"]
        XCTAssertTrue(dark.exists, "the three appearances should be listed")
        dark.tap()
        XCTAssertTrue(dark.isSelected, "choosing dark should select it")
    }

    /// The complaint that started this: choosing to play on your own must not
    /// put a form in front of you. Only a shared game wants a name, because only
    /// a shared game has anybody else to read it.
    func testSoloPlayNeverAsksForAName() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-vibegames.playerName", "",
                                "-vibegames.namePromptAnswered", ""]
        app.launch()

        let skip = app.buttons["firstRun.nameSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "a first run asks first")
        skip.tap()

        app.descendants(matching: .any)["game.vibe-trio"].firstMatch.tap()
        XCTAssertTrue(app.buttons["trio.playSolo"].waitForExistence(timeout: 10),
                      "the lobby should open without asking anything")
        XCTAssertFalse(app.textFields["trio.nameField"].exists,
                       "and without a name field anywhere on it")

        app.buttons["trio.playSolo"].tap()
        XCTAssertTrue(app.buttons["trio.card.0"].waitForExistence(timeout: 10),
                      "solo play should deal with no name at all")

        // Back to the lobby, and ask to race — which is when a name is wanted.
        app.buttons["trio.back"].tap()

        let create = app.buttons["trio.createGame"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")
        create.tap()

        let field = app.textFields["trio.nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5),
                      "starting a shared game should ask for a name")
        attach(app, named: "70-trio-name-only-when-sharing")
    }

    /// The games are free, so the only thing behind the heart is a thank-you —
    /// and the ways to act on it have to be reachable.
    func testTheHeartOpensTheSupportPanel() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        dismissNamePromptIfPresent(app)

        let heart = app.buttons["hub.support"]
        XCTAssertTrue(heart.waitForExistence(timeout: 15), "the hub should carry a heart")

        // The heart is the whole of it: there was a line under it saying the
        // games are free, and it was doing nothing the panel does not.
        XCTAssertFalse(app.descendants(matching: .any)["hub.supportStrip"].exists,
                       "the hub should not carry a banner about it")
        attach(app, named: "71-hub-support-heart")

        heart.tap()

        let done = app.buttons["support.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the heart should open the panel")
        attach(app, named: "72-support-panel")

        // The handle is written out as well as linked, for anyone who would
        // rather type it than follow a link.
        let handle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "@chill-gelato"))
            .firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "the Venmo handle should be on screen")

        done.tap()
        XCTAssertTrue(heart.waitForExistence(timeout: 5), "and close back to the hub")
    }

    // MARK: - Helpers

    /// A leftover name from an earlier run means there is no first-run prompt to
    /// dismiss; a clean one means there is. Either way the test carries on.
    private func dismissNamePromptIfPresent(_ app: XCUIApplication) {
        let skip = app.buttons["firstRun.nameSkip"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let existing = (field.value as? String) ?? ""
        // An empty field reports its placeholder as the value.
        if !existing.isEmpty, existing != "Your name" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                  count: existing.count + 4))
        }
        field.typeText(text)
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
