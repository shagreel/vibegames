import Foundation
import StoreKit

/// The tip jar, and the one thing in this app that can be bought.
///
/// **Why this is an in-app purchase rather than a link.** Apple allows an app to
/// sell a tip to its developer, but only through in-app purchase; a link out to
/// PayPal or Venmo for the same thing is what guideline 3.1.1 forbids, and a
/// *charitable* donation — the one case that may use the web — has to go to a
/// verified non-profit. So this is a consumable product, priced in App Store
/// Connect, sold by Apple, with Apple's commission on it. The website keeps the
/// Venmo route for people playing in a browser, where Apple has no say.
///
/// The rules a tip jar has to keep, all of which this one does:
///
///   * It buys **nothing**. No feature, no content, no removal of an advert,
///     because there are no adverts. `Support.blurb` says so in as many words.
///   * It is **consumable**, so it can be given more than once — a non-consumable
///     tip is a tip somebody can only give once.
///   * The price comes from the store, never from the app. `displayPrice` is
///     already formatted for the person's own storefront, which is why nothing
///     here has a currency or a number in it.
///
/// The panel hides the row entirely when the product cannot be loaded — in a
/// checkout with no StoreKit configuration, or before the product exists in App
/// Store Connect. A button that cannot do anything is worse than no button.

/// What the store knows, in terms this app owns.
///
/// `Product` is StoreKit's, and cannot be made in a test; this can. The model
/// below is therefore about the *behaviour* — asking, buying, being thanked —
/// and all of it is testable without a store.
struct Treat: Equatable {
    /// Formatted for the storefront, e.g. "$2.99".
    let price: String
}

/// What happened when somebody tried to buy one.
enum TreatOutcome: Equatable {
    case bought
    /// Dismissed the sheet.
    case cancelled
    /// Ask to Buy: a parent has to approve it, and it arrives later.
    case pending
}

protocol TreatStore: Sendable {
    /// The tip, or nil when there is nothing to sell.
    func treat() async throws -> Treat?
    func buy() async throws -> TreatOutcome
}

/// The real one.
struct AppStoreTreat: TreatStore {
    /// Must match the product in App Store Connect, and the one in
    /// `VibeGames.storekit` used for testing.
    static let productID = "party.vibegames.VibeGames.tip"

    private func product() async throws -> Product? {
        try await Product.products(for: [Self.productID]).first
    }

    func treat() async throws -> Treat? {
        guard let product = try await product() else { return nil }
        return Treat(price: product.displayPrice)
    }

    func buy() async throws -> TreatOutcome {
        guard let product = try await product() else { return .cancelled }

        switch try await product.purchase() {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Finishing is what tells StoreKit the tip has been dealt with.
                // A consumable that is not finished comes back on every launch.
                await transaction.finish()
                return .bought
            case .unverified:
                // The receipt could not be checked. There was never anything to
                // grant, and the money has already changed hands, so the honest
                // thing is to finish it — leaving it open would mean StoreKit
                // re-delivering it forever — and to say thank you rather than to
                // explain a receipt to somebody who just gave us money.
                return .bought
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// Tips that arrive outside a purchase: Ask to Buy approving later, or a
    /// purchase interrupted before it finished. Called once, at launch.
    static func finishOutstanding() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }
}

/// What the panel shows, and what happens when somebody taps.
@MainActor
final class TreatJar: ObservableObject {

    enum State: Equatable {
        /// Asking the store. Nothing is shown yet: a row that appears, jumps to
        /// a price and settles is worse than one that arrives when it knows.
        case loading
        case ready(String)
        /// The sheet is up, or the purchase is being settled.
        case buying
        case thanked
        /// Nothing to sell: no product configured, or no store to ask. The row
        /// is hidden rather than shown broken.
        case unavailable
    }

    @Published private(set) var state: State = .loading

    private let store: TreatStore

    init(store: TreatStore = AppStoreTreat()) {
        self.store = store
    }

    func load() async {
        guard state == .loading else { return }
        do {
            guard let treat = try await store.treat() else {
                state = .unavailable
                return
            }
            state = .ready(treat.price)
        } catch {
            state = .unavailable
        }
    }

    func buy() async {
        guard case .ready = state else { return }
        state = .buying
        do {
            switch try await store.buy() {
            case .bought:
                state = .thanked
                AppAnalytics.treatBought()
            case .cancelled:
                await reload()
            case .pending:
                // Ask to Buy: nothing to say yet, and the price is still the
                // right thing to show if they come back.
                await reload()
            }
        } catch {
            await reload()
        }
    }

    /// Back to whatever the store says now, rather than assuming.
    private func reload() async {
        state = .loading
        await load()
    }
}
