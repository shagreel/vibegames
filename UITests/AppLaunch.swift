import XCTest

extension XCUIApplication {

    /// Launches with a player name already stored, so the first-run prompt is
    /// not sitting over the hub in tests that are about something else.
    ///
    /// The name goes in as a launch argument, which lands in `UserDefaults`'
    /// argument domain and so wins over anything an earlier run left behind —
    /// the same trick `-vibegames.appearance` already uses. Pass `nil` for the
    /// tests that are about naming, and drive the prompt yourself.
    func launch(withName name: String? = "Tester") {
        if let name {
            launchArguments += ["-vibegames.playerName", name]
        }
        launch()
    }
}
