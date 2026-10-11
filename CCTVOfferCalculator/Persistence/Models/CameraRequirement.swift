import Foundation
import SwiftData
import CCTVCore

/// Kameraanforderung eines Bereichs: Anzahl, Bauform, Auflösung und Distanz.
@Model
final class CameraRequirement {
    var quantity: Int = 1
    var formFactorRaw: String = CameraFormFactor.automatisch.rawValue
    var preferredMegapixels: Int = 0
    var distanceMeters: Int = 10
    var area: SiteArea?

    init() {}

    var record: CameraRequirementRecord {
        CameraRequirementRecord(
            quantity: quantity,
            formFactor: CameraFormFactor(rawValue: formFactorRaw) ?? .automatisch,
            preferredMegapixels: preferredMegapixels,
            distanceMeters: distanceMeters
        )
    }

    func apply(_ record: CameraRequirementRecord) {
        quantity = record.quantity
        formFactorRaw = record.formFactor.rawValue
        preferredMegapixels = record.preferredMegapixels
        distanceMeters = record.distanceMeters
    }
}
