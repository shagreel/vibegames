import XCTest
@testable import VibeGames

/// Vibe Five's deck memory.
///
/// A fresh shuffle of the whole pool repeats, and repeats are the thing people
/// notice: with one pack switched on, ten prompts twice shares one every game or
/// so. The deck now leaves out everything already dealt and only starts over
/// once the pool is genuinely used up.
@MainActor
final class VibeFiveDeckTests: XCTestCase {

    private let seenKey = "vibefive.seen"
    private let packsKey = "vibefive.packs"

    override func setUp() {
        super.setUp()
        // A leftover set from another test or a real run would make these
        // assertions mean something else.
        UserDefaults.standard.removeObject(forKey: seenKey)
        UserDefaults.standard.removeObject(forKey: packsKey)
    }

    /// One pack only, so the pool is small enough for exhaustion to be reachable
    /// inside a test.
    private func modelOnFoodOnly() -> VibeFiveModel {
        let model = VibeFiveModel()
        for pack in CategoryPack.allCases where pack != .food {
            model.togglePack(pack)
        }
        return model
    }

    /// Reveals `count` prompts, one per round, and names them.
    private func deal(_ model: VibeFiveModel, _ count: Int) -> [String] {
        (0..<count).map { _ in
            model.primaryAction()
            let id = model.category?.id ?? ""
            model.resetToReady()
            return id
        }
    }

    func testASecondGameDoesNotDealTheFirstOnesPrompts() {
        let model = modelOnFoodOnly()

        let first = deal(model, 12)
        XCTAssertEqual(first.count, Set(first).count, "a prompt came round twice inside one game")

        model.restartSession()
        let second = deal(model, 12)

        XCTAssertEqual(Set(first).intersection(second), [],
                       "the second game dealt a prompt the first one had already used")
    }

    func testThePromptsComeBackOnceThePoolIsUsedUp() {
        let model = modelOnFoodOnly()
        let size = CategoryLibrary.categories(in: [.food]).count
        XCTAssertGreaterThan(size, 4, "the pack under test should be worth testing")

        let firstTimeRound = Set(deal(model, size))

        model.restartSession()
        let afterExhaustion = deal(model, 3)

        XCTAssertEqual(afterExhaustion.count, 3)
        XCTAssertFalse(afterExhaustion.contains(""), "an empty pool must not deal a blank card")
        XCTAssertTrue(afterExhaustion.allSatisfy(firstTimeRound.contains),
                      "an exhausted pool should start again from the same prompts")
    }
}
