import XCTest

/// The hub owns the two things that belong to the whole suite rather than to one
/// game: what you are called, and how the app looks.
final class HomeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The name used to be asked for inside each game that wanted one, so
    /// choosing Vibe Pairings to play solo put a form in front of you that the game
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
                      "Vibe Pairings should open straight to its lobby")
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

        // The app must not point at a way to pay: Apple rejects that, and this
        // panel is where the link used to be.
        let aboutPaying = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
                                  "venmo", "buy us a treat"))
            .firstMatch
        XCTAssertFalse(aboutPaying.exists, "the app should offer no way to pay in it")

        // What it offers instead: a page on the website, opened in the browser.
        // It is not tapped here — the tap leaves the app for Safari, and a UI run
        // has no business driving the browser. `SupportTests` pins the address.
        let ways = app.descendants(matching: .any)["support.waysToHelp"]
        XCTAssertTrue(ways.waitForExistence(timeout: 5),
                      "the panel should point at the ways to help")
        XCTAssertTrue(ways.label.localizedCaseInsensitiveContains("ways to help"),
                      "and say so, rather than being an unlabelled row")
        // Present is not the same as reachable: a row under the Done button, or
        // behind the keyboard, would satisfy everything above and still be a
        // link nobody can follow.
        XCTAssertTrue(ways.isHittable, "and be somewhere a thumb can get to")

        // The app itself must offer nothing to buy: the row hands over to the
        // website, which is the only place the Venmo link is allowed to live.
        XCTAssertFalse(app.staticTexts["Venmo @chill-gelato"].exists,
                       "the app should not offer the handle itself")

        done.tap()
        XCTAssertTrue(heart.waitForExistence(timeout: 5), "and close back to the hub")

        // The same page, from the bottom of the hub — the way in for somebody who
        // is not looking for the heart.
        let fromHub = app.descendants(matching: .any)["hub.waysToHelp"]
        XCTAssertTrue(fromHub.waitForExistence(timeout: 5),
                      "the hub should link to it at the bottom")
        if !fromHub.isHittable { app.swipeUp() }
        XCTAssertTrue(fromHub.isHittable,
                      "the hub's link should be reachable, not just in the hierarchy")
        attach(app, named: "73-hub-ways-to-help")
    }

    /// The one thing about that link that cannot be read off the source: following
    /// it really does leave the app.
    ///
    /// It used to open a screen built in SwiftUI, which is a thing that looks
    /// right in a screenshot and is the wrong answer to "where does this go" — the
    /// page has to be the website's, because the website is the only place the
    /// payment link is allowed to live.
    func testTheWaysToHelpLinkOpensThePageInTheBrowser() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let link = app.descendants(matching: .any)["hub.waysToHelp"]
        XCTAssertTrue(link.waitForExistence(timeout: 15), "the hub should link to it")
        if !link.isHittable { app.swipeUp() }
        link.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30),
                      "following it should hand over to the browser")
        // A sheet inside the app would leave the app in front and Safari would
        // never appear, so that it does is the whole assertion. Asking the app
        // for its own `state` after this adds nothing: XCUITest keeps reporting
        // the state it saw at launch.
        attach(safari, named: "75-ways-to-help-in-the-browser")
    }

    /// The whole point of the heart being on every screen: you can say what is
    /// wrong while you are looking at it, without a GitHub account and without
    /// leaving the game.
    func testFeedbackCanBeSentFromInsideAGame() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        dismissNamePromptIfPresent(app)

        app.descendants(matching: .any)["game.vibe-trio"].firstMatch.tap()
        XCTAssertTrue(app.buttons["trio.playSolo"].waitForExistence(timeout: 10),
                      "Vibe Pairings should open")

        // The heart is here too, not only on the hub.
        let heart = app.buttons["hub.support"]
        XCTAssertTrue(heart.waitForExistence(timeout: 5), "a game screen should carry the heart")
        heart.tap()

        let box = app.textViews["feedback.text"]
        XCTAssertTrue(box.waitForExistence(timeout: 5), "the panel should carry the form")
        XCTAssertFalse(app.buttons["feedback.send"].isEnabled,
                       "an empty note should not be sendable")

        box.tap()
        // This walks the real path and posts to the live inbox on purpose — a
        // form that only ever works against a stub proves nothing. A client
        // cannot delete what it wrote, so the note is marked instead, and
        // Tools/feedback_to_issues.py leaves anything marked alone.
        box.typeText("[test] The trio animation is a lovely touch.")

        let send = app.buttons["feedback.send"]
        XCTAssertTrue(send.isEnabled, "and a written one should be")
        attach(app, named: "73-feedback-form")
        send.tap()

        // Generous on purpose. The thank-you appears only once the database has
        // acknowledged the write — the form deliberately does not claim success
        // before it is true — and that round trip goes through App Check, so it
        // can take far longer than it usually does. Twenty seconds was enough
        // most runs and not others.
        XCTAssertTrue(app.descendants(matching: .any)["feedback.sent"].waitForExistence(timeout: 60),
                      "sending should say so rather than failing quietly; a "
                      + "feedback.problem element here means the write was refused")
        attach(app, named: "74-feedback-sent")
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
