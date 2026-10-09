import XCTest

/// Appearance is chosen in Preferences on the hub, so that is where these check
/// it. The per-game screens are covered by their own suites, which can be run
/// with the simulator switched to either appearance to inspect the result.
final class AppearanceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHubRendersInLightAppearance() throws {
        let app = try hubRunning(appearance: "light")
        attach(app, named: "40-light-hub")
        try assertPreferencesShow(app, appearance: "Light")
    }

    func testHubRendersInDarkAppearance() throws {
        let app = try hubRunning(appearance: "dark")
        attach(app, named: "44-dark-hub")
        try assertPreferencesShow(app, appearance: "Dark")
    }

    /// Launches with the appearance forced through the same argument the app
    /// reads, then waits for the hub.
    private func hubRunning(appearance: String) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-vibegames.appearance", appearance]
        // A name that reads as a person: these two shots end up on the landing
        // page, where "Tester" would look like exactly what it is.
        app.launch(withName: "Sam")

        let preferences = app.buttons["hub.preferences"]
        XCTAssertTrue(preferences.waitForExistence(timeout: 15), "Hub should load")
        return app
    }

    /// The override is in effect when the preferences screen agrees with it.
    private func assertPreferencesShow(_ app: XCUIApplication, appearance: String) throws {
        app.buttons["hub.preferences"].tap()

        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Preferences should open")

        let segment = picker.buttons[appearance]
        XCTAssertTrue(segment.exists, "\(appearance) should be on offer — got \(picker.debugDescription)")
        XCTAssertTrue(segment.isSelected, "the \(appearance.lowercased()) override should be in effect")
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
