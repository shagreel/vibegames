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
    private let chipsHolder = SCNNode()

    /// Called when a die has come to rest and the face looking up has been read.
    var onSettled: ((UUID, Int) -> Void)?

    /// The view drawing this table, so the accessibility tree can be rebuilt when
    /// the dice change and the render loop can stop when nothing is moving.
    weak var view: DiceTableSceneView?

    private var dice: [UUID: SCNNode] = [:]
    private var chips: [UUID: SCNNode] = [:]
    private(set) var sides: [UUID: Int] = [:]

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

        addWall(at: SCNVector3(0, 0, -Self.halfDepth), half: (Self.halfWidth, 1.2, 0.06))
        addWall(at: SCNVector3(0, 0, Self.halfDepth), half: (Self.halfWidth, 1.2, 0.06))
        addWall(at: SCNVector3(-Self.halfWidth, 0, 0), half: (0.06, 1.2, Self.halfDepth))
        addWall(at: SCNVector3(Self.halfWidth, 0, 0), half: (0.06, 1.2, Self.halfDepth))

        scene.rootNode.addChildNode(diceHolder)
        scene.rootNode.addChildNode(chipsHolder)

        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 0.1
        camera.zFar = 100
        camera.wantsHDR = true
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
        key.light?.shadowMode = .deferred
        key.light?.shadowSampleCount = 16
        key.light?.shadowRadius = 4
        key.light?.shadowColor = UIColor.black.withAlphaComponent(0.35)
        key.light?.orthographicScale = 14
        key.eulerAngles = SCNVector3(-CGFloat.pi / 2.6, -CGFloat.pi / 5, 0)
        scene.rootNode.addChildNode(key)
    }

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
        node.position = SCNVector3(slotX(), 2.0 + Float.random(in: 0...0.8), slotZ())
        node.eulerAngles = SCNVector3(Float.random(in: 0...(2 * .pi)),
                                      Float.random(in: 0...(2 * .pi)),
                                      Float.random(in: 0...(2 * .pi)))
        diceHolder.addChildNode(node)
        dice[id] = node
        chips[id]?.removeFromParentNode()
        chips[id] = nil
        nextSlot += 1

        settleClock(start: true)
        view?.wake()
    }

    func removeAll() {
        diceHolder.childNodes.forEach { $0.removeFromParentNode() }
        chipsHolder.childNodes.forEach { $0.removeFromParentNode() }
        dice = [:]
        chips = [:]
        sides = [:]
        nextSlot = 0
        quietSince = nil
    }

    /// Throws every die on the table again.
    func tossAll() {
        for (_, node) in dice {
            // Lift it, spin it, and push it towards the middle so a die near the
            // edge does not climb the lip and bounce back on the spot.
            node.physicsBody?.resetTransform()
            var transform = node.simdTransform
            transform.columns.3.y = 1.5 + Float.random(in: 0...0.9)
            transform.columns.3.x *= 0.75
            transform.columns.3.z *= 0.75
            node.simdTransform = transform
            node.physicsBody?.clearAllForces()
            // Velocities rather than impulses: an impulse is divided by the die's
            // mass and a handful of newtons sent dice clean off the table.
            node.physicsBody?.velocity = SCNVector3(Float.random(in: -0.9...0.9),
                                                    1.1,
                                                    Float.random(in: -0.9...0.9))
            node.physicsBody?.angularVelocity = SCNVector4(Float.random(in: -3...3),
                                                           Float.random(in: -3...3),
                                                           Float.random(in: -3...3),
                                                           6)
        }
        chipsHolder.childNodes.forEach { $0.removeFromParentNode() }
        chips = [:]
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

    private func settleClock(start: Bool) {
        quietSince = nil
        lastCheck = 0
        wantsSettling = start
        settleDeadline = start ? Date().timeIntervalSinceReferenceDate + 2.5 : 0
    }

    // MARK: - Settling

    /// Runs on every frame the view draws. A die is at rest when the simulation
    /// says its body has stopped; when every die has been still for a moment,
    /// the table reads the faces that are up.
    func settleIfQuiet(atTime time: TimeInterval) {
        guard wantsSettling, !dice.isEmpty, !isFinishing else { return }
        guard time - lastCheck > 0.12 else { return }
        lastCheck = time

        let moving = dice.values.contains { node in
            guard let body = node.physicsBody else { return false }
            if body.isResting { return false }
            let velocity = body.velocity
            let spin = body.angularVelocity
            return abs(velocity.x) + abs(velocity.y) + abs(velocity.z) > 0.6
                || abs(spin.x) + abs(spin.y) + abs(spin.z) > 1.2
        }

        let overdue = settleDeadline > 0 && Date().timeIntervalSinceReferenceDate > settleDeadline
        if moving, !overdue {
            quietSince = nil
            return
        }

        if !overdue {
            if let quietSince, time - quietSince < 0.25 { return }
            if quietSince == nil {
                quietSince = time
                return
            }
        }

        // Still. Nothing happens inside the render callback itself — not even
        // stopping the loop, which deadlocks when it is done from in here. The
        // work goes to the next runloop pass, and the callback just returns.
        quietSince = nil
        isFinishing = true
        DispatchQueue.main.async { [weak self] in
            self?.finishSettling()
        }
    }

    /// Reads the faces, tags the dice, tells the app, and stops drawing.
    private func finishSettling() {
        isFinishing = false
        wantsSettling = false
        for (id, node) in dice {
            guard let sides = sides[id] else { continue }
            let value = DiceSolid.faceLookingUp(of: node, sides: sides)
            onSettled?(id, value)
            showChip(for: id, value: value, at: node.presentation.position)
        }
        view?.rest()
    }

    /// A little tag under each die with its number, so which face is the result
    /// is never in doubt — the face on a d20 is small, and a die at the back is
    /// far away.
    private func showChip(for id: UUID, value: Int, at position: SCNVector3) {
        chips[id]?.removeFromParentNode()
        guard let sides = sides[id] else { return }

        let chip = SCNNode()
        chip.geometry = SCNPlane(width: 1.15, height: 0.55)
        (chip.geometry?.firstMaterial)?.diffuse.contents = DiceSolid.chipTexture(
            sides: sides, value: value
        )
        (chip.geometry?.firstMaterial)?.isDoubleSided = true
        (chip.geometry?.firstMaterial)?.lightingModel = .constant
        // Above the die, not in front of it: the tag says what the die shows and
        // must not cover the face that is showing it.
        chip.position = SCNVector3(position.x, 1.6, position.z)
        chip.constraints = [SCNBillboardConstraint()]
        chipsHolder.addChildNode(chip)
        chips[id] = chip
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
