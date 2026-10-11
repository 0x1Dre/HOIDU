import Foundation

/// Auswahloption mit deutscher Bezeichnung für Picker und Dokumente.
public protocol LabeledOption: CaseIterable, Codable, Hashable, Sendable, Identifiable, RawRepresentable
where RawValue == String, AllCases: RandomAccessCollection {
    var label: String { get }
}

public extension LabeledOption {
    var id: String { rawValue }
}

public extension Set where Element: LabeledOption {
    /// Elemente in der Reihenfolge von `allCases`.
    var ordered: [Element] {
        Element.allCases.filter { contains($0) }
    }

    var labels: String {
        ordered.map(\.label).joined(separator: ", ")
    }
}

public enum ObjectType: String, LabeledOption {
    case eigenheim, mehrfamilienhaus, laden, buero, lager, werkstatt, baustelle, sonstiges

    public var label: String {
        switch self {
        case .eigenheim: "Eigenheim"
        case .mehrfamilienhaus: "Mehrfamilienhaus"
        case .laden: "Laden"
        case .buero: "Büro"
        case .lager: "Lager"
        case .werkstatt: "Werkstatt"
        case .baustelle: "Baustelle"
        case .sonstiges: "Sonstiges"
        }
    }

    public var isResidential: Bool { self == .eigenheim || self == .mehrfamilienhaus }

    public var isCommercial: Bool {
        switch self {
        case .laden, .buero, .lager, .werkstatt, .baustelle: true
        default: false
        }
    }
}

public enum AreaLocation: String, LabeledOption {
    case innen, aussen

    public var label: String {
        switch self {
        case .innen: "Innen"
        case .aussen: "Aussen"
        }
    }
}

public enum AreaPurpose: String, LabeledOption {
    case abschreckung, einbruchVandalismus, diebstahlpraevention, zufahrtZutritt, fernueberwachung, prozesskontrolle

    public var label: String {
        switch self {
        case .abschreckung: "Abschreckung"
        case .einbruchVandalismus: "Einbruch/Vandalismus"
        case .diebstahlpraevention: "Diebstahlprävention"
        case .zufahrtZutritt: "Zufahrt/Zutritt"
        case .fernueberwachung: "Fernüberwachung"
        case .prozesskontrolle: "Prozesskontrolle"
        }
    }
}

public enum DetectionTarget: String, LabeledOption {
    case bewegung, person, gesicht, fahrzeug, kennzeichen, kasseVorgang

    public var label: String {
        switch self {
        case .bewegung: "Bewegung"
        case .person: "Person"
        case .gesicht: "Gesicht"
        case .fahrzeug: "Fahrzeug"
        case .kennzeichen: "Kennzeichen"
        case .kasseVorgang: "Kasse/Vorgang"
        }
    }

    /// Minimale Sensorauflösung als konservativer Richtwert.
    public var minimumMegapixels: Int {
        switch self {
        case .bewegung: 2
        case .person, .fahrzeug, .kasseVorgang: 4
        case .kennzeichen: 4
        case .gesicht: 8
        }
    }

    /// Richtwert Pixeldichte nach DORI (EN 62676-4).
    public var pixelDensityHint: String {
        switch self {
        case .bewegung: "Detektion: ca. 25 px/m"
        case .person, .fahrzeug: "Beobachtung: ca. 63 px/m"
        case .kasseVorgang: "Erkennung: ca. 125 px/m"
        case .gesicht, .kennzeichen: "Identifikation: ca. 250 px/m"
        }
    }
}

public enum NightVision: String, LabeledOption {
    case keine, infrarot, farbeNacht

    public var label: String {
        switch self {
        case .keine: "Keine"
        case .infrarot: "IR"
        case .farbeNacht: "Farbbild bei Nacht"
        }
    }
}

public enum AudioMode: String, LabeledOption {
    case nein, mithoeren, gegensprechen

    public var label: String {
        switch self {
        case .nein: "Nein"
        case .mithoeren: "Mithören"
        case .gegensprechen: "Gegensprechen"
        }
    }
}

public enum CameraFormFactor: String, LabeledOption {
    case automatisch, bullet, dome, turret, ptz

    public var label: String {
        switch self {
        case .automatisch: "Automatisch"
        case .bullet: "Bullet"
        case .dome: "Dome"
        case .turret: "Turret"
        case .ptz: "PTZ"
        }
    }
}

public enum CablingStatus: String, LabeledOption {
    case ja, teilweise, nein, unklar

    public var label: String {
        switch self {
        case .ja: "Ja"
        case .teilweise: "Teilweise"
        case .nein: "Nein"
        case .unklar: "Unklar"
        }
    }

    /// Anteil neu zu ziehender Kabel.
    public var newCableShare: Decimal {
        switch self {
        case .ja: 0
        case .teilweise: Decimal(5) / 10
        case .nein: 1
        case .unklar: Decimal(75) / 100
        }
    }
}

public enum Clarification: String, LabeledOption {
    case ja, nein, abzuklaeren

    public var label: String {
        switch self {
        case .ja: "Ja"
        case .nein: "Nein"
        case .abzuklaeren: "Abzuklären"
        }
    }
}

public enum ConnectionType: String, LabeledOption {
    case poeLan, wlan, akku, solar

    public var label: String {
        switch self {
        case .poeLan: "PoE/LAN"
        case .wlan: "WLAN"
        case .akku: "Akku"
        case .solar: "Solar"
        }
    }

    public var isWireless: Bool { self != .poeLan }
    public var isBatteryPowered: Bool { self == .akku || self == .solar }
}

public enum MountingAccess: String, LabeledOption {
    case einfach, leiter, hebebuehne, spezialzugang

    public var label: String {
        switch self {
        case .einfach: "Einfach"
        case .leiter: "Leiter"
        case .hebebuehne: "Hebebühne"
        case .spezialzugang: "Spezialzugang"
        }
    }

    /// Montagestunden pro Kamera.
    public var hoursPerCamera: Decimal {
        switch self {
        case .einfach: Decimal(75) / 100
        case .leiter: 1
        case .hebebuehne: Decimal(15) / 10
        case .spezialzugang: 2
        }
    }
}

public enum LightingCondition: String, LabeledOption {
    case gut, schwach, keine, zusaetzlich

    public var label: String {
        switch self {
        case .gut: "Gut"
        case .schwach: "Schwach"
        case .keine: "Keine"
        case .zusaetzlich: "Zusätzliche Beleuchtung nötig"
        }
    }
}

public enum InfrastructureItem: String, LabeledOption {
    case nvr, poeSwitch, rack, usv, vpn, vlan

    public var label: String {
        switch self {
        case .nvr: "NVR"
        case .poeSwitch: "Switch"
        case .rack: "Rack"
        case .usv: "USV"
        case .vpn: "VPN"
        case .vlan: "VLAN"
        }
    }
}

public enum RecordingMode: String, LabeledOption {
    case dauer, ereignis, zeitplan

    public var label: String {
        switch self {
        case .dauer: "Daueraufnahme"
        case .ereignis: "Nur Ereignisse"
        case .zeitplan: "Zeitplan"
        }
    }
}

public enum AccessChannel: String, LabeledOption {
    case smartphone, pcBrowser, monitorVorOrt, vms

    public var label: String {
        switch self {
        case .smartphone: "Smartphone"
        case .pcBrowser: "PC/Browser"
        case .monitorVorOrt: "Monitor vor Ort"
        case .vms: "VMS"
        }
    }
}

public enum SystemFeature: String, LabeledOption {
    case personenerkennung, fahrzeugerkennung, kennzeichenerkennung, ptz, audio, zweiWegeAudio, pushMeldungen

    public var label: String {
        switch self {
        case .personenerkennung: "Personenerkennung"
        case .fahrzeugerkennung: "Fahrzeugerkennung"
        case .kennzeichenerkennung: "Kennzeichenerkennung"
        case .ptz: "PTZ"
        case .audio: "Audio"
        case .zweiWegeAudio: "Zwei-Wege-Audio"
        case .pushMeldungen: "Push-Meldungen"
        }
    }

    public var isAnalytics: Bool {
        self == .personenerkennung || self == .fahrzeugerkennung || self == .kennzeichenerkennung
    }
}

public enum SystemTier: String, LabeledOption {
    case budget, standard, premium, offen

    public var label: String {
        switch self {
        case .budget: "Budget"
        case .standard: "Standard"
        case .premium: "Premium"
        case .offen: "Offen"
        }
    }

    public var preferredOfferTier: OfferTier {
        switch self {
        case .budget: .budget
        case .standard, .offen: .standard
        case .premium: .premium
        }
    }
}

public enum OfferTier: String, LabeledOption, Comparable {
    case budget, standard, premium

    public var label: String {
        switch self {
        case .budget: "Budget"
        case .standard: "Standard"
        case .premium: "Premium"
        }
    }

    public var rank: Int {
        switch self {
        case .budget: 0
        case .standard: 1
        case .premium: 2
        }
    }

    public static func < (lhs: OfferTier, rhs: OfferTier) -> Bool { lhs.rank < rhs.rank }
}

public enum VideoCodec: String, LabeledOption {
    case h264, h265

    public var label: String {
        switch self {
        case .h264: "H.264"
        case .h265: "H.265"
        }
    }

    /// Konservative Bitrate in kbit/s pro Megapixel und Bild pro Sekunde.
    public var kbpsPerMegapixelPerFrame: Double {
        switch self {
        case .h264: 80
        case .h265: 48
        }
    }
}

public enum ProductCategory: String, LabeledOption {
    case kamera, nvr, festplatte, poeSwitch, usv, netzwerkkabel, zubehoer, montagematerial, beschilderung, lizenz

    public var label: String {
        switch self {
        case .kamera: "Kamera"
        case .nvr: "NVR / Rekorder"
        case .festplatte: "Festplatte"
        case .poeSwitch: "PoE-Switch"
        case .usv: "USV"
        case .netzwerkkabel: "Netzwerkkabel"
        case .zubehoer: "Zubehör"
        case .montagematerial: "Montagematerial"
        case .beschilderung: "Beschilderung"
        case .lizenz: "Lizenz/Software"
        }
    }
}

public enum ProductUnit: String, LabeledOption {
    case stueck, meter, pauschal, lizenz, tag, stunde

    public var label: String {
        switch self {
        case .stueck: "Stk."
        case .meter: "m"
        case .pauschal: "Pauschal"
        case .lizenz: "Lizenz"
        case .tag: "Tag"
        case .stunde: "h"
        }
    }
}

public enum LaborKind: String, LabeledOption {
    case begehung, montage, verkabelung, konfiguration, test, dokumentation, anfahrt

    public var label: String {
        switch self {
        case .begehung: "Begehung vor Ort"
        case .montage: "Montage"
        case .verkabelung: "Verkabelung"
        case .konfiguration: "Konfiguration"
        case .test: "Test und Inbetriebnahme"
        case .dokumentation: "Dokumentation und Instruktion"
        case .anfahrt: "Anfahrt"
        }
    }
}

public enum MaintenancePackage: String, LabeledOption {
    case basic, business, premium

    public var label: String {
        switch self {
        case .basic: "Basic"
        case .business: "Business"
        case .premium: "Premium"
        }
    }
}

public enum ProjectStatus: String, LabeledOption {
    case entwurf, erfasst, offeriert, gewonnen, verloren, archiviert

    public var label: String {
        switch self {
        case .entwurf: "Entwurf"
        case .erfasst: "Erfasst"
        case .offeriert: "Offeriert"
        case .gewonnen: "Auftrag erhalten"
        case .verloren: "Nicht erhalten"
        case .archiviert: "Archiviert"
        }
    }

    public var isOpen: Bool { self == .entwurf || self == .erfasst || self == .offeriert }
}

public enum OfferStatus: String, LabeledOption {
    case entwurf, versendet, angenommen, abgelehnt

    public var label: String {
        switch self {
        case .entwurf: "Entwurf"
        case .versendet: "Versendet"
        case .angenommen: "Angenommen"
        case .abgelehnt: "Abgelehnt"
        }
    }
}

public enum Manufacturer: String, LabeledOption {
    case eufy, reolink, dahua, uniview, axis, neutral

    public var label: String {
        switch self {
        case .eufy: "Eufy"
        case .reolink: "Reolink"
        case .dahua: "Dahua"
        case .uniview: "Uniview"
        case .axis: "Axis"
        case .neutral: "Herstellerneutral"
        }
    }

    /// Hersteller, die bewertet und als Systemlieferant vorgeschlagen werden.
    public static let scored: [Manufacturer] = [.eufy, .reolink, .dahua, .uniview, .axis]
}
