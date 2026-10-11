import Foundation

public enum LineItemKind: String, Codable, Hashable, Sendable {
    case material
    case labor
}

public struct OfferLineItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: LineItemKind
    public var position: Int
    public var category: String
    public var manufacturer: Manufacturer?
    public var productID: UUID?
    public var articleNumber: String
    public var description: String
    public var quantity: Decimal
    public var unit: ProductUnit
    public var unitPurchasePrice: Decimal
    public var unitSellPrice: Decimal

    public init(
        id: UUID = UUID(),
        kind: LineItemKind,
        position: Int = 0,
        category: String,
        manufacturer: Manufacturer? = nil,
        productID: UUID? = nil,
        articleNumber: String = "",
        description: String,
        quantity: Decimal,
        unit: ProductUnit,
        unitPurchasePrice: Decimal,
        unitSellPrice: Decimal
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.category = category
        self.manufacturer = manufacturer
        self.productID = productID
        self.articleNumber = articleNumber
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitPurchasePrice = unitPurchasePrice
        self.unitSellPrice = unitSellPrice
    }

    public init(product: ProductRecord, quantity: Decimal, description: String? = nil) {
        self.init(
            kind: .material,
            category: product.category.label,
            manufacturer: product.manufacturer,
            productID: product.id,
            articleNumber: product.articleNumber,
            description: description ?? product.name,
            quantity: quantity,
            unit: product.unit,
            unitPurchasePrice: product.purchasePrice,
            unitSellPrice: product.sellPrice
        )
    }

    public var totalPurchase: Decimal { (unitPurchasePrice * quantity).roundedTo(scale: 2) }
    public var totalSell: Decimal { (unitSellPrice * quantity).roundedTo(scale: 2) }
    public var marginAmount: Decimal { totalSell - totalPurchase }
    public var marginPercent: Decimal { PricingCalculator.marginPercent(sell: totalSell, cost: totalPurchase) }
}

public struct OfferTotals: Codable, Hashable, Sendable {
    public var materialNet: Decimal
    public var materialCost: Decimal
    public var laborNet: Decimal
    public var laborCost: Decimal
    public var subtotal: Decimal
    public var discountPercent: Decimal
    public var discountAmount: Decimal
    public var netAfterDiscount: Decimal
    public var vatPercent: Decimal
    public var vatAmount: Decimal
    public var roundingDifference: Decimal
    public var totalInclVAT: Decimal
    public var laborHours: Decimal

    public var materialMargin: Decimal { materialNet - materialCost }
    public var materialMarginPercent: Decimal { PricingCalculator.marginPercent(sell: materialNet, cost: materialCost) }
    public var laborMargin: Decimal { laborNet - laborCost }
    /// Deckungsbeitrag nach Rabatt: Nettoerlös abzüglich Material- und Arbeitskosten.
    public var contributionMargin: Decimal { netAfterDiscount - materialCost - laborCost }
    public var contributionMarginPercent: Decimal {
        PricingCalculator.marginPercent(sell: netAfterDiscount, cost: materialCost + laborCost)
    }

    public static let zero = OfferTotals(
        materialNet: 0, materialCost: 0, laborNet: 0, laborCost: 0, subtotal: 0,
        discountPercent: 0, discountAmount: 0, netAfterDiscount: 0, vatPercent: 0,
        vatAmount: 0, roundingDifference: 0, totalInclVAT: 0, laborHours: 0
    )
}

public enum PricingCalculator {
    public static let maximumDiscountPercent: Decimal = 30

    /// Marge in Prozent vom Verkaufspreis. Bei Verkaufspreis 0 ist die Marge 0.
    public static func marginPercent(sell: Decimal, cost: Decimal) -> Decimal {
        guard sell != 0 else { return 0 }
        return ((sell - cost) / sell * 100).roundedTo(scale: 1)
    }

    /// Verkaufspreis aus Einkaufspreis und Zielmarge (Prozent vom Verkaufspreis), auf 5 Rappen gerundet.
    public static func sellPrice(purchase: Decimal, targetMarginPercent: Decimal) -> Decimal {
        let margin = targetMarginPercent.clamped(to: 0...95)
        return (purchase / (1 - margin / 100)).roundedToFiveRappen
    }

    public static func vat(on net: Decimal, percent: Decimal) -> Decimal {
        (net * percent / 100).roundedTo(scale: 2)
    }

    public static func totals(
        for items: [OfferLineItem],
        discountPercent: Decimal,
        vatPercent: Decimal
    ) -> OfferTotals {
        let material = items.filter { $0.kind == .material }
        let labor = items.filter { $0.kind == .labor }
        let materialNet = material.reduce(Decimal(0)) { $0 + $1.totalSell }
        let materialCost = material.reduce(Decimal(0)) { $0 + $1.totalPurchase }
        let laborNet = labor.reduce(Decimal(0)) { $0 + $1.totalSell }
        let laborCost = labor.reduce(Decimal(0)) { $0 + $1.totalPurchase }
        let laborHours = labor.filter { $0.unit == .stunde }.reduce(Decimal(0)) { $0 + $1.quantity }

        let subtotal = materialNet + laborNet
        let discount = discountPercent.clamped(to: 0...maximumDiscountPercent)
        let discountAmount = (subtotal * discount / 100).roundedTo(scale: 2)
        let netAfterDiscount = subtotal - discountAmount
        let vatAmount = vat(on: netAfterDiscount, percent: vatPercent)
        let exactTotal = netAfterDiscount + vatAmount
        let roundedTotal = exactTotal.roundedToFiveRappen

        return OfferTotals(
            materialNet: materialNet,
            materialCost: materialCost,
            laborNet: laborNet,
            laborCost: laborCost,
            subtotal: subtotal,
            discountPercent: discount,
            discountAmount: discountAmount,
            netAfterDiscount: netAfterDiscount,
            vatPercent: vatPercent,
            vatAmount: vatAmount,
            roundingDifference: roundedTotal - exactTotal,
            totalInclVAT: roundedTotal,
            laborHours: laborHours
        )
    }

    /// Nummeriert Positionen fortlaufend: Material zuerst, danach Arbeit.
    public static func numbered(_ items: [OfferLineItem]) -> [OfferLineItem] {
        let ordered = items.filter { $0.kind == .material } + items.filter { $0.kind == .labor }
        return ordered.enumerated().map { index, item in
            var copy = item
            copy.position = index + 1
            return copy
        }
    }
}
