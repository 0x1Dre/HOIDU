import Foundation

public struct ProductSpecs: Codable, Hashable, Sendable {
    public var megapixels: Int
    public var isOutdoor: Bool
    public var nightVision: NightVision
    public var audio: AudioMode
    public var formFactor: CameraFormFactor
    public var supportsPoE: Bool
    public var supportsWiFi: Bool
    public var isBattery: Bool
    public var isPTZ: Bool
    public var hasAnalytics: Bool
    public var hasLPR: Bool
    /// Kanäle bei NVR, Ports bei Switch.
    public var channels: Int
    public var poePorts: Int
    public var driveBays: Int
    public var capacityTB: Int
    /// Leistung in VA bei USV.
    public var powerVA: Int

    public init(
        megapixels: Int = 0,
        isOutdoor: Bool = false,
        nightVision: NightVision = .keine,
        audio: AudioMode = .nein,
        formFactor: CameraFormFactor = .automatisch,
        supportsPoE: Bool = false,
        supportsWiFi: Bool = false,
        isBattery: Bool = false,
        isPTZ: Bool = false,
        hasAnalytics: Bool = false,
        hasLPR: Bool = false,
        channels: Int = 0,
        poePorts: Int = 0,
        driveBays: Int = 0,
        capacityTB: Int = 0,
        powerVA: Int = 0
    ) {
        self.megapixels = megapixels
        self.isOutdoor = isOutdoor
        self.nightVision = nightVision
        self.audio = audio
        self.formFactor = formFactor
        self.supportsPoE = supportsPoE
        self.supportsWiFi = supportsWiFi
        self.isBattery = isBattery
        self.isPTZ = isPTZ
        self.hasAnalytics = hasAnalytics
        self.hasLPR = hasLPR
        self.channels = channels
        self.poePorts = poePorts
        self.driveBays = driveBays
        self.capacityTB = capacityTB
        self.powerVA = powerVA
    }
}

/// Verwendung eines Produkts in der automatischen Komponentenauswahl.
public enum ComponentRole: String, LabeledOption {
    case kamera, rekorder, festplatte, poeSwitch, usv, kabel, stecker, halterung, anschlussdose, kabelkanal
    case schildKlein, schildGross, hebebuehne, monitor, rack, vmsLizenz, speicherkarte, keine

    public var label: String {
        switch self {
        case .kamera: "Kamera"
        case .rekorder: "Rekorder / Zentrale"
        case .festplatte: "Festplatte"
        case .poeSwitch: "PoE-Switch"
        case .usv: "USV"
        case .kabel: "Netzwerkkabel"
        case .stecker: "Stecker/Anschlussmaterial"
        case .halterung: "Wand-/Masthalter"
        case .anschlussdose: "Anschlussdose aussen"
        case .kabelkanal: "Kabelkanal/Befestigung"
        case .schildKlein: "Hinweisschild klein"
        case .schildGross: "Hinweisschild gross"
        case .hebebuehne: "Hebebühne (Miete)"
        case .monitor: "Monitor vor Ort"
        case .rack: "Netzwerkschrank"
        case .vmsLizenz: "VMS-Lizenz pro Kamera"
        case .speicherkarte: "Speicherkarte"
        case .keine: "Nur manuell"
        }
    }

    public static func defaultRole(for category: ProductCategory) -> ComponentRole {
        switch category {
        case .kamera: .kamera
        case .nvr: .rekorder
        case .festplatte: .festplatte
        case .poeSwitch: .poeSwitch
        case .usv: .usv
        case .netzwerkkabel: .kabel
        case .lizenz: .vmsLizenz
        case .zubehoer, .montagematerial, .beschilderung: .keine
        }
    }
}

public struct ProductRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var manufacturer: Manufacturer
    public var category: ProductCategory
    public var role: ComponentRole
    public var name: String
    public var articleNumber: String
    public var unit: ProductUnit
    public var purchasePrice: Decimal
    public var sellPrice: Decimal
    /// Produktlinie, für welche Variante das Produkt bevorzugt wird.
    public var tier: OfferTier
    public var specs: ProductSpecs
    public var isActive: Bool
    public var notes: String

    public init(
        id: UUID = UUID(),
        manufacturer: Manufacturer,
        category: ProductCategory,
        role: ComponentRole? = nil,
        name: String,
        articleNumber: String = "",
        unit: ProductUnit = .stueck,
        purchasePrice: Decimal,
        sellPrice: Decimal,
        tier: OfferTier = .standard,
        specs: ProductSpecs = ProductSpecs(),
        isActive: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.category = category
        self.role = role ?? ComponentRole.defaultRole(for: category)
        self.name = name
        self.articleNumber = articleNumber
        self.unit = unit
        self.purchasePrice = purchasePrice
        self.sellPrice = sellPrice
        self.tier = tier
        self.specs = specs
        self.isActive = isActive
        self.notes = notes
    }

    public var marginAmount: Decimal { sellPrice - purchasePrice }

    /// Marge in Prozent vom Verkaufspreis.
    public var marginPercent: Decimal {
        PricingCalculator.marginPercent(sell: sellPrice, cost: purchasePrice)
    }
}

public struct PriceListRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var manufacturer: Manufacturer
    public var name: String
    public var validFrom: Date
    public var currency: String
    public var note: String
    public var isExampleData: Bool
    public var products: [ProductRecord]

    public init(
        id: UUID = UUID(),
        manufacturer: Manufacturer,
        name: String,
        validFrom: Date = Date(),
        currency: String = "CHF",
        note: String = "",
        isExampleData: Bool = false,
        products: [ProductRecord] = []
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.name = name
        self.validFrom = validFrom
        self.currency = currency
        self.note = note
        self.isExampleData = isExampleData
        self.products = products
    }
}

/// Zusammengefasste, aktive Produkte aller Preislisten.
public struct ProductCatalog: Sendable {
    public let products: [ProductRecord]

    public init(priceLists: [PriceListRecord]) {
        self.products = priceLists.flatMap(\.products).filter(\.isActive)
    }

    public init(products: [ProductRecord]) {
        self.products = products.filter(\.isActive)
    }

    public func products(of manufacturer: Manufacturer, role: ComponentRole) -> [ProductRecord] {
        products.filter { $0.manufacturer == manufacturer && $0.role == role }
    }

    /// Produkte des Herstellers; fehlen solche, die herstellerneutralen Produkte derselben Rolle.
    public func productsPreferring(_ manufacturer: Manufacturer, role: ComponentRole) -> [ProductRecord] {
        let own = products(of: manufacturer, role: role)
        return own.isEmpty ? products(of: .neutral, role: role) : own
    }

    public func hasCameras(for manufacturer: Manufacturer) -> Bool {
        !products(of: manufacturer, role: .kamera).isEmpty
    }
}
