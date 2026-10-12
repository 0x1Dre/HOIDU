import Foundation

/// Art des 3D-Scans.
public enum ScanKind: String, LabeledOption {
    /// Innenraum mit Apple RoomPlan: Wände, Türen, Fenster und Möbel werden erkannt.
    case raum
    /// Freier LiDAR-Scan (Mesh), auch draussen. Reichweite ca. 5 m, ohne Objekterkennung.
    case umgebung

    public var label: String {
        switch self {
        case .raum: "Innenraum"
        case .umgebung: "Umgebung"
        }
    }

    public var detail: String {
        switch self {
        case .raum: "Wände, Türen und Fenster werden erkannt. Nur in Innenräumen."
        case .umgebung: "Freier 3D-Scan, auch draussen. Reichweite rund 5 m."
        }
    }

    public var systemImage: String {
        switch self {
        case .raum: "cube.transparent"
        case .umgebung: "mountain.2"
        }
    }
}

/// Ausschnitt des Grundrisses in Weltkoordinaten (Meter). x zeigt nach rechts, z im Bild nach unten.
public struct ScanBounds: Codable, Hashable, Sendable {
    public var minX: Double
    public var maxX: Double
    public var minZ: Double
    public var maxZ: Double

    public init(minX: Double, maxX: Double, minZ: Double, maxZ: Double) {
        self.minX = min(minX, maxX)
        self.maxX = max(minX, maxX)
        self.minZ = min(minZ, maxZ)
        self.maxZ = max(minZ, maxZ)
    }

    public var width: Double { max(maxX - minX, 0.01) }
    public var depth: Double { max(maxZ - minZ, 0.01) }

    /// Rand in Metern auf allen Seiten ergänzen.
    public func padded(by margin: Double) -> ScanBounds {
        ScanBounds(minX: minX - margin, maxX: maxX + margin, minZ: minZ - margin, maxZ: maxZ + margin)
    }

    /// Relative Position (0…1) eines Weltpunkts im Grundriss.
    public func relative(x: Double, z: Double) -> (x: Double, y: Double) {
        ((x - minX) / width, (z - minZ) / depth)
    }
}

/// Grundriss als Draufsicht (PNG), erzeugt beim Scannen. Das Bild deckt genau `bounds` ab.
public struct ScanFloorPlan: Codable, Hashable, Sendable {
    public var imageData: Data
    public var bounds: ScanBounds

    public init(imageData: Data, bounds: ScanBounds) {
        self.imageData = imageData
        self.bounds = bounds
    }
}

/// Im 3D-Modell gesetzte Kamera. Koordinaten in Metern im Koordinatensystem des Scans (y nach oben).
public struct ScanCameraPlacement: Codable, Hashable, Sendable, Identifiable {
    public static let defaultFieldOfView: Double = 100
    public static let defaultRange: Double = 10
    public static let defaultTilt: Double = 25

    public var id: UUID
    /// Verknüpfte Kameraposition des Projekts (optional).
    public var positionID: UUID?
    /// Eigene Beschriftung, falls keine Kameraposition verknüpft ist.
    public var label: String
    public var x: Double
    public var y: Double
    public var z: Double
    /// Blickrichtung im Grundriss in Grad, im Uhrzeigersinn: 0 = oben (−z), 90 = rechts (+x).
    public var yawDegrees: Double
    /// Neigung nach unten in Grad (0 = waagrecht).
    public var tiltDegrees: Double
    /// Horizontaler Öffnungswinkel in Grad.
    public var fieldOfViewDegrees: Double
    /// Nutzbare Reichweite in Metern (Darstellung des Blickfelds).
    public var rangeMeters: Double

    public init(
        id: UUID = UUID(),
        positionID: UUID? = nil,
        label: String = "",
        x: Double,
        y: Double,
        z: Double,
        yawDegrees: Double = 0,
        tiltDegrees: Double = ScanCameraPlacement.defaultTilt,
        fieldOfViewDegrees: Double = ScanCameraPlacement.defaultFieldOfView,
        rangeMeters: Double = ScanCameraPlacement.defaultRange
    ) {
        self.id = id
        self.positionID = positionID
        self.label = label
        self.x = x.isFinite ? x : 0
        self.y = y.isFinite ? y : 0
        self.z = z.isFinite ? z : 0
        self.yawDegrees = ScanCameraPlacement.normalizedYaw(yawDegrees)
        self.tiltDegrees = min(90, max(0, tiltDegrees.isFinite ? tiltDegrees : ScanCameraPlacement.defaultTilt))
        self.fieldOfViewDegrees = min(180, max(10, fieldOfViewDegrees.isFinite ? fieldOfViewDegrees : ScanCameraPlacement.defaultFieldOfView))
        self.rangeMeters = min(100, max(1, rangeMeters.isFinite ? rangeMeters : ScanCameraPlacement.defaultRange))
    }

    /// Winkel auf 0…<360 Grad bringen.
    public static func normalizedYaw(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// Blickrichtung im Grundriss als Einheitsvektor (x nach rechts, z nach unten).
    public var planDirection: (x: Double, z: Double) {
        let radians = yawDegrees * .pi / 180
        return (sin(radians), -cos(radians))
    }

    /// Blickrichtung (Yaw) aus einer Flächennormalen im Grundriss: die Kamera schaut von der Wand weg.
    /// Gibt `nil` zurück, wenn die Normale (fast) senkrecht ist (Boden oder Decke).
    public static func yaw(fromNormalX nx: Double, normalZ nz: Double) -> Double? {
        let length = (nx * nx + nz * nz).squareRoot()
        guard length > 0.3 else { return nil }
        return normalizedYaw(atan2(nx, -nz) * 180 / .pi)
    }

    /// Himmelsrichtung im Grundriss als Text (nur relativ zum Scan, nicht geografisch).
    public var directionLabel: String {
        let names = ["oben", "oben rechts", "rechts", "unten rechts", "unten", "unten links", "links", "oben links"]
        let index = Int((yawDegrees + 22.5) / 45) % 8
        return names[index]
    }

    enum CodingKeys: String, CodingKey {
        case id, positionID, label, x, y, z, yawDegrees, tiltDegrees, fieldOfViewDegrees, rangeMeters
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            positionID: try c.decodeIfPresent(UUID.self, forKey: .positionID),
            label: try c.decodeIfPresent(String.self, forKey: .label) ?? "",
            x: try c.decode(Double.self, forKey: .x),
            y: try c.decodeIfPresent(Double.self, forKey: .y) ?? 0,
            z: try c.decode(Double.self, forKey: .z),
            yawDegrees: try c.decodeIfPresent(Double.self, forKey: .yawDegrees) ?? 0,
            tiltDegrees: try c.decodeIfPresent(Double.self, forKey: .tiltDegrees) ?? ScanCameraPlacement.defaultTilt,
            fieldOfViewDegrees: try c.decodeIfPresent(Double.self, forKey: .fieldOfViewDegrees) ?? ScanCameraPlacement.defaultFieldOfView,
            rangeMeters: try c.decodeIfPresent(Double.self, forKey: .rangeMeters) ?? ScanCameraPlacement.defaultRange
        )
    }
}

/// 3D-Scan eines Raums oder einer Umgebung mit darin platzierten Kameras.
public struct SiteScanRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var kind: ScanKind
    public var createdAt: Date
    /// 3D-Modell als SceneKit-Datei (`.scn`). Im kompakten JSON-Export entfernt.
    public var modelData: Data?
    /// Draufsicht für Grundriss und PDF.
    public var floorPlan: ScanFloorPlan?
    public var placements: [ScanCameraPlacement]
    public var note: String

    public init(
        id: UUID = UUID(),
        name: String = "",
        kind: ScanKind = .raum,
        createdAt: Date = Date(),
        modelData: Data? = nil,
        floorPlan: ScanFloorPlan? = nil,
        placements: [ScanCameraPlacement] = [],
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.createdAt = createdAt
        self.modelData = modelData
        self.floorPlan = floorPlan
        self.placements = placements
        self.note = note
    }

    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.label : trimmed
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, createdAt, modelData, floorPlan, placements, note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        kind = try c.decodeIfPresent(ScanKind.self, forKey: .kind) ?? .raum
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modelData = try c.decodeIfPresent(Data.self, forKey: .modelData)
        floorPlan = try c.decodeIfPresent(ScanFloorPlan.self, forKey: .floorPlan)
        placements = try c.decodeIfPresent([ScanCameraPlacement].self, forKey: .placements) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

public extension ProjectRecord {
    /// Alle Kamerapositionen mit zugehörigem Bereich, in Erfassungsreihenfolge.
    var allPositions: [(area: SiteAreaRecord, position: CameraPositionRecord)] {
        areas.flatMap { area in area.positions.map { (area: area, position: $0) } }
    }

    /// Anzeigename einer platzierten Kamera: verknüpfte Position, sonst eigene Beschriftung, sonst Nummer.
    func displayLabel(for placement: ScanCameraPlacement, number: Int) -> String {
        if let id = placement.positionID,
           let match = allPositions.first(where: { $0.position.id == id }) {
            let label = match.position.label.trimmingCharacters(in: .whitespaces)
            if !label.isEmpty { return label }
        }
        let own = placement.label.trimmingCharacters(in: .whitespaces)
        return own.isEmpty ? "Kamera \(number)" : own
    }

    /// Bereich der verknüpften Kameraposition.
    func areaName(for placement: ScanCameraPlacement) -> String? {
        guard let id = placement.positionID else { return nil }
        return allPositions.first { $0.position.id == id }?.area.name
    }

    var placedCameraCount: Int {
        scans.reduce(0) { $0 + $1.placements.count }
    }
}
