import XCTest

/// End-to-end checks for Vibe Pairings.
///
/// The interesting one reads the cards back off the screen, works out a real
/// trio using the same rule the game is supposed to implement, and taps it. If
/// the renderer or the engine disagree about a card's features, that test fails.
final class VibeTrioUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Hub

    func testHubOffersTrioAsPlayable() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let tile = app.descendants(matching: .any)["game.vibe-trio"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Pairings should be on the hub")
        XCTAssertFalse(tile.label.contains("SOON"), "Vibe Pairings should be playable")
        attach(app, named: "50-trio-hub")
    }

    // MARK: - Solo play

    func testSoloDealsTwelveCards() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSolo(app)
        attach(app, named: "51-trio-solo")

        XCTAssertGreaterThanOrEqual(cardCount(app), 12, "a game starts with twelve cards")
        XCTAssertTrue(app.descendants(matching: .any)["trio.deckCount"].exists)
    }

    /// The real test: solve a trio the app itself has laid out.
    func testFindingARealTrioAdvancesTheDeck() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSolo(app)

        let deckCounter = app.descendants(matching: .any)["trio.deckCount"].firstMatch
        XCTAssertTrue(deckCounter.waitForExistence(timeout: backendTimeout))
        let before = remaining(in: deckCounter)
        XCTAssertGreaterThan(before, 3)

        let trio = try solveTrio(in: app)
        let attempts = expectation(
            for: NSPredicate(format: "label != %@", deckCounter.label),
            evaluatedWith: deckCounter
        )
        for index in trio { app.buttons["trio.card.\(index)"].tap() }
        wait(for: [attempts], timeout: 8)

        XCTAssertEqual(remaining(in: deckCounter), before - 3,
                       "a trio should pull three cards from the deck")
        attach(app, named: "52-trio-scored")
    }

    func testAnInvalidSelectionIsRejected() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSolo(app)

        let deckCounter = app.descendants(matching: .any)["trio.deckCount"].firstMatch
        XCTAssertTrue(deckCounter.waitForExistence(timeout: backendTimeout))
        let before = remaining(in: deckCounter)
        let beforeLabel = deckCounter.label

        let nonTrio = try anyNonTrio(in: app)
        for index in nonTrio { app.buttons["trio.card.\(index)"].tap() }

        // Give it longer than the rejection flash, then confirm nothing moved.
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(deckCounter.label, beforeLabel, "the deck should be untouched")
        XCTAssertEqual(remaining(in: deckCounter), before)
    }

    // MARK: - Shared play

    func testCreatingASharedGameShowsACode() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openLobby(app)

        let create = app.buttons["trio.createGame"]
        XCTAssertTrue(create.exists, "The race option should be listed")
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")

        create.tap()

        let code = app.descendants(matching: .any)["trio.gameCode"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: backendTimeout),
                      "Should land in the waiting room after creating a game")
        XCTAssertTrue(code.label.uppercased().contains("CODE"), "got: \(code.label)")
        XCTAssertTrue(app.buttons["trio.startShared"].exists)
        attach(app, named: "53-trio-shared-host")

        // The host must not be able to study the table while the room fills up.
        let firstCard = app.buttons["trio.card.0"]
        XCTAssertTrue(firstCard.exists, "a shared game deals its table up front")
        XCTAssertFalse(firstCard.isEnabled, "cards stay face down until the host starts")
        XCTAssertNil(parse(firstCard.label), "a face-down card should not name its features")

        app.buttons["trio.startShared"].tap()

        let faceUp = expectation(for: NSPredicate(format: "isEnabled == true"),
                                 evaluatedWith: firstCard)
        wait(for: [faceUp], timeout: 10)
        XCTAssertNotNil(parse(firstCard.label),
                        "after the start, cards should read back as real cards — got: \(firstCard.label)")
        attach(app, named: "54-trio-shared-started")
    }

    /// The point of a shared table: a trio taken on one phone is gone for good.
    /// Leaving and rejoining turns this device into a late arrival at its own
    /// game, which is exactly the case the server's record of takes has to cover.
    func testATakenTrioStaysTakenForALaterArrival() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openLobby(app)

        let create = app.buttons["trio.createGame"]
        XCTAssertTrue(create.exists, "The race option should be listed")
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")
        create.tap()

        let codeLabel = app.descendants(matching: .any)["trio.gameCode"].firstMatch
        XCTAssertTrue(codeLabel.waitForExistence(timeout: backendTimeout))
        let code = displayedCode(in: codeLabel.label)
        // Two four-letter words a space apart — the shape the other games share.
        // It is typed back in further down exactly as it appears here, so this
        // also covers the promise that what is displayed is what can be entered.
        assertLooksLikeADisplayedCode(code, label: codeLabel.label)

        app.buttons["trio.startShared"].tap()
        XCTAssertTrue(app.buttons["trio.card.0"].waitForExistence(timeout: backendTimeout))

        let deckCounter = app.descendants(matching: .any)["trio.deckCount"].firstMatch
        XCTAssertTrue(deckCounter.waitForExistence(timeout: backendTimeout))
        let before = remaining(in: deckCounter)

        let trio = try solveTrio(in: app)
        // The label has to be read *before* the taps: a shared take lands here
        // first and is reconciled with the server second, which can be quicker
        // than the next line of the test.
        let beforeLabel = deckCounter.label
        let moved = expectation(for: NSPredicate(format: "label != %@", beforeLabel),
                                evaluatedWith: deckCounter)
        for index in trio { app.buttons["trio.card.\(index)"].tap() }
        wait(for: [moved], timeout: backendTimeout)
        let after = remaining(in: deckCounter)
        XCTAssertLessThan(after, before, "the take should reach the server")
        attach(app, named: "58-trio-shared-taken")

        // Leave and come back with the code, reading the game cold.
        app.buttons["trio.back"].tap()

        let joinField = app.textFields["trio.joinField"]
        XCTAssertTrue(joinField.waitForExistence(timeout: 5), "the lobby should offer a code field")
        joinField.tap()
        joinField.typeText(code)
        app.buttons["trio.joinButton"].tap()

        XCTAssertTrue(app.buttons["trio.card.0"].waitForExistence(timeout: backendTimeout),
                      "the code should let this device back in")
        let rejoined = app.descendants(matching: .any)["trio.deckCount"].firstMatch
        XCTAssertTrue(rejoined.waitForExistence(timeout: backendTimeout))

        let restored = expectation(
            for: NSPredicate(format: "label == %@", "\(after) left in the deck"),
            evaluatedWith: rejoined
        )
        wait(for: [restored], timeout: backendTimeout)
        attach(app, named: "59-trio-shared-rejoined")
    }

    /// The whole table has to be in front of you at once. A card that exists but
    /// sits below the fold is a card you cannot play without scrolling, so this
    /// measures the frames rather than trusting that they are there.
    func testTheWholeTableIsOnScreen() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSolo(app)

        let window = app.windows.firstMatch.frame
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                     "trio.card."))
        XCTAssertGreaterThanOrEqual(cards.count, 12, "a game starts with twelve cards")

        for index in 0..<cards.count {
            let frame = cards.element(boundBy: index).frame
            XCTAssertTrue(window.contains(frame),
                          "card \(index) at \(frame) is not fully inside the window \(window)")
            XCTAssertGreaterThan(frame.width, 20, "card \(index) is too small to tap")
        }
        attach(app, named: "66-trio-fits-the-screen")
    }

    // MARK: - Hints

    func testAHintLightsUpASingleCard() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openSolo(app)

        let hint = app.buttons["trio.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 10), "solo play offers a hint")
        hint.tap()

        let dealt = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                     "trio.card."))
        let lit = (0..<dealt.count).filter { dealt.element(boundBy: $0).isSelected }
        XCTAssertEqual(lit.count, 1,
                       "a hint should narrow it to one card, not hand over the trio")
        attach(app, named: "57-trio-hint")
    }

    func testRacingOffersNoHint() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openLobby(app)

        let create = app.buttons["trio.createGame"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        try XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")
        create.tap()

        let code = app.descendants(matching: .any)["trio.gameCode"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: backendTimeout))
        app.buttons["trio.startShared"].tap()

        XCTAssertTrue(app.buttons["trio.card.0"].waitForExistence(timeout: backendTimeout))
        XCTAssertFalse(app.buttons["trio.hint"].exists,
                       "a race is about who spots it first, so no hints")
    }

    // MARK: - Instructions

    func testInstructionsOpenFromTheLobby() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openLobby(app)

        let open = app.buttons["trio.instructions.open"]
        XCTAssertTrue(open.exists, "the lobby should offer the instructions")
        attach(app, named: "54-trio-lobby-with-instructions")
        open.tap()

        XCTAssertTrue(app.descendants(matching: .any)["trio.instructions"].waitForExistence(timeout: 5),
                      "the instructions should open")
        XCTAssertTrue(app.descendants(matching: .any)["trio.example.trio"].exists,
                      "with a worked example of a trio")
        XCTAssertTrue(app.descendants(matching: .any)["trio.example.notATrio"].exists,
                      "and one of a near miss")

        attach(app, named: "55-trio-instructions-top")
        app.swipeUp(); app.swipeUp()
        attach(app, named: "56-trio-instructions-examples")
        app.buttons["trio.instructions.back"].tap()
        XCTAssertTrue(app.buttons["trio.playSolo"].waitForExistence(timeout: 5),
                      "and close back to the lobby")
    }

    // MARK: - Appearance
    //
    // These double as the source of the screenshots the landing page uses, which
    // is why they cover both appearances in one run.

    func testLightAppearance() throws {
        capture(appearance: "light", board: "60-trio-board-light", shared: "61-trio-shared-light")
    }

    func testDarkAppearance() throws {
        capture(appearance: "dark", board: "62-trio-board-dark", shared: "63-trio-shared-dark")
    }

    /// The end state, shot for the landing page. Clearing the deck takes a
    /// couple of dozen takes, so this is also the only test that runs the board
    /// all the way out — a shared game reaches the same leaderboard, with more
    /// names on it.
    func testLeaderboardLight() throws {
        shootLeaderboard(appearance: "light", named: "64-trio-leaderboard-light")
    }

    func testLeaderboardDark() throws {
        shootLeaderboard(appearance: "dark", named: "65-trio-leaderboard-dark")
    }

    private func shootLeaderboard(appearance: String, named name: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-vibegames.appearance", appearance]
        app.launch(withName: "Tester")
        openSolo(app)

        let leaderboard = app.descendants(matching: .any)["trio.leaderboard"].firstMatch
        let counter = app.descendants(matching: .any)["trio.deckCount"].firstMatch

        var rounds = 0
        while rounds < 40, !leaderboard.exists, counter.exists {
            rounds += 1
            let before = counter.label
            guard let trio = findTrio(in: app) else { break }
            for index in trio { app.buttons["trio.card.\(index)"].tap() }
            settle(counter, leaving: before)
        }

        XCTAssertTrue(leaderboard.waitForExistence(timeout: 10),
                      "clearing the deck should end on the leaderboard")
        XCTAssertTrue(app.descendants(matching: .any)["trio.result"].exists,
                      "and say who won")
        attach(app, named: name)
    }

    private func capture(appearance: String, board: String, shared: String) {        let app = XCUIApplication()
        app.launchArguments += ["-vibegames.appearance", appearance]
        app.launch(withName: "Tester")

        openSolo(app)
        XCTAssertGreaterThanOrEqual(cardCount(app), 12)
        attach(app, named: board)

        // Back to the lobby, then host a game so the waiting room can be shot too.
        app.buttons["trio.back"].tap()

        let create = app.buttons["trio.createGame"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        try? XCTSkipUnless(create.isEnabled, "Multiplayer needs a configured Firebase project")
        create.tap()

        let code = app.descendants(matching: .any)["trio.gameCode"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: backendTimeout))
        attach(app, named: shared)
    }

    // MARK: - Card reading
    //
    // Cards are labelled like "round walnut platter, swiss wedge, prosciutto
    // ribbon, purple grapes", so the test can read the board back and reason
    // about it exactly as a player would.

    private struct Card {
        let base: Int, cheese: Int, meat: Int, garnish: Int
    }

    private let baseNames = ["round walnut platter": 0,
                             "bamboo hexagon platter": 1,
                             "slate rectangle platter": 2]
    private let cheeseNames = ["swiss wedge": 0, "gouda cubes": 1, "brie round": 2]
    private let meatNames = ["prosciutto ribbon": 0, "salami stack": 1, "turkey roll-up": 2]
    private let garnishNames = ["purple grapes": 0, "red strawberry": 1, "pear slices": 2]

    /// The label is four phrases, in a fixed order, so splitting on the commas
    /// is exact rather than a guess.
    private func parse(_ label: String) -> Card? {
        let parts = label.lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 4,
              let base = baseNames[parts[0]],
              let cheese = cheeseNames[parts[1]],
              let meat = meatNames[parts[2]],
              let garnish = garnishNames[parts[3]]
        else { return nil }
        return Card(base: base, cheese: cheese, meat: meat, garnish: garnish)
    }

    private func formsTrio(_ a: Card, _ b: Card, _ c: Card) -> Bool {
        func ok(_ x: Int, _ y: Int, _ z: Int) -> Bool {
            (x == y && y == z) || (x != y && y != z && x != z)
        }
        return ok(a.base, b.base, c.base)
            && ok(a.cheese, b.cheese, c.cheese)
            && ok(a.meat, b.meat, c.meat)
            && ok(a.garnish, b.garnish, c.garnish)
    }

    /// The cards on the table, read in a single pass.
    ///
    /// Every `exists` and every `.label` is a round trip to the app's
    /// accessibility tree, and asking about indices one at a time cost more than
    /// everything else this file does put together: the board is read once a
    /// round, there are up to 24 cards to ask about, and a game that runs to the
    /// leaderboard is two dozen rounds. One query, and the labels come off the
    /// snapshot it returns.
    private func readBoard(_ app: XCUIApplication) -> [Int: Card] {
        var cards: [Int: Card] = [:]
        let all = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "trio.card.")
        )
        for element in all.allElementsBoundByIndex {
            guard let index = Int(element.identifier.dropFirst("trio.card.".count)),
                  let parsed = parse(element.label) else { continue }
            cards[index] = parsed
        }
        return cards
    }

    private func findTrio(in app: XCUIApplication) -> [Int]? {
        let cards = readBoard(app)
        let indices = cards.keys.sorted()
        for i in indices {
            for j in indices where j > i {
                for k in indices where k > j {
                    if formsTrio(cards[i]!, cards[j]!, cards[k]!) { return [i, j, k] }
                }
            }
        }
        return nil
    }

    private func solveTrio(in app: XCUIApplication) throws -> [Int] {
        guard let trio = findTrio(in: app) else {
            throw XCTSkip("No trio on the table — the game would have dealt more")
        }
        return trio
    }

    /// Waits for the board to catch up with a tap, by watching the deck count
    /// move. Returns as soon as it does, or when the count disappears because
    /// the game has ended and the leaderboard has taken the board's place.
    private func settle(_ element: XCUIElement, leaving label: String, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists || element.label != label { return }
            usleep(60_000)
        }
    }

    private func anyNonTrio(in app: XCUIApplication) throws -> [Int] {
        let cards = readBoard(app)
        let indices = cards.keys.sorted()
        for i in indices {
            for j in indices where j > i {
                for k in indices where k > j {
                    if !formsTrio(cards[i]!, cards[j]!, cards[k]!) { return [i, j, k] }
                }
            }
        }
        throw XCTSkip("Every triple on the table is a trio")
    }

    private func cardCount(_ app: XCUIApplication) -> Int {
        readBoard(app).count
    }

    /// "44 left in the deck" -> 44
    private func remaining(in element: XCUIElement) -> Int {
        let digits = element.label.split(separator: " ").first.map(String.init) ?? ""
        return Int(digits) ?? -1
    }

    // MARK: - Helpers

    private func openLobby(_ app: XCUIApplication) {
        let tile = app.descendants(matching: .any)["game.vibe-trio"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Pairings tile should exist")
        tile.tap()

        // No name gate any more: solo play never needs one, and a shared game
        // asks for it only when it is started.
        XCTAssertTrue(app.buttons["trio.playSolo"].waitForExistence(timeout: 5),
                      "Lobby should offer solo play")
        attach(app, named: "50-trio-lobby")
    }

    private func openSolo(_ app: XCUIApplication) {
        openLobby(app)
        app.buttons["trio.playSolo"].tap()
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
