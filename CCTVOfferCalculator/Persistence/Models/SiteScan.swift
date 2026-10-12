import Foundation
import SwiftData
import CCTVCore

/// 3D-Scan eines Projekts. Modell und Grundriss liegen ausserhalb der Datenbank (`externalStorage`).
@Model
final class SiteScan {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var name: String = ""
    var kindRaw: String = ScanKind.raum.rawValue
    var createdAt: Date = Date()
    var note: String = ""
    @Attribute(.externalStorage) var modelData: Data?
    @Attribute(.externalStorage) var floorPlanImageData: Data?
    var floorPlanBoundsData: Data?
    var placementsData: Data?
    var project: Project?

    init(id: UUID) {
        self.id = id
    }

    var placements: [ScanCameraPlacement] {
        guard let placementsData else { return [] }
        return (try? JSONDecoder().decode([ScanCameraPlacement].self, from: placementsData)) ?? []
    }

    var floorPlan: ScanFloorPlan? {
        guard let floorPlanImageData,
              let floorPlanBoundsData,
              let bounds = try? JSONDecoder().decode(ScanBounds.self, from: floorPlanBoundsData) else { return nil }
        return ScanFloorPlan(imageData: floorPlanImageData, bounds: bounds)
    }

    var record: SiteScanRecord {
        SiteScanRecord(
            id: id,
            name: name,
            kind: ScanKind(rawValue: kindRaw) ?? .raum,
            createdAt: createdAt,
            modelData: modelData,
            floorPlan: floorPlan,
            placements: placements,
            note: note
        )
    }

    func apply(_ record: SiteScanRecord, index: Int) {
        sortIndex = index
        name = record.name
        kindRaw = record.kind.rawValue
        createdAt = record.createdAt
        note = record.note

        let encodedPlacements = record.placements.isEmpty ? nil : try? JSONEncoder().encode(record.placements)
        if placementsData != encodedPlacements { placementsData = encodedPlacements }

        // Grosse Daten nur schreiben, wenn sie sich geändert haben.
        if modelData != record.modelData { modelData = record.modelData }
        let image = record.floorPlan?.imageData
        if floorPlanImageData != image { floorPlanImageData = image }
        let bounds = record.floorPlan.flatMap { try? JSONEncoder().encode($0.bounds) }
        if floorPlanBoundsData != bounds { floorPlanBoundsData = bounds }
    }
}
