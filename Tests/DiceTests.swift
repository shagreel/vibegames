import XCTest
@testable import VibeGames

/// The dice bag's rules, away from the screen.
///
/// The one thing a party actually needs from a dice app is that a d4 is a d4 and
/// that "roll" rerolls *these* dice rather than dealing new ones, so that is what
/// is pinned here.
@MainActor
final class DiceTests: XCTestCase {

    func testTheBagHasTheSixDiceAPartyNeeds() {
        XCTAssertEqual(DiceModel.sidesOptions, [4, 6, 8, 10, 12, 20])
    }

    /// The buttons are the shape of one face of each die: triangles for the
    /// tetrahedron, octahedron and icosahedron, a square for the cube, a pentagon
    /// for the dodecahedron, a kite for the d10's trapezohedron.
    func testEachDieWearsTheShapeOfItsOwnFace() {
        XCTAssertEqual(DieFace.of(sides: 4), .triangle)
        XCTAssertEqual(DieFace.of(sides: 6), .square)
        XCTAssertEqual(DieFace.of(sides: 8), .triangle)
        XCTAssertEqual(DieFace.of(sides: 10), .kite)
        XCTAssertEqual(DieFace.of(sides: 12), .pentagon)
        XCTAssertEqual(DieFace.of(sides: 20), .triangle)
    }

    func testADieLandsBetweenOneAndItsSides() {
        let model = DiceModel(generator: SeededGenerator(seed: 7))
        for sides in DiceModel.sidesOptions {
            model.add(sides: sides)
        }

        XCTAssertEqual(model.dice.map(\.sides), DiceModel.sidesOptions,
                       "each tap puts that die on the table")

        for die in model.dice {
            XCTAssertTrue((1...die.sides).contains(die.value),
                          "a d\(die.sides) rolled \(die.value)")
        }

        // And it stays in range however often it is rolled.
        for _ in 0..<50 {
            model.rollAll()
            for die in model.dice {
                XCTAssertTrue((1...die.sides).contains(die.value),
                              "a d\(die.sides) rolled \(die.value)")
            }
        }
    }

    func testRollingRerollsTheSameDiceRatherThanDealingNewOnes() {
        let model = DiceModel(generator: SeededGenerator(seed: 99))
        model.add(sides: 4)
        model.add(sides: 4)
        model.add(sides: 8)

        let ids = model.dice.map(\.id)
        var values: [[Int]] = [model.dice.map(\.value)]

        for _ in 0..<10 {
            model.rollAll()
            values.append(model.dice.map(\.value))
        }

        XCTAssertEqual(model.dice.map(\.id), ids, "the dice on the table are the same dice")
        XCTAssertEqual(model.dice.map(\.sides), [4, 4, 8], "and they keep their sides")
        let distinctTables = Set(values.map { $0.map(String.init).joined(separator: ",") })
        XCTAssertGreaterThan(distinctTables.count, 1,
                             "rolling ten times should not give the same numbers every time")
    }

    func testEachDieRollsOnItsOwnTable() {
        // A d4 among d20s must still be a d4: the sides travel with the die, not
        // with the bag.
        let model = DiceModel(generator: SeededGenerator(seed: 3))
        model.add(sides: 4)
        for _ in 0..<40 {
            model.rollAll()
            XCTAssertTrue((1...4).contains(model.dice[0].value),
                          "the d4 rolled \(model.dice[0].value)")
        }
    }

    func testClearingTakesEveryDieOffTheTable() {
        let model = DiceModel(generator: SeededGenerator(seed: 11))
        model.add(sides: 6)
        model.add(sides: 20)
        XCTAssertFalse(model.isEmpty)

        model.clear()

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.dice.count, 0)

        // The table is not remembered: the next tap is whatever was tapped.
        model.add(sides: 12)
        XCTAssertEqual(model.dice.map(\.sides), [12])
    }

    func testANonsenseDieIsNotAdded() {
        let model = DiceModel(generator: SeededGenerator(seed: 5))
        model.add(sides: 0)
        XCTAssertTrue(model.isEmpty, "a die with no sides is not a die")
    }
}
