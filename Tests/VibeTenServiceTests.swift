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
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)
        try await service.recordScore(gameID: room,
                                      playerID: PlayerIdentity.id,
                                      score: 4,
                                      finishedAt: Date())

        let contents = try await read("ten/\(room)")
        XCTAssertEqual(Set(contents.keys), ["meta", "players", "scores"],
                       "a room is a seed, who is here, and the scores — not a board")

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
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)

        let status = try await put("ten/\(room)/taken/0", ["by": PlayerIdentity.id, "value": 1])
        XCTAssertNotEqual(status, 200, "the rules should refuse a take")
        XCTAssertTrue((400...403).contains(status), "expected a refusal, got \(status)")
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
