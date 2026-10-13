import XCTest
@testable import VibeGames

/// The code that shares a game.
///
/// It is read out loud and typed in by somebody who only heard it, so what
/// matters is that it is sayable and that a mistyped one still lands in the
/// right room. Both of those are easy to break by accident and invisible until
/// somebody cannot join.
final class GameCodeTests: XCTestCase {

    func testACodeIsTwoFourLetterWords() {
        for _ in 0..<200 {
            let code = GameCode.make()
            let parts = code.split(separator: "-", omittingEmptySubsequences: false)

            XCTAssertEqual(parts.count, 2, "Unexpected code: \(code)")
            XCTAssertEqual(parts[0].count, 4, "Unexpected code: \(code)")
            XCTAssertEqual(parts[1].count, 4, "Unexpected code: \(code)")
            XCTAssertTrue(code.allSatisfy { $0.isLetter || $0 == "-" }, "Unexpected code: \(code)")
            XCTAssertEqual(code, code.lowercased(), "A code is lowercase everywhere")
        }
    }

    func testEveryWordComesFromTheList() {
        let words = Set(GameCodeWords.all)
        for _ in 0..<200 {
            for part in GameCode.make().split(separator: "-") {
                XCTAssertTrue(words.contains(String(part)), "\(part) is not a word from the list")
            }
        }
    }

    func testTheTwoWordsAreNeverTheSame() {
        // "dock-dock" reads like a mistake when it is said aloud.
        for _ in 0..<400 {
            let parts = GameCode.make().split(separator: "-")
            XCTAssertNotEqual(parts[0], parts[1])
        }
    }

    func testTheWordListIsWorthDrawingFrom() {
        let words = GameCodeWords.all
        XCTAssertGreaterThanOrEqual(words.count, 200, "too few words to make a code from")
        XCTAssertEqual(Set(words).count, words.count, "a duplicate word")
        for word in words {
            // Read out loud and typed back in: anything but four plain lowercase
            // letters is a code somebody cannot share.
            XCTAssertEqual(word.count, 4, word)
            XCTAssertTrue(word.allSatisfy { $0.isASCII && $0.isLowercase && $0.isLetter }, word)
        }
    }

    func testTheCodeSpaceIsBigEnoughToShareIn() {
        // Counted, not sampled. Collisions are what this is really about — two
        // rooms landing on the same name — but a sample cannot answer it: 500
        // codes drawn from 57,360 expect 2.2 collisions by the birthday problem
        // and see six or more about 2% of the time, so "no collisions in 500
        // draws" is a coin toss rather than a property. The size of the space
        // is the part that can be checked.
        let words = GameCodeWords.all.count
        XCTAssertGreaterThanOrEqual(words * (words - 1), 40_000)
    }

    func testCodesAreSpreadAcrossTheWordList() {
        // What a collision count was reaching for: a generator that has quietly
        // collapsed onto a handful of words. 200 draws from 240 words land on
        // about 136 distinct first words; 100 is far below that and still out of
        // reach for a generator stuck on a small pool.
        let firstWords = Set((0..<200).map { _ in String(GameCode.make().prefix(4)) })
        XCTAssertGreaterThan(firstWords.count, 100)
    }

    // MARK: - What somebody typed

    func testACodeSurvivesTheRoundTrip() {
        for _ in 0..<100 {
            let code = GameCode.make()
            XCTAssertEqual(GameCode.normalise(code), code)
        }
    }

    func testTheWaysPeopleActuallyTypeIt() {
        // Heard across a room, typed from memory: capitals, a stray space, the
        // hyphen forgotten, the whole thing pasted with whitespace round it.
        let wanted = "cars-feed"
        for typed in ["cars-feed", "CARS-FEED", "Cars-Feed", "carsfeed", "CARSFEED",
                      "cars feed", "cars_feed", " cars-feed ", "cars-feed.", "cars–feed"] {
            XCTAssertEqual(GameCode.normalise(typed), wanted, "typed as \(typed.debugDescription)")
        }
    }

    func testACodeFromBeforeTheWordsChangedIsLeftAlone() {
        // Digits are not stripped, so an old code still names the room it named.
        // Nobody has to care, but a code that silently became a different one
        // would be worse than one that does not resolve.
        XCTAssertEqual(GameCode.normalise("abc12345"), "abc12345")
        XCTAssertEqual(GameCode.normalise("ab12cd34"), "ab12cd34")
    }

    func testNonsenseBecomesEmptyRatherThanSomethingElse() {
        // Every game refuses an empty code, so rubbish must not turn into a
        // plausible room.
        for typed in ["", "   ", "!!!", "-", "--", "🙂", "a"] {
            let cleaned = GameCode.normalise(typed)
            XCTAssertTrue(cleaned.isEmpty || cleaned.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" },
                          "\(typed.debugDescription) became \(cleaned.debugDescription)")
        }
        XCTAssertEqual(GameCode.normalise("!!!"), "")
    }

    func testTheDisplayPutsASpaceBetweenTheWords() {
        // The space is a reading aid: it is what stops `carsfeed` reading as one
        // long noise, and it is why somebody who hears the code can hold it in
        // their head long enough to type it. It is not part of the code, and
        // typing it is optional — but it is what the screen shows, because the
        // code is read out loud.
        XCTAssertEqual(GameCode.display("cars-feed"), "CARS FEED")
        XCTAssertEqual(GameCode.display("dock-time"), "DOCK TIME")

        // Harmless on a code that never had one, and on the older numeric codes,
        // because the display is applied to whatever the room happens to hold.
        XCTAssertEqual(GameCode.display("CARS FEED"), "CARS FEED")
        XCTAssertEqual(GameCode.display("carsfeed"), "CARSFEED")
        XCTAssertEqual(GameCode.display("abc12345"), "ABC12345")
        XCTAssertEqual(GameCode.display(""), "")
    }

    func testWhatIsDisplayedCanBeTypedStraightBack() {
        // Whatever the screen shows has to work when it is typed in as it
        // appears. The space and the hyphen are both dropped on the way in, so
        // the separator is genuinely optional rather than something to get right.
        for code in ["cars-feed", "dock-time", "game-code"] {
            XCTAssertEqual(GameCode.normalise(GameCode.display(code)), code,
                           "\(GameCode.display(code)) did not resolve back to \(code)")
        }
    }

    func testTheDisplayedCodeIsTwoWordsOfFourLetters() {
        // Checked over fresh codes rather than examples, so it holds for whatever
        // `make` starts returning.
        for _ in 0..<200 {
            let shown = GameCode.display(GameCode.make())
            let words = shown.split(separator: " ", omittingEmptySubsequences: false)
            XCTAssertEqual(words.count, 2, "\(shown) is not two words")
            XCTAssertTrue(words.allSatisfy { $0.count == 4 }, "\(shown) is not four and four")
            XCTAssertTrue(shown.allSatisfy { $0.isLetter || $0 == " " },
                          "\(shown) is not letters and a space")
            XCTAssertFalse(shown.contains("-"), "\(shown) still shows the hyphen")
        }
    }
}
