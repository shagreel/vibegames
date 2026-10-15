import StoreKit
import StoreKitTest
import XCTest
@testable import VibeGames

/// The StoreKit half: the twenty lines that talk to Apple.
///
/// Everything else about the tip is tested without a store, because StoreKit's
/// types cannot be made in a test. These cannot: the question here is whether the
/// app asks for the right product and deals with what comes back, and the only
/// honest way to ask it is to put a store in front of it.
///
/// `SKTestSession` is meant to be that store. It reads `VibeGames.storekit` out
/// of this test bundle and answers as the App Store would — same product ids,
/// same purchase results, same Ask to Buy — with no App Store Connect account and
/// nobody to tap a sheet.
///
/// **It does not answer here.** On this machine the session reports `notEntitled`
/// for any purchase and an empty storefront, which is the simulator's StoreKit
/// sandbox rather than anything in the app: it needs the app signed with the
/// in-app purchase entitlement, and these test builds are signed for a simulator
/// with nothing at all. So the tests below **skip themselves** when the store has
/// nothing to sell, the way the back-end tests skip when the database cannot be
/// reached — the alternative is a red suite that means "this laptop", which is
/// worse than no test.
///
/// What that leaves unverified is `AppStoreTreat`'s twenty lines, and it is worth
/// being clear about it: the purchase path is proven in sandbox and TestFlight
/// once the product exists in App Store Connect, and nowhere before. Everything
/// around it — the price the panel shows, what happens when somebody cancels, the
/// thank-you, the failure to load — is tested without a store in `TreatJarTests`.
final class TreatStoreTests: XCTestCase {

    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "VibeGames")
        session.resetToDefaultState()
        session.clearTransactions()
        // Nobody is here to tap "Confirm": the session buys what it is asked to.
        session.disableDialogs = true

        // The probe. A store that cannot sell is not a failing app.
        let products = try await Product.products(for: [AppStoreTreat.productID])
        try XCTSkipIf(products.isEmpty, """
            the local store has nothing to sell here — StoreKit testing needs the \
            app signed with the in-app purchase entitlement, which simulator test \
            builds are not
            """)
    }

    override func tearDown() {
        session.clearTransactions()
        session = nil
    }

    func testTheProductLoadsAndIsPricedByTheStore() async throws {
        let treat = try await AppStoreTreat().treat()
        let price = try XCTUnwrap(treat?.price, "the store should sell the treat")
        XCTAssertTrue(price.contains("2.99"),
                      "the price comes from the store, formatted for its storefront "
                      + "— got: \(price)")
    }

    /// The whole purchase, through the same call the button makes.
    func testBuyingOneReturnsBoughtAndGrantsNothing() async throws {
        let outcome = try await AppStoreTreat().buy()
        XCTAssertEqual(outcome, .bought)

        // A tip unlocks nothing, so there is nothing to be entitled to. This is
        // the guideline as much as it is the behaviour: the moment a purchase
        // leaves something behind, it stops being a tip.
        var entitlements: [String] = []
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                entitlements.append(transaction.productID)
            }
        }
        XCTAssertTrue(entitlements.isEmpty,
                      "a consumable tip should leave no entitlement, got: \(entitlements)")
    }

    /// A tip can be given twice. A non-consumable one could only ever be given
    /// once, which is why the product type is part of the test in `TreatJarTests`.
    func testItCanBeGivenMoreThanOnce() async throws {
        let store = AppStoreTreat()
        let first = try await store.buy()
        let second = try await store.buy()
        XCTAssertEqual(first, .bought)
        XCTAssertEqual(second, .bought,
                       "the second treat should be as buyable as the first")
    }

    /// Ask to Buy: the sheet is not dismissed, it is put off, and the app has to
    /// tell the difference rather than saying thank you for money that has not
    /// been paid.
    func testAPendingPurchaseIsNotAThankYou() async throws {
        session.askToBuyEnabled = true
        let outcome = try await AppStoreTreat().buy()
        XCTAssertEqual(outcome, .pending)
    }

    func testAStoreWithNothingInItSellsNothing() async throws {
        session.clearTransactions()
        session.failTransactionsEnabled = true
        session.failureError = .unknown

        // A failing store is a store that throws, and the model above turns that
        // into "show nothing" rather than "show a button that does not work".
        let store = AppStoreTreat()
        do {
            _ = try await store.buy()
            XCTFail("a store set to fail should not report a purchase")
        } catch {
            // The throw is the point: `TreatJar` catches it and reloads.
        }
    }
}
