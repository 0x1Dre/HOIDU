#if !targetEnvironment(simulator)
import Foundation
import UIKit
import simd
import CCTVCore

/// RGBA-Bild als Rohdaten (threadsicher übergebbar).
struct RGBAImage: Sendable {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    /// Horizontal gespiegelt (für die Rückseite einer Wand).
    func mirrored() -> RGBAImage {
        var copy = self
        for row in 0..<height {
            for column in 0..<width {
                let source = (row * width + (width - 1 - column)) * 4
                let target = (row * width + column) * 4
                copy.pixels[target] = pixels[source]
                copy.pixels[target + 1] = pixels[source + 1]
                copy.pixels[target + 2] = pixels[source + 2]
                copy.pixels[target + 3] = pixels[source + 3]
            }
        }
        return copy
    }

    @MainActor
    func makeImage() -> UIImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Holt für einen Punkt im Raum die Farbe aus der Aufnahme, die ihn am besten zeigt:
/// sichtbar (Tiefenprüfung), möglichst frontal, nah und eher in der Bildmitte.
struct KeyframeSampler: Sendable {
    let keyframes: [ScanKeyframe]

    func color(at point: SIMD3<Float>, normal: SIMD3<Float>?, candidates: [Int]? = nil) -> SIMD4<UInt8>? {
        var bestScore: Float = 0
        var best: SIMD4<UInt8>?
        for index in candidates ?? Array(keyframes.indices) {
            let frame = keyframes[index]
            guard let projected = frame.project(point),
                  frame.isVisible(u: projected.u, v: projected.v, distance: projected.distance) else { continue }
            var score = 1 / max(projected.distance, 0.4)
            if let normal {
                let toCamera = simd_normalize(frame.position - point)
                let facing = abs(simd_dot(normal, toCamera))
                guard facing > 0.2 else { continue }
                score *= facing * facing
            }
            let du = projected.u / Float(frame.width) - 0.5
            let dv = projected.v / Float(frame.height) - 0.5
            score *= 1 - 1.2 * (du * du + dv * dv)
            if score > bestScore {
                bestScore = score
                best = frame.color(u: projected.u, v: projected.v)
            }
        }
        return best
    }

    /// Aufnahmen, die mindestens einen der Punkte sehen (Vorauswahl für eine Fläche).
    func candidates(seeing points: [SIMD3<Float>]) -> [Int] {
        keyframes.indices.filter { index in
            points.contains { keyframes[index].project($0) != nil }
        }
    }
}

enum ScanTexturing {
    /// Farbiges Bild einer ebenen Fläche. Die Fläche liegt in der lokalen x/y-Ebene von `transform`
    /// (z = Normale); das Bild deckt das Rechteck `minX…maxX` × `minY…maxY` ab (oben = maxY).
    /// Punkte ausserhalb von `polygon` (falls angegeben) werden transparent.
    static func surfaceTexture(
        transform: simd_float4x4,
        minX: Float, maxX: Float, minY: Float, maxY: Float,
        polygon: [SIMD2<Float>]? = nil,
        pixelsPerMeter: Float = 60,
        maxDimension: Int = 1024,
        sampler: KeyframeSampler
    ) -> RGBAImage? {
        let widthMeters = maxX - minX, heightMeters = maxY - minY
        guard widthMeters > 0.05, heightMeters > 0.05 else { return nil }
        let scale = min(pixelsPerMeter, Float(maxDimension) / max(widthMeters, heightMeters))
        let width = max(8, Int(widthMeters * scale))
        let height = max(8, Int(heightMeters * scale))
        let normal = simd_normalize(SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))

        func world(_ x: Float, _ y: Float) -> SIMD3<Float> {
            let p = transform * SIMD4<Float>(x, y, 0, 1)
            return SIMD3(p.x, p.y, p.z)
        }
        let corners = [world(minX, minY), world(maxX, minY), world(maxX, maxY), world(minX, maxY), world((minX + maxX) / 2, (minY + maxY) / 2)]
        let candidates = sampler.candidates(seeing: corners)

        // Ersatzfarbe, wo keine Aufnahme hinsieht
        let fallback = SIMD4<UInt8>(236, 233, 225, 255)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let y = maxY - (Float(row) + 0.5) / Float(height) * heightMeters
            for column in 0..<width {
                let x = minX + (Float(column) + 0.5) / Float(width) * widthMeters
                let index = (row * width + column) * 4
                if let polygon, !contains(polygon, SIMD2(x, y)) {
                    continue // transparent
                }
                let color = sampler.color(at: world(x, y), normal: normal, candidates: candidates) ?? fallback
                pixels[index] = color.x
                pixels[index + 1] = color.y
                pixels[index + 2] = color.z
                pixels[index + 3] = 255
            }
        }
        return RGBAImage(width: width, height: height, pixels: pixels)
    }

    /// Farbe je Vertex (0…1) für ein Dreiecksnetz.
    static func vertexColors(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], sampler: KeyframeSampler) -> [SIMD4<Float>] {
        let fallback = SIMD4<Float>(0.85, 0.84, 0.80, 1)
        return vertices.indices.map { index in
            let normal = index < normals.count ? normals[index] : nil
            guard let color = sampler.color(at: vertices[index], normal: normal) else { return fallback }
            return SIMD4(Float(color.x) / 255, Float(color.y) / 255, Float(color.z) / 255, 1)
        }
    }

    /// Punkt-in-Polygon (gerade/ungerade Regel).
    static func contains(_ polygon: [SIMD2<Float>], _ point: SIMD2<Float>) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Wählt bis zu `limit` gut verteilte Aufnahmen als Fotos zum Scan aus.
    static func photos(from keyframes: [ScanKeyframe], limit: Int = 8) -> (photos: [PhotoRecord], poses: [ScanPhotoPose]) {
        guard !keyframes.isEmpty else { return ([], []) }
        var chosen = [0]
        while chosen.count < min(limit, keyframes.count) {
            var bestIndex: Int?
            var bestDistance: Float = 0
            for index in keyframes.indices where !chosen.contains(index) {
                let distance = chosen.map { other -> Float in
                    let a = keyframes[index], b = keyframes[other]
                    return simd_distance(a.position, b.position) + (1 - simd_dot(a.forward, b.forward)) * 2
                }.min() ?? 0
                if distance > bestDistance {
                    bestDistance = distance
                    bestIndex = index
                }
            }
            guard let bestIndex else { break }
            chosen.append(bestIndex)
        }

        var photos: [PhotoRecord] = []
        var poses: [ScanPhotoPose] = []
        for (number, index) in chosen.sorted().enumerated() {
            let frame = keyframes[index]
            let photo = PhotoRecord(caption: "Aufnahme \(number + 1)", imageData: frame.jpeg)
            photos.append(photo)
            let yaw = Double(atan2(frame.forward.x, -frame.forward.z)) * 180 / .pi
            let pitch = Double(-asin(max(-1, min(1, frame.forward.y)))) * 180 / .pi
            poses.append(ScanPhotoPose(photoID: photo.id, x: Double(frame.position.x), y: Double(frame.position.y),
                                       z: Double(frame.position.z), yawDegrees: yaw, pitchDegrees: pitch))
        }
        return (photos, poses)
    }
}
#endif
