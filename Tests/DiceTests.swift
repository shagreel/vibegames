import XCTest
import simd
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

/// The solids behind the dice.
///
/// Faces are worked out from the corners, which is the part most likely to go
/// quietly wrong: a cube has triangle-shaped planes through three of its corners
/// that are not faces, and a d10's faces are kites rather than any regular shape.
@MainActor
final class DiceMeshTests: XCTestCase {

    private func mesh(_ sides: Int) -> DieMesh { DiceMeshes.mesh(sides: sides) }

    func testEachDieHasTheRightNumberofFacesAndCorners() {
        let expected: [Int: (faces: Int, corners: Int)] = [
            4: (4, 4), 6: (6, 8), 8: (8, 6), 10: (10, 12), 12: (12, 20), 20: (20, 12)
        ]
        for (sides, counts) in expected {
            let solid = mesh(sides)
            XCTAssertEqual(solid.faces.count, counts.faces, "a d\(sides) has \(counts.faces) faces")
            XCTAssertEqual(solid.vertices.count, counts.corners, "and \(counts.corners) corners")
        }
    }

    func testAFaceIsATriangleSquareKiteOrPentagon() {
        XCTAssertEqual(mesh(4).faces.allSatisfy { $0.count == 3 }, true, "a d4 is triangles")
        XCTAssertEqual(mesh(6).faces.allSatisfy { $0.count == 4 }, true, "a d6 is squares")
        XCTAssertEqual(mesh(8).faces.allSatisfy { $0.count == 3 }, true, "a d8 is triangles")
        XCTAssertEqual(mesh(10).faces.allSatisfy { $0.count == 4 }, true, "a d10 is kites")
        XCTAssertEqual(mesh(12).faces.allSatisfy { $0.count == 5 }, true, "a d12 is pentagons")
        XCTAssertEqual(mesh(20).faces.allSatisfy { $0.count == 3 }, true, "a d20 is triangles")
    }

    func testEveryNumberIsOnExactlyOneFace() {
        for sides in [4, 6, 8, 10, 12, 20] {
            let numbers = mesh(sides).numbers.sorted()
            XCTAssertEqual(numbers, Array(1...sides), "a d\(sides) is numbered 1 to \(sides)")
        }
    }

    /// Opposite faces add up to one more than the highest number, as on a real
    /// die. The d4 is the exception: its faces all meet, so it just counts.
    func testOppositeFacesAddUpLikeARealDie() {
        for sides in [6, 8, 10, 12, 20] {
            let solid = mesh(sides)
            for face in solid.faces.indices {
                let normal = solid.normal(of: face)
                let opposite = solid.faces.indices.first { other in
                    other != face && simd_dot(normal, solid.normal(of: other)) < -0.99
                }
                guard let opposite else {
                    return XCTFail("a d\(sides) face should have an opposite")
                }
                XCTAssertEqual(solid.value(on: face) + solid.value(on: opposite), sides + 1,
                               "d\(sides) faces \(solid.value(on: face)) and \(solid.value(on: opposite))")
            }
        }
    }

    func testEveryFacePointsOutwards() {
        for sides in [4, 6, 8, 10, 12, 20] {
            let solid = mesh(sides)
            for face in solid.faces.indices {
                XCTAssertGreaterThan(simd_dot(solid.normal(of: face), solid.centroid(of: face)), 0,
                                     "a d\(sides) face points away from the middle")
            }
        }
    }

    func testTheDiceAreAllTheSameSize() {
        for sides in [4, 6, 8, 10, 12, 20] {
            let radius = mesh(sides).vertices.map(simd_length).max() ?? 0
            XCTAssertEqual(radius, 1, accuracy: 0.0001, "a d\(sides) is the same size as the rest")
        }
    }
}

/// The die that is showing is the die that was rolled.
///
/// The table draws the solid at an angle, so the value has to be on the face
/// that is turned to the ceiling — otherwise the number you can read and the
/// number that was rolled are two different things.
@MainActor
final class DiceRendererTests: XCTestCase {

    func testTheRolledFaceIsTheOneTurnedUpwards() {
        for sides in [4, 6, 8, 10, 12, 20] {
            let mesh = DiceMeshes.mesh(sides: sides)
            for value in 1...sides {
                let rotation = DiceRenderer.restingRotation(mesh: mesh, value: value, yaw: 0.4)
                // The face with the rolled number should be the one most
                // horizontal, facing the ceiling.
                let shown = DiceRenderer.displayDirection(sides: sides)
                var best = -Float.greatestFiniteMagnitude
                var bestValue = 0
                for face in mesh.faces.indices {
                    let normal = rotation.act(mesh.normal(of: face))
                    let facing = simd_dot(normal, shown)
                    if facing > best {
                        best = facing
                        bestValue = mesh.value(on: face)
                    }
                }
                XCTAssertEqual(bestValue, value,
                               "a d\(sides) rolled \(value) shows \(bestValue) on top")
            }
        }
    }

    func testTheRolledFaceIsExactlyTurnedUpwards() {
        for sides in [4, 6, 8, 10, 12, 20] {
            let mesh = DiceMeshes.mesh(sides: sides)
            for value in 1...sides {
                let rotation = DiceRenderer.restingRotation(mesh: mesh, value: value, yaw: 1.1)
                let normal = rotation.act(mesh.normal(of: mesh.face(for: value)))
                let shown = DiceRenderer.displayDirection(sides: sides)
                XCTAssertEqual(simd_dot(normal, shown), 1, accuracy: 0.0005,
                               "d\(sides) face \(value) should point where it is shown")
            }
        }
    }

    func testARollingDieTurnsAndThenSettlesExactly() {
        let mesh = DiceMeshes.mesh(sides: 20)
        let rest = DiceRenderer.restingRotation(mesh: mesh, value: 7, yaw: 0.2)
        let axisA = simd_normalize(SIMD3<Float>(1, 0.4, 0.2))
        let axisB = simd_normalize(SIMD3<Float>(-0.3, 1, 0.5))

        // At the start it is somewhere else entirely.
        let atStart = DiceRenderer.rollingRotation(rest: rest, progress: 0,
                                                   axisA: axisA, axisB: axisB,
                                                   turns: 2, tilt: 1.2)
        let startNormal = atStart.act(mesh.normal(of: mesh.face(for: 7)))
        XCTAssertLessThan(startNormal.y, 0.99, "the roll should start off the resting face")

        // By the end it is exactly the face it was rolled on.
        let atEnd = DiceRenderer.rollingRotation(rest: rest, progress: 1,
                                                 axisA: axisA, axisB: axisB,
                                                 turns: 2, tilt: 1.2)
        let endNormal = atEnd.act(mesh.normal(of: mesh.face(for: 7)))
        XCTAssertEqual(endNormal.y, 1, accuracy: 0.0005, "and settle on it")
    }

    func testTheCameraLooksDownAtTheTable() {
        // The eye is above the die and in front of it, so the face turned upwards
        // is the one you can see.
        XCTAssertGreaterThan(DiceRenderer.eye.y, 0)
        XCTAssertGreaterThan(DiceRenderer.eye.z, 0)
        XCTAssertLessThan(DiceRenderer.lightDirection.y, 0 + 1)
    }
}

/// What the camera actually sees.
@MainActor
final class DiceRenderingTests: XCTestCase {

    /// The renderer culls faces that point away, and on a resting die that
    /// should still leave a solid: more than one face, and the rolled one facing
    /// the camera.
    func testARestingDieShowsMoreThanOneFace() {
        let eye = DiceRenderer.eye
        for sides in [4, 6, 8, 10, 12, 20] {
            let mesh = DiceMeshes.mesh(sides: sides)
            let rotation = DiceRenderer.restingRotation(mesh: mesh, value: 1, yaw: 0.6)
            var visible = 0
            var valueFacingAway = false
            for face in mesh.faces.indices {
                let normal = rotation.act(mesh.normal(of: face))
                let centre = rotation.act(mesh.centroid(of: face))
                let toEye = simd_normalize(eye - centre)
                let facing = simd_dot(normal, toEye)
                if facing > 0.02 { visible += 1 }
                if mesh.value(on: face) == 1, facing < 0.02 { valueFacingAway = true }
            }
            XCTAssertGreaterThan(visible, 1, "a resting d\(sides) should show more than one face")
            XCTAssertFalse(valueFacingAway, "the rolled face of a d\(sides) should face the camera")
        }
    }
}
