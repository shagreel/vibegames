import SceneKit
import SwiftUI

/// The table, as a view.
struct DiceTableView: UIViewRepresentable {
    let table: DiceTable

    func makeUIView(context: Context) -> DiceTableSceneView {
        let view = DiceTableSceneView()
        view.table = table
        view.scene = table.scene
        view.pointOfView = table.cameraNode
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.delegate = view
        view.accessibilityIdentifier = "dice.tableView"
        table.view = view
        view.rest()
        return view
    }

    func updateUIView(_ view: DiceTableSceneView, context: Context) {
        view.accessibilityValue = table.isEmpty ? "No dice" : "\(table.count) dice"
        view.refreshAccessibility()
    }
}

/// The SceneKit view, with one job beyond drawing: telling the table when the
/// simulation is still, and answering what is on the table for VoiceOver.
final class DiceTableSceneView: SCNView, SCNSceneRendererDelegate {
    weak var table: DiceTable?

    /// Built when the dice change rather than every time VoiceOver — or a UI
    /// test — asks, which in a render loop is many times a second.
    private var elements: [UIAccessibilityElement] = []

    override var accessibilityElements: [Any]? {
        get { elements }
        set { _ = newValue }
    }

    func refreshAccessibility() {
        elements = table?.makeAccessibilityElements(in: self) ?? []
    }

    /// Something is in the air: draw every frame and keep the tree current.
    func wake() {
        isPlaying = true
        refreshAccessibility()
    }

    /// Everything has landed: draw one last frame, then stop until the next
    /// throw, and rebuild what VoiceOver can find.
    func rest() {
        refreshAccessibility()
        isPlaying = false
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        table?.settleIfQuiet(atTime: time)
    }
}
