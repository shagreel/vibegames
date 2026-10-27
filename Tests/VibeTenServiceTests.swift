import XCTest
@testable import VibeGames

/// A room shares a board, not a game.
///
/// Every player deals the same digits from one seed and then takes their own
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
                                     rows: 18,
                                     rowsPerAdd: 2,
                                     wrapRows: true,
                                     mode: .dim,
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)
        try await service.recordScore(gameID: room,
                                      playerID: PlayerIdentity.id,
                                      score: 4,
                                      finishedAt: Date(),
                                      clearedAt: Date())

        let contents = try await read("ten/\(room)")
        XCTAssertEqual(Set(contents.keys), ["meta", "players", "scores"],
                       "a room is a seed, who is here, and the scores — not a board")

        let meta = try await read("ten/\(room)/meta")
        XCTAssertEqual(meta["rows"] as? Int, 18, "the room remembers the rows it was made with")
        XCTAssertEqual(meta["wrap"] as? Bool, true,
                       "and whether the rows join, because it changes the way through")
        XCTAssertEqual(meta["mode"] as? String, "dim",
                       "and how a pair leaves the board, because a room is played one way")
        XCTAssertEqual(meta["rowsPerAdd"] as? Int, 2,
                       "and how many rows a press reveals, since everybody can grow the board")
        XCTAssertNil(meta["columns"], "the columns are always nine, so they are not a setting")
        XCTAssertNil(meta["difficulty"], "there are no levels any more")

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
                                     rows: 12,
                                     rowsPerAdd: 2,
                                     wrapRows: false,
                                     mode: .remove,
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)

        let meta = try await read("ten/\(room)/meta")
        XCTAssertEqual(meta["rows"] as? Int, 12, "a shorter room is a shorter room")

        let status = try await put("ten/\(room)/taken/0", ["by": PlayerIdentity.id, "value": 1])
        XCTAssertNotEqual(status, 200, "the rules should refuse a take")
        XCTAssertTrue((400...403).contains(status), "expected a refusal, got \(status)")

        // And a row count that is not on offer is refused, so a room cannot be
        // made with a board no client can draw.
        let badRows = try await put("ten/\(room)/meta/rows", ["value": 5])
        XCTAssertNotEqual(badRows, 200, "five rows is not a board this game has")

        // The rules are fixed when the room is made: a joiner cannot turn the
        // join on, or change the way pairs leave the board, for everybody.
        let changedWrap = try await put("ten/\(room)/meta/wrap", ["value": true])
        XCTAssertNotEqual(changedWrap, 200, "the host's rules are the room's rules")
        let changedMode = try await put("ten/\(room)/meta/mode", ["value": "dim"])
        XCTAssertNotEqual(changedMode, 200, "and they are decided once")
        let changedPress = try await put("ten/\(room)/meta/rowsPerAdd", ["value": 4])
        XCTAssertNotEqual(changedPress, 200, "nor can a joiner change how many rows a press adds")
    }

    /// A clear is a fact about the round, and it is never taken away by a later
    /// score update: the first one is the winner.
    func testAClearIsWrittenAndKept() async throws {
        let service = VibeTenService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 779,
                                     rows: 18,
                                     rowsPerAdd: 2,
                                     wrapRows: false,
                                     mode: .remove,
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)

        let clearedAt = Date()
        try await service.recordScore(gameID: room,
                                      playerID: PlayerIdentity.id,
                                      score: 40,
                                      finishedAt: clearedAt,
                                      clearedAt: clearedAt)
        let score = try await read("ten/\(room)/scores/\(PlayerIdentity.id)")
        XCTAssertEqual(score["clearedAt"] as? Int64 ?? (score["clearedAt"] as? Int).map(Int64.init),
                       Int64(clearedAt.timeIntervalSince1970 * 1000),
                       "the clear is in the room and it is the time it happened")

        // A later report of the same round does not take the win away.
        try await service.recordScore(gameID: room,
                                      playerID: PlayerIdentity.id,
                                      score: 41,
                                      finishedAt: nil,
                                      clearedAt: nil)
        let after = try await read("ten/\(room)/scores/\(PlayerIdentity.id)")
        XCTAssertNotNil(after["clearedAt"], "the clear survives an update without one")
    }

    /// The rows, the join and the pair mode are in the room too, so every device
    /// plays the same game. Rooms made before they existed read as full, off and
    /// remove.
    func testASnapshotCarriesTheRoomsRules() {
        let plain = VibeTenSnapshot(meta: ["seed": 1], players: nil, scores: nil)
        XCTAssertEqual(plain.rows, VibeTenBoard.defaultStartRows)
        XCTAssertFalse(plain.wrapRows, "the rows do not join unless the host says so")
        XCTAssertEqual(plain.mode, .remove, "and a room without a mode removes")

        let joined = VibeTenSnapshot(meta: ["seed": 1, "rows": 12, "rowsPerAdd": 4,
                                            "wrap": true, "mode": "dim"],
                                     players: nil, scores: nil)
        XCTAssertEqual(joined.rows, 12)
        XCTAssertEqual(joined.rowsPerAdd, 4)

        // A room made when a press could be one, two or three rows still plays:
        // anything but two or four reads as the smallest press.
        let oldRoom = VibeTenSnapshot(meta: ["seed": 1, "rowsPerAdd": 3],
                                      players: nil, scores: nil)
        XCTAssertEqual(oldRoom.rowsPerAdd, 2)
        XCTAssertTrue(joined.wrapRows)
        XCTAssertEqual(joined.mode, .dim)

        let nonsense = VibeTenSnapshot(meta: ["seed": 1, "rows": 3, "mode": "vanish",
                                              "columns": 6, "difficulty": "hard"],
                                       players: nil, scores: nil)
        XCTAssertEqual(nonsense.rows, VibeTenBoard.defaultStartRows,
                       "a row count that is not a board is not played")
        XCTAssertEqual(nonsense.mode, .remove, "a mode that does not exist is remove")
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
