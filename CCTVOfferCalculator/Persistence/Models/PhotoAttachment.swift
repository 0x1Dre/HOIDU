import Foundation
import SwiftData
import CCTVCore

/// Foto eines Bereichs oder einer Kameraposition. Bilddaten liegen als verkleinertes JPEG
/// ausserhalb der Datenbank (`externalStorage`) im Sandbox-Speicher der App.
@Model
final class PhotoAttachment {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var caption: String = ""
    var note: String = ""
    var capturedAt: Date = Date()
    @Attribute(.externalStorage) var imageData: Data?
    var markersData: Data?
    var includeInCustomerPDF: Bool = true
    var area: SiteArea?
    var position: CameraPosition?

    init(id: UUID) {
        self.id = id
    }

    var markers: [PhotoMarker] {
        guard let markersData else { return [] }
        return (try? JSONDecoder().decode([PhotoMarker].self, from: markersData)) ?? []
    }

    var record: PhotoRecord {
        PhotoRecord(
            id: id,
            caption: caption,
            note: note,
            capturedAt: capturedAt,
            imageData: imageData,
            markers: markers,
            includeInCustomerPDF: includeInCustomerPDF
        )
    }

    func apply(_ record: PhotoRecord, index: Int) {
        sortIndex = index
        caption = record.caption
        note = record.note
        capturedAt = record.capturedAt
        includeInCustomerPDF = record.includeInCustomerPDF
        let encodedMarkers = record.markers.isEmpty ? nil : try? JSONEncoder().encode(record.markers)
        if markersData != encodedMarkers { markersData = encodedMarkers }
        if imageData != record.imageData { imageData = record.imageData }
    }
}
