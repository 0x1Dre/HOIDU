import Foundation
import SwiftData
import CCTVCore

/// Konkrete Montageposition einer Kamera mit Fotos, Montagehöhe und Blickrichtung.
@Model
final class CameraPosition {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var label: String = ""
    var mountingHeight: String = ""
    var viewDirection: String = ""
    var note: String = ""
    var area: SiteArea?
    @Relationship(deleteRule: .cascade, inverse: \PhotoAttachment.position)
    var photos: [PhotoAttachment] = []

    init(id: UUID) {
        self.id = id
    }

    var record: CameraPositionRecord {
        CameraPositionRecord(
            id: id,
            label: label,
            mountingHeight: mountingHeight,
            viewDirection: viewDirection,
            note: note,
            photos: photos.sorted { $0.sortIndex < $1.sortIndex }.map(\.record)
        )
    }

    func apply(_ record: CameraPositionRecord, index: Int, context: ModelContext) {
        sortIndex = index
        label = record.label
        mountingHeight = record.mountingHeight
        viewDirection = record.viewDirection
        note = record.note
        photos = ModelSync.sync(
            photos, with: record.photos, context: context,
            id: { $0.id },
            create: { PhotoAttachment(id: $0.id) },
            update: { model, photo, index in model.apply(photo, index: index) }
        )
    }
}
