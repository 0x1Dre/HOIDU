#if !targetEnvironment(simulator)
import SwiftUI
import ARKit
import simd

/// Sammelt erfasste Punkte im Raum, damit beim Scannen sichtbar ist, was schon aufgenommen wurde.
///
/// Quelle ist vor allem die LiDAR-Tiefenkarte jedes Bilds (dicht und genau); ohne Tiefe dienen
/// die Merkmalspunkte von ARKit als Ersatz. Punkte werden in einem Raster (Voxel) zusammengefasst,
/// damit pro Zelle nur ein Punkt bleibt und die Darstellung auch bei langen Scans flüssig bleibt.
@MainActor
final class ScanPointCloud {
    /// Kantenlänge einer Rasterzelle in Metern.
    let voxelSize: Float
    let maxPoints: Int
    private(set) var points: [SIMD3<Float>] = []
    private var occupied = Set<Int64>()
    private var lastFrameTimestamp: TimeInterval = 0
    private var lastDepthSample: TimeInterval = 0

    init(voxelSize: Float = 0.05, maxPoints: Int = 60_000) {
        self.voxelSize = voxelSize
        self.maxPoints = maxPoints
    }

    var count: Int { points.count }

    func reset() {
        points.removeAll(keepingCapacity: true)
        occupied.removeAll(keepingCapacity: true)
        lastFrameTimestamp = 0
        lastDepthSample = 0
    }

    func ingest(_ frame: ARFrame) {
        guard frame.timestamp != lastFrameTimestamp else { return }
        lastFrameTimestamp = frame.timestamp

        if let depth = frame.smoothedSceneDepth ?? frame.sceneDepth {
            guard frame.timestamp - lastDepthSample > 0.12 else { return }
            lastDepthSample = frame.timestamp
            ingestDepth(depth, camera: frame.camera)
        } else if let featurePoints = frame.rawFeaturePoints?.points {
            for point in featurePoints { add(point) }
        }
    }

    /// Wandelt die Tiefenkarte in Weltpunkte um (jedes sechste Pixel, nur sichere Messwerte bis 5 m).
    private func ingestDepth(_ depth: ARDepthData, camera: ARCamera) {
        let map = depth.depthMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let rowBytes = CVPixelBufferGetBytesPerRow(map)

        var confidenceBase: UnsafeMutableRawPointer?
        var confidenceRowBytes = 0
        if let confidence = depth.confidenceMap {
            CVPixelBufferLockBaseAddress(confidence, .readOnly)
            confidenceBase = CVPixelBufferGetBaseAddress(confidence)
            confidenceRowBytes = CVPixelBufferGetBytesPerRow(confidence)
        }
        defer {
            if let confidence = depth.confidenceMap { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        }

        let resolution = camera.imageResolution
        let sx = Float(width) / Float(resolution.width)
        let sy = Float(height) / Float(resolution.height)
        let fx = camera.intrinsics[0][0] * sx, fy = camera.intrinsics[1][1] * sy
        let cx = camera.intrinsics[2][0] * sx, cy = camera.intrinsics[2][1] * sy
        let transform = camera.transform

        let step = 6
        for row in stride(from: 0, to: height, by: step) {
            let depthRow = base.advanced(by: row * rowBytes).assumingMemoryBound(to: Float32.self)
            let confidenceRow = confidenceBase?.advanced(by: row * confidenceRowBytes).assumingMemoryBound(to: UInt8.self)
            for column in stride(from: 0, to: width, by: step) {
                if let confidenceRow, confidenceRow[column] < UInt8(ARConfidenceLevel.medium.rawValue) { continue }
                let d = depthRow[column]
                guard d > 0.2, d < 5 else { continue }
                let x = (Float(column) - cx) / fx * d
                let y = -(Float(row) - cy) / fy * d
                let world = transform * SIMD4<Float>(x, y, -d, 1)
                add(SIMD3(world.x, world.y, world.z))
            }
        }
    }

    private func add(_ point: SIMD3<Float>) {
        guard points.count < maxPoints, point.x.isFinite, point.y.isFinite, point.z.isFinite else { return }
        let cell = (point / voxelSize).rounded(.down)
        // 21 Bit pro Achse reichen für ±50 km bei 5 cm Raster.
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
/// Das Sammeln geschieht in `ScanCaptureData.ingest`; hier wird nur gezeichnet.
struct PointCloudOverlay: View {
    let session: ARSession
    let cloud: ScanPointCloud

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { context, size in
                guard let frame = session.currentFrame else { return }
                let orientation = InterfaceOrientation.current
                let camera = frame.camera
                let projection = camera.projectionMatrix(for: orientation, viewportSize: size, zNear: 0.05, zFar: 50)
                let view = camera.viewMatrix(for: orientation)
                let matrix = projection * view
                let dot: CGFloat = 3.5

                var near = Path()
                var far = Path()
                for point in cloud.points {
                    let clip = matrix * SIMD4<Float>(point.x, point.y, point.z, 1)
                    guard clip.w > 0.05 else { continue }
                    let ndcX = clip.x / clip.w
                    let ndcY = clip.y / clip.w
                    guard abs(ndcX) <= 1, abs(ndcY) <= 1 else { continue }
                    let x = CGFloat(ndcX + 1) / 2 * size.width
                    let y = CGFloat(1 - ndcY) / 2 * size.height
                    // Nahe Punkte etwas grösser, damit Tiefe erkennbar bleibt.
                    let dotSize = clip.w < 1.5 ? dot + 1 : dot
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    if clip.w < 1.5 { near.addEllipse(in: rect) } else { far.addEllipse(in: rect) }
                }
                context.fill(far, with: .color(Color(uiColor: OstsichtColor.gruenHell).opacity(0.85)))
                context.fill(near, with: .color(Color(uiColor: OstsichtColor.gruenHell)))
                context.stroke(near, with: .color(Theme.gruenSolid), lineWidth: 0.7)
                context.stroke(far, with: .color(Theme.gruenSolid.opacity(0.8)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

/// Sammelt während des Scans regelmässig Punkte und Aufnahmen aus der AR-Sitzung.
struct ScanFrameCollector: ViewModifier {
    let data: ScanCaptureData
    let isActive: Bool

    func body(content: Content) -> some View {
        content.task(id: isActive) { @MainActor [data, isActive] in
            guard isActive else { return }
            while !Task.isCancelled {
                data.ingestCurrentFrame()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
#endif
