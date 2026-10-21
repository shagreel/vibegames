import XCTest
@testable import VibeGames

/// Leaving has to come off the roster, in every game.
///
/// Presence is otherwise only cleared by `onDisconnect`, which fires when the
/// phone dies or the signal goes — not when somebody taps back. So a room used
/// to keep counting a player who had walked out of it. These talk to the real
/// database, because "the roster says two" is a fact about the rules as much as
/// the client, and they skip themselves when Firebase is not configured.
///
/// Rooms are left behind for the nightly prune rather than deleted: the rules do
/// not let a client remove a room.
@MainActor
final class PresenceTests: XCTestCase {

    // MARK: - Each game

    func testWordVibeTakesAPlayerOffTheRosterOnLeave() async throws {
        let service = VibeWordsService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     word: "CRANE",
                                     creatorName: "Leaver",
                                     playerID: PlayerIdentity.id)
        let onRoster = try await roster(in: "games/\(room)")
        XCTAssertEqual(onRoster, 1, "the host starts on the roster")

        service.removePresence(gameID: room, playerID: PlayerIdentity.id)
        let left = try await waitForRoster(in: "games/\(room)", toBe: 0)
        XCTAssertEqual(left, 0,
                       "leaving takes the host off the roster")
    }

    func testNumberVibeTakesAPlayerOffTheRosterOnLeave() async throws {
        let service = VibeSudokuService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 12345,
                                     difficulty: .medium,
                                     creatorName: "Leaver",
                                     playerID: PlayerIdentity.id)
        let onRoster = try await roster(in: "sudoku/\(room)")
        XCTAssertEqual(onRoster, 1, "the host starts on the roster")

        service.removePresence(gameID: room, playerID: PlayerIdentity.id)
        let left = try await waitForRoster(in: "sudoku/\(room)", toBe: 0)
        XCTAssertEqual(left, 0,
                       "leaving takes the host off the roster")
    }

    func testVibePairingsTakesAPlayerOffTheRosterOnLeave() async throws {
        let service = VibeTrioService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 12345,
                                     creatorName: "Leaver",
                                     playerID: PlayerIdentity.id)
        let onRoster = try await roster(in: "trio/\(room)")
        XCTAssertEqual(onRoster, 1, "the host starts on the roster")

        service.removePresence(gameID: room, playerID: PlayerIdentity.id)
        let left = try await waitForRoster(in: "trio/\(room)", toBe: 0)
        XCTAssertEqual(left, 0,
                       "leaving takes the host off the roster")
    }

    func testSimilarVibeTakesAPlayerOffTheRosterOnLeave() async throws {
        let service = VibeBlurtService.shared
        try XCTSkipUnless(service.isAvailable, "needs a configured Firebase project")

        let room = GameCode.make()
        try await service.createGame(gameID: room,
                                     seed: 12345,
                                     creatorName: "Leaver",
                                     playerID: PlayerIdentity.id,
                                     packs: Set(BlurtPack.allCases))
        let onRoster = try await roster(in: "blurt/\(room)")
        XCTAssertEqual(onRoster, 1, "the host starts on the roster")

        service.removePresence(gameID: room, playerID: PlayerIdentity.id)
        let left = try await waitForRoster(in: "blurt/\(room)", toBe: 0)
        XCTAssertEqual(left, 0,
                       "leaving takes the host off the roster")
    }

    // MARK: - Reading the roster

    private func waitForRoster(in path: String, toBe expected: Int,
                               timeout: TimeInterval = 10) async throws -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var count = -1
        while Date() < deadline {
            count = try await roster(in: path)
            if count == expected { return count }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        return count
    }

    private func roster(in path: String) async throws -> Int {
        let url = URL(string: "https://vibe-words-party-default-rtdb.firebaseio.com"
                      + "/\(path)/players.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard !data.isEmpty, data != Data("null".utf8) else { return 0 }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 0 }
        return json.count
    }
}
