import Foundation
import simd

/// A solid die: its corners, its faces as loops of corner indices, and the
/// number printed on each face.
///
/// The faces are found from the corners rather than typed in. Every solid here
/// is convex, so a plane is a face exactly when every corner is on or behind it —
/// which is a cheap test and means no hand-written face tables to get wrong.
struct DieMesh {
    let sides: Int
    let vertices: [SIMD3<Float>]
    let faces: [[Int]]
    /// `numbers[i]` is printed on `faces[i]`.
    let numbers: [Int]

    /// The number printed on the face, 1...sides.
    func value(on face: Int) -> Int { numbers[face] }

    func face(for value: Int) -> Int {
        numbers.firstIndex(of: value) ?? 0
    }

    func centroid(of face: Int) -> SIMD3<Float> {
        let points = faces[face].map { vertices[$0] }
        return points.reduce(.zero, +) / Float(points.count)
    }

    /// The face's outward normal, normalised, worked out from its winding.
    func normal(of face: Int) -> SIMD3<Float> {
        let points = faces[face].map { vertices[$0] }
        guard points.count >= 3 else { return .init(0, 1, 0) }
        // Every face here is planar, so the first non-degenerate pair of edges
        // defines the plane.
        var n = SIMD3<Float>.zero
        for index in 1..<(points.count - 1) {
            n = simd_cross(points[1] - points[0], points[index + 1] - points[0])
            if simd_length(n) > 1e-5 { break }
        }
        guard simd_length(n) > 1e-5 else { return .init(0, 1, 0) }
        n = simd_normalize(n)
        return simd_dot(n, centroid(of: face)) < 0 ? -n : n
    }
}

/// Builds the six dice once, and remembers them: the face search is cheap but
/// pointless to repeat on every frame.
enum DiceMeshes {
    static func mesh(sides: Int) -> DieMesh {
        if let cached = cache[sides] { return cached }
        let mesh = build(sides: sides)
        cache[sides] = mesh
        return mesh
    }

    private static var cache: [Int: DieMesh] = [:]

    // MARK: - The solids

    static func vertices(sides: Int) -> [SIMD3<Float>] {
        switch sides {
        case 4:
            // Tetrahedron.
            return [SIMD3(1, 1, 1), SIMD3(1, -1, -1),
                    SIMD3(-1, 1, -1), SIMD3(-1, -1, 1)]
        case 6:
            // Cube.
            var points: [SIMD3<Float>] = []
            for x in [-1, 1] as [Float] {
                for y in [-1, 1] as [Float] {
                    for z in [-1, 1] as [Float] {
                        points.append(SIMD3(x, y, z))
                    }
                }
            }
            return points
        case 8:
            // Octahedron.
            return [SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 1, 0),
                    SIMD3(0, -1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1)]
        case 12:
            // Dodecahedron: the cube's corners plus three golden rectangles.
            let phi = Float((1 + CGFloat(5).squareRoot()) / 2)
            let inv: Float = 1 / phi
            var points: [SIMD3<Float>] = []
            for x in [-1, 1] as [Float] {
                for y in [-1, 1] as [Float] {
                    for z in [-1, 1] as [Float] {
                        points.append(SIMD3(x, y, z))
                    }
                }
            }
            for a in [-inv, inv] as [Float] {
                for b in [-phi, phi] as [Float] {
                    points.append(SIMD3(0, a, b))
                    points.append(SIMD3(a, b, 0))
                    points.append(SIMD3(b, 0, a))
                }
            }
            return points
        case 20:
            // Icosahedron: three golden rectangles, corner to corner.
            let phi = Float((1 + CGFloat(5).squareRoot()) / 2)
            var points: [SIMD3<Float>] = []
            for a in [-1, 1] as [Float] {
                for b in [-phi, phi] as [Float] {
                    points.append(SIMD3(0, a, b))
                    points.append(SIMD3(a, b, 0))
                    points.append(SIMD3(b, 0, a))
                }
            }
            return points
        case 10:
            // Pentagonal trapezohedron, built as the dual of the pentagonal
            // antiprism: one corner per antiprism face. That is what makes the
            // belt zigzag properly — two rings at fixed heights is not the same
            // solid, and it comes out slightly concave.
            return trapezohedronCorners()
        default:
            return vertices(sides: 6)
        }
    }

    /// The d10's corners: the polar dual of the pentagonal antiprism.
    ///
    /// A trapezohedron is the dual of an antiprism, and the dual has to be taken
    /// through the faces' *planes* — a corner at every plane's pole — rather than
    /// through their centres. The centres do not even give flat kites: the four
    /// around an antiprism corner are not coplanar, and the hull splits every
    /// face into two triangles. The poles are flat by construction.
    ///
    /// The antiprism is the uniform one — regular pentagons, equilateral
    /// triangles — so its side length fixes the height instead of it being
    /// guessed at.
    private static func trapezohedronCorners() -> [SIMD3<Float>] {
        let edge: Float = 1
        let halfStep = Float.pi / 10
        let radius = edge / (2 * sin(halfStep))
        let ring = 2 * radius * sin(halfStep / 2)
        let height = ((edge * edge - ring * ring) / 4).squareRoot()

        var top: [SIMD3<Float>] = []
        var bottom: [SIMD3<Float>] = []
        for index in 0..<5 {
            let angle = Float(index) * 2 * .pi / 5
            top.append(SIMD3(radius * cos(angle), height, radius * sin(angle)))
            let offset = angle + .pi / 5
            bottom.append(SIMD3(radius * cos(offset), -height, radius * sin(offset)))
        }

        var faces: [[SIMD3<Float>]] = [top, bottom]
        for index in 0..<5 {
            let next = (index + 1) % 5
            faces.append([top[index], top[next], bottom[index]])
            faces.append([bottom[index], bottom[next], top[next]])
        }

        return faces.map { face in
            let centre = face.reduce(.zero, +) / Float(face.count)
            var normal = simd_normalize(simd_cross(face[1] - face[0], face[2] - face[0]))
            var offset = simd_dot(normal, face[0])
            if offset < 0 {
                normal = -normal
                offset = -offset
            }
            _ = centre
            return normal / offset
        }
    }

    // MARK: - Faces and numbers

    private static func build(sides: Int) -> DieMesh {
        var points = vertices(sides: sides)

        // A d10 straight off the uniform antiprism is a flat plate. Real ones
        // are stretched along their axis so they read as a die rather than a
        // shard; stretching keeps the kites flat.
        if sides == 10 {
            points = points.map { SIMD3($0.x, $0.y * 1.35, $0.z) }
        }

        // One size for every die, so a d20 is not a different scale to a d6.
        let radius = points.map(simd_length).max() ?? 1
        points = points.map { $0 / radius }

        let faces = facesOfConvexSolid(points)
        let numbers = faceNumbers(count: faces.count, normals: faces.map { faceNormal($0, points) })
        return DieMesh(sides: sides, vertices: points, faces: faces, numbers: numbers)
    }

    /// Every plane that has all the corners on or behind it is a face, and every
    /// corner on that plane belongs to it.
    static func facesOfConvexSolid(_ points: [SIMD3<Float>]) -> [[Int]] {
        let tolerance: Float = 1e-4
        var planes: [(normal: SIMD3<Float>, offset: Float)] = []

        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                for k in (j + 1)..<points.count {
                    var normal = simd_cross(points[j] - points[i], points[k] - points[i])
                    let length = simd_length(normal)
                    guard length > tolerance else { continue }
                    normal /= length
                    var offset = simd_dot(normal, points[i])
                    if offset < 0 {
                        normal = -normal
                        offset = -offset
                    }
                    // A face of the hull: nothing is in front of it.
                    let highest = points.map { simd_dot(normal, $0) }.max() ?? 0
                    guard highest <= offset + tolerance else { continue }
                    if planes.contains(where: { simd_dot($0.normal, normal) > 0.9999
                                                && abs($0.offset - offset) < tolerance }) {
                        continue
                    }
                    planes.append((normal, offset))
                }
            }
        }

        return planes.map { plane in
            let indices = points.indices.filter {
                abs(simd_dot(plane.normal, points[$0]) - plane.offset) < 1e-3
            }
            return ordered(indices, points: points, normal: plane.normal)
        }
    }

    /// Walks the face's corners into a loop, so it can be drawn as one polygon.
    private static func ordered(_ indices: [Int], points: [SIMD3<Float>],
                                normal: SIMD3<Float>) -> [Int] {
        let centre = indices.map { points[$0] }.reduce(.zero, +) / Float(indices.count)
        let reference: SIMD3<Float> = abs(normal.y) > 0.9 ? SIMD3(0, 0, 1) : SIMD3(0, 1, 0)
        let u = simd_normalize(simd_cross(reference, normal))
        let v = simd_cross(normal, u)
        return indices.sorted { a, b in
            let da = points[a] - centre
            let db = points[b] - centre
            return atan2(simd_dot(da, v), simd_dot(da, u))
                 < atan2(simd_dot(db, v), simd_dot(db, u))
        }
    }

    private static func faceNormal(_ face: [Int], _ points: [SIMD3<Float>]) -> SIMD3<Float> {
        let p0 = points[face[0]], p1 = points[face[1]], p2 = points[face[2]]
        var n = simd_normalize(simd_cross(p1 - p0, p2 - p0))
        let centre = face.map { points[$0] }.reduce(.zero, +) / Float(face.count)
        if simd_dot(n, centre) < 0 { n = -n }
        return n
    }

    /// Numbers, arranged the way a real die is: faces that point opposite ways
    /// add up to one more than the highest number. The d4 has no opposite faces,
    /// so it simply counts.
    static func faceNumbers(count: Int, normals: [SIMD3<Float>]) -> [Int] {
        var numbers = Array(repeating: 0, count: count)
        var used = Set<Int>()
        let highest = count

        for index in 0..<count where numbers[index] == 0 {
            // The most opposite face that is still unnumbered.
            var partner: Int?
            var best: Float = -1
            for other in 0..<count where other != index && numbers[other] == 0 {
                let opposition = -simd_dot(normals[index], normals[other])
                if opposition > best {
                    best = opposition
                    partner = other
                }
            }

            if let partner, best > 0.99, used.count + 2 <= highest {
                let low = (1...highest).first { !used.contains($0) } ?? 1
                var high = highest + 1 - low
                if used.contains(high) || high == low {
                    high = (1...highest).reversed().first { !used.contains($0) && $0 != low } ?? low
                }
                if high != low {
                    numbers[index] = low
                    numbers[partner] = high
                    used.insert(low)
                    used.insert(high)
                    continue
                }
            }

            let next = (1...highest).first { !used.contains($0) } ?? 1
            numbers[index] = next
            used.insert(next)
        }
        return numbers
    }
}
