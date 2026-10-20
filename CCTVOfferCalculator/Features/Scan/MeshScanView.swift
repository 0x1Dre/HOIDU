#if !targetEnvironment(simulator)
import SwiftUI
import ARKit
import Metal
import RealityKit
import simd
import CCTVCore

/// Steuert den freien LiDAR-Scan (Mesh). Funktioniert auch draussen, Reichweite rund 5 m.
@MainActor
@Observable
final class MeshScanController {
    var meshAnchorCount = 0
    var trackingHint: String?
    @ObservationIgnored let arView: ARView
    @ObservationIgnored private let delegateProxy = ARSessionDelegateProxy()

    init() {
        arView = ARView(frame: ScreenSize.bounds, cameraMode: .ar, automaticallyConfigureSession: false)
        delegateProxy.onMeshAnchorsAdded = { [weak self] count in
            self?.meshAnchorCount += count
        }
        delegateProxy.onTrackingHint = { [weak self] hint in
            self?.trackingHint = hint
        }
    }

    func start() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.environmentTexturing = .none
        configuration.planeDetection = [.horizontal, .vertical]
        // Tiefenkarte für dichte Punkte und die Verdeckungsprüfung beim Einfärben
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.renderOptions.insert(.disableMotionBlur)
        // Erfasstes Netz live über dem Kamerabild zeigen (Knoten und Kanten, verdeckt von Wänden)
        arView.debugOptions.insert(.showSceneUnderstanding)
        arView.session.delegate = delegateProxy
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        meshAnchorCount = 0
    }

    func stop() {
        arView.debugOptions.remove(.showSceneUnderstanding)
        arView.session.pause()
    }

    /// Sammelt alle Mesh-Anker als ein Dreiecksnetz in Weltkoordinaten.
    func collectMesh() -> WorldMesh {
        let anchors = arView.session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
        var mesh = WorldMesh()
        for anchor in anchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let normalMatrix = simd_float3x3(
                SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
                SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
                SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
            )
            let base = UInt32(mesh.vertices.count)

            let vertices = geometry.vertices
            let normals = geometry.normals
            for index in 0..<vertices.count {
                let local = Self.float3(vertices, index)
                let world = transform * SIMD4(local.x, local.y, local.z, 1)
                mesh.vertices.append(SIMD3(world.x, world.y, world.z))
                let normal = index < normals.count ? Self.float3(normals, index) : SIMD3<Float>(0, 1, 0)
                mesh.normals.append(simd_normalize(normalMatrix * normal))
            }

            let faces = geometry.faces
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let pointer = faces.buffer.contents()
            for i in 0..<indexCount {
                let value: UInt32
                if faces.bytesPerIndex == 2 {
                    value = UInt32(pointer.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self))
                } else {
                    value = pointer.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self)
                }
                mesh.indices.append(base + value)
            }
        }
        return mesh
    }

    private static func float3(_ source: ARGeometrySource, _ index: Int) -> SIMD3<Float> {
        // Daten liegen als drei gepackte Floats (12 Byte) vor; SIMD3<Float> belegt 16 Byte.
        let offset = source.offset + source.stride * index
        let pointer = source.buffer.contents()
        return SIMD3(
            pointer.loadUnaligned(fromByteOffset: offset, as: Float.self),
            pointer.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
            pointer.loadUnaligned(fromByteOffset: offset + 8, as: Float.self)
        )
    }

}

/// Empfängt die Rückmeldungen der AR-Sitzung (Delegate ohne Actor-Bindung) und leitet sie an den Main Actor weiter.
final class ARSessionDelegateProxy: NSObject, ARSessionDelegate {
    var onMeshAnchorsAdded: (@MainActor (Int) -> Void)?
    var onTrackingHint: (@MainActor (String?) -> Void)?

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let added = anchors.filter { $0 is ARMeshAnchor }.count
        guard added > 0, let callback = onMeshAnchorsAdded else { return }
        MainActor.assumeIsolated { callback(added) }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let hint: String?
        switch camera.trackingState {
        case .normal: hint = nil
        case .notAvailable: hint = "Tracking nicht verfügbar"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion: hint = "Langsamer bewegen"
            case .insufficientFeatures: hint = "Zu wenig Details – auf strukturierte Flächen richten"
            case .initializing, .relocalizing: hint = "Wird gestartet …"
            @unknown default: hint = "Eingeschränktes Tracking"
            }
        }
        guard let callback = onTrackingHint else { return }
        MainActor.assumeIsolated { callback(hint) }
    }
}

/// Schaltet die Punktedarstellung beim Scannen ein und aus.
struct PointsToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? "circle.grid.3x3.fill" : "circle.grid.3x3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isOn ? Theme.gruen : Theme.grau)
                .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
        }
        .accessibilityLabel(isOn ? "Erfasste Punkte ausblenden" : "Erfasste Punkte anzeigen")
    }
}

private struct ARViewContainer: UIViewRepresentable {
    let controller: MeshScanController

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: ScreenSize.bounds)
        container.backgroundColor = .black
        let view = controller.arView
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Vollbild-Scan der Umgebung (auch aussen).
struct MeshScanScreen: View {
    let onComplete: (SiteScanRecord) -> Void
    let onCancel: () -> Void

    /// Wird erst beim Erscheinen erzeugt, damit SwiftUI keine überzähligen AR-Ansichten anlegt.
    @State private var controller: MeshScanController?
    @State private var isRunning = false
    @State private var captureData = ScanCaptureData()
    /// Das Netz zeigt die Erfassung bereits; Punkte sind zusätzlich zuschaltbar.
    @State private var showPoints = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let controller {
                ARViewContainer(controller: controller)
                    .ignoresSafeArea()

                if showPoints, isRunning {
                    PointCloudOverlay(session: controller.arView.session, cloud: captureData.cloud)
                        .ignoresSafeArea()
                }

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button("Abbrechen") {
                            controller.stop()
                            onCancel()
                        }
                        .buttonStyle(.secondaryAction)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                        Spacer()
                        if isRunning {
                            PointCountBadge(cloud: captureData.cloud)
                            PointsToggle(isOn: $showPoints)
                        }
                    }
                    if isRunning {
                        HStack {
                            Spacer()
                            ScanCoverageMap(cloud: captureData.cloud)
                        }
                    }
                    if isRunning, let hint = controller.trackingHint {
                        Text(hint)
                            .font(.brand(.subheadline))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.smallRadius))
                    }
                    Spacer()
                    bottomPanel(controller)
                }
                .padding()
            }

            if isSaving {
                ProgressView("Modell wird erstellt …")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .onAppear {
            if controller == nil { controller = MeshScanController() }
        }
        .onDisappear { controller?.stop() }
        .modifier(ScanFrameCollector(data: captureData, isActive: isRunning))
        .alert("Scan fehlgeschlagen", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func bottomPanel(_ controller: MeshScanController) -> some View {
        if isRunning {
            VStack(spacing: 10) {
                Text("Langsam über Boden, Wände und Objekte schwenken, bis alles vom Netz bedeckt ist. Abstand höchstens 5 m.")
                    .font(.brand(.subheadline))
                    .multilineTextAlignment(.center)
                if showPoints { ScanPointLegend() }
                Button {
                    save(controller)
                } label: {
                    Label("Scan beenden", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .disabled(controller.meshAnchorCount == 0 || isSaving)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Umgebung scannen").font(.brand(.title3))
                VStack(alignment: .leading, spacing: 6) {
                    Label("Funktioniert auch draussen, Reichweite rund 5 m.", systemImage: "sun.max")
                    Label("Langsam gehen und das iPhone ruhig über Boden, Fassade und Objekte führen.", systemImage: "figure.walk")
                    Label("Das Netz zeigt, was schon erfasst ist. Stellen ohne Netz fehlen noch.", systemImage: "circle.grid.3x3.fill")
                    Label("Die Karte oben rechts zeigt die erfasste Fläche von oben.", systemImage: "map")
                }
                .font(.brand(.subheadline))
                Button {
                    start(controller)
                } label: {
                    Label("Scan starten", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private func start(_ controller: MeshScanController) {
        captureData.reset()
        captureData.session = controller.arView.session
        controller.start()
        isRunning = true
    }

    private func save(_ controller: MeshScanController) {
        isSaving = true
        let collected = controller.collectMesh()
        let keyframes = captureData.keyframes.keyframes
        let textured = keyframes.filter(\.hasTexture)
        controller.stop()
        isRunning = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            do {
                var mesh = collected
                guard !mesh.isEmpty else { throw ScanError.emptyScan }
                if !textured.isEmpty {
                    let vertices = mesh.vertices, normals = mesh.normals
                    mesh.colors = await Task.detached(priority: .userInitiated) {
                        ScanTexturing.vertexColors(vertices: vertices, normals: normals, sampler: KeyframeSampler(keyframes: textured))
                    }.value
                }
                let data = try ScanModelFile.data(from: mesh.makeScene())
                let photos = ScanTexturing.photos(from: keyframes)
                let record = SiteScanRecord(kind: .umgebung, modelData: data, floorPlan: mesh.makeFloorPlan(),
                                            photos: photos.photos, photoPoses: photos.poses)
                isSaving = false
                onComplete(record)
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
