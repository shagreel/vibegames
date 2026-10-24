import XCTest
@testable import VibeGames

/// The First Player decider: the bank of questions, and the draw that pairs one
/// with the seat that starts.
final class FirstPlayerTests: XCTestCase {

    /// A generator that replays a fixed list, so a draw is the same draw twice.
    private struct ScriptedGenerator: RandomNumberGenerator {
        private var values: [UInt64]
        private var index = 0

        init(_ values: [UInt64]) {
            self.values = values
        }

        mutating func next() -> UInt64 {
            defer { index += 1 }
            return values[index % values.count]
        }
    }

    func testEveryQuestionIsAskingSomethingOnePersonCanAnswer() {
        XCTAssertGreaterThanOrEqual(FirstPlayer.questions.count, 24,
                                    "one question is not a decider, and ten is a short one")
        XCTAssertEqual(Set(FirstPlayer.questions).count, FirstPlayer.questions.count,
                       "the same question twice is a decider that repeats itself")

        for question in FirstPlayer.questions {
            XCTAssertTrue(question.hasPrefix("Who ") || question.hasPrefix("Whose "),
                          "not a question about a person: \(question)")
            XCTAssertTrue(question.hasSuffix("?"), "does not read as a question: \(question)")
            XCTAssertFalse(question.contains(" or "),
                           "two answers cannot resolve to one person: \(question)")
            XCTAssertLessThanOrEqual(question.count, 60, "too long to read out: \(question)")
        }
    }

    func testTheThreeSeatsSayWhichDirectionToGo() {
        XCTAssertEqual(FirstPlayer.Seat.allCases.count, 3)
        XCTAssertTrue(FirstPlayer.Seat.them.instruction.contains("goes first"))
        for seat in FirstPlayer.Seat.allCases {
            XCTAssertTrue(seat.instruction.hasSuffix("goes first"),
                          "\(seat.rawValue) should end with who starts")
        }
        XCTAssertTrue(FirstPlayer.Seat.left.instruction.contains("left"))
        XCTAssertTrue(FirstPlayer.Seat.right.instruction.contains("right"))
        XCTAssertFalse(FirstPlayer.Seat.them.instruction.contains("left"))
        XCTAssertFalse(FirstPlayer.Seat.them.instruction.contains("right"))
    }

    func testADrawAlwaysPicksAQuestionFromTheBankAndASeat() {
        var generator = SystemRandomNumberGenerator()
        var seenQuestions = Set<String>()
        var seenSeats = Set<FirstPlayer.Seat>()

        for _ in 0..<400 {
            let draw = FirstPlayer.draw(using: &generator)
            XCTAssertTrue(FirstPlayer.questions.contains(draw.question),
                          "drew something that is not in the bank: \(draw.question)")
            seenQuestions.insert(draw.question)
            seenSeats.insert(draw.seat)
        }

        XCTAssertEqual(seenSeats, Set(FirstPlayer.Seat.allCases),
                       "every seat should come up")
        XCTAssertGreaterThan(seenQuestions.count, FirstPlayer.questions.count / 2,
                             "a decider that keeps picking the same question is not deciding")
    }

    func testItNeverAsksTheSameQuestionTwiceRunning() {
        var generator = SystemRandomNumberGenerator()
        var thisTurn = FirstPlayer.draw(using: &generator)

        for _ in 0..<500 {
            let nextTurn = FirstPlayer.draw(avoiding: thisTurn, using: &generator)
            XCTAssertNotEqual(nextTurn.question, thisTurn.question,
                              "the table would think the decider had not worked")
            thisTurn = nextTurn
        }
    }

    func testTheSameDrawComesBackFromTheSameGenerator() {
        var first = ScriptedGenerator([7, 11])
        var second = ScriptedGenerator([7, 11])
        XCTAssertEqual(FirstPlayer.draw(avoiding: nil, using: &first),
                       FirstPlayer.draw(avoiding: nil, using: &second))
    }
}
