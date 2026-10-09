import XCTest
import UIKit
@testable import VibeGames

/// The card faces are drawn per combination and shipped as files, so the thing
/// that can go wrong is a name falling out of step with the artwork: a card that
/// renders blank because no such image is in the bundle.
///
/// These check the names against what is actually there, for all 81.
final class TrioArtworkTests: XCTestCase {

    private let deck = TrioDeck.all

    func testDeckIsEightyOneDistinctCards() {
        XCTAssertEqual(deck.count, 81, "3 platters x 3 cheeses x 3 meats x 3 garnishes")
        XCTAssertEqual(Set(deck.map(\.id)).count, 81, "ids must be unique")
        XCTAssertEqual(Set(deck.map(\.imageName)).count, 81, "two cards share a picture")
    }

    /// The one that matters: every card resolves to a real image.
    func testEveryCardHasArtworkInTheBundle() {
        for card in deck {
            let image = UIImage(named: card.artworkName)
            XCTAssertNotNil(image, "no artwork for \(card.spokenDescription) — \(card.imageName)")
            XCTAssertEqual(image?.size.width, 900, "\(card.imageName) is the wrong size")
        }
    }

    /// The artwork is numbered card-01 upward, so the number in the file name is
    /// the card's index plus one. If the two ever disagree the deck order and the
    /// pictures would quietly diverge.
    func testTheArtworkNumbersRunInDeckOrder() {
        for (index, card) in deck.enumerated() {
            let number = String(format: "%02d", index + 1)
            XCTAssertTrue(card.imageName.hasPrefix("card-\(number)_"),
                          "card \(index) is \(card.imageName), expected card-\(number)")
        }
    }

    func testNoSpokenDescriptionIsUsedTwice() {
        let spoken = deck.map(\.spokenDescription)
        XCTAssertEqual(Set(spoken).count, 81, "two cards read out the same")
    }
}
