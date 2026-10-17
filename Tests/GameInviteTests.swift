import XCTest
@testable import VibeGames

/// The invitation sent from a shared game.
///
/// It carries a link into the browser version, so the words and the address have
/// to agree with what the website actually serves — a path that is right on the
/// phone and wrong in the link is a person clicking a 404.
final class GameInviteTests: XCTestCase {

    /// `web/src/App.tsx` routes exactly these. Changing one without the other is
    /// the mistake this test is for.
    private let routes: [(game: AppAnalytics.Game, path: String)] = [
        (.five, "five"),
        (.words, "words"),
        (.sudoku, "sudoku"),
        (.trio, "trio"),
        (.blurt, "blurt"),
    ]

    func testEveryGameUsesTheRouteTheWebsiteServes() {
        for (game, path) in routes {
            XCTAssertEqual(GameInvite.path(for: game), path, "\(game.title) should live at /\(path)")
        }
    }

    func testTheInviteCarriesTheRoomAsALinkAndACode() {
        let text = GameInvite.text(game: .trio, code: "tram-puff")

        XCTAssertTrue(text.contains("https://play.vibegames.party/trio?game=tram-puff"),
                      "the link should open the game with the room in it — got: \(text)")
        XCTAssertTrue(text.contains("TRAM PUFF"),
                      "and the code should still be there for anybody using the app — got: \(text)")
    }

    /// The link is the point: `?game=` is how the browser joins, and the two
    /// words are how a person joins from the app.
    func testEveryGamesLinkOpensItsOwnRoom() {
        for (game, path) in routes {
            XCTAssertEqual(GameInvite.link(game: game, code: "tram-puff"),
                           "https://play.vibegames.party/\(path)?game=tram-puff")
        }
    }
}
