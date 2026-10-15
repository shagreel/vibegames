import XCTest
@testable import VibeGames

/// The app sells exactly one thing — a tip — and Apple sells it. Nothing here
/// points at any other way to pay: no Venmo, no website page carrying one.
///
/// `Tools/check_app_no_payments.py` scans the whole of `Sources/` for those
/// markers; this covers the words on the panel, which a scan cannot read as copy,
/// and the one URL the app does open, which no scan can know is the right one.
final class SupportTests: XCTestCase {

    func testSharingSendsPeopleToTheBrowserVersion() {
        XCTAssertEqual(Support.playURL.absoluteString, "https://play.vibegames.party",
                       "the browser version moved, or the link was mistyped")
    }

    /// The blurb is where the app explains what the treat is, and Apple reads it:
    /// a tip that quietly unlocked something would be a purchase wearing a tip's
    /// clothes, and the copy is what says it does not.
    func testThePanelSaysTheTreatUnlocksNothing() {
        let copy = Support.blurb.lowercased()
        XCTAssertTrue(copy.contains("gift"),
                      "the panel should call it a gift, plainly")
        XCTAssertTrue(copy.contains("does not unlock anything"),
                      "and say that it buys nothing, which is what makes a tip jar "
                      + "a tip jar rather than a way round in-app purchase")
    }

    /// The panel is the app's own words about helping, and Apple reads the panel.
    func testThePanelCopyNamesNoWayToPay() {
        let copy = (Support.heading + " " + Support.blurb).lowercased()
        for marker in ["venmo", "@chill", "paypal", "cash.app", "ko-fi"] {
            XCTAssertFalse(copy.contains(marker),
                           "the panel mentions \(marker), which is a way to pay in all "
                           + "but name — that belongs on the website")
        }
        XCTAssertTrue(copy.contains("free"),
                      "the panel should still say the games are free")
    }
}
