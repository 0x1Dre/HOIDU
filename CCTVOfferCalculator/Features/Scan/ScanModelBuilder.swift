import Foundation
import SceneKit
import UIKit
import simd
import CCTVCore

/// Speichern und Laden der 3D-Modelle sowie Erzeugen des Grundrisses.
///
/// Beide Scan-Arten werden als SceneKit-Szene (`.scn`) im selben Koordinatensystem gespeichert
/// (Meter, y nach oben). Der Grundriss ist eine Draufsicht auf die x/z-Ebene: x nach rechts, z nach unten.
@MainActor
enum ScanModelFile {
    /// Kategorie für Treffer auf dem gescannten Modell.
    static let modelCategory = 1
    /// Kategorie für platzierte Kameras.
    static let markerCategory = 2

    static func data(from scene: SCNScene) throws -> Data {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString).scn")
        defer { try? FileManager.default.removeItem(at: url) }
        guard scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) else {
            throw ScanError.saveFailed
        }
        return try Data(contentsOf: url)
    }

    static func scene(from data: Data) throws -> SCNScene {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString).scn")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let scene = try SCNScene(url: url, options: nil)
        scene.rootNode.enumerateHierarchy { node, _ in
            node.categoryBitMask = modelCategory
        }
        return scene
    }
}

enum ScanError: LocalizedError {
    case saveFailed
    case emptyScan
    case unsupported

    var errorDescription: String? {
        switch self {
        case .saveFailed: "Das 3D-Modell konnte nicht gespeichert werden."
        case .emptyScan: "Der Scan enthält keine Daten. Bitte langsamer bewegen und erneut scannen."
        case .unsupported: "Dieses Gerät unterstützt keine 3D-Scans (LiDAR-Sensor erforderlich)."
        }
    }
}

// MARK: - Grundriss zeichnen

/// Zeichnet einen Grundriss als PNG. Der Inhalt wird über eine Zeichenfunktion in Weltkoordinaten (Meter) geliefert.
@MainActor
enum FloorPlanRasterizer {
    /// Pixel pro Meter, begrenzt auf eine maximale Kantenlänge.
    static func render(bounds: ScanBounds, draw: (CGContext, (Double, Double) -> CGPoint, CGFloat) -> Void) -> ScanFloorPlan? {
        let maxEdge: Double = 2400
        let pixelsPerMeter = min(120, maxEdge / max(bounds.width, bounds.depth))
        let size = CGSize(width: max(200, bounds.width * pixelsPerMeter).rounded(),
                          height: max(200, bounds.depth * pixelsPerMeter).rounded())
        let scaleX = size.width / bounds.width
        let scaleZ = size.height / bounds.depth
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let data = renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let map: (Double, Double) -> CGPoint = { x, z in
                CGPoint(x: (x - bounds.minX) * scaleX, y: (z - bounds.minZ) * scaleZ)
            }
            draw(context.cgContext, map, CGFloat(min(scaleX, scaleZ)))
        }
        return ScanFloorPlan(imageData: data, bounds: bounds)
    }
}

// MARK: - Dreiecksnetz (LiDAR-Mesh)

/// Dreiecksnetz in Weltkoordinaten, gesammelt aus den Mesh-Ankern von ARKit.
struct WorldMesh {
    var vertices: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    var isEmpty: Bool { indices.isEmpty }

    /// SceneKit-Szene mit einem einzigen Knoten.
    @MainActor
    func makeScene() -> SCNScene {
        let scene = SCNScene()
        let vertexSource = SCNGeometrySource(vertices: vertices.map { SCNVector3($0.x, $0.y, $0.z) })
        let normalSource = SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(hex: 0xD9D6CC)
        material.lightingModel = .lambert
        material.isDoubleSided = true
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = "scan-mesh"
        node.categoryBitMask = ScanModelFile.modelCategory
        scene.rootNode.addChildNode(node)
        return scene
    }

    /// Draufsicht: waagrechte Flächen hell, senkrechte (Wände, Objekte) dunkel.
    /// Alles oberhalb von Bodenhöhe + 2.3 m (z. B. Decke) wird weggelassen.
    @MainActor
    func makeFloorPlan() -> ScanFloorPlan? {
        guard !isEmpty else { return nil }
        let sortedY = vertices.map(\.y).sorted()
        let floorY = sortedY[min(sortedY.count - 1, sortedY.count / 20)]
        let cutY = floorY + 2.3

        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
        for v in vertices where v.y <= cutY {
            minX = min(minX, v.x); maxX = max(maxX, v.x)
            minZ = min(minZ, v.z); maxZ = max(maxZ, v.z)
        }
        guard minX < maxX, minZ < maxZ else { return nil }
        let bounds = ScanBounds(minX: Double(minX), maxX: Double(maxX), minZ: Double(minZ), maxZ: Double(maxZ)).padded(by: 0.5)

        return FloorPlanRasterizer.render(bounds: bounds) { cg, map, _ in
            let horizontal = CGMutablePath()
            let vertical = CGMutablePath()
            var i = 0
            while i + 2 < indices.count {
                let a = vertices[Int(indices[i])], b = vertices[Int(indices[i + 1])], c = vertices[Int(indices[i + 2])]
                i += 3
                let centroidY = (a.y + b.y + c.y) / 3
                guard centroidY <= cutY else { continue }
                let normal = simd_normalize(simd_cross(b - a, c - a))
                guard normal.x.isFinite else { continue }
                let path = abs(normal.y) > 0.7 ? horizontal : vertical
                path.move(to: map(Double(a.x), Double(a.z)))
                path.addLine(to: map(Double(b.x), Double(b.z)))
                path.addLine(to: map(Double(c.x), Double(c.z)))
                path.closeSubpath()
            }
            cg.addPath(horizontal)
            cg.setFillColor(OstsichtColor.kalk.cgColor)
            cg.fillPath()
            cg.addPath(vertical)
            cg.setFillColor(OstsichtColor.anthrazit.withAlphaComponent(0.85).cgColor)
            cg.setStrokeColor(OstsichtColor.anthrazit.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(1)
            cg.drawPath(using: .fillStroke)
        }
    }
}
