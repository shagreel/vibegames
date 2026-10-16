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

/// How long a wait may take when the answer has to come back through the live
/// database.
///
/// The shared-game tests talk to a real Firebase project, and a round trip that
/// is usually a few hundred milliseconds can take far longer when the machine is
/// busy — running a browser end-to-end script at the same time is enough to do
/// it. Ten seconds was enough most runs, which is the worst kind of timeout: the
/// failures look like bugs in the game rather than a busy laptop, and they pass
/// again the moment they are run on their own.
let backendTimeout: TimeInterval = 40

/// The database key for a code, from the code as it is *displayed*.
///
/// The display puts a space between the words: the separator is a reading aid,
/// and it is not part of the code, so typing it is optional. The room in the
/// database keeps a hyphen, though, so a test that reads the code off the screen
/// and then talks to the database has to put that back. This is
/// `GameCode.normalise` cut down to what a UI test needs — the app's own type is
/// not reachable from here, because a UI test runs out of process.
func roomKey(for displayed: String) -> String {
    let cleaned = displayed.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    // Eight letters and no hyphen is the only shape the display produces.
    guard cleaned.count == 8, cleaned.allSatisfy(\.isLetter) else { return cleaned }
    let middle = cleaned.index(cleaned.startIndex, offsetBy: 4)
    return "\(cleaned[..<middle])-\(cleaned[middle...])"
}

/// The code itself, out of an accessibility label that also introduces it.
///
/// The labels read "CODE CARS FEED" and "Game code CARS FEED", and the display is
/// always two words a space apart — so the last two tokens are the code and
/// everything before them is the screen talking about it. Splitting on the space
/// and taking the last token stopped working the moment the display started
/// showing both words, and it failed by handing back `FEED`.
func displayedCode(in label: String) -> String {
    label.split(separator: " ").suffix(2).joined(separator: " ")
}

/// Fails with the label that was actually on screen, which is the only thing
/// worth knowing when a code does not look like a code.
func assertLooksLikeADisplayedCode(_ displayed: String, label: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
    // Two four-letter words, a space apart: the shape a code has to have to be
    // sayable across a room. The space separates them for reading; it is not
    // part of the code, which is why the hyphen never appears here.
    XCTAssertEqual(displayed.split(separator: " ").map(\.count), [4, 4],
                   "unexpected code: \(label)", file: file, line: line)
    XCTAssertFalse(displayed.contains("-"),
                   "the hyphen is a database detail, not something to show: \(label)",
                   file: file, line: line)
    XCTAssertTrue(displayed.replacingOccurrences(of: " ", with: "").allSatisfy(\.isLetter),
                  "a code is two words, so letters and a space: \(label)", file: file, line: line)
}

/// Gets the first-run name prompt out of the way.
///
/// A test that launches without a name has this sitting over the hub, and every
/// one of them was writing the same three lines to dismiss it.
func dismissNamePromptIfPresent(_ app: XCUIApplication) {
    let skip = app.buttons["firstRun.nameSkip"]
    if skip.waitForExistence(timeout: 3) { skip.tap() }
}

/// Types over whatever is in a text field.
///
/// An empty field reports its placeholder as its value, so the placeholder is
/// not a name to delete.
func replaceText(in field: XCUIElement, with text: String) {
    field.tap()
    let existing = (field.value as? String) ?? ""
    if !existing.isEmpty, existing != "Your name" {
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                              count: existing.count + 4))
    }
    field.typeText(text)
}
