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

        let field = app.textFields["gameSettings.nameField"]
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

        // Where a settings screen keeps them: the version, and the two URLs the
        // App Store listing asks for. On screen without scrolling, which the
        // bottom of the support panel is not.
        for identifier in ["preferences.privacy", "preferences.support"] {
            let link = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(link.exists, "\(identifier) should be in preferences")
            XCTAssertTrue(link.isHittable, "\(identifier) should be reachable")
        }
        let version = app.staticTexts["preferences.version"].firstMatch
        XCTAssertTrue(version.exists, "preferences should say which build this is")
        XCTAssertTrue(version.label.contains("Vibe Games"),
                      "and name the app — got: \(version.label)")
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

        // The tip row is deliberately not asserted here. A test run has no store
        // — StoreKit testing needs the app signed with the in-app purchase
        // entitlement, which simulator test builds are not — and a build before
        // the product exists in App Store Connect has none either. In both, the
        // row is hidden rather than shown broken, which is the behaviour
        // `TreatJarTests` covers. What is checked here is that the panel is a
        // panel without it: the share row is offered.
        XCTAssertTrue(app.descendants(matching: .any)["support.share"].firstMatch.exists,
                      "the panel should offer the one way to help that costs nothing")

        // The app itself must offer nothing to buy: the row hands over to the
        // website, which is the only place the Venmo link is allowed to live.
        XCTAssertFalse(app.staticTexts["Venmo @chill-gelato"].exists,
                       "the app should not offer the handle itself")

        // App Store Connect wants a URL for the privacy policy and one for
        // support, and a reviewer should be able to reach the policy without
        // leaving the app to guess where it is. They sit at the bottom of the
        // panel, below the fold on a phone — the preferences screen carries the
        // same two links where they can be seen without scrolling.
        for identifier in ["support.privacyPolicy", "support.supportPage"] {
            let link = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(link.waitForExistence(timeout: 5), "\(identifier) should be in the panel")
            if !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.isHittable, "\(identifier) should be reachable")
        }

        done.tap()
        XCTAssertTrue(heart.waitForExistence(timeout: 5), "and close back to the hub")

        // The hub's footer used to name the website and offer a button to it.
        // Both went with the tip jar — the same page carries the Venmo link, and
        // pointing at it from an app that sells the same thing is the guideline.
        // `testNothingOutsideTheAppStoreIsOffered` is where that is checked.
        XCTAssertFalse(app.descendants(matching: .any)["hub.waysToHelp"].exists,
                       "the hub should offer no other way to help")
        attach(app, named: "73-hub-footer")
    }

    /// The app sells one thing, and Apple sells it.
    ///
    /// This was a test that the ways-to-help link handed over to Safari, and it
    /// was a good test of a thing that had to go: the page it opened carries a
    /// Venmo link, and once the same tip is sold in the app a link to another
    /// payment route is exactly what guideline 3.1.1 forbids. So what is left to
    /// check is that nothing outside the App Store is offered anywhere.
    func testNothingOutsideTheAppStoreIsOffered() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        // A heading is fine; a route to somewhere else that takes money is not.
        // So the markers are the names of the payment services and of the page
        // that carries them — not the words, and not the site itself. The hub
        // names `play.vibegames.party` on purpose: it is the way to the same free
        // games in a browser, which is not a way to pay for anything.
        let elsewhere = ["venmo", "paypal", "cash.app", "ways-to-help"]

        func offersAnotherWayToPay() -> String? {
            for marker in elsewhere {
                let found = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label CONTAINS[c] %@", marker))
                    .firstMatch
                if found.exists { return marker }
            }
            return nil
        }

        XCTAssertNil(offersAnotherWayToPay(), "the hub should offer no other way to pay")

        app.buttons["hub.support"].tap()
        let done = app.buttons["support.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "the heart should open the panel")

        XCTAssertNil(offersAnotherWayToPay(),
                     "and neither should the panel: the tip in it is Apple's, and "
                     + "pointing at another way to pay is the rejection")
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
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
