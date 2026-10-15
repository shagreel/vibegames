import XCTest
@testable import VibeGames

/// The app sells nothing, points at nothing purchasable, and — since the row that
/// opened the ways-to-help page was removed — does not open the page that carries
/// the payment link either. It names the website in plain text and stops there.
///
/// `Tools/check_app_no_payments.py` scans the whole of `Sources/` for a way to
/// pay *and* for a link to that page; this pins the one URL the app does open,
/// which no scan can know is the right one.
final class SupportTests: XCTestCase {

    func testSharingSendsPeopleToTheBrowserVersion() {
        XCTAssertEqual(Support.playURL.absoluteString, "https://play.vibegames.party",
                       "the browser version moved, or the link was mistyped")
    }

    /// What the app says instead of linking: the website, by name, for somebody
    /// to go and look at themselves.
    func testTheWebsiteIsNamedRatherThanOpened() {
        XCTAssertEqual(Support.site, "vibegames.party",
                       "the panel and the hub both name this, and nothing links it")
    }

    /// The panel is the app's own words about helping, and Apple reads the panel.
    func testThePanelCopyNamesNoWayToPay() {
        let copy = (Support.heading + " " + Support.blurb).lowercased()
        for marker in ["venmo", "@chill", "paypal", "cash.app", "buy us a treat"] {
            XCTAssertFalse(copy.contains(marker),
                           "the panel mentions \(marker), which is a way to pay in all "
                           + "but name — that belongs on the website")
        }
        XCTAssertTrue(copy.contains("free"),
                      "the panel should still say the games are free")
    }
}
