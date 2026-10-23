import XCTest

/// The hub's utility drawer, end to end: one button on the hub, a list of tools,
/// and the dice bag behind it.
final class UtilitiesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheHubOpensTheUtilitiesAndTheDiceAreThere() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")

        let utilities = app.descendants(matching: .any)["hub.utilities"].firstMatch
        XCTAssertTrue(utilities.waitForExistence(timeout: 15),
                      "The hub should offer the utilities")
        attach(app, named: "40-hub-utilities")
        utilities.tap()

        let dice = app.descendants(matching: .any)["utility.dice"].firstMatch
        XCTAssertTrue(dice.waitForExistence(timeout: 5),
                      "The utilities screen should list dice")
        attach(app, named: "41-utilities-list")
        dice.tap()

        for sides in [4, 6, 8, 10, 12, 20] {
            XCTAssertTrue(app.buttons["dice.add.\(sides)"].waitForExistence(timeout: 3),
                          "A d\(sides) should be on offer")
        }
        XCTAssertTrue(app.buttons["dice.roll"].exists, "There should be a roll button")
        XCTAssertTrue(app.buttons["dice.clear"].exists, "and a clear button")
        attach(app, named: "42-dice-empty")
    }

    /// The three things the bag is for: add the dice you have, roll them again,
    /// sweep the table.
    func testAddingRollingAndClearingTheDice() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openDice(app)

        app.buttons["dice.add.4"].tap()
        app.buttons["dice.add.4"].tap()
        app.buttons["dice.add.8"].tap()

        XCTAssertEqual(dieCount(app), 3, "three taps should put three dice on the table")
        XCTAssertEqual(dieLabels(app).map(sidesOf).sorted(), ["d4", "d4", "d8"],
                       "each tap puts the die that was tapped on the table")
        Thread.sleep(forTimeInterval: 0.6)
        attach(app, named: "43-dice-three")

        // Rolling rerolls those same dice: same number of them, same sides.
        let before = dieLabels(app)
        app.buttons["dice.roll"].tap()
        Thread.sleep(forTimeInterval: 0.18)
        attach(app, named: "43b-dice-rolling")
        Thread.sleep(forTimeInterval: 1.2)
        attach(app, named: "43c-dice-settled")
        let after = dieLabels(app)
        XCTAssertEqual(dieCount(app), 3, "rolling must not deal new dice")
        XCTAssertEqual(after.map(sidesOf).sorted(), before.map(sidesOf).sorted(),
                       "and they keep their sides — a d4 stays a d4")

        // Every value reads inside its own die.
        for label in after {
            let parts = label.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let sides = Int(parts[0].dropFirst()),
                  let value = Int(parts[1]) else {
                return XCTFail("Unexpected die label: \(label)")
            }
            XCTAssertTrue((1...sides).contains(value), "\(label) is out of range")
        }

        app.buttons["dice.clear"].tap()
        XCTAssertEqual(dieCount(app), 0, "clear should take every die off the table")
        XCTAssertTrue(app.descendants(matching: .any)["dice.empty"].exists,
                      "and the empty table says so")
        attach(app, named: "44-dice-cleared")
    }

    /// Every die in the bag, on the table at once. The shapes are drawn from
    /// real solids, so this is the check that each one comes out as the die it is
    /// — and that each shows the number it rolled.
    func testEveryDieInTheBagRenders() throws {
        let app = XCUIApplication()
        app.launch(withName: "Tester")
        openDice(app)

        for sides in [4, 6, 8, 10, 12, 20] {
            app.buttons["dice.add.\(sides)"].tap()
        }

        XCTAssertEqual(dieCount(app), 6, "all six dice should be on the table")
        let labels = dieLabels(app)
        XCTAssertEqual(labels.map(sidesOf).sorted(),
                       ["d10", "d12", "d20", "d4", "d6", "d8"],
                       "each die keeps the sides it was tapped with")

        for label in labels {
            let parts = label.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let sides = Int(parts[0].dropFirst()),
                  let value = Int(parts[1]) else {
                return XCTFail("Unexpected die label: \(label)")
            }
            XCTAssertTrue((1...sides).contains(value), "\(label) is out of range")
        }
        Thread.sleep(forTimeInterval: 6.0)
        attach(app, named: "45-dice-every-kind")
    }

    // MARK: - Helpers

    private func openDice(_ app: XCUIApplication) {
        let utilities = app.descendants(matching: .any)["hub.utilities"].firstMatch
        XCTAssertTrue(utilities.waitForExistence(timeout: 15))
        utilities.tap()

        let dice = app.descendants(matching: .any)["utility.dice"].firstMatch
        XCTAssertTrue(dice.waitForExistence(timeout: 5))
        dice.tap()

        XCTAssertTrue(app.buttons["dice.add.4"].waitForExistence(timeout: 5),
                      "The dice screen should appear")
    }

    /// One element per die, labelled "d12: 7".
    private func dieLabels(_ app: XCUIApplication) -> [String] {
        app.descendants(matching: .any)
            .matching(identifier: "dice.die")
            .allElementsBoundByIndex
            .map(\.label)
    }

    private func dieCount(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any).matching(identifier: "dice.die").count
    }

    /// "d4: 3" is a d4.
    private func sidesOf(_ label: String) -> String {
        label.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? label
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
