import XCTest
@testable import VibeGames

/// The same contract as the word game's: the room is the only place the other
/// players can learn about a finished board, so the write has to land, and the
/// first one has to keep it.
///
/// It talks to the real database, because "the win is on record" is a fact about
/// the rules as much as the client, and it skips itself when Firebase is not
/// configured. The room is left behind for the nightly prune: the rules do not
/// let a client remove a room.
@MainActor
final class SudokuServiceTests: XCTestCase {

    func testAWinsIsRecordedAndTheFirstOneStands() async throws {
        let service = VibeSudokuService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 4242,
                                     difficulty: .easy,
                                     creatorName: "Tester",
                                     playerID: PlayerIdentity.id)

        try await service.recordWinnerIfAbsent(gameID: room, name: "Tester")

        let recorded = try await readWinner(room)
        XCTAssertEqual(recorded?["name"] as? String, "Tester",
                       "the room should record the player who finished the board")
        XCTAssertNotNil(recorded?["timestamp"] as? NSNumber, "and carry when it happened")

        // A second claim, from a slower board, changes nothing.
        try? await service.recordWinnerIfAbsent(gameID: room, name: "Second")
        let stillFirst = try await readWinner(room)
        XCTAssertEqual(stillFirst?["name"] as? String, "Tester", "the first finished board keeps it")
    }

    private func readWinner(_ room: String) async throws -> [String: Any]? {
        let url = URL(string: "https://vibe-words-party-default-rtdb.firebaseio.com"
                      + "/sudoku/\(room)/winner.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard !data.isEmpty,
              let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
                as? [String: Any]
        else { return nil }
        return json
    }
}
