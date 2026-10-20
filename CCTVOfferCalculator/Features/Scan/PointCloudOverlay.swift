#if !targetEnvironment(simulator)
import SwiftUI
import ARKit
import simd

/// Sammelt erfasste Punkte im Raum, damit beim Scannen sichtbar ist, was schon aufgenommen wurde.
///
/// Quelle ist vor allem die LiDAR-Tiefenkarte jedes Bilds (dicht und genau); ohne Tiefe dienen
/// die Merkmalspunkte von ARKit als Ersatz. Punkte werden in einem Raster (Voxel) zusammengefasst:
/// pro Zelle bleibt ein Punkt, und es wird gezählt, wie oft die Zelle gesehen wurde. Selten gesehene
/// Stellen sind noch unsicher und werden orange gezeigt, damit man dort nochmals hinschwenkt.
@MainActor
final class ScanPointCloud {
    /// Ab so vielen Messungen gilt eine Stelle als sicher erfasst.
    static let confidentHits: UInt8 = 4
    /// Ab so vielen Punkten pro Säule zeigt die Übersichtskarte eine Wand bzw. ein Objekt.
    static let wallColumnPoints: UInt16 = 40

    /// Kantenlänge einer Rasterzelle in Metern.
    let voxelSize: Float
    let maxPoints: Int
    /// Rastergrösse der Übersichtskarte (von oben) in Metern.
    let columnSize: Float = 0.2

    private(set) var points: [SIMD3<Float>] = []
    /// Wie oft jeder Punkt gemessen wurde (höchstens 255).
    private(set) var hits: [UInt8] = []
    /// Anzahl Punkte je Säule (x/z) für die Übersichtskarte.
    private(set) var columns: [Int64: UInt16] = [:]
    /// Gerätestandort und Blickrichtung (Winkel in der x/z-Ebene) beim letzten Bild.
    private(set) var devicePosition: SIMD3<Float>?
    private(set) var deviceHeading: Float = 0
    private(set) var isFull = false

    private var index: [Int64: Int32] = [:]
    private var lastFrameTimestamp: TimeInterval = 0
    private var lastDepthSample: TimeInterval = 0

    init(voxelSize: Float = 0.05, maxPoints: Int = 250_000) {
        self.voxelSize = voxelSize
        self.maxPoints = maxPoints
    }

    var count: Int { points.count }

    /// Anteil der sicher erfassten Punkte (0…1).
    var confidentShare: Double {
        guard !hits.isEmpty else { return 0 }
        let confident = hits.reduce(into: 0) { if $1 >= Self.confidentHits { $0 += 1 } }
        return Double(confident) / Double(hits.count)
    }

    func reset() {
        points.removeAll(keepingCapacity: true)
        hits.removeAll(keepingCapacity: true)
        index.removeAll(keepingCapacity: true)
        columns.removeAll(keepingCapacity: true)
        devicePosition = nil
        deviceHeading = 0
        isFull = false
        lastFrameTimestamp = 0
        lastDepthSample = 0
    }

    func ingest(_ frame: ARFrame) {
        guard frame.timestamp != lastFrameTimestamp else { return }
        lastFrameTimestamp = frame.timestamp

        let transform = frame.camera.transform
        devicePosition = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forward = -SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        if abs(forward.x) + abs(forward.z) > 0.05 {
            deviceHeading = atan2(forward.z, forward.x)
        }

        // Bei unruhigem Tracking keine Punkte sammeln, sonst entstehen falsche Stellen.
        guard case .normal = frame.camera.trackingState else { return }

        if let depth = frame.smoothedSceneDepth ?? frame.sceneDepth {
            guard frame.timestamp - lastDepthSample > 0.12 else { return }
            lastDepthSample = frame.timestamp
            ingestDepth(depth, camera: frame.camera)
        } else if let featurePoints = frame.rawFeaturePoints?.points {
            for point in featurePoints { add(point) }
        }
    }

    /// Wandelt die Tiefenkarte in Weltpunkte um (jedes fünfte Pixel, nur sichere Messwerte bis 5 m).
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

        let step = 5
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
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              abs(point.x) < 10_000, abs(point.y) < 10_000, abs(point.z) < 10_000 else { return }
        let cell = (point / voxelSize).rounded(.down)
        // 21 Bit pro Achse reichen für ±50 km bei 5 cm Raster.
        let x = Int64(Int32(cell.x)) & 0x1FFFFF
        let y = Int64(Int32(cell.y)) & 0x1FFFFF
        let z = Int64(Int32(cell.z)) & 0x1FFFFF
        let key = (x << 42) | (y << 21) | z

        if let existing = index[key] {
            let i = Int(existing)
            if hits[i] < 255 { hits[i] += 1 }
            return
        }
        guard points.count < maxPoints else {
            isFull = true
            return
        }
        index[key] = Int32(points.count)
        points.append(point)
        hits.append(1)

        let columnKey = Self.columnKey(x: Int32((point.x / columnSize).rounded(.down)),
                                       z: Int32((point.z / columnSize).rounded(.down)))
        let current = columns[columnKey] ?? 0
        if current < .max { columns[columnKey] = current + 1 }
    }

    nonisolated static func columnKey(x: Int32, z: Int32) -> Int64 {
        (Int64(x) << 32) | Int64(UInt32(bitPattern: z))
    }

    nonisolated static func column(from key: Int64) -> (x: Int32, z: Int32) {
        (Int32(truncatingIfNeeded: key >> 32), Int32(bitPattern: UInt32(truncatingIfNeeded: key)))
    }
}

/// Aktuelle LiDAR-Tiefe, um Punkte hinter Wänden und Möbeln auszublenden.
private struct DepthOcclusion {
    let values: [Float]
    let width: Int
    let height: Int
    let fx: Float, fy: Float, cx: Float, cy: Float
    let worldToCamera: simd_float4x4

    init?(frame: ARFrame) {
        guard let map = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap else { return nil }
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let rowBytes = CVPixelBufferGetBytesPerRow(map)
        var values = [Float](repeating: 0, count: width * height)
        values.withUnsafeMutableBytes { target in
            guard let destination = target.baseAddress else { return }
            for row in 0..<height {
                memcpy(destination.advanced(by: row * width * MemoryLayout<Float>.size),
                       base.advanced(by: row * rowBytes),
                       width * MemoryLayout<Float>.size)
            }
        }
        let resolution = frame.camera.imageResolution
        let sx = Float(width) / Float(resolution.width)
        let sy = Float(height) / Float(resolution.height)
        let intrinsics = frame.camera.intrinsics
        self.values = values
        self.width = width
        self.height = height
        self.fx = intrinsics[0][0] * sx
        self.fy = intrinsics[1][1] * sy
        self.cx = intrinsics[2][0] * sx
        self.cy = intrinsics[2][1] * sy
        self.worldToCamera = frame.camera.transform.inverse
    }

    /// `true`, wenn vor dem Punkt etwas Näheres gemessen wurde.
    func hides(_ point: SIMD3<Float>) -> Bool {
        let c = worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        let distance = -c.z
        guard distance > 0.1 else { return true }
        let u = Int(fx * c.x / distance + cx)
        let v = Int(-fy * c.y / distance + cy)
        guard u >= 0, v >= 0, u < width, v < height else { return false }
        let measured = values[v * width + u]
        guard measured > 0 else { return false }
        return distance > measured + 0.15
    }
}

/// Zeichnet die gesammelten Punkte über das Kamerabild: grün = sicher erfasst, orange = nochmals hinschwenken.
/// Punkte hinter Wänden werden ausgeblendet, damit nur die sichtbaren Flächen markiert sind.
/// Das Sammeln geschieht in `ScanCaptureData.ingest`; hier wird nur gezeichnet.
struct PointCloudOverlay: View {
    let session: ARSession
    let cloud: ScanPointCloud

    static let confidentColor = Color(uiColor: UIColor(hex: 0x5BBF86))
    static let unsureColor = Color(uiColor: OstsichtColor.sonne)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { _ in
            Canvas { context, size in
                guard let frame = session.currentFrame else { return }
                let orientation = InterfaceOrientation.current
                let camera = frame.camera
                let projection = camera.projectionMatrix(for: orientation, viewportSize: size, zNear: 0.05, zFar: 50)
                let matrix = projection * camera.viewMatrix(for: orientation)
                let occlusion = DepthOcclusion(frame: frame)
                let points = cloud.points
                let hits = cloud.hits

                var confident = Path()
                var unsure = Path()
                for i in points.indices {
                    let point = points[i]
                    let clip = matrix * SIMD4<Float>(point.x, point.y, point.z, 1)
                    guard clip.w > 0.1 else { continue }
                    let ndcX = clip.x / clip.w
                    let ndcY = clip.y / clip.w
                    guard abs(ndcX) <= 1, abs(ndcY) <= 1 else { continue }
                    if let occlusion, occlusion.hides(point) { continue }
                    let x = CGFloat(ndcX + 1) / 2 * size.width
                    let y = CGFloat(1 - ndcY) / 2 * size.height
                    // Nahe Punkte etwas grösser, damit Tiefe erkennbar bleibt.
                    let dot: CGFloat = clip.w < 1.5 ? 4 : 3
                    let rect = CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)
                    if hits[i] >= ScanPointCloud.confidentHits { confident.addRect(rect) } else { unsure.addRect(rect) }
                }
                context.fill(confident, with: .color(Self.confidentColor))
                context.fill(unsure, with: .color(Self.unsureColor))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Karte von oben: zeigt, welche Flächen und Wände rund um das Gerät schon erfasst sind.
/// Die Blickrichtung zeigt immer nach oben; Lücken in den Wänden sind sofort sichtbar.
struct ScanCoverageMap: View {
    let cloud: ScanPointCloud
    /// Sichtbarer Umkreis in Metern.
    var radius: Float = 5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let scale = min(size.width, size.height) / 2 / CGFloat(radius)
                let cell = CGFloat(cloud.columnSize) * scale

                if let device = cloud.devicePosition {
                    // Drehen, damit die Blickrichtung nach oben zeigt (Bildschirm: x rechts, y = z nach unten).
                    let rotation = -Float.pi / 2 - cloud.deviceHeading
                    let cosR = cos(rotation), sinR = sin(rotation)
                    let limit = radius * 1.5
                    var floor = Path()
                    var walls = Path()
                    for (key, count) in cloud.columns {
                        let column = ScanPointCloud.column(from: key)
                        let dx = (Float(column.x) + 0.5) * cloud.columnSize - device.x
                        let dz = (Float(column.z) + 0.5) * cloud.columnSize - device.z
                        guard abs(dx) < limit, abs(dz) < limit else { continue }
                        let rx = dx * cosR - dz * sinR
                        let ry = dx * sinR + dz * cosR
                        let x = center.x + CGFloat(rx) * scale
                        let y = center.y + CGFloat(ry) * scale
                        let rect = CGRect(x: x - cell / 2, y: y - cell / 2, width: cell + 0.6, height: cell + 0.6)
                        if count >= ScanPointCloud.wallColumnPoints { walls.addRect(rect) } else { floor.addRect(rect) }
                    }
                    context.fill(floor, with: .color(PointCloudOverlay.confidentColor.opacity(0.45)))
                    context.fill(walls, with: .color(.white))
                }

                // Gerät mit Blickrichtung
                var cone = Path()
                cone.move(to: center)
                cone.addLine(to: CGPoint(x: center.x - 16, y: center.y - 30))
                cone.addLine(to: CGPoint(x: center.x + 16, y: center.y - 30))
                cone.closeSubpath()
                context.fill(cone, with: .color(PointCloudOverlay.unsureColor.opacity(0.45)))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)),
                             with: .color(PointCloudOverlay.unsureColor))
            }
        }
        .frame(width: 136, height: 136)
        .background(Color.black.opacity(0.55))
        .overlay(alignment: .bottomLeading) {
            Text("Von oben")
                .font(.brand(.caption2))
                .foregroundStyle(.white.opacity(0.85))
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .allowsHitTesting(false)
        .accessibilityLabel("Karte der erfassten Fläche von oben")
    }
}

/// Anzahl erfasster Punkte; 0 bedeutet, dass die Kamera noch keine Tiefendaten liefert.
struct PointCountBadge: View {
    let cloud: ScanPointCloud

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let share = Int((cloud.confidentShare * 100).rounded())
            Label(cloud.isFull ? "Speicher voll" : "\(share) % sicher", systemImage: "circle.grid.3x3.fill")
                .font(.brand(.footnote).monospacedDigit())
                .padding(.horizontal, 10)
                .frame(minHeight: Theme.minimumTouchTarget)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                .accessibilityLabel(cloud.isFull
                                    ? "Maximale Punktzahl erreicht, Scan beenden"
                                    : "\(cloud.count) Punkte erfasst, davon \(share) Prozent sicher")
        }
    }
}

/// Kurze Erklärung der Punktfarben während des Scans.
struct ScanPointLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            Label {
                Text("Erfasst")
            } icon: {
                Circle().fill(PointCloudOverlay.confidentColor).frame(width: 10, height: 10)
            }
            Label {
                Text("Nochmals hinschwenken")
            } icon: {
                Circle().fill(PointCloudOverlay.unsureColor).frame(width: 10, height: 10)
            }
        }
        .font(.brand(.footnote))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
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
