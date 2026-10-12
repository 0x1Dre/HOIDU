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
        arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
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
        arView.renderOptions.insert(.disableMotionBlur)
        arView.session.delegate = delegateProxy
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        meshAnchorCount = 0
    }

    func stop() {
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

    func makeUIView(context: Context) -> ARView { controller.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

/// Vollbild-Scan der Umgebung (auch aussen).
struct MeshScanScreen: View {
    let onComplete: (SiteScanRecord) -> Void
    let onCancel: () -> Void

    @State private var controller = MeshScanController()
    @State private var pointCloud = ScanPointCloud()
    @State private var showPoints = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ARViewContainer(controller: controller)
                .ignoresSafeArea()

            if showPoints {
                PointCloudOverlay(session: controller.arView.session, cloud: pointCloud)
                    .ignoresSafeArea()
            }

            VStack(spacing: 12) {
                HStack {
                    Button("Abbrechen") {
                        controller.stop()
                        onCancel()
                    }
                    .buttonStyle(.secondaryAction)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                    Spacer()
                    PointsToggle(isOn: $showPoints)
                    Text("\(controller.meshAnchorCount) Abschnitte")
                        .font(.brand(.footnote).monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.smallRadius))
                }
                if let hint = controller.trackingHint {
                    Text(hint)
                        .font(.brand(.subheadline))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.smallRadius))
                }
                Spacer()
                VStack(spacing: 10) {
                    Text("Bewegen Sie das iPhone langsam über Boden, Wände und Objekte. Abstand höchstens 5 m.")
                        .font(.brand(.subheadline))
                        .multilineTextAlignment(.center)
                    Button {
                        save()
                    } label: {
                        Label("Fertig", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                    .disabled(controller.meshAnchorCount == 0 || isSaving)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .padding()

            if isSaving {
                ProgressView("Modell wird erstellt …")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
        .alert("Scan fehlgeschlagen", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        isSaving = true
        let mesh = controller.collectMesh()
        controller.stop()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            do {
                guard !mesh.isEmpty else { throw ScanError.emptyScan }
                let data = try ScanModelFile.data(from: mesh.makeScene())
                let record = SiteScanRecord(kind: .umgebung, modelData: data, floorPlan: mesh.makeFloorPlan())
                isSaving = false
                onComplete(record)
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                pointCloud.reset()
                controller.start()
            }
        }
    }
}
#endif
