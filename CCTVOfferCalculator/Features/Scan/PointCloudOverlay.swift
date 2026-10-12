#if !targetEnvironment(simulator)
import SwiftUI
import ARKit
import simd

/// Sammelt erfasste Punkte im Raum, damit beim Scannen sichtbar ist, was schon aufgenommen wurde.
///
/// Punkte werden in einem Raster (Voxel) zusammengefasst, damit pro Zelle nur ein Punkt bleibt
/// und die Darstellung auch bei langen Scans flüssig bleibt.
@MainActor
final class ScanPointCloud {
    /// Kantenlänge einer Rasterzelle in Metern.
    let voxelSize: Float
    let maxPoints: Int
    private(set) var points: [SIMD3<Float>] = []
    private var occupied = Set<Int64>()
    private var lastFrameTimestamp: TimeInterval = 0
    private var lastMeshSample: TimeInterval = 0

    init(voxelSize: Float = 0.06, maxPoints: Int = 40_000) {
        self.voxelSize = voxelSize
        self.maxPoints = maxPoints
    }

    var count: Int { points.count }

    func reset() {
        points.removeAll(keepingCapacity: true)
        occupied.removeAll(keepingCapacity: true)
        lastFrameTimestamp = 0
        lastMeshSample = 0
    }

    /// Übernimmt Merkmalspunkte des aktuellen Bilds und – falls vorhanden – Punkte aus dem LiDAR-Netz.
    func ingest(_ frame: ARFrame) {
        guard frame.timestamp != lastFrameTimestamp else { return }
        lastFrameTimestamp = frame.timestamp

        if let featurePoints = frame.rawFeaturePoints?.points {
            for point in featurePoints { add(point) }
        }

        // Das LiDAR-Netz ist dicht; höchstens zweimal pro Sekunde auswerten.
        guard frame.timestamp - lastMeshSample > 0.5 else { return }
        lastMeshSample = frame.timestamp
        for anchor in frame.anchors {
            guard let mesh = anchor as? ARMeshAnchor else { continue }
            let vertices = mesh.geometry.vertices
            let pointer = vertices.buffer.contents()
            let transform = mesh.transform
            // Jeden dritten Vertex nehmen; das Raster dünnt zusätzlich aus.
            var index = 0
            while index < vertices.count {
                let offset = vertices.offset + vertices.stride * index
                let local = SIMD4<Float>(
                    pointer.loadUnaligned(fromByteOffset: offset, as: Float.self),
                    pointer.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                    pointer.loadUnaligned(fromByteOffset: offset + 8, as: Float.self),
                    1
                )
                let world = transform * local
                add(SIMD3(world.x, world.y, world.z))
                index += 3
            }
        }
    }

    private func add(_ point: SIMD3<Float>) {
        guard points.count < maxPoints, point.x.isFinite, point.y.isFinite, point.z.isFinite else { return }
        let cell = (point / voxelSize).rounded(.down)
        // 21 Bit pro Achse reichen für ±60 km bei 6 cm Raster.
        let x = Int64(Int32(clamping: Int(cell.x))) & 0x1FFFFF
        let y = Int64(Int32(clamping: Int(cell.y))) & 0x1FFFFF
        let z = Int64(Int32(clamping: Int(cell.z))) & 0x1FFFFF
        let key = (x << 42) | (y << 21) | z
        if occupied.insert(key).inserted {
            points.append(point)
        }
    }
}

/// Zeichnet die gesammelten Punkte über das Kamerabild. Durchlässig für Berührungen.
struct PointCloudOverlay: View {
    let session: ARSession
    let cloud: ScanPointCloud

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { _ in
            Canvas { context, size in
                guard let frame = session.currentFrame else { return }
                cloud.ingest(frame)

                let orientation = Self.interfaceOrientation
                let camera = frame.camera
                let projection = camera.projectionMatrix(for: orientation, viewportSize: size, zNear: 0.05, zFar: 50)
                let view = camera.viewMatrix(for: orientation)
                let matrix = projection * view
                let dot: CGFloat = 3

                var path = Path()
                for point in cloud.points {
                    let clip = matrix * SIMD4<Float>(point.x, point.y, point.z, 1)
                    guard clip.w > 0.05 else { continue }
                    let ndcX = clip.x / clip.w
                    let ndcY = clip.y / clip.w
                    guard abs(ndcX) <= 1, abs(ndcY) <= 1 else { continue }
                    let x = CGFloat(ndcX + 1) / 2 * size.width
                    let y = CGFloat(1 - ndcY) / 2 * size.height
                    path.addRect(CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot))
                }
                context.fill(path, with: .color(Color(uiColor: OstsichtColor.gruenHell).opacity(0.9)))
                context.fill(path.strokedPath(StrokeStyle(lineWidth: 0.6)), with: .color(Theme.gruenSolid))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @MainActor
    private static var interfaceOrientation: UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.effectiveGeometry.interfaceOrientation ?? .portrait
    }
}
/// Anzahl erfasster Punkte; 0 bedeutet, dass die Kamera noch keine Tiefendaten liefert.
struct PointCountBadge: View {
    let cloud: ScanPointCloud

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            Label("\(cloud.count)", systemImage: "circle.grid.3x3.fill")
                .font(.brand(.footnote).monospacedDigit())
                .padding(.horizontal, 10)
                .frame(minHeight: Theme.minimumTouchTarget)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                .accessibilityLabel("\(cloud.count) Punkte erfasst")
        }
    }
}
#endif
