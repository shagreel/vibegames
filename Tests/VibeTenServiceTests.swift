import XCTest
@testable import VibeGames

/// A room shares a board, not a game.
///
/// Every player deals the same 162 digits from one seed and then takes their own
/// pairs on their own device. If the room recorded takes, one player's move would
/// vanish from everybody else's board and the scores would stop meaning anything;
/// these tests pin the fact that it does not.
///
/// The database is real, because half of the guarantee is in the rules: a client
/// cannot write a take into the room even if a future client tried to.
@MainActor
final class VibeTenServiceTests: XCTestCase {

    private let database = "https://vibe-words-party-default-rtdb.firebaseio.com"

    func testARoomHoldsTheSeedAndTheScoresAndNothingElse() async throws {
        let service = VibeTenService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 777,
                                     columns: 9,
                                     rows: 18,
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)
        try await service.recordScore(gameID: room,
                                      playerID: PlayerIdentity.id,
                                      score: 4,
                                      finishedAt: Date())

        let contents = try await read("ten/\(room)")
        XCTAssertEqual(Set(contents.keys), ["meta", "players", "scores"],
                       "a room is a seed, who is here, and the scores — not a board")

        let meta = try await read("ten/\(room)/meta")
        XCTAssertEqual(meta["columns"] as? Int, 9, "the room remembers the shape it was made with")
        XCTAssertEqual(meta["rows"] as? Int, 18)

        // Nobody's pairs are in the room to be replayed.
        let taken = try await read("ten/\(room)/taken")
        XCTAssertTrue(taken.isEmpty, "there is no record of which pairs were taken")
    }

    func testAClientCannotWriteTakesIntoTheRoom() async throws {
        let service = VibeTenService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 778,
                                     columns: 6,
                                     rows: 12,
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)

        let meta = try await read("ten/\(room)/meta")
        XCTAssertEqual(meta["columns"] as? Int, 6, "a smaller room is a smaller room")
        XCTAssertEqual(meta["rows"] as? Int, 12)

        let status = try await put("ten/\(room)/taken/0", ["by": PlayerIdentity.id, "value": 1])
        XCTAssertNotEqual(status, 200, "the rules should refuse a take")
        XCTAssertTrue((400...403).contains(status), "expected a refusal, got \(status)")

        // And a shape that is not one of the four is refused, so a room cannot
        // be made with a board no client can draw.
        let bad = try await put("ten/\(room)/meta/columns", ["value": 12])
        XCTAssertNotEqual(bad, 200, "twelve columns is not a board this game has")
    }

    /// The shape is in the room, so a joiner deals the host's board. Rooms made
    /// before the choice existed have no shape and read as the full board.
    func testASnapshotCarriesTheRoomsShape() {
        let full = VibeTenSnapshot(meta: ["seed": 1, "creator": "Alex"], players: nil, scores: nil)
        XCTAssertEqual(full.columns, 9)
        XCTAssertEqual(full.rows, 18)

        let small = VibeTenSnapshot(meta: ["seed": 1, "creator": "Alex",
                                           "columns": 6, "rows": 12],
                                    players: nil, scores: nil)
        XCTAssertEqual(small.columns, 6, "a room remembers the shape it was made with")
        XCTAssertEqual(small.rows, 12)

        let nonsense = VibeTenSnapshot(meta: ["seed": 1, "columns": 12, "rows": 3],
                                       players: nil, scores: nil)
        XCTAssertEqual(nonsense.columns, 9, "a shape that is not a board is not played")
        XCTAssertEqual(nonsense.rows, 18)
    }

    // MARK: - Reading and writing

    private func read(_ path: String) async throws -> [String: Any] {
        let url = URL(string: "\(database)/\(path).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:] as [String: Any]
    }

    private func put(_ path: String, _ value: [String: Any]) async throws -> Int {
        var request = URLRequest(url: URL(string: "\(database)/\(path).json")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: value)
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
