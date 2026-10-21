import XCTest
@testable import VibeGames

/// The one thing a shared game has to get right at the end: a win is recorded
/// against the player who solved it, and everybody else can read it.
///
/// This talks to the real database, the way the app does — the rules are the
/// half of the contract the client cannot check for itself. It skips itself when
/// Firebase is not configured, so a checkout without the config file stays green,
/// and it leaves its room behind for the nightly prune rather than deleting it
/// (the rules do not allow a client to remove a room).
@MainActor
final class WordVibeServiceTests: XCTestCase {

    func testAWinsIsRecordedAgainstThePlayerWhoSolvedIt() async throws {
        let service = VibeWordsService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        let name = "Tester"
        try await service.createGame(gameID: room,
                                     word: "CRANE",
                                     creatorName: name,
                                     playerID: PlayerIdentity.id)

        try await service.recordWinnerIfAbsent(gameID: room, name: name)

        let winner = try await readWinner(room)
        XCTAssertEqual(winner?["name"] as? String, name,
                       "the win should be recorded against the player who solved it")
        XCTAssertNotNil(winner?["timestamp"] as? NSNumber, "and carry when it happened")
    }

    /// First one home keeps it: a second claim, however it arrives, changes
    /// nothing.
    func testTheFirstWinStands() async throws {
        let service = VibeWordsService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     word: "CRANE",
                                     creatorName: "First",
                                     playerID: PlayerIdentity.id)
        try await service.recordWinnerIfAbsent(gameID: room, name: "First")

        // Somebody else solves the same word a moment later. The rules refuse
        // it; the client must not treat that as an error to surface.
        try? await service.recordWinnerIfAbsent(gameID: room, name: "Second")

        let winner = try await readWinner(room)
        XCTAssertEqual(winner?["name"] as? String, "First", "the first home keeps the win")
    }

    private func readWinner(_ room: String) async throws -> [String: Any]? {
        let url = URL(string: "https://vibe-words-party-default-rtdb.firebaseio.com"
                      + "/games/\(room)/winner.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard !data.isEmpty, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}
