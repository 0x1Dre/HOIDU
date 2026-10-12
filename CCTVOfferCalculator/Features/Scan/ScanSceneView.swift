import SwiftUI
import SceneKit
import simd
import CCTVCore

/// 3D-Ansicht eines Scans. Drehen, Zoomen und Verschieben mit Gesten.
/// Im Platzierungsmodus setzt ein Tipp auf das Modell eine Kamera; ein Tipp auf eine Kamera wählt sie aus.
struct ScanSceneView: UIViewRepresentable {
    let scene: SCNScene
    var placements: [ScanCameraPlacement]
    var numbers: [UUID: Int]
    var selectedID: UUID?
    var isPlacing: Bool
    var onPlace: (_ point: SIMD3<Float>, _ normal: SIMD3<Float>) -> Void
    var onSelect: (UUID?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene
        view.backgroundColor = OstsichtColor.kalk
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true

        let markerRoot = SCNNode()
        markerRoot.name = "markers"
        scene.rootNode.addChildNode(markerRoot)
        context.coordinator.markerRoot = markerRoot

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)

        // Zwei Finger: Ansicht verschieben (ein Finger dreht, Pinch zoomt – von SceneKit).
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        context.coordinator.frameScene(in: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncMarkers()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ScanSceneView
        var markerRoot: SCNNode?
        private var lastSignature: Int?

        init(parent: ScanSceneView) {
            self.parent = parent
        }

        /// Kamera schräg von oben auf das ganze Modell richten.
        func frameScene(in view: SCNView) {
            let (minBox, maxBox) = parent.scene.rootNode.boundingBox
            let center = SCNVector3((minBox.x + maxBox.x) / 2, (minBox.y + maxBox.y) / 2, (minBox.z + maxBox.z) / 2)
            let extent = max(maxBox.x - minBox.x, maxBox.z - minBox.z, 2)
            let camera = SCNCamera()
            camera.zNear = 0.05
            camera.zFar = 500
            camera.fieldOfView = 60
            let node = SCNNode()
            node.camera = camera
            node.position = SCNVector3(center.x, center.y + extent * 0.9, center.z + extent * 0.9)
            node.look(at: center)
            parent.scene.rootNode.addChildNode(node)
            view.pointOfView = node
            view.defaultCameraController.target = center
        }

        func syncMarkers() {
            guard let markerRoot else { return }
            var hasher = Hasher()
            hasher.combine(parent.placements)
            hasher.combine(parent.selectedID)
            hasher.combine(parent.numbers)
            let signature = hasher.finalize()
            guard signature != lastSignature else { return }
            lastSignature = signature

            markerRoot.childNodes.forEach { $0.removeFromParentNode() }
            for placement in parent.placements {
                markerRoot.addChildNode(CameraMarkerNode.make(for: placement, selected: placement.id == parent.selectedID))
            }
        }

        /// Verschiebt Kamera und Drehpunkt gemeinsam in der Bildebene.
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let pointOfView = view.pointOfView else { return }
            let translation = gesture.translation(in: view)
            gesture.setTranslation(.zero, in: view)
            guard translation != .zero else { return }

            let controller = view.defaultCameraController
            let target = SIMD3<Float>(controller.target)
            let distance = max(simd_distance(pointOfView.simdWorldPosition, target), 0.5)
            let fieldOfView = Float(pointOfView.camera?.fieldOfView ?? 60) * .pi / 180
            // Meter pro Bildschirmpunkt in der Entfernung des Drehpunkts.
            let metersPerPoint = 2 * distance * tan(fieldOfView / 2) / Float(max(view.bounds.height, 1))
            let delta = pointOfView.simdWorldRight * (-Float(translation.x) * metersPerPoint)
                + pointOfView.simdWorldUp * (Float(translation.y) * metersPerPoint)

            pointOfView.simdWorldPosition += delta
            controller.target = SCNVector3(target + delta)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let location = gesture.location(in: view)

            let markerHits = view.hitTest(location, options: [
                .categoryBitMask: ScanModelFile.markerCategory,
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            if let node = markerHits.first?.node, let id = CameraMarkerNode.placementID(of: node) {
                parent.onSelect(id)
                return
            }

            guard parent.isPlacing else {
                parent.onSelect(nil)
                return
            }
            let modelHits = view.hitTest(location, options: [
                .categoryBitMask: ScanModelFile.modelCategory,
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: true
            ])
            guard let hit = modelHits.first else { return }
            let point = SIMD3<Float>(hit.worldCoordinates)
            let normal = SIMD3<Float>(hit.worldNormal)
            parent.onPlace(point, normal)
        }
    }
}

/// 3D-Darstellung einer platzierten Kamera mit Blickkegel.
@MainActor
enum CameraMarkerNode {
    private static let prefix = "placement:"

    static func placementID(of node: SCNNode) -> UUID? {
        var current: SCNNode? = node
        while let candidate = current {
            if let name = candidate.name, name.hasPrefix(prefix) {
                return UUID(uuidString: String(name.dropFirst(prefix.count)))
            }
            current = candidate.parent
        }
        return nil
    }

    static func make(for placement: ScanCameraPlacement, selected: Bool) -> SCNNode {
        let root = SCNNode()
        root.name = prefix + placement.id.uuidString
        root.position = SCNVector3(Float(placement.x), Float(placement.y), Float(placement.z))

        // Yaw um die Hochachse (0° = −z, im Uhrzeigersinn von oben gesehen), dann Neigung nach unten.
        let yawNode = SCNNode()
        yawNode.eulerAngles.y = Float(-placement.yawDegrees * .pi / 180)
        root.addChildNode(yawNode)
        let pitchNode = SCNNode()
        pitchNode.eulerAngles.x = Float(-placement.tiltDegrees * .pi / 180)
        yawNode.addChildNode(pitchNode)

        let body = SCNNode(geometry: SCNSphere(radius: 0.09))
        body.geometry?.materials = [material(selected ? OstsichtColor.sonne : OstsichtColor.gruen, lit: true)]
        pitchNode.addChildNode(body)

        let lens = SCNNode(geometry: SCNCylinder(radius: 0.045, height: 0.12))
        lens.geometry?.materials = [material(OstsichtColor.anthrazit, lit: true)]
        lens.eulerAngles.x = .pi / 2
        lens.position = SCNVector3(0, 0, -0.1)
        pitchNode.addChildNode(lens)

        // Blickkegel: Spitze bei der Kamera, Öffnung entlang −z.
        let range = CGFloat(min(placement.rangeMeters, 30))
        let halfAngle = min(placement.fieldOfViewDegrees, 170) / 2 * .pi / 180
        let cone = SCNCone(topRadius: 0, bottomRadius: range * CGFloat(tan(halfAngle)), height: range)
        cone.radialSegmentCount = 36
        cone.materials = [coneMaterial(selected: selected)]
        let coneNode = SCNNode(geometry: cone)
        coneNode.eulerAngles.x = .pi / 2
        coneNode.position = SCNVector3(0, 0, -Float(range) / 2)
        coneNode.renderingOrder = 10
        pitchNode.addChildNode(coneNode)

        root.enumerateHierarchy { node, _ in node.categoryBitMask = ScanModelFile.markerCategory }
        return root
    }

    private static func material(_ color: UIColor, lit: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = lit ? .lambert : .constant
        return material
    }

    private static func coneMaterial(selected: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = OstsichtColor.sonne.withAlphaComponent(selected ? 0.35 : 0.2)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        return material
    }
}
