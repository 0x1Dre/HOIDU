import Foundation
import SwiftData
import CCTVCore

@Model
final class PriceList {
    var id: UUID = UUID()
    var manufacturerRaw: String = Manufacturer.neutral.rawValue
    var name: String = ""
    var validFrom: Date = Date()
    var currency: String = "CHF"
    var note: String = ""
    var isExampleData: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Product.priceList)
    var products: [Product] = []

    init(id: UUID = UUID()) {
        self.id = id
    }

    var manufacturer: Manufacturer {
        Manufacturer(rawValue: manufacturerRaw) ?? .neutral
    }

    var record: PriceListRecord {
        PriceListRecord(
            id: id,
            manufacturer: manufacturer,
            name: name,
            validFrom: validFrom,
            currency: currency,
            note: note,
            isExampleData: isExampleData,
            products: products.sorted { $0.sortKey < $1.sortKey }.map(\.record)
        )
    }

    func apply(_ record: PriceListRecord, context: ModelContext) {
        manufacturerRaw = record.manufacturer.rawValue
        name = record.name
        validFrom = record.validFrom
        currency = record.currency
        note = record.note
        isExampleData = record.isExampleData
        products = ModelSync.sync(
            products, with: record.products, context: context,
            id: { $0.id },
            create: { Product(id: $0.id) },
            update: { model, product, _ in model.apply(product) }
        )
    }
}
