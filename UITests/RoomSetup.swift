import XCTest

/// Doing what the second player does, from the test process.
///
/// XCUITest drives one device, so a two-player moment is staged by writing the
/// one fact the other player would have written — a win recorded in the room.
/// That is the same write the app and the browser client make when they solve
/// the word or the grid, and the rest of what is under test is the real client
/// reading the real room.
enum RoomSetup {

    /// `Game code TRAM PUFF` is the badge's label; the room is `tram-puff`.
    static func code(from label: String) -> String? {
        let words = label.split(whereSeparator: { !$0.isLetter })
        guard words.count >= 2 else { return nil }
        return words.suffix(2).joined(separator: "-").lowercased()
    }

    /// Records a win in a room nobody has won yet.
    ///
    /// `path` is the game's node: `games` for Word Vibe, `sudoku` for Number
    /// Vibe. The rules refuse a second claim, so this must come before the app's
    /// own solve.
    static func writeWinner(path: String, room: String, name: String) -> Bool {
        let url = URL(string: "https://vibe-words-party-default-rtdb.firebaseio.com"
                      + "/\(path)/\(room)/winner.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "name": name,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ])

        let finished = DispatchSemaphore(value: 0)
        var accepted = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            accepted = (response as? HTTPURLResponse)?.statusCode == 200
            finished.signal()
        }.resume()
        _ = finished.wait(timeout: .now() + 15)
        return accepted
    }
}
