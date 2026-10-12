#if canImport(RoomPlan) && !targetEnvironment(simulator)
import SwiftUI
import RoomPlan
import SceneKit
import simd
import CCTVCore

// MARK: - Erfassung

/// Steuert den RoomPlan-Scan. Die `RoomCaptureView` zeigt das Kamerabild mit dem wachsenden 3D-Modell.
@MainActor
@Observable
final class RoomScanController {
    enum Phase {
        case scanning
        case processing
        case review(CapturedRoom)
        case failed(String)
    }

    var phase: Phase = .scanning
    @ObservationIgnored let captureView: RoomCaptureView
    @ObservationIgnored private let delegateProxy = RoomCaptureDelegateProxy()

    init() {
        captureView = RoomCaptureView(frame: .zero)
        captureView.delegate = delegateProxy
        delegateProxy.onResult = { [weak self] room, error in
            guard let self else { return }
            if let error {
                self.phase = .failed(error)
            } else if let room {
                self.phase = .review(room)
            }
        }
    }

    func start() {
        phase = .scanning
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    func finish() {
        phase = .processing
        captureView.captureSession.stop()
    }

    func cancel() {
        captureView.captureSession.stop()
    }
}

/// Empfängt die Rückmeldungen der `RoomCaptureView` (Delegate ohne Actor-Bindung).
final class RoomCaptureDelegateProxy: NSObject, RoomCaptureViewDelegate {
    var onResult: (@MainActor (CapturedRoom?, String?) -> Void)?

    override init() {
        super.init()
    }

    // RoomCaptureViewDelegate erbt von NSCoding; das Objekt wird nie archiviert.
    required init?(coder: NSCoder) {
        return nil
    }

    func encode(with coder: NSCoder) {}

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (any Error)?) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        guard let callback = onResult else { return }
        let message = error?.localizedDescription
        let room = message == nil ? processedResult : nil
        MainActor.assumeIsolated {
            callback(room, message)
        }
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    let controller: RoomScanController

    func makeUIView(context: Context) -> RoomCaptureView { controller.captureView }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}

/// Vollbild-Scan eines Innenraums.
struct RoomScanScreen: View {
    let onComplete: (SiteScanRecord) -> Void
    let onCancel: () -> Void

    @State private var controller = RoomScanController()
    @State private var pointCloud = ScanPointCloud()
    @State private var showPoints = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            RoomCaptureContainer(controller: controller)
                .ignoresSafeArea()

            if showPoints, case .scanning = controller.phase {
                PointCloudOverlay(session: controller.captureView.captureSession.arSession, cloud: pointCloud)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Abbrechen") {
                        controller.cancel()
                        onCancel()
                    }
                    .buttonStyle(.secondaryAction)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                    Spacer()
                    PointsToggle(isOn: $showPoints)
                }
                Spacer()
                bottomPanel
            }
            .padding()

            if isSaving {
                ProgressView("Modell wird erstellt …")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .onAppear { controller.start() }
        .alert("Scan fehlgeschlagen", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { onCancel() }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        switch controller.phase {
        case .scanning:
            VStack(spacing: 10) {
                Text("Gehen Sie langsam durch den Raum und richten Sie das iPhone auf Wände, Türen und Fenster.")
                    .font(.brand(.subheadline))
                    .multilineTextAlignment(.center)
                Button {
                    controller.finish()
                } label: {
                    Label("Fertig", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        case .processing:
            ProgressView("Raum wird ausgewertet …")
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        case .review(let room):
            HStack(spacing: 12) {
                Button {
                    pointCloud.reset()
                    controller.start()
                } label: {
                    Label("Neu", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaryAction)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                Button {
                    save(room)
                } label: {
                    Label("Übernehmen", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .disabled(isSaving)
            }
        case .failed(let message):
            Text(message)
                .font(.brand(.subheadline))
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private func save(_ room: CapturedRoom) {
        isSaving = true
        Task { @MainActor in
            // Kurz warten, damit die Fortschrittsanzeige erscheint.
            try? await Task.sleep(for: .milliseconds(80))
            do {
                let record = try RoomModelBuilder.record(from: room)
                isSaving = false
                onComplete(record)
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Modell und Grundriss aus RoomPlan

@MainActor
enum RoomModelBuilder {
    static func record(from room: CapturedRoom) throws -> SiteScanRecord {
        guard !room.walls.isEmpty else { throw ScanError.emptyScan }
        let scene = makeScene(room)
        let data = try ScanModelFile.data(from: scene)
        return SiteScanRecord(kind: .raum, modelData: data, floorPlan: makeFloorPlan(room))
    }

    // MARK: 3D

    static func makeScene(_ room: CapturedRoom) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        for floor in room.floors {
            let node: SCNNode
            if floor.polygonCorners.count >= 3 {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: CGFloat(floor.polygonCorners[0].x), y: CGFloat(floor.polygonCorners[0].y)))
                for corner in floor.polygonCorners.dropFirst() {
                    path.addLine(to: CGPoint(x: CGFloat(corner.x), y: CGFloat(corner.y)))
                }
                path.close()
                node = SCNNode(geometry: SCNShape(path: path, extrusionDepth: 0.02))
            } else {
                node = SCNNode(geometry: SCNBox(width: CGFloat(floor.dimensions.x), height: CGFloat(floor.dimensions.y), length: 0.02, chamferRadius: 0))
            }
            node.geometry?.materials = [material(OstsichtColor.kalk)]
            node.simdTransform = floor.transform
            root.addChildNode(node)
        }

        for wall in room.walls {
            root.addChildNode(box(wall.dimensions.x, wall.dimensions.y, 0.1, transform: wall.transform, color: UIColor(hex: 0xEFECE4)))
        }
        for door in room.doors {
            root.addChildNode(box(door.dimensions.x, door.dimensions.y, 0.14, transform: door.transform, color: OstsichtColor.gruen.withAlphaComponent(0.75)))
        }
        for window in room.windows {
            root.addChildNode(box(window.dimensions.x, window.dimensions.y, 0.14, transform: window.transform, color: UIColor(hex: 0xA9C7D8).withAlphaComponent(0.7)))
        }
        for object in room.objects {
            root.addChildNode(box(object.dimensions.x, object.dimensions.y, object.dimensions.z, transform: object.transform, color: UIColor(hex: 0xCFCBBF)))
        }

        root.enumerateHierarchy { node, _ in node.categoryBitMask = ScanModelFile.modelCategory }
        return scene
    }

    private static func box(_ width: Float, _ height: Float, _ length: Float, transform: simd_float4x4, color: UIColor) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(max(width, 0.01)), height: CGFloat(max(height, 0.01)), length: CGFloat(max(length, 0.01)), chamferRadius: 0)
        geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry)
        node.simdTransform = transform
        return node
    }

    private static func material(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        material.isDoubleSided = true
        return material
    }

    // MARK: Grundriss

    nonisolated private static func world(_ transform: simd_float4x4, _ point: SIMD3<Float>) -> SIMD3<Float> {
        let v = transform * SIMD4<Float>(point.x, point.y, point.z, 1)
        return SIMD3(v.x, v.y, v.z)
    }

    /// Endpunkte einer senkrechten Fläche (Wand, Tür, Fenster) in Weltkoordinaten.
    nonisolated private static func endpoints(_ surface: CapturedRoom.Surface) -> (SIMD3<Float>, SIMD3<Float>) {
        let half = surface.dimensions.x / 2
        return (world(surface.transform, SIMD3(-half, 0, 0)), world(surface.transform, SIMD3(half, 0, 0)))
    }

    nonisolated private static func footprint(_ object: CapturedRoom.Object) -> [SIMD3<Float>] {
        let dx = object.dimensions.x / 2, dz = object.dimensions.z / 2
        return [SIMD3(-dx, 0, -dz), SIMD3(dx, 0, -dz), SIMD3(dx, 0, dz), SIMD3(-dx, 0, dz)].map { world(object.transform, $0) }
    }

    nonisolated private static func floorPolygon(_ floor: CapturedRoom.Surface) -> [SIMD3<Float>] {
        if floor.polygonCorners.count >= 3 {
            return floor.polygonCorners.map { world(floor.transform, $0) }
        }
        let dx = floor.dimensions.x / 2, dy = floor.dimensions.y / 2
        return [SIMD3(-dx, -dy, 0), SIMD3(dx, -dy, 0), SIMD3(dx, dy, 0), SIMD3(-dx, dy, 0)].map { world(floor.transform, $0) }
    }

    static func makeFloorPlan(_ room: CapturedRoom) -> ScanFloorPlan? {
        var points: [SIMD3<Float>] = []
        for wall in room.walls {
            let (a, b) = endpoints(wall)
            points += [a, b]
        }
        for object in room.objects { points += footprint(object) }
        for floor in room.floors { points += floorPolygon(floor) }
        guard let first = points.first else { return nil }

        var minX = first.x, maxX = first.x, minZ = first.z, maxZ = first.z
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minZ = min(minZ, p.z); maxZ = max(maxZ, p.z)
        }
        let bounds = ScanBounds(minX: Double(minX), maxX: Double(maxX), minZ: Double(minZ), maxZ: Double(maxZ)).padded(by: 0.6)

        return FloorPlanRasterizer.render(bounds: bounds) { cg, map, scale in
            func point(_ p: SIMD3<Float>) -> CGPoint { map(Double(p.x), Double(p.z)) }
            func polygon(_ corners: [SIMD3<Float>]) -> CGPath {
                let path = CGMutablePath()
                guard let first = corners.first else { return path }
                path.move(to: point(first))
                for corner in corners.dropFirst() { path.addLine(to: point(corner)) }
                path.closeSubpath()
                return path
            }
            func segment(_ surface: CapturedRoom.Surface, width: CGFloat, color: UIColor) {
                let (a, b) = endpoints(surface)
                cg.move(to: point(a))
                cg.addLine(to: point(b))
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(width)
                cg.setLineCap(.butt)
                cg.strokePath()
            }

            let wallWidth = max(4, 0.12 * scale)

            // Boden
            for floor in room.floors {
                cg.addPath(polygon(floorPolygon(floor)))
                cg.setFillColor(OstsichtColor.kalk.cgColor)
                cg.fillPath()
            }

            // Möbel und Objekte
            for object in room.objects {
                cg.addPath(polygon(footprint(object)))
                cg.setFillColor(UIColor(hex: 0xE6E3DA).cgColor)
                cg.setStrokeColor(OstsichtColor.grau.withAlphaComponent(0.6).cgColor)
                cg.setLineWidth(max(1, 0.02 * scale))
                cg.drawPath(using: .fillStroke)
            }

            // Wände
            for wall in room.walls {
                let (a, b) = endpoints(wall)
                cg.move(to: point(a))
                cg.addLine(to: point(b))
                cg.setStrokeColor(OstsichtColor.anthrazit.cgColor)
                cg.setLineWidth(wallWidth)
                cg.setLineCap(.square)
                cg.strokePath()
            }

            // Öffnungen: Lücke in der Wand
            for opening in room.openings {
                segment(opening, width: wallWidth + 2, color: .white)
            }

            // Fenster: graue Doppellinie
            for window in room.windows {
                segment(window, width: wallWidth, color: OstsichtColor.grau)
                segment(window, width: wallWidth * 0.45, color: .white)
            }

            // Türen: Lücke, Türblatt und Öffnungsbogen
            for door in room.doors {
                segment(door, width: wallWidth + 2, color: .white)
                let (a, b) = endpoints(door)
                let along = SIMD2<Float>(b.x - a.x, b.z - a.z)
                let length = simd_length(along)
                guard length > 0.05 else { continue }
                let u = along / length
                let normalColumn = door.transform.columns.2
                var n = simd_normalize(SIMD2<Float>(normalColumn.x, normalColumn.z))
                if !n.x.isFinite { n = SIMD2(-u.y, u.x) }
                let hinge = SIMD2<Float>(a.x, a.z)
                let path = CGMutablePath()
                path.move(to: map(Double(hinge.x), Double(hinge.y)))
                let leaf = hinge + n * length
                path.addLine(to: map(Double(leaf.x), Double(leaf.y)))
                for step in 0...16 {
                    let angle = Float.pi / 2 * (1 - Float(step) / 16)
                    let p = hinge + length * (cos(angle) * u + sin(angle) * n)
                    path.addLine(to: map(Double(p.x), Double(p.y)))
                }
                cg.addPath(path)
                cg.setStrokeColor(OstsichtColor.gruen.cgColor)
                cg.setLineWidth(max(1.5, 0.02 * scale))
                cg.setLineCap(.round)
                cg.strokePath()
            }
        }
    }
}
#endif
