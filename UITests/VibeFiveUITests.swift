import XCTest

/// End-to-end checks for the Vibe Five round loop.
///
/// These drive the real UI, so they also serve as the visual verification pass:
/// every step attaches a screenshot to the test result bundle.
final class VibeFiveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Round loop

    func testStartRevealsCategoryThenBuzzesThenDealsNext() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        attach(app, named: "01-hub")

        let tile = app.descendants(matching: .any)["game.vibe-five"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "Vibe Five tile should be on the hub")
        tile.tap()

        let primary = app.buttons["vibeFive.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), "Primary button should exist")

        // Ready state: no category has been revealed yet.
        XCTAssertEqual(primary.label, "START", "Opening button should read START")
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.category"].exists,
                       "Category must stay hidden until Start is pressed")
        attach(app, named: "02-ready")

        primary.tap()

        // The category is revealed; the clock waits to be started.
        let category = app.descendants(matching: .any)["vibeFive.category"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 3),
                      "A category should appear as soon as Start is pressed")
        let firstCategory = category.label
        XCTAssertTrue(firstCategory.hasPrefix("Category: "),
                      "Expected a category label, got \(firstCategory)")
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.ring"].exists,
                       "The clock must not have started yet")

        primary.tap()
        waitForLabel(primary, "Done!")

        Thread.sleep(forTimeInterval: 2.0)
        attach(app, named: "03-counting-down")

        // Five seconds from the tap, the buzzer fires.
        let timesUp = app.descendants(matching: .any)["vibeFive.timesUp"].firstMatch
        XCTAssertTrue(timesUp.waitForExistence(timeout: 6),
                      "TIME'S UP should appear when the clock reaches zero")
        attach(app, named: "04-buzzed")

        XCTAssertEqual(primary.label, "NEXT", "After the buzzer the button should read NEXT")

        // Next deals a fresh category and restarts the clock.
        primary.tap()
        XCTAssertTrue(primary.waitForExistence(timeout: 3))

        let changed = expectation(for: NSPredicate(format: "label != %@", firstCategory),
                                  evaluatedWith: category)
        wait(for: [changed], timeout: 5)

        attach(app, named: "05-next-round")
    }

    // MARK: - Stopping early

    func testStopEndsRoundEarlyWithoutBuzzing() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        app.descendants(matching: .any)["game.vibe-five"].firstMatch.tap()

        let primary = app.buttons["vibeFive.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), "Primary button should exist")
        waitForLabel(primary, "START")

        primary.tap()

        let category = app.descendants(matching: .any)["vibeFive.category"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 3), "Start should reveal a category")

        // Second press starts the clock; the button then offers to end it.
        primary.tap()
        waitForLabel(primary, "Done!")
        attach(app, named: "07-running-with-done")

        primary.tap()

        let stopped = app.descendants(matching: .any)["vibeFive.stopped"].firstMatch
        XCTAssertTrue(stopped.waitForExistence(timeout: 3),
                      "Stopping should be acknowledged on the card")
        waitForLabel(primary, "NEXT")

        // A manual stop is not a time-out.
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.timesUp"].exists,
                       "Stopping early must not show TIME'S UP")
        attach(app, named: "08-stopped")

        // Outlast the original five seconds: the clock must be cancelled,
        // not merely paused.
        Thread.sleep(forTimeInterval: 5.5)
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.timesUp"].exists,
                       "The clock should be cancelled, not paused")

        // Next deals a fresh category, which again waits to be started.
        primary.tap()
        waitForLabel(primary, "START")
        XCTAssertTrue(category.waitForExistence(timeout: 3))
    }

    // MARK: - Manual clock start

    func testClockOnlyStartsOnASecondStart() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        app.descendants(matching: .any)["game.vibe-five"].firstMatch.tap()

        let primary = app.buttons["vibeFive.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), "Primary button should exist")
        waitForLabel(primary, "START")

        primary.tap()

        // The category appears straight away...
        let category = app.descendants(matching: .any)["vibeFive.category"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 3),
                      "Category should appear on the first press")

        // ...with a GET READY badge and no dial at all.
        let badge = app.descendants(matching: .any)["vibeFive.getReady"].firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 2), "A GET READY badge should be shown")
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.ring"].exists,
                       "The dial must not be shown before the clock starts")
        waitForLabel(primary, "START")
        attach(app, named: "09-revealed")

        // Wait longer than a whole round would take: nothing may start itself,
        // so the table can talk for as long as it likes.
        Thread.sleep(forTimeInterval: 6.0)
        XCTAssertTrue(badge.exists, "The clock must not start on its own")
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.ring"].exists,
                       "The dial must still be hidden after waiting")
        XCTAssertFalse(app.descendants(matching: .any)["vibeFive.timesUp"].exists,
                       "No round may have run while the clock sat idle")

        // The second press is what starts the clock.
        primary.tap()
        waitForLabel(primary, "Done!")
        XCTAssertFalse(badge.exists, "GET READY should clear once the clock starts")
        XCTAssertTrue(app.descendants(matching: .any)["vibeFive.ring"].waitForExistence(timeout: 3),
                      "The dial should appear once the clock starts")
        attach(app, named: "10-clock-after-manual-start")
    }

    // MARK: - Settings

    func testSettingsSheetOpensAndTogglesAPack() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        app.descendants(matching: .any)["game.vibe-five"].firstMatch.tap()

        let settings = app.buttons["vibeFive.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "Settings button should exist")
        settings.tap()

        XCTAssertTrue(app.staticTexts["Game Setup"].waitForExistence(timeout: 5),
                      "Settings sheet should open")

        let summary = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "categories ·"))
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Deck summary should be shown")
        let before = summary.label

        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Animals & Nature"))
            .firstMatch
            .tap()

        let changed = expectation(for: NSPredicate(format: "label != %@", before),
                                  evaluatedWith: summary)
        wait(for: [changed], timeout: 5)

        attach(app, named: "06-settings")
    }

    // MARK: - Helpers

    /// Waits for a control's label to become `label`, so assertions do not race
    /// the SwiftUI update.
    private func waitForLabel(_ element: XCUIElement,
                              _ label: String,
                              timeout: TimeInterval = 5,
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        let matched = expectation(for: NSPredicate(format: "label == %@", label),
                                  evaluatedWith: element)
        let result = XCTWaiter().wait(for: [matched], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "Expected label \"\(label)\" but saw \"\(element.label)\"",
                       file: file, line: line)
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
