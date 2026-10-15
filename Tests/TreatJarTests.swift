import StoreKit
import XCTest
@testable import VibeGames

/// The tip jar's behaviour, without a store to talk to.
///
/// `TreatStore` exists so this can be true: StoreKit's `Product` cannot be made
/// in a test, but "the price came back", "they changed their mind" and "the
/// receipt could not be checked" can all be said in a fake. What is left over —
/// the twenty lines of `AppStoreTreat` — is exercised by the UI test that
/// actually buys one, and by tapping it in the simulator.
@MainActor
final class TreatJarTests: XCTestCase {

    /// A store that says whatever the test wants it to.
    private final class FakeStore: TreatStore, @unchecked Sendable {
        var treat: Treat?
        var outcome: TreatOutcome = .bought
        var loadError: Error?
        var buyError: Error?
        private(set) var buys = 0

        init(treat: Treat? = Treat(price: "$2.99")) {
            self.treat = treat
        }

        func treat() async throws -> Treat? {
            if let loadError { throw loadError }
            return treat
        }

        func buy() async throws -> TreatOutcome {
            buys += 1
            if let buyError { throw buyError }
            return outcome
        }
    }

    private struct Boom: Error {}

    func testItShowsThePriceTheStoreGivesIt() async {
        let jar = TreatJar(store: FakeStore(treat: Treat(price: "£2.49")))
        await jar.load()
        XCTAssertEqual(jar.state, .ready("£2.49"),
                       "the price is the store's, formatted for the storefront, "
                       + "so nothing here has a currency or a number in it")
    }

    func testNothingToSellMeansNothingIsShown() async {
        let jar = TreatJar(store: FakeStore(treat: nil))
        await jar.load()
        XCTAssertEqual(jar.state, .unavailable,
                       "before the product exists in App Store Connect the row is "
                       + "hidden, rather than shown broken")
    }

    func testAStoreThatWillNotAnswerIsAlsoNothingToShow() async {
        let store = FakeStore()
        store.loadError = Boom()
        let jar = TreatJar(store: store)
        await jar.load()
        XCTAssertEqual(jar.state, .unavailable)
    }

    func testBuyingSaysThankYou() async {
        let store = FakeStore()
        let jar = TreatJar(store: store)
        await jar.load()
        await jar.buy()
        XCTAssertEqual(jar.state, .thanked)
        XCTAssertEqual(store.buys, 1)
    }

    func testChangingTheirMindLeavesThePriceOnScreen() async {
        for outcome in [TreatOutcome.cancelled, .pending] {
            let store = FakeStore()
            store.outcome = outcome
            let jar = TreatJar(store: store)
            await jar.load()
            await jar.buy()
            XCTAssertEqual(jar.state, .ready("$2.99"),
                           "\(outcome): the row comes back rather than vanishing, "
                           + "because most people who cancel still meant well")
        }
    }

    func testAFailedPurchaseDoesNotClaimToHaveWorked() async {
        let store = FakeStore()
        store.buyError = Boom()
        let jar = TreatJar(store: store)
        await jar.load()
        await jar.buy()
        XCTAssertEqual(jar.state, .ready("$2.99"),
                       "a purchase that threw is not a thank-you")
    }

    func testItCannotBeBoughtBeforeItHasLoaded() async {
        let store = FakeStore()
        let jar = TreatJar(store: store)
        await jar.buy()
        XCTAssertEqual(store.buys, 0, "there is no row to tap before there is a price")
        XCTAssertEqual(jar.state, .loading)
    }

    /// The product id is the join between three things that have to agree: the
    /// code, the StoreKit configuration used in testing, and App Store Connect.
    /// Nothing else in the app would notice two of them drifting apart.
    func testTheProductIDMatchesTheOneTheStoreSells() throws {
        XCTAssertEqual(AppStoreTreat.productID, "party.vibegames.VibeGames.tip")

        let config = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // the repository root
            .appendingPathComponent("VibeGames.storekit")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any]
        let products = json?["products"] as? [[String: Any]]
        XCTAssertEqual(products?.first?["productID"] as? String, AppStoreTreat.productID,
                       "VibeGames.storekit sells a different product from the one "
                       + "the app asks for, so nothing would ever load in testing")
        XCTAssertEqual(products?.first?["type"] as? String, "Consumable",
                       "a tip has to be consumable: a non-consumable one can only "
                       + "be given once")
    }
}
