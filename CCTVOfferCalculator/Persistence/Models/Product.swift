import Foundation
import SwiftData
import CCTVCore

/// Preislistenposition. Beträge werden in Rappen (Ganzzahl) gespeichert.
@Model
final class Product {
    var id: UUID = UUID()
    var manufacturerRaw: String = Manufacturer.neutral.rawValue
    var categoryRaw: String = ProductCategory.zubehoer.rawValue
    var roleRaw: String = ComponentRole.keine.rawValue
    var name: String = ""
    var articleNumber: String = ""
    var unitRaw: String = ProductUnit.stueck.rawValue
    var purchaseRappen: Int = 0
    var sellRappen: Int = 0
    var tierRaw: String = OfferTier.standard.rawValue
    var isActive: Bool = true
    var notes: String = ""

    // Technische Merkmale
    var megapixels: Int = 0
    var isOutdoor: Bool = false
    var nightVisionRaw: String = NightVision.keine.rawValue
    var audioRaw: String = AudioMode.nein.rawValue
    var formFactorRaw: String = CameraFormFactor.automatisch.rawValue
    var supportsPoE: Bool = false
    var supportsWiFi: Bool = false
    var isBattery: Bool = false
    var isPTZ: Bool = false
    var hasAnalytics: Bool = false
    var hasLPR: Bool = false
    var channels: Int = 0
    var poePorts: Int = 0
    var driveBays: Int = 0
    var capacityTB: Int = 0
    var powerVA: Int = 0

    var priceList: PriceList?

    init(id: UUID = UUID()) {
        self.id = id
    }

    var category: ProductCategory { ProductCategory(rawValue: categoryRaw) ?? .zubehoer }

    var sortKey: String {
        let index = ProductCategory.allCases.firstIndex(of: category) ?? 99
        return String(format: "%02d-", index) + name
    }

    var record: ProductRecord {
        ProductRecord(
            id: id,
            manufacturer: Manufacturer(rawValue: manufacturerRaw) ?? .neutral,
            category: category,
            role: ComponentRole(rawValue: roleRaw) ?? .keine,
            name: name,
            articleNumber: articleNumber,
            unit: ProductUnit(rawValue: unitRaw) ?? .stueck,
            purchasePrice: Money.rappen(purchaseRappen),
            sellPrice: Money.rappen(sellRappen),
            tier: OfferTier(rawValue: tierRaw) ?? .standard,
            specs: ProductSpecs(
                megapixels: megapixels,
                isOutdoor: isOutdoor,
                nightVision: NightVision(rawValue: nightVisionRaw) ?? .keine,
                audio: AudioMode(rawValue: audioRaw) ?? .nein,
                formFactor: CameraFormFactor(rawValue: formFactorRaw) ?? .automatisch,
                supportsPoE: supportsPoE,
                supportsWiFi: supportsWiFi,
                isBattery: isBattery,
                isPTZ: isPTZ,
                hasAnalytics: hasAnalytics,
                hasLPR: hasLPR,
                channels: channels,
                poePorts: poePorts,
                driveBays: driveBays,
                capacityTB: capacityTB,
                powerVA: powerVA
            ),
            isActive: isActive,
            notes: notes
        )
    }

    func apply(_ r: ProductRecord) {
        manufacturerRaw = r.manufacturer.rawValue
        categoryRaw = r.category.rawValue
        roleRaw = r.role.rawValue
        name = r.name
        articleNumber = r.articleNumber
        unitRaw = r.unit.rawValue
        purchaseRappen = Money.toRappen(r.purchasePrice)
        sellRappen = Money.toRappen(r.sellPrice)
        tierRaw = r.tier.rawValue
        isActive = r.isActive
        notes = r.notes
        megapixels = r.specs.megapixels
        isOutdoor = r.specs.isOutdoor
        nightVisionRaw = r.specs.nightVision.rawValue
        audioRaw = r.specs.audio.rawValue
        formFactorRaw = r.specs.formFactor.rawValue
        supportsPoE = r.specs.supportsPoE
        supportsWiFi = r.specs.supportsWiFi
        isBattery = r.specs.isBattery
        isPTZ = r.specs.isPTZ
        hasAnalytics = r.specs.hasAnalytics
        hasLPR = r.specs.hasLPR
        channels = r.specs.channels
        poePorts = r.specs.poePorts
        driveBays = r.specs.driveBays
        capacityTB = r.specs.capacityTB
        powerVA = r.specs.powerVA
    }
}
