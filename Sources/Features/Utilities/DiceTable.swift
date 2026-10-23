import SceneKit
import UIKit

/// The table the dice are thrown onto.
///
/// This is a real physics simulation rather than an animation: each die is a
/// solid with the physics shape of the solid, dropped onto a table with gravity,
/// bounce and friction, and it comes to rest wherever it lands. The face that is
/// up at the end is the result — the same way a real die decides, which is why
/// the numbers are read back from the pose rather than handed in.
@MainActor
final class DiceTable: NSObject, ObservableObject {

    /// Half the table's width and depth, in die radii. Dice live inside this.
    static let halfWidth: Float = 4.6
    static let halfDepth: Float = 3.6

    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let tableNode = SCNNode()
    private let diceHolder = SCNNode()

    /// Called when a die has come to rest and the face looking up has been read.
    var onSettled: ((UUID, Int) -> Void)?

    /// The view drawing this table, so the accessibility tree can be rebuilt when
    /// the dice change and the render loop can stop when nothing is moving.
    weak var view: DiceTableSceneView?

    private var dice: [UUID: SCNNode] = [:]
    private(set) var sides: [UUID: Int] = [:]

    /// The dice that have been read since the last throw. The app shows a
    /// placeholder for the rest, so a number never appears before the die has
    /// stopped — which happens when one lands on another and rolls off it.
    @Published private(set) var settled: Set<UUID> = []

    var isEmpty: Bool { dice.isEmpty }
    var count: Int { dice.count }

    /// Settling is judged from the simulation itself: everything slow enough, for
    /// long enough, that the next frame will not change its mind.
    /// Where the next die is dropped. Dice are spread over a jittered grid rather
    /// than at random, so a handful does not pile up in one corner.
    private var nextSlot = 0

    private var quietSince: TimeInterval?
    private var lastCheck: TimeInterval = 0
    /// True while a settle is already queued for the next runloop pass.
    private var isFinishing = false
    /// True from a throw until the dice have been read.
    ///
    /// Without this the table settles again every time it looks at a table that
    /// is still at rest — reading every die, rebuilding every tag and rewriting
    /// the model two or three times a second for ever, which is what made the
    /// screen stop taking taps after the first die landed.
    private var wantsSettling = false
    /// When to read the faces whether or not the simulation has stopped. A die
    /// can wedge on an edge and jitter forever; the player still wants an answer.
    private var settleDeadline: TimeInterval = 0

    override init() {
        super.init()
        buildScene()
    }

    // MARK: - The scene

    private func buildScene() {
        scene.background.contents = UIColor.clear
        scene.physicsWorld.gravity = SCNVector3(0, -14, 0)

        // The table, with a lip around it so a hard throw stays on the table.
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.10, alpha: 1)
                : UIColor(white: 0.96, alpha: 1)
        }
        mat.roughness.contents = 1
        mat.lightingModel = .physicallyBased

        let table = SCNBox(width: CGFloat(Self.halfWidth * 2),
                           height: 0.2,
                           length: CGFloat(Self.halfDepth * 2),
                           chamferRadius: 0.4)
        table.materials = [mat]
        tableNode.geometry = table
        tableNode.position = SCNVector3(0, -0.1, 0)
        tableNode.physicsBody = SCNPhysicsBody.static()
        tableNode.physicsBody?.friction = 1
        tableNode.physicsBody?.restitution = 0.1
        scene.rootNode.addChildNode(tableNode)

        // The name on the baize: a picture laid flat on the table, just above the
        // felt, so the table is the same colour and texture it was and the mark
        // is only a mark. `constant` lighting keeps it from being blown out by
        // the key light.
        let wordmark = SCNNode()
        wordmark.geometry = SCNPlane(width: CGFloat(Self.halfWidth * 2),
                                     height: CGFloat(Self.halfDepth * 2))
        let mark = SCNMaterial()
        mark.diffuse.contents = Self.wordmarkTexture()
        mark.lightingModel = .constant
        mark.isDoubleSided = true
        wordmark.geometry?.materials = [mark]
        wordmark.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        wordmark.position = SCNVector3(0, 0.012, 0)
        scene.rootNode.addChildNode(wordmark)

        // Tall enough that a die dropped or thrown from head height cannot clear
        // it, and reaching below the table so nothing squeezes underneath.
        let wallHeight: Float = 4.4
        let wallCentre: Float = 1.2
        addWall(at: SCNVector3(0, wallCentre, -Self.halfDepth), half: (Self.halfWidth, wallHeight, 0.06))
        addWall(at: SCNVector3(0, wallCentre, Self.halfDepth), half: (Self.halfWidth, wallHeight, 0.06))
        addWall(at: SCNVector3(-Self.halfWidth, wallCentre, 0), half: (0.06, wallHeight, Self.halfDepth))
        addWall(at: SCNVector3(Self.halfWidth, wallCentre, 0), half: (0.06, wallHeight, Self.halfDepth))

        scene.rootNode.addChildNode(diceHolder)

        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 100
        // No tone mapping: with it on, the dice were washed out against the dark
        // table and their own colours stopped reading.
        camera.wantsHDR = false
        cameraNode.camera = camera
        // Looking down at the table from the near side, so a die that lands
        // towards the back is not hidden behind one at the front.
        cameraNode.position = SCNVector3(0, 8.6, 9.1)
        cameraNode.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 220
        ambient.light?.color = UIColor(white: 1, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 600
        key.light?.castsShadow = true
        key.light?.shadowSampleCount = 16
        key.light?.shadowRadius = 4
        key.light?.shadowColor = UIColor.black.withAlphaComponent(0.35)
        key.light?.orthographicScale = 14
        key.eulerAngles = SCNVector3(-CGFloat.pi / 2.6, -CGFloat.pi / 5, 0)
        scene.rootNode.addChildNode(key)
    }

    /// The table's cloth: the Vibe Games name, faint enough to read as a mark on
    /// the felt rather than a label stuck to the table.
    ///
    /// One mid-grey at low opacity, because the table is light in light mode and
    /// dark in dark mode and a fixed colour has to work on both — a mid-grey is
    /// lighter than one and darker than the other.
    private static func wordmarkTexture() -> UIImage {
        if let cached = wordmarkImage { return cached }

        let size = CGSize(width: 1024, height: 1024 * CGFloat(halfDepth / halfWidth))
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let ink = UIColor(white: 0.5, alpha: 0.30)

            let name = "VIBE GAMES" as NSString
            let nameFont = UIFont.systemFont(ofSize: 150, weight: .black)
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: ink,
                .kern: 10
            ]
            let nameBounds = name.size(withAttributes: nameAttributes)
            name.draw(at: CGPoint(x: (size.width - nameBounds.width) / 2,
                                  y: size.height * 0.42 - nameBounds.height / 2),
                      withAttributes: nameAttributes)

            let site = "vibegames.party" as NSString
            let siteAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .semibold),
                .foregroundColor: UIColor(white: 0.5, alpha: 0.22),
                .kern: 6
            ]
            let siteBounds = site.size(withAttributes: siteAttributes)
            site.draw(at: CGPoint(x: (size.width - siteBounds.width) / 2,
                                  y: size.height * 0.56),
                      withAttributes: siteAttributes)

            // A hairline round the edge, so the table has an edge to look at.
            let border = UIBezierPath(rect: CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18))
            UIColor(white: 0.5, alpha: 0.14).setStroke()
            border.lineWidth = 10
            border.stroke()
        }

        wordmarkImage = image
        return image
    }

    private static var wordmarkImage: UIImage?

    /// The lip around the table is a physics body with nothing to draw: a die
    /// near the edge bounces back, and the table looks like a table.
    private func addWall(at position: SCNVector3, half: (Float, Float, Float)) {
        let wall = SCNNode()
        wall.position = position
        let box = SCNBox(width: CGFloat(half.0 * 2),
                         height: CGFloat(half.1 * 2),
                         length: CGFloat(half.2 * 2),
                         chamferRadius: 0)
        let body = SCNPhysicsBody(type: .static,
                                  shape: SCNPhysicsShape(geometry: box, options: nil))
        body.friction = 0.4
        body.restitution = 0.2
        wall.physicsBody = body
        scene.rootNode.addChildNode(wall)
    }

    // MARK: - Dice

    func addDie(id: UUID, sides: Int, value: Int) {
        guard dice[id] == nil else { return }
        self.sides[id] = sides

        let node = DiceSolid.node(sides: sides, value: value)
        // Somewhere random on the table, dropped from a little way up, so the
        // die is already rolling by the time it lands.
        node.position = SCNVector3(slotX(), 2.0 + Float.random(in: 0...0.6), slotZ())
        node.eulerAngles = SCNVector3(Float.random(in: 0...(2 * .pi)),
                                      Float.random(in: 0...(2 * .pi)),
                                      Float.random(in: 0...(2 * .pi)))
        // Thrown rather than dropped: a die that falls straight down never rolls,
        // which is not what a die does when it is put on a table.
        node.physicsBody?.velocity = SCNVector3(Float.random(in: -1.1...1.1),
                                                -0.4,
                                                Float.random(in: -1.1...1.1))
        node.physicsBody?.angularVelocity = SCNVector4(Float.random(in: -3...3),
                                                       Float.random(in: -3...3),
                                                       Float.random(in: -3...3),
                                                       4)
        diceHolder.addChildNode(node)
        dice[id] = node
        settled.remove(id)
        nextSlot += 1

        settleClock(start: true)
        view?.wake()
    }

    func removeAll() {
        diceHolder.childNodes.forEach { $0.removeFromParentNode() }
        dice = [:]
        sides = [:]
        settled = []
        nextSlot = 0
        quietSince = nil
        lastSample = [:]
        stillSamples = 0
    }

    /// Throws every die on the table again.
    func tossAll() {
        for (_, node) in dice {
            // Lift it, spin it, and push it towards the middle so a die near the
            // edge does not climb the lip and bounce back on the spot.
            node.physicsBody?.resetTransform()
            var transform = node.simdTransform
            transform.columns.3.y = 1.9 + Float.random(in: 0...0.7)
            transform.columns.3.x *= 0.75
            transform.columns.3.z *= 0.75
            node.simdTransform = transform
            node.physicsBody?.clearAllForces()
            // Velocities rather than impulses: an impulse is divided by the die's
            // mass and a handful of newtons sent dice clean off the table.
            node.physicsBody?.velocity = SCNVector3(Float.random(in: -0.8...0.8),
                                                    0.8,
                                                    Float.random(in: -0.8...0.8))
            node.physicsBody?.angularVelocity = SCNVector4(Float.random(in: -2...2),
                                                           Float.random(in: -2...2),
                                                           Float.random(in: -2...2),
                                                           3.5)
        }
        settled = []
        settleClock(start: true)
        view?.wake()
    }

    private func slotX() -> Float {
        let column = Float(nextSlot % 3) - 1                       // -1, 0, 1
        return column * (Self.halfWidth * 0.52) + .random(in: -0.35...0.35)
    }

    private func slotZ() -> Float {
        let row = Float((nextSlot / 3) % 2) - 0.5                  // -0.5, 0.5
        return row * (Self.halfDepth * 1.1) + .random(in: -0.3...0.3)
    }

    /// Three quiet samples, or the deadline.
    private func oddStill(still: Bool, overdue: Bool) -> Bool {
        (still && stillSamples >= 2) || overdue
    }

    private func settleClock(start: Bool) {
        quietSince = nil
        lastSample = [:]
        stillSamples = 0
        lastCheck = 0
        wantsSettling = start
        settleDeadline = start ? Date().timeIntervalSinceReferenceDate + 6 : 0
    }

    // MARK: - Settling

    /// Runs on every frame the view draws. A die is at rest when the simulation
    /// says its body has stopped; when every die has been still for a moment,
    /// the table reads the faces that are up.
    func settleIfQuiet(atTime time: TimeInterval) {
        guard wantsSettling, !dice.isEmpty, !isFinishing else { return }
        guard time - lastCheck > 0.1 else { return }
        lastCheck = time

        // Stillness is judged by watching the dice, not by trusting a velocity
        // threshold or waiting for the solver to declare them asleep: three
        // samples in a row with no die moving a millimetre or a fraction of a
        // degree, which is direct evidence and arrives much sooner.
        let asleep = dice.values.allSatisfy { $0.physicsBody?.isResting == true }
        let still = sampleMovement()
        let overdue = settleDeadline > 0 && Date().timeIntervalSinceReferenceDate > settleDeadline

        if !still {
            stillSamples = 0
        } else {
            stillSamples += 1
        }

        guard asleep || oddStill(still: still, overdue: overdue) else { return }

        // Nothing happens inside the render callback itself — not even
        // stopping the loop, which deadlocks when it is done from in here. The
        // work goes to the next runloop pass, and the callback just returns.
        stillSamples = 0
        isFinishing = true
        DispatchQueue.main.async { [weak self] in
            self?.finishSettling()
        }
    }

    /// Reads the faces, tags the dice, tells the app, and stops drawing.
    /// The last place each die was, so "has it stopped?" can be answered by
    /// looking: SceneKit puts a body to sleep only after its own quiet timer, and
    /// that timer is a good half second of the pause the table had after a throw.
    private var lastSample: [UUID: (position: SIMD3<Float>, orientation: simd_quatf)] = [:]
    private var stillSamples = 0

    private func sampleMovement() -> Bool {
        var still = true
        var next: [UUID: (position: SIMD3<Float>, orientation: simd_quatf)] = [:]
        for (id, node) in dice {
            let position = node.presentation.simdPosition
            let orientation = node.presentation.simdOrientation
            next[id] = (position, orientation)

            if let previous = lastSample[id] {
                let moved = simd_length(position - previous.position)
                let angle = abs(simd_angle(simd_normalize(previous.orientation.conjugate * orientation)))
                if moved > 0.015 || angle > 0.03 { still = false }
            } else {
                still = false
            }
        }
        lastSample = next
        return still
    }

    private func finishSettling() {
        isFinishing = false
        wantsSettling = false
        settled = Set(dice.keys)
        for (id, node) in dice {
            guard let sides = sides[id] else { continue }
            let value = DiceSolid.faceLookingUp(of: node, sides: sides)
            onSettled?(id, value)
        }
        view?.rest()
    }

    // MARK: - Posing

    /// Where each die is, as the view sees it, for the accessibility elements.
    func makeAccessibilityElements(in view: SCNView) -> [UIAccessibilityElement] {
        let bounds = view.bounds
        return dice.compactMap { id, node in
            guard let sides = sides[id] else { return nil }
            let position = node.presentation.position
            let value = DiceSolid.faceLookingUp(of: node, sides: sides)

            // Mapped by hand rather than through `projectPoint`: asking the
            // renderer for a screen point while it is stopped is what froze the
            // screen, and for finding a die with a finger a linear map over the
            // table is close enough.
            let x = bounds.midX + CGFloat(position.x / Self.halfWidth) * bounds.width * 0.42
            let y = bounds.midY - CGFloat(position.z / Self.halfDepth) * bounds.height * 0.30
            let element = UIAccessibilityElement(accessibilityContainer: view)
            element.accessibilityIdentifier = "dice.die"
            element.accessibilityLabel = "d\(sides): \(value)"
            element.accessibilityFrameInContainerSpace = CGRect(x: x - 22, y: y - 22,
                                                                width: 44, height: 44)
            return element
        }
    }
}
