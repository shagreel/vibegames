import SwiftUI

/// The shape of one face of each die.
///
/// These are the real faces, not a polygon with N sides: a d4, a d8 and a d20
/// all show triangles, because those are the faces of a tetrahedron, an octahedron
/// and an icosahedron; a d6 is a square; a d12 is a pentagon (a dodecahedron's
/// face); a d10 is a kite (a pentagonal trapezohedron's face — the one die whose
/// face is not a regular polygon). Colour and the label tell the three triangles
/// apart.
enum DieFace: Equatable {
    case triangle
    case square
    case pentagon
    case kite

    static func of(sides: Int) -> DieFace {
        switch sides {
        case 4, 8, 20: return .triangle
        case 6: return .square
        case 12: return .pentagon
        case 10: return .kite
        default: return .square
        }
    }

    /// The corners, in a unit square with y running down. Kept inside the box so
    /// the rounded stroke has room.
    var vertices: [CGPoint] {
        switch self {
        case .triangle:
            return [CGPoint(x: 0.50, y: 0.03),
                    CGPoint(x: 0.97, y: 0.90),
                    CGPoint(x: 0.03, y: 0.90)]
        case .square:
            return [CGPoint(x: 0.06, y: 0.04),
                    CGPoint(x: 0.94, y: 0.04),
                    CGPoint(x: 0.94, y: 0.92),
                    CGPoint(x: 0.06, y: 0.92)]
        case .pentagon:
            return (0..<5).map { index in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / 5
                return CGPoint(x: 0.5 + 0.47 * cos(angle),
                               y: 0.48 + 0.47 * sin(angle))
            }
        case .kite:
            // Wide across the top, like the kite that makes up a d10.
            return [CGPoint(x: 0.50, y: 0.02),
                    CGPoint(x: 0.95, y: 0.46),
                    CGPoint(x: 0.50, y: 0.98),
                    CGPoint(x: 0.05, y: 0.46)]
        }
    }

    func path(in rect: CGRect, cornerRadius: CGFloat) -> Path {
        let points = vertices.map {
            CGPoint(x: rect.minX + $0.x * rect.width,
                    y: rect.minY + $0.y * rect.height)
        }
        guard points.count > 2 else { return Path(rect) }

        func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        var path = Path()
        path.move(to: middle(points[0], points[1]))
        for index in 1...points.count {
            let corner = points[index % points.count]
            let after = points[(index + 1) % points.count]
            path.addArc(tangent1End: corner, tangent2End: after, radius: cornerRadius)
        }
        path.closeSubpath()
        return path
    }
}

/// One die, drawn as a face with some depth under it.
///
/// The 3D is three cheap things stacked: a darker copy of the face offset
/// downwards (the side of the die), a light-to-shade gradient across the face,
/// and a hairline highlight along the top edge. It is a picture of a die rather
/// than a rendered one, which is what keeps it crisp at every size and cheap
/// enough to tumble half a dozen at once.
struct DieBody: View {
    let sides: Int
    /// How far the body sits below the face. Zero for the small picker buttons.
    var depth: CGFloat = 7
    var cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let colour = VibeTheme.diceColour(sides: sides)
            let face = DieFace.of(sides: sides)
            let rect = CGRect(origin: .zero, size: geo.size)
            let top = rect.insetBy(dx: depth * 0.4, dy: depth * 0.4)
            // The back of the die is a touch smaller than the face, so the sides
            // lean in: a slab with parallel edges looks like a sticker standing
            // up, not like a solid.
            let back = top.offsetBy(dx: 0, dy: depth).insetBy(dx: depth * 0.22, dy: 0)
            let side = face.path(in: back, cornerRadius: cornerRadius)

            ZStack {
                // The shadow on the table, so the die sits on something.
                face.path(in: top.offsetBy(dx: 0, dy: depth + 1), cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.30))
                    .blur(radius: 6)
                    .offset(y: 2)

                // The side of the die: the same face, pushed down and darkened.
                side.fill(colour)
                    .overlay { side.fill(Color.black.opacity(0.40)) }

                face.path(in: top, cornerRadius: cornerRadius)
                    .fill(colour)
                    .overlay {
                        LinearGradient(colors: [.white.opacity(0.40),
                                                .white.opacity(0.05),
                                                .black.opacity(0.20)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                            .mask(face.path(in: top, cornerRadius: cornerRadius))
                    }
                    .overlay {
                        // A bevel: lit along the top-left edge, in shade along
                        // the bottom-right, which is what makes a flat shape
                        // read as a solid.
                        face.path(in: top, cornerRadius: cornerRadius)
                            .stroke(LinearGradient(colors: [.white.opacity(0.55),
                                                            .white.opacity(0.10),
                                                            .black.opacity(0.28)],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing),
                                    lineWidth: 1.4)
                    }
            }
        }
    }
}
