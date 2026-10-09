import XCTest
import UIKit
@testable import VibeGames

/// The instructions show two worked examples. If either were wrong the page
/// would be teaching the wrong rule, which is worse than teaching nothing — so
/// both are checked against the engine rather than trusted.
final class TrioInstructionTests: XCTestCase {

    func testTheWorkedTrioIsActuallyATrio() {
        let trio = TrioInstructionsView.trioExample
        XCTAssertEqual(trio.count, 3)
        XCTAssertTrue(TrioDeck.isTrio(trio[0], trio[1], trio[2]),
                      "the page labels this one a trio")
    }

    /// It should show *both* halves of the rule: some features the same on all
    /// three, some different on all three. An all-different example would leave
    /// half the rule unillustrated.
    func testTheWorkedTrioShowsBothHalvesOfTheRule() {
        let trio = TrioInstructionsView.trioExample
        func same<T: Hashable>(_ key: (TrioCard) -> T) -> Bool {
            Set(trio.map(key)).count == 1
        }
        let sames = [same(\.base), same(\.cheese), same(\.meat), same(\.garnish)]
        XCTAssertTrue(sames.contains(true), "nothing is the same on all three")
        XCTAssertTrue(sames.contains(false), "nothing is different on all three")
    }

    func testTheNearMissIsNotATrio() {
        let miss = TrioInstructionsView.notATrioExample
        XCTAssertEqual(miss.count, 3)
        XCTAssertFalse(TrioDeck.isTrio(miss[0], miss[1], miss[2]),
                       "the page labels this one as not a trio")
    }

    /// The page calls out the meat as the feature that breaks it, so exactly
    /// that one feature has to be the two-against-one.
    func testTheNearMissFailsOnTheMeatAlone() {
        let miss = TrioInstructionsView.notATrioExample
        XCTAssertEqual(miss[0].meat, miss[1].meat, "two of them should agree")
        XCTAssertNotEqual(miss[0].meat, miss[2].meat, "and the third should not")

        let others: [(String, [String])] = [
            ("platter", miss.map(\.base.slug)),
            ("cheese", miss.map(\.cheese.slug)),
            ("garnish", miss.map(\.garnish.slug)),
        ]
        for (name, values) in others {
            let distinct = Set(values).count
            XCTAssertTrue(distinct == 1 || distinct == 3,
                          "\(name) is neither all the same nor all different, so the "
                          + "meat is not the only thing wrong with this example")
        }
    }

    func testEveryExampleCardHasArtwork() {
        for card in TrioInstructionsView.trioExample + TrioInstructionsView.notATrioExample {
            XCTAssertNotNil(UIImage(named: card.artworkName),
                            "no artwork for \(card.artworkName)")
        }
    }
}
