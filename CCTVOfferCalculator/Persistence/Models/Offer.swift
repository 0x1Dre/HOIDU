import Foundation
import SwiftData
import CCTVCore

/// Erstellte Offerte (Version) eines Projekts mit Momentaufnahme der drei Varianten.
@Model
final class Offer {
    var id: UUID = UUID()
    var number: String = ""
    var createdAt: Date = Date()
    var validUntil: Date = Date()
    var statusRaw: String = OfferStatus.entwurf.rawValue
    var recommendedTierRaw: String = OfferTier.standard.rawValue
    var discountBasisPoints: Int = 0
    var recommendedTotalRappen: Int = 0
    var notes: String = ""
    var project: Project?
    @Relationship(deleteRule: .cascade, inverse: \Calculation.offer)
    var calculations: [Calculation] = []

    init(number: String) {
        self.number = number
    }

    var status: OfferStatus {
        get { OfferStatus(rawValue: statusRaw) ?? .entwurf }
        set { statusRaw = newValue.rawValue }
    }

    var recommendedTier: OfferTier {
        OfferTier(rawValue: recommendedTierRaw) ?? .standard
    }

    var recommendedTotal: Decimal {
        Money.rappen(recommendedTotalRappen)
    }
}
