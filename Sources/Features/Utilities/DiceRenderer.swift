import SwiftUI
import UIKit
import simd

/// Draws a solid die.
///
/// The camera is fixed and looks down on the die the way somebody sitting at a
/// table would. The die is a real solid — its faces are found from its corners —
/// so a d20 is a tumble of triangles and a d12 shows pentagons, rather than a
/// picture of a die that rotates in two dimensions.
enum DiceRenderer {

    // MARK: - The camera

    /// Looking down on the table from a little way off.
    static let eye = SIMD3<Float>(0, 2.00, 2.83)
    static let target = SIMD3<Float>.zero
    static let worldUp = SIMD3<Float>(0, 1, 0)
    /// Light from above and to the left, which is where every drawing of a solid
    /// puts its light.
    static let lightDirection = simd_normalize(SIMD3<Float>(-0.45, 0.85, 0.55))

    private static let forward = simd_normalize(target - eye)
    private static let right = simd_normalize(simd_cross(forward, worldUp))
    private static let up = simd_cross(right, forward)

    /// Projects a point into the box, with a die of radius 1 filling most of the
    /// shorter side.
    private static func project(_ point: SIMD3<Float>, in size: CGSize) -> (point: CGPoint, depth: Float) {
        let offset = point - eye
        let x = simd_dot(offset, right)
        let y = simd_dot(offset, up)
        let depth = max(simd_dot(offset, forward), 0.05)

        let reach = CGFloat(simd_length(eye - target))
        let focal = 0.55 * min(size.width, size.height) * reach
        return (CGPoint(x: size.width / 2 + CGFloat(x / depth) * focal,
                        y: size.height / 2 - CGFloat(y / depth) * focal),
                depth)
    }

    // MARK: - Resting and rolling

    /// Where a die turns its rolled face.
    ///
    /// Up, for every die that can stand on a face. A tetrahedron cannot: the face
    /// that is up is the face it is standing on a point *below*, which looks like
    /// a spinning top rather than a die. So a d4 leans that face towards the
    /// viewer and rests on an edge, which is how a d4 sits in the hand anyway.
    static func displayDirection(sides: Int) -> SIMD3<Float> {
        sides == 4 ? simd_normalize(SIMD3<Float>(0.62, 0.60, 0.50)) : worldUp
    }

    /// The orientation a die rests in: the face showing `value` pointed at the
    /// ceiling — or, for a d4, at the viewer — with a yaw so a table of dice does
    /// not look stamped out.
    static func restingRotation(mesh: DieMesh, value: Int, yaw: Double) -> simd_quatf {
        let face = mesh.face(for: value)
        let normal = mesh.normal(of: face)
        let direction = displayDirection(sides: mesh.sides)
        let align = simd_quatf(from: normal, to: direction)
        let turn = simd_quatf(angle: Float(yaw), axis: direction)
        return turn * align
    }

    /// Where a die is part-way through a roll.
    ///
    /// The face that will show is decided before the roll starts, so the tumble
    /// is a spin *down* to that orientation: two rotations about their own axes,
    /// both easing to nothing, which makes the die look thrown rather than
    /// tweened.
    static func rollingRotation(rest: simd_quatf, progress: Double,
                                axisA: SIMD3<Float>, axisB: SIMD3<Float>,
                                turns: Double, tilt: Double) -> simd_quatf {
        let p = Float(min(max(progress, 0), 1))
        let easedA = 1 - pow(1 - p, 3)
        let easedB = 1 - pow(1 - p, 2)
        let spinA = simd_quatf(angle: Float(turns * 2 * .pi) * (1 - easedA), axis: axisA)
        let spinB = simd_quatf(angle: Float(tilt) * (1 - easedB), axis: axisB)
        return rest * spinA * spinB
    }

    // MARK: - Drawing

    static func draw(mesh: DieMesh, value: Int, colour: Color, rotation: simd_quatf,
                     lift: Float = 0, in size: CGSize, into context: inout GraphicsContext) {
        let height = simd_length(eye) * 0.18

        let centre = SIMD3(0, lift * height, 0)

        let projected = mesh.vertices.map { vertex -> (CGPoint, Float) in
            let world = rotation.act(vertex) + centre
            let (point, depth) = project(world, in: size)
            return (point, depth)
        }

        // The shadow sits under wherever the die actually is, which keeps a
        // leaning d4 from looking like it is hovering beside its own shadow.
        if let lowest = projected.map({ $0.0.y }).max(),
           let centreX = projected.map({ $0.0.x }).min(),
           let rightX = projected.map({ $0.0.x }).max() {
            let width = (rightX - centreX) * 0.42
            let shadow = Path(ellipseIn: CGRect(x: (centreX + rightX) / 2 - width,
                                                y: lowest - width * 0.30,
                                                width: width * 2,
                                                height: width * 0.60))
            context.fill(shadow, with: .color(.black.opacity(0.16 - 0.06 * Double(lift))))
        }

        // Front faces only, far ones first, so the near faces paint over them.
        var visible: [(face: Int, depth: Float, points: [CGPoint], normal: SIMD3<Float>)] = []
        for face in mesh.faces.indices {
            let normal = rotation.act(mesh.normal(of: face))
            let faceCentre = centre + rotation.act(mesh.centroid(of: face))
            guard simd_dot(normal, simd_normalize(eye - faceCentre)) > 0.02 else { continue }
            let points = mesh.faces[face].map { projected[$0].0 }
            let depth = mesh.faces[face].map { projected[$0].1 }.reduce(0, +) / Float(mesh.faces[face].count)
            visible.append((face, depth, points, normal))
        }
        visible.sort { $0.depth > $1.depth }

        for entry in visible {
            var path = Path()
            path.addLines(entry.points)
            path.closeSubpath()

            let light = max(0, simd_dot(entry.normal, lightDirection))
            let brightness = 0.28 + 0.95 * Double(light)
            context.fill(path, with: .color(shaded(colour, by: brightness)))
            if light > 0.82 {
                // A little bloom on the face nearest the light, which is what
                // makes a solid look solid rather than folded.
                context.fill(path, with: .color(.white.opacity(0.10 * Double(light - 0.82) / 0.18)))
            }
            context.stroke(path, with: .color(shaded(colour, by: 0.35)),
                           lineWidth: max(0.6, min(size.width, size.height) * 0.009))

            // The number, in the face's own plane. The numeral of the face that
            // is showing at the end of the roll is the one that reads.
            let numeral = mesh.value(on: entry.face)
            draw(numeral: numeral, of: entry.face, mesh: mesh, rotation: rotation,
                 centre: centre, in: size, into: &context)
        }
    }

    private static func draw(numeral: Int, of face: Int, mesh: DieMesh, rotation: simd_quatf,
                             centre: SIMD3<Float>, in size: CGSize,
                             into context: inout GraphicsContext) {
        let normal = rotation.act(mesh.normal(of: face))
        let faceCentre = centre + rotation.act(mesh.centroid(of: face))

        // Text stands upright on the face as seen from the camera: "up" on the
        // face is the world's up pushed into the face's plane, falling back to
        // the view direction when the face is flat to the camera and that
        // projection vanishes.
        var textUp = worldUp - normal * simd_dot(worldUp, normal)
        if simd_length(textUp) < 0.15 {
            textUp = forward - normal * simd_dot(forward, normal)
        }
        guard simd_length(textUp) > 0.001 else { return }
        textUp = simd_normalize(textUp)
        let textRight = simd_cross(textUp, normal)

        let origin = project(faceCentre, in: size).point
        let rightPoint = project(faceCentre + textRight * 0.3, in: size).point
        let upPoint = project(faceCentre + textUp * 0.3, in: size).point

        let rightVector = CGPoint(x: rightPoint.x - origin.x, y: rightPoint.y - origin.y)
        let upVector = CGPoint(x: upPoint.x - origin.x, y: upPoint.y - origin.y)
        let rightLength = max(hypot(rightVector.x, rightVector.y), 0.001)
        let upLength = max(hypot(upVector.x, upVector.y), 0.001)

        // A glyph about a fifth of the way across the face.
        let glyph = min(rightLength, upLength) * 1.1
        let transform = CGAffineTransform(
            a: rightVector.x / rightLength * glyph,
            b: rightVector.y / rightLength * glyph,
            c: -upVector.x / upLength * glyph,
            d: -upVector.y / upLength * glyph,
            tx: origin.x,
            ty: origin.y
        )

        context.drawLayer { layer in
            layer.transform = transform
            let shadow = Text("\(numeral)")
                .font(.system(size: 1, weight: .black, design: .rounded))
                .foregroundColor(.black.opacity(0.5))
            layer.draw(shadow, at: CGPoint(x: 0.03, y: 0.04), anchor: .center)

            let text = Text("\(numeral)")
                .font(.system(size: 1, weight: .black, design: .rounded))
                .foregroundColor(.white)
            layer.draw(text, at: .zero, anchor: .center)
        }
    }

    /// A face's colour at a given brightness, keeping its hue.
    static func shaded(_ colour: Color, by factor: Double) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(colour).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let scaled = CGFloat(max(0, min(1.5, factor)))
        return Color(hue: Double(hue),
                     saturation: Double(saturation),
                     brightness: Double(min(1, brightness * scaled)),
                     opacity: Double(alpha))
    }
}
