import SceneKit
import UIKit
import simd

/// The solid dice themselves: the SceneKit geometry, their painted numbers, and
/// the bit of maths that says which face is looking up.
enum DiceSolid {

    /// The radius of a die on the table, in table units.
    static let radius: CGFloat = 0.72

    // MARK: - Nodes

    /// A die as a SceneKit node, ready to be thrown.
    ///
    /// Each face is its own geometry element with its own material, so every face
    /// can carry its own number rather than one texture wrapped over the solid.
    static func node(sides: Int, value: Int) -> SCNNode {
        let mesh = DiceMeshes.mesh(sides: sides)

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var textureCoordinates: [CGPoint] = []
        var elements: [SCNGeometryElement] = []
        var materials: [SCNMaterial] = []

        for (index, face) in mesh.faces.enumerated() {
            var points: [SIMD3<Float>] = []
            for corner in face {
                points.append(mesh.vertices[corner] * Float(radius))
            }
            let normal = mesh.normal(of: index)

            // The face's own little 2D world, so the number fills it: project the
            // corners onto the face plane and normalise to the unit square.
            let reference: SIMD3<Float> = abs(normal.y) > 0.9 ? SIMD3(0, 0, 1) : SIMD3(0, 1, 0)
            let along = simd_normalize(simd_cross(reference, normal))
            let alongUp = simd_cross(normal, along)
            let flat: [SIMD2<Float>] = points.map {
                SIMD2<Float>(simd_dot($0, along), simd_dot($0, alongUp))
            }
            let xs: [Float] = flat.map { $0.x }
            let ys: [Float] = flat.map { $0.y }
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 1
            let spanX = max(maxX - minX, 0.0001)
            let spanY = max(maxY - minY, 0.0001)

            let start = vertices.count
            for (corner, point) in points.enumerated() {
                vertices.append(SCNVector3(point.x, point.y, point.z))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))
                // A little inset so a number does not run off the edge of its face.
                let u = 0.5 + (flat[corner].x - (minX + maxX) / 2) / spanX * 0.82
                let v = 0.5 + (flat[corner].y - (minY + maxY) / 2) / spanY * 0.82
                textureCoordinates.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))
            }

            var indices: [Int32] = []
            for corner in 1..<(points.count - 1) {
                indices += [Int32(start), Int32(start + corner), Int32(start + corner + 1)]
            }
            // Elements take the material at their own index, so the order here
            // and in `materials` has to stay the same.
            elements.append(SCNGeometryElement(indices: indices, primitiveType: .triangles))
            materials.append(faceMaterial(sides: sides, value: mesh.value(on: index)))
        }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: textureCoordinates)
            ],
            elements: elements
        )
        geometry.materials = materials

        let node = SCNNode(geometry: geometry)
        let shape = SCNPhysicsShape(geometry: geometry,
                                    options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull])
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = 0.12
        body.restitution = 0.28
        body.friction = 0.85
        body.rollingFriction = 0.35
        body.damping = 0.12
        body.angularDamping = 0.18
        body.allowsResting = true
        node.physicsBody = body
        return node
    }

    // MARK: - Which face is up

    /// The number the die is showing.
    ///
    /// For every die but one, that is the face pointing at the ceiling: it rests
    /// on a face, and the opposite face is the result, as on a real die. A
    /// tetrahedron cannot do that — it rests on a face, so the top is a corner
    /// and the three faces round it are equally "up". So a d4 is read the way you
    /// read one in your hand: the face turned towards you. That is also the
    /// number the tag has to agree with, or the tag and the die say two different
    /// things.
    static func faceLookingUp(of node: SCNNode, sides: Int) -> Int {
        let mesh = DiceMeshes.mesh(sides: sides)
        let transform = node.presentation.simdWorldTransform
        let towards: SIMD3<Float> = sides == 4
            ? simd_normalize(SIMD3<Float>(0, 1.1, 1))     // the camera's corner
            : SIMD3<Float>(0, 1, 0)

        var best: Float = -.greatestFiniteMagnitude
        var bestValue = 1
        for face in mesh.faces.indices {
            let local = mesh.normal(of: face)
            let world = transform * SIMD4<Float>(local, 0)
            let facing = simd_dot(simd_normalize(SIMD3<Float>(world.x, world.y, world.z)), towards)
            if facing > best {
                best = facing
                bestValue = mesh.value(on: face)
            }
        }
        return bestValue
    }

    // MARK: - The paint

    private static var faceImages: [String: UIImage] = [:]
    private static var chipImages: [String: UIImage] = [:]

    private static func faceMaterial(sides: Int, value: Int) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.55
        material.metalness.contents = 0.0
        material.diffuse.contents = faceImage(sides: sides, value: value)
        return material
    }

    private static func faceImage(sides: Int, value: Int) -> UIImage {
        let key = "\(sides)-\(value)"
        if let cached = faceImages[key] { return cached }

        let side: CGFloat = 256
        let size = CGSize(width: side, height: side)
        let colour = UIColor(VibeTheme.diceColour(sides: sides))
        let image = UIGraphicsImageRenderer(size: size).image { context in
            colour.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // A soft sheen so a face is not a flat printed square.
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor.white.withAlphaComponent(0.22).cgColor,
                                               UIColor.black.withAlphaComponent(0.13).cgColor] as CFArray,
                                      locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient,
                                                 start: .zero,
                                                 end: CGPoint(x: side, y: side),
                                                 options: [])

            let text = "\(value)" as NSString
            let font = UIFont.systemFont(ofSize: value > 9 ? 120 : 150, weight: .black)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black.withAlphaComponent(0.28),
                .strokeWidth: -3
            ]
            let bounds = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (side - bounds.width) / 2,
                                  y: (side - bounds.height) / 2),
                      withAttributes: attributes)
        }

        faceImages[key] = image
        return image
    }

    /// The little tag beside a resting die: its number, large, so nobody has to
    /// squint at a far face to read a d20.
    static func chipTexture(sides: Int, value: Int) -> UIImage {
        let key = "\(sides)-\(value)"
        if let cached = chipImages[key] { return cached }

        let size = CGSize(width: 256, height: 128)
        let colour = UIColor(VibeTheme.diceColour(sides: sides))
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let capsule = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6),
                                       cornerRadius: 54)
            UIColor.black.withAlphaComponent(0.55).setFill()
            capsule.fill()
            colour.setStroke()
            capsule.lineWidth = 5
            capsule.stroke()

            let sidesText = "d\(sides)" as NSString
            sidesText.draw(at: CGPoint(x: 34, y: 44), withAttributes: [
                .font: UIFont.systemFont(ofSize: 38, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.72)
            ])

            let text = "\(value)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let bounds = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: size.width - bounds.width - 30,
                                  y: (size.height - bounds.height) / 2),
                      withAttributes: attributes)
        }

        chipImages[key] = image
        return image
    }
}
