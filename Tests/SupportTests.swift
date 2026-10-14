import XCTest
@testable import VibeGames

/// The app sells nothing and points at nothing purchasable, so the few things it
/// does point at are worth pinning down by hand: where the games are played, and
/// where the page about helping lives.
///
/// `Tools/check_app_no_payments.py` scans the whole of `Sources/` for a way to
/// pay; this covers the two URLs, which no scan can know are the right ones.
final class SupportTests: XCTestCase {

    func testSharingSendsPeopleToTheBrowserVersion() {
        XCTAssertEqual(Support.playURL.absoluteString, "https://play.vibegames.party",
                       "the browser version moved, or the link was mistyped")
    }

    /// The page the app opens instead of offering a way to pay. It has to be the
    /// website — that is the entire reason it exists — and it has to be a page
    /// that is actually there, so it is spelled out in one place.
    func testTheWaysToHelpPageIsOnTheWebsite() {
        let url = Support.waysToHelpURL
        XCTAssertEqual(url.scheme, "https", "the page must open over a secure connection")
        XCTAssertEqual(url.host, "vibegames.party",
                       "the app must not point at the browser version for this: the "
                       + "website can carry a way to pay and the app cannot")
        XCTAssertEqual(url.path, "/ways-to-help",
                       "which is served from site/ways-to-help.html")
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
