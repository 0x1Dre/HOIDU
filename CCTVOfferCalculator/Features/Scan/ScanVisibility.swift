import SceneKit
import simd
import CCTVCore

/// Sichtbarkeit einer Kamera im gescannten Modell: Sichtstrahlen enden an Wänden, Boden und Möbeln.
@MainActor
enum ScanVisibility {
    /// Anzahl Richtungen für die Sichtweite im Grundriss.
    static let planSamples = 48
    /// Abstand vom Montagepunkt, damit die eigene Wand nicht getroffen wird.
    private static let startOffset: Float = 0.12

    struct Geometry {
        /// Blickkörper: Seitenflächen vom Objektiv bis zum Auftreffpunkt.
        let volume: SCNGeometry?
        /// Sichtbare Fläche auf Wänden, Boden und Objekten.
        let footprint: SCNGeometry?
    }

    /// Schlüssel für den Zwischenspeicher: nur die geometrisch relevanten Werte.
    struct Key: Hashable {
        let x, y, z, yaw, tilt, fov, range: Double

        init(_ p: ScanCameraPlacement) {
            x = p.x; y = p.y; z = p.z
            yaw = p.yawDegrees; tilt = p.tiltDegrees; fov = p.fieldOfViewDegrees; range = p.rangeMeters
        }
    }

    // MARK: - Strahlen

    private static func cast(in root: SCNNode, from origin: SIMD3<Float>, direction: SIMD3<Float>, range: Float) -> (point: SIMD3<Float>, hit: Bool) {
        let start = origin + direction * startOffset
        let end = origin + direction * range
        let results = root.hitTestWithSegment(from: SCNVector3(start), to: SCNVector3(end), options: [
            SCNHitTestOption.categoryBitMask.rawValue: ScanModelFile.modelCategory,
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.backFaceCulling.rawValue: false,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: true
        ])
        if let hit = results.first {
            return (SIMD3<Float>(hit.worldCoordinates), true)
        }
        return (end, false)
    }

    /// Ausrichtung wie bei den Kameraknoten: zuerst Blickrichtung (Yaw), dann Neigung.
    private static func orientation(_ p: ScanCameraPlacement) -> simd_quatf {
        let yaw = simd_quatf(angle: Float(-p.yawDegrees * .pi / 180), axis: SIMD3(0, 1, 0))
        let pitch = simd_quatf(angle: Float(-p.tiltDegrees * .pi / 180), axis: SIMD3(1, 0, 0))
        return yaw * pitch
    }

    // MARK: - Grundriss

    /// Waagrechte Sichtweite je Richtung über den Öffnungswinkel, auf Personenhöhe unter der Kamera.
    static func planReach(in root: SCNNode, for p: ScanCameraPlacement) -> [Double] {
        let origin = SIMD3<Float>(Float(p.x), Float(p.y) - 1.0, Float(p.z))
        let range = Float(p.rangeMeters)
        let fov = min(p.fieldOfViewDegrees, 359)
        return (0..<planSamples).map { index in
            let degrees = p.yawDegrees - fov / 2 + fov * Double(index) / Double(planSamples - 1)
            let radians = Float(degrees * .pi / 180)
            let direction = SIMD3<Float>(sin(radians), 0, -cos(radians))
            let result = cast(in: root, from: origin, direction: direction, range: range)
            let distance = result.hit ? simd_distance(SIMD3(origin.x, 0, origin.z), SIMD3(result.point.x, 0, result.point.z)) : range
            return (Double(distance) * 100).rounded() / 100
        }
    }

    // MARK: - 3D

    static func geometry(in root: SCNNode, for p: ScanCameraPlacement) -> Geometry {
        let origin = SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z))
        let range = Float(min(p.rangeMeters, 40))
        let horizontal = Float(min(p.fieldOfViewDegrees, 179) * .pi / 180)
        let vertical = min(horizontal * 0.5625, Float(100 * Double.pi / 180))
        let columns = max(8, min(28, Int(p.fieldOfViewDegrees / 6)))
        let rows = 12
        let rotation = orientation(p)

        // Raster der Auftreffpunkte (relativ zum Objektiv).
        var points = [[SIMD3<Float>]](repeating: [], count: rows + 1)
        var hits = [[Bool]](repeating: [], count: rows + 1)
        for row in 0...rows {
            let v = vertical / 2 - vertical * Float(row) / Float(rows)
            for column in 0...columns {
                let h = -horizontal / 2 + horizontal * Float(column) / Float(columns)
                let local = SIMD3<Float>(sin(h) * cos(v), sin(v), -cos(h) * cos(v))
                let direction = simd_normalize(rotation.act(local))
                let result = cast(in: root, from: origin, direction: direction, range: range)
                // Leicht zum Objektiv zurückversetzt, damit die Fläche nicht in der Wand verschwindet.
                let point = result.hit ? result.point - direction * 0.015 : result.point
                points[row].append(point - origin)
                hits[row].append(result.hit)
            }
        }

        // Blickkörper: Fächer vom Objektiv entlang des Rands.
        var border: [SIMD3<Float>] = []
        border += points[0]
        border += (1...rows).map { points[$0][columns] }
        border += points[rows].reversed().dropFirst()
        border += (1..<rows).reversed().map { points[$0][0] }
        var volumeVertices: [SIMD3<Float>] = [.zero]
        var volumeIndices: [UInt32] = []
        for (index, point) in border.enumerated() {
            volumeVertices.append(point)
            let current = UInt32(index + 1)
            let next = UInt32((index + 1) % border.count + 1)
            volumeIndices += [0, current, next]
        }

        // Sichtbare Fläche: Rasterzellen, deren vier Ecken etwas getroffen haben.
        var footprintVertices: [SIMD3<Float>] = []
        var footprintIndices: [UInt32] = []
        for row in 0..<rows {
            for column in 0..<columns {
                guard hits[row][column], hits[row][column + 1], hits[row + 1][column], hits[row + 1][column + 1] else { continue }
                let corners = [points[row][column], points[row][column + 1], points[row + 1][column + 1], points[row + 1][column]]
                // Zellen über Kanten hinweg (z. B. Wand → Boden weit dahinter) nicht verbinden.
                let lengths = [simd_distance(corners[0], corners[1]), simd_distance(corners[1], corners[2]),
                               simd_distance(corners[2], corners[3]), simd_distance(corners[3], corners[0])]
                let typical = simd_length(corners[0]) * horizontal / Float(columns) * 3 + 0.3
                guard lengths.allSatisfy({ $0 < typical }) else { continue }
                let base = UInt32(footprintVertices.count)
                footprintVertices += corners
                footprintIndices += [base, base + 1, base + 2, base, base + 2, base + 3]
            }
        }

        return Geometry(
            volume: makeGeometry(volumeVertices, volumeIndices),
            footprint: footprintIndices.isEmpty ? nil : makeGeometry(footprintVertices, footprintIndices)
        )
    }

    private static func makeGeometry(_ vertices: [SIMD3<Float>], _ indices: [UInt32]) -> SCNGeometry? {
        guard !indices.isEmpty else { return nil }
        let source = SCNGeometrySource(vertices: vertices.map { SCNVector3($0.x, $0.y, $0.z) })
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [source], elements: [element])
    }

    // MARK: - Materialien

    static func volumeMaterial(selected: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = OstsichtColor.sonne.withAlphaComponent(selected ? 0.22 : 0.12)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        return material
    }

    static func footprintMaterial(selected: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = OstsichtColor.sonne.withAlphaComponent(selected ? 0.7 : 0.5)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        return material
    }
}
