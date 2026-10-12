#if !targetEnvironment(simulator)
import ARKit
import CoreImage
import UIKit
import simd

/// Kamerabild mit Lage im Raum, aufgenommen während des Scans.
/// Dient zum Einfärben des Modells (Texturen) und als Foto zum Scan.
struct ScanKeyframe: Sendable {
    /// Bild für Texturen in Sensor-Ausrichtung (Querformat), RGBA.
    let width: Int
    let height: Int
    let pixels: [UInt8]
    /// LiDAR-Tiefe in Metern (gleiche Ausrichtung, kleinere Auflösung) für die Verdeckungsprüfung.
    let depth: [Float]?
    let depthWidth: Int
    let depthHeight: Int
    /// Kameraparameter für `width` × `height`.
    let fx: Float, fy: Float, cx: Float, cy: Float
    let worldToCamera: simd_float4x4
    let position: SIMD3<Float>
    let forward: SIMD3<Float>
    /// Aufrechtes Foto (JPEG).
    let jpeg: Data

    /// Bildpunkt eines Weltpunkts und Abstand vor der Kamera; `nil`, wenn ausserhalb des Bilds.
    func project(_ point: SIMD3<Float>) -> (u: Float, v: Float, distance: Float)? {
        let c = worldToCamera * SIMD4<Float>(point.x, point.y, point.z, 1)
        let distance = -c.z
        guard distance > 0.1 else { return nil }
        let u = fx * c.x / distance + cx
        let v = -fy * c.y / distance + cy
        guard u >= 1, v >= 1, u < Float(width - 1), v < Float(height - 1) else { return nil }
        return (u, v, distance)
    }

    /// Ist der Punkt in diesem Bild sichtbar (nicht von etwas Näherem verdeckt)?
    func isVisible(u: Float, v: Float, distance: Float) -> Bool {
        guard let depth else { return true }
        let du = min(depthWidth - 1, max(0, Int(u * Float(depthWidth) / Float(width))))
        let dv = min(depthHeight - 1, max(0, Int(v * Float(depthHeight) / Float(height))))
        let measured = depth[dv * depthWidth + du]
        guard measured > 0 else { return true }
        return distance <= measured + 0.12
    }

    func color(u: Float, v: Float) -> SIMD4<UInt8> {
        let index = (Int(v) * width + Int(u)) * 4
        return SIMD4(pixels[index], pixels[index + 1], pixels[index + 2], 255)
    }
}

/// Wählt während des Scans laufend neue Aufnahmen aus (Ortswechsel oder neuer Blickwinkel).
@MainActor
final class ScanKeyframeRecorder {
    let maxKeyframes = 40
    private(set) var keyframes: [ScanKeyframe] = []
    private var lastCapture: TimeInterval = 0
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let textureWidth: CGFloat = 640
    private let photoMaxDimension: CGFloat = 1600

    func reset() {
        keyframes.removeAll()
        lastCapture = 0
    }

    func consider(_ frame: ARFrame, orientation: UIInterfaceOrientation) {
        guard keyframes.count < maxKeyframes, frame.timestamp - lastCapture > 0.4 else { return }
        guard case .normal = frame.camera.trackingState else { return }
        let transform = frame.camera.transform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forward = -simd_normalize(SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
        let minimumTurn = cos(Float(25) * .pi / 180)
        let isNew = keyframes.allSatisfy {
            simd_distance($0.position, position) > 0.5 || simd_dot($0.forward, forward) < minimumTurn
        }
        guard isNew else { return }
        lastCapture = frame.timestamp
        if let keyframe = makeKeyframe(frame, position: position, forward: forward, orientation: orientation) {
            keyframes.append(keyframe)
        }
    }

    private func makeKeyframe(_ frame: ARFrame, position: SIMD3<Float>, forward: SIMD3<Float>, orientation: UIInterfaceOrientation) -> ScanKeyframe? {
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        let extent = image.extent
        guard extent.width > 0 else { return nil }

        // Texturbild in Sensor-Ausrichtung
        let scale = textureWidth / extent.width
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let width = Int(scaled.extent.width.rounded(.down))
        let height = Int(scaled.extent.height.rounded(.down))
        guard width > 2, height > 2,
              let cgImage = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: width, height: height)) else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let bitmap = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        // Tiefe
        var depthValues: [Float]?
        var depthWidth = 0, depthHeight = 0
        if let depth = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap {
            CVPixelBufferLockBaseAddress(depth, .readOnly)
            depthWidth = CVPixelBufferGetWidth(depth)
            depthHeight = CVPixelBufferGetHeight(depth)
            let rowBytes = CVPixelBufferGetBytesPerRow(depth)
            if let base = CVPixelBufferGetBaseAddress(depth) {
                var values = [Float](repeating: 0, count: depthWidth * depthHeight)
                for row in 0..<depthHeight {
                    let rowPointer = base.advanced(by: row * rowBytes).assumingMemoryBound(to: Float32.self)
                    for column in 0..<depthWidth {
                        values[row * depthWidth + column] = rowPointer[column]
                    }
                }
                depthValues = values
            }
            CVPixelBufferUnlockBaseAddress(depth, .readOnly)
        }

        // Kameraparameter auf die Texturgrösse umrechnen
        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution
        let sx = Float(width) / Float(resolution.width)
        let sy = Float(height) / Float(resolution.height)

        // Aufrechtes Foto
        let photoScale = min(1, photoMaxDimension / max(extent.width, extent.height))
        let upright = image
            .transformed(by: CGAffineTransform(scaleX: photoScale, y: photoScale))
            .oriented(Self.imageOrientation(for: orientation))
        guard let photoImage = context.createCGImage(upright, from: upright.extent),
              let jpeg = UIImage(cgImage: photoImage).jpegData(compressionQuality: 0.72) else { return nil }

        return ScanKeyframe(
            width: width, height: height, pixels: pixels,
            depth: depthValues, depthWidth: depthWidth, depthHeight: depthHeight,
            fx: intrinsics[0][0] * sx, fy: intrinsics[1][1] * sy,
            cx: intrinsics[2][0] * sx, cy: intrinsics[2][1] * sy,
            worldToCamera: frame.camera.transform.inverse,
            position: position, forward: forward,
            jpeg: jpeg
        )
    }

    /// Das Kamerabild liegt immer im Querformat (Home-Taste rechts) vor.
    private static func imageOrientation(for orientation: UIInterfaceOrientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .portrait: .right
        case .portraitUpsideDown: .left
        case .landscapeLeft: .down
        default: .up
        }
    }
}

/// Punktewolke und Aufnahmen eines laufenden Scans.
@MainActor
final class ScanCaptureData {
    let cloud = ScanPointCloud()
    let keyframes = ScanKeyframeRecorder()
    /// Laufende AR-Sitzung (von RoomPlan oder dem eigenen Mesh-Scan).
    weak var session: ARSession?

    func reset() {
        cloud.reset()
        keyframes.reset()
    }

    func ingestCurrentFrame() {
        guard let frame = session?.currentFrame else { return }
        cloud.ingest(frame)
        keyframes.consider(frame, orientation: InterfaceOrientation.current)
    }
}

@MainActor
enum InterfaceOrientation {
    static var current: UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.effectiveGeometry.interfaceOrientation ?? .portrait
    }
}
#endif
