import Foundation
import SwiftData
import CCTVCore

/// Kalkulierte Variante einer Offerte. Positionen werden als JSON gesichert, damit die
/// Offerte auch nach späteren Preisänderungen nachvollziehbar bleibt.
@Model
final class Calculation {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var tierRaw: String = OfferTier.standard.rawValue
    var manufacturerRaw: String = Manufacturer.reolink.rawValue
    var score: Int = 0
    var cameraCount: Int = 0
    var materialNetRappen: Int = 0
    var materialCostRappen: Int = 0
    var laborNetRappen: Int = 0
    var laborCostRappen: Int = 0
    var discountRappen: Int = 0
    var vatRappen: Int = 0
    var totalInclVATRappen: Int = 0
    var contributionMarginRappen: Int = 0
    var lineItemsData: Data?
    var offer: Offer?

    init(variant: OfferVariant) {
        tierRaw = variant.tier.rawValue
        manufacturerRaw = variant.manufacturer.rawValue
        score = variant.score.score
        cameraCount = variant.selection.cameraCount
        let t = variant.totals
        materialNetRappen = Money.toRappen(t.materialNet)
        materialCostRappen = Money.toRappen(t.materialCost)
        laborNetRappen = Money.toRappen(t.laborNet)
        laborCostRappen = Money.toRappen(t.laborCost)
        discountRappen = Money.toRappen(t.discountAmount)
        vatRappen = Money.toRappen(t.vatAmount)
        totalInclVATRappen = Money.toRappen(t.totalInclVAT)
        contributionMarginRappen = Money.toRappen(t.contributionMargin)
        lineItemsData = try? JSONEncoder().encode(variant.lineItems)
    }

    var tier: OfferTier { OfferTier(rawValue: tierRaw) ?? .standard }
    var manufacturer: Manufacturer { Manufacturer(rawValue: manufacturerRaw) ?? .neutral }
    var totalInclVAT: Decimal { Money.rappen(totalInclVATRappen) }

    var lineItems: [OfferLineItem] {
        guard let lineItemsData else { return [] }
        return (try? JSONDecoder().decode([OfferLineItem].self, from: lineItemsData)) ?? []
    }
}
