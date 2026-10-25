import XCTest
@testable import VibeGames

/// A board picked back up has its rows already scored, so its tiles are born
/// face-up — otherwise the words guessed are on the board but turned away, which
/// is what the owner saw: the keyboard remembered the letters, the rows did not.
final class WordsResumeRevealTests: XCTestCase {

    func testAScoredTileStartsFaceUp() {
        XCTAssertTrue(VibeWordsTileReveal.startsFaceUp(feedback: .correct))
        XCTAssertTrue(VibeWordsTileReveal.startsFaceUp(feedback: .present))
        XCTAssertTrue(VibeWordsTileReveal.startsFaceUp(feedback: .absent))
    }

    func testAnUnscoredTileStillTurnsOverWhenItIsPlayed() {
        XCTAssertFalse(VibeWordsTileReveal.startsFaceUp(feedback: nil),
                       "a tile with no score is dealt face-down and flips on the guess")
    }
}
