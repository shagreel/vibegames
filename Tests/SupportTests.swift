import XCTest
@testable import VibeGames

/// The app sells nothing: no in-app purchase, no tip jar, no link to a website
/// page that carries one. `Tools/check_app_no_payments.py` scans the whole of
/// `Sources/` for the markers; this covers the words on the panel, which a scan
/// cannot read as copy, and the one URL the app does open, which no scan can
/// know is the right one.
final class SupportTests: XCTestCase {

    func testSharingSendsPeopleToTheBrowserVersion() {
        XCTAssertEqual(Support.playURL.absoluteString, "https://play.vibegames.party",
                       "the browser version moved, or the link was mistyped")
    }

    /// The panel is the app's own words about helping, and Apple reads the panel.
    func testThePanelCopyNamesNoWayToPay() {
        let copy = (Support.heading + " " + Support.blurb).lowercased()
        for marker in ["venmo", "@chill", "paypal", "cash.app", "ko-fi", "buy us a treat"] {
            XCTAssertFalse(copy.contains(marker),
                           "the panel mentions \(marker), which is a way to pay in all "
                           + "but name — that belongs on the website")
        }
        XCTAssertTrue(copy.contains("free"),
                      "the panel should still say the games are free")
    }
}
