import XCTest

/// Screenshots of Vibe Blurt for the landing page.
///
/// Four people cannot be simulated on one phone, so the room is assembled by
/// writing it straight into the database. The app creates the game itself —
/// which is how it gets a player id and a code — and the test then fills the
/// other three seats, deals the teams, and sets the turn to whatever is being
/// photographed. Whoever the app is meant to be is stated outright rather than
/// left to the shuffle, because a screenshot run that sometimes catches the
/// wrong screen is worse than no screenshots.
///
/// Like the other back-end tests it skips itself when the database cannot be
/// reached, so a checkout without a network still gets a green suite.
final class VibeBlurtScreenshots: XCTestCase {

    private let database = "https://vibe-words-party-default-rtdb.firebaseio.com"

    /// A seed whose first word is "Rainbow", and whose next few are Lion, Mouse
    /// and Dolphin. Normally the room's seed is random; pinning it here is only
    /// so the screenshots show a word worth reading.
    private let seed = 52

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLightAppearance() throws {
        try capture(appearance: "light")
    }

    func testDarkAppearance() throws {
        try capture(appearance: "dark")
    }

    // MARK: - The run

    private func capture(appearance: String) throws {
        try skipUnlessTheDatabaseAnswers()

        let app = XCUIApplication()
        app.launchArguments += ["-vibegames.appearance", appearance]
        app.launch(withName: "Sam")

        app.descendants(matching: .any)["game.vibe-blurt"].firstMatch.tap()
        let create = app.buttons["blurt.createGame"]
        XCTAssertTrue(create.waitForExistence(timeout: 15), "the lobby should offer a game")
        create.tap()

        // The code, read out of the room the app just made.
        let codeLabel = app.descendants(matching: .any)["blurt.gameCode"]
        if !codeLabel.waitForExistence(timeout: 25) {
            // Say what was actually on screen rather than just that the code was
            // not: this failed once and the log gave nothing to go on.
            attach(app, named: "\(appearance)-blurt-no-code")
            return XCTFail("the room never showed a code. On screen: "
                           + String(app.debugDescription.prefix(3000)))
        }
        let code = codeLabel.label.components(separatedBy: " ").last?.lowercased() ?? ""
        // Two four-letter words: the shape a code has to have to be sayable.
        XCTAssertEqual(code.split(separator: "-").map(\.count), [4, 4],
                       "unexpected code: \(codeLabel.label)")
        attach(app, named: "\(appearance)-blurt-lobby")

        // Who the app is, as far as this room is concerned. Reading the roster
        // back is the only way to learn its short id.
        // The write that registers the player happens just after the one that
        // makes the room, so give it a moment rather than racing it.
        var me: String?
        var lastSeen = "nothing"
        for _ in 0..<10 {
            let (status, roster) = request("GET", "\(code)/players")
            if status == 200, let players = roster as? [String: Any], let first = players.keys.first {
                me = first
                break
            }
            lastSeen = "HTTP \(status) \(String(describing: roster))"
            Thread.sleep(forTimeInterval: 1)
        }
        guard let me else {
            return XCTFail("the app never registered in its own room — last read: \(lastSeen)")
        }

        for (index, name) in ["Alex", "Jo", "Robin"].enumerated() {
            request("PUT", "\(code)/players/ffff00\(index)", body: name)
        }
        request("PUT", "\(code)/meta/seed", body: seed)
        request("PUT", "\(code)/meta/started", body: true)
        request("PUT", "\(code)/teams", body: [me: 1, "ffff000": 1, "ffff001": 2, "ffff002": 2])

        // 1. The app is the one holding the word.
        writeTurn(code: code, team: 1, describer: me, word: 0)
        let word = app.descendants(matching: .any)["blurt.word"]
        XCTAssertTrue(word.waitForExistence(timeout: 20), "the describer should be given a word")
        attach(app, named: "\(appearance)-blurt-word")

        // 2. The app is on the team holding the word, but somebody else has it:
        //    the team-mate who is guessing.
        writeTurn(code: code, team: 1, describer: "ffff000", word: 1)
        let guessing = app.descendants(matching: .any)["blurt.guessing"]
        XCTAssertTrue(guessing.waitForExistence(timeout: 20), "a team-mate should be told to guess")
        attach(app, named: "\(appearance)-blurt-guessing")

        // 3. The app is on the other team, watching for it — the screen with the
        //    red button, which is the one worth showing.
        writeTurn(code: code, team: 2, describer: "ffff001", word: 3)
        let buzz = app.buttons["blurt.buzz"]
        XCTAssertTrue(buzz.waitForExistence(timeout: 20), "the other team should get the button")
        attach(app, named: "\(appearance)-blurt-buzz")
    }

    private func writeTurn(code: String, team: Int, describer: String, word: Int) {
        let now = Int(Date().timeIntervalSince1970 * 1000)
        request("PUT", "\(code)/play", body: [
            "round": 0,
            "turn": team == 1 ? 0 : 1,
            "team": team,
            "describer": describer,
            "word": word,
            "state": "running",
            "one": 0,
            "two": 0,
            "finished": false,
            "startedAt": now,
            "endsAt": now + 45_000,
        ])
    }

    // MARK: - Talking to the database

    /// The rules let anyone read and write a room, which is what makes this
    /// possible from a test process at all.
    @discardableResult
    private func request(_ method: String, _ path: String, body: Any? = nil) -> (Int, Any?) {
        guard let url = URL(string: "\(database)/blurt/\(path).json") else { return (0, nil) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // A name, a seed and a boolean are all written on their own, and
            // JSONSerialization refuses a bare scalar without being told.
            request.httpBody = try? JSONSerialization.data(withJSONObject: body,
                                                           options: .fragmentsAllowed)
        }

        var status = 0
        var payload: Any?
        let finished = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let data { payload = try? JSONSerialization.jsonObject(with: data) }
            finished.signal()
        }.resume()
        _ = finished.wait(timeout: .now() + 15)
        return (status, payload)
    }

    private func skipUnlessTheDatabaseAnswers() throws {
        // A game id nobody will ever use. The rules grant read per room, not on
        // `blurt` itself, so asking for the whole tree comes back 401 — which
        // looked exactly like being offline and skipped both runs.
        guard let url = URL(string: "\(database)/blurt/zzreachabilityprobe.json") else {
            throw XCTSkip("no database to photograph")
        }
        var reachable = false
        let finished = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { _, response, _ in
            reachable = (response as? HTTPURLResponse)?.statusCode == 200
            finished.signal()
        }.resume()
        _ = finished.wait(timeout: .now() + 10)
        try XCTSkipUnless(reachable, "the database is not reachable")
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
