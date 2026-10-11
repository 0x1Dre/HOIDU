import Foundation

public enum FitLevel: String, Codable, Hashable, Sendable {
    case sehrGut, geeignet, bedingt, nichtEmpfohlen

    public var label: String {
        switch self {
        case .sehrGut: "Sehr gut geeignet"
        case .geeignet: "Geeignet"
        case .bedingt: "Bedingt geeignet"
        case .nichtEmpfohlen: "Nicht empfohlen"
        }
    }

    public init(score: Int) {
        switch score {
        case 75...: self = .sehrGut
        case 55..<75: self = .geeignet
        case 35..<55: self = .bedingt
        default: self = .nichtEmpfohlen
        }
    }
}

public struct ScoreFactor: Codable, Hashable, Sendable {
    public var points: Int
    public var reason: String

    public init(_ points: Int, _ reason: String) {
        self.points = points
        self.reason = reason
    }
}

public struct ManufacturerScore: Codable, Hashable, Sendable, Identifiable {
    public var manufacturer: Manufacturer
    public var score: Int
    public var factors: [ScoreFactor]
    public var warnings: [String]

    public var id: String { manufacturer.rawValue }
    public var fit: FitLevel { FitLevel(score: score) }
    public var pros: [String] { factors.filter { $0.points > 0 }.sorted { $0.points > $1.points }.map(\.reason) }
    public var cons: [String] { factors.filter { $0.points < 0 }.sorted { $0.points < $1.points }.map(\.reason) }

    /// Kurzbegründung aus den stärksten Faktoren.
    public var rationale: String {
        let positive = pros.prefix(2)
        let negative = cons.prefix(1)
        var parts: [String] = []
        if !positive.isEmpty { parts.append(positive.joined(separator: "; ")) }
        if !negative.isEmpty { parts.append("Einschränkung: " + negative.joined()) }
        return parts.isEmpty ? "Neutral bewertet – keine ausgeprägten Vor- oder Nachteile." : parts.joined(separator: ". ") + "."
    }
}

/// Regelbasierte Herstellerbewertung (0–100). Basiswert 50, Faktoren addieren oder ziehen Punkte ab.
public enum ManufacturerScoring {
    public static let baseScore = 50

    public static func scores(for project: ProjectRecord) -> [ManufacturerScore] {
        let profile = ProjectProfile(project: project)
        return Manufacturer.scored
            .map { score($0, profile: profile) }
            .sorted { $0.score == $1.score ? $0.manufacturer.rawValue < $1.manufacturer.rawValue : $0.score > $1.score }
    }

    public static func score(_ manufacturer: Manufacturer, profile: ProjectProfile) -> ManufacturerScore {
        var factors: [ScoreFactor] = []
        var warnings: [String] = []

        switch manufacturer {
        case .eufy: eufy(profile, &factors, &warnings)
        case .reolink: reolink(profile, &factors, &warnings)
        case .dahua: dahua(profile, &factors, &warnings)
        case .uniview: uniview(profile, &factors, &warnings)
        case .axis: axis(profile, &factors, &warnings)
        case .neutral: break
        }

        if profile.totalCameras == 0 {
            warnings.append("Noch keine Kameras erfasst – Bewertung ist nur vorläufig.")
        }

        let total = baseScore + factors.reduce(0) { $0 + $1.points }
        return ManufacturerScore(
            manufacturer: manufacturer,
            score: min(100, max(0, total)),
            factors: factors,
            warnings: warnings
        )
    }

    // MARK: - Regeln je Hersteller

    private static func eufy(_ p: ProjectProfile, _ f: inout [ScoreFactor], _ w: inout [String]) {
        switch p.totalCameras {
        case 1...4: f.append(ScoreFactor(20, "1–4 Kameras: ideale Systemgrösse für Eufy"))
        case 5...8: f.append(ScoreFactor(-10, "5–8 Kameras: an der Grenze eines Eufy-Systems"))
        case 9...: f.append(ScoreFactor(-35, "Mehr als 8 Kameras: für Eufy zu gross"))
            w.append("Eufy ist für mehr als 8 Kameras nicht ausgelegt.")
        default: break
        }
        if p.usesWireless { f.append(ScoreFactor(15, "Akku-/WLAN-Betrieb ist Kernkompetenz von Eufy")) }
        if p.usesPoE { f.append(ScoreFactor(-10, "PoE-Verkabelung wird von Eufy kaum unterstützt")) }
        if p.isResidential { f.append(ScoreFactor(15, "Wohnobjekt mit einfacher Bedienung per App")) }
        if p.isCommercial { f.append(ScoreFactor(-10, "Gewerbliches Objekt: begrenzte Verwaltungsfunktionen")) }
        if p.littleCabling { f.append(ScoreFactor(10, "Wenig Verkabelung nötig")) }
        if p.continuousRecording {
            f.append(ScoreFactor(p.usesPoE ? -30 : -20, "Daueraufnahme 24/7 ist mit Eufy nur eingeschränkt möglich"))
            w.append("Eufy-Akkukameras zeichnen nur Ereignisse auf, keine 24/7-Daueraufnahme.")
        }
        if p.needsVMS || p.thirdPartyIntegration {
            f.append(ScoreFactor(-25, "Keine ONVIF-/VMS-Integration"))
            w.append("Eufy lässt sich nicht in ein VMS oder Drittsysteme einbinden.")
        }
        if p.multiSite { f.append(ScoreFactor(-15, "Mehrere Standorte zentral verwalten ist nicht vorgesehen")) }
        if p.highCybersecurity { f.append(ScoreFactor(-15, "Erhöhte Cybersecurity-Anforderungen schwer nachweisbar")) }
        if p.isCommercial && (p.complianceSensitive || p.userCount > 5) {
            f.append(ScoreFactor(-10, "Komplexes gewerbliches Umfeld"))
        }
        if p.wantsLPR { f.append(ScoreFactor(-10, "Keine Kennzeichenerkennung")) }
        switch p.tier {
        case .budget: f.append(ScoreFactor(10, "Günstiger Einstieg"))
        case .premium: f.append(ScoreFactor(-10, "Premium-Anspruch übersteigt das Consumer-Segment"))
        default: break
        }
    }

    private static func reolink(_ p: ProjectProfile, _ f: inout [ScoreFactor], _ w: inout [String]) {
        switch p.totalCameras {
        case 2...16: f.append(ScoreFactor(15, "2–16 Kameras: Reolink-Kernbereich"))
        case 1: f.append(ScoreFactor(5, "Einzelkamera mit lokaler Speicherung möglich"))
        case 17...: f.append(ScoreFactor(-15, "Mehr als 16 Kameras: Verwaltung wird aufwendig"))
        default: break
        }
        if p.usesPoE { f.append(ScoreFactor(10, "PoE-Kameras mit NVR, lokal gespeichert")) }
        if p.tier == .budget || p.tier == .standard || p.tier == .offen {
            f.append(ScoreFactor(10, "Sehr gutes Preis-Leistungs-Verhältnis"))
        }
        if p.continuousRecording { f.append(ScoreFactor(5, "Lokale Daueraufnahme auf NVR")) }
        if p.isCommercial && p.totalCameras <= 16 { f.append(ScoreFactor(5, "Passend für kleinere Gewerbeobjekte")) }
        if p.isResidential { f.append(ScoreFactor(5, "Einfache App für Privatkunden")) }
        if p.needsVMS {
            f.append(ScoreFactor(-15, "Enterprise-VMS-Anbindung nur eingeschränkt"))
            w.append("Reolink unterstützt ONVIF nur teilweise – VMS-Kompatibilität vorgängig testen.")
        }
        if p.thirdPartyIntegration { f.append(ScoreFactor(-10, "Begrenzte Integrationsschnittstellen")) }
        if p.highCybersecurity { f.append(ScoreFactor(-15, "Hohe Compliance-Anforderungen schwer abbildbar")) }
        if p.multiSite { f.append(ScoreFactor(-10, "Keine zentrale Mehrstandort-Verwaltung")) }
        if p.tier == .premium { f.append(ScoreFactor(-5, "Premium-Anspruch nur teilweise erfüllt")) }
    }

    private static func dahua(_ p: ProjectProfile, _ f: inout [ScoreFactor], _ w: inout [String]) {
        switch p.totalCameras {
        case 1...3: f.append(ScoreFactor(-5, "Kleines System: Dahua spielt Stärken erst ab mehreren Kameras aus"))
        case 4...32: f.append(ScoreFactor(15, "4–32 Kameras: typische KMU-Grösse"))
        case 33...: f.append(ScoreFactor(5, "Grosses System mit skalierbaren NVR"))
        default: break
        }
        if p.usesPoE { f.append(ScoreFactor(10, "PoE mit NVR, professionelle Installation")) }
        if p.continuousRecording || p.existing.contains(.nvr) { f.append(ScoreFactor(10, "Zuverlässige Daueraufnahme auf NVR")) }
        if p.analyticsFeatureCount > 0 { f.append(ScoreFactor(10, "KI-Funktionen (WizSense) für Personen/Fahrzeuge")) }
        if p.wantsLPR { f.append(ScoreFactor(5, "Kennzeichenerkennung im Portfolio")) }
        if p.isCommercial { f.append(ScoreFactor(10, "Bewährt im KMU-Umfeld")) }
        if p.isResidential && p.totalCameras <= 4 { f.append(ScoreFactor(-5, "Für einfache Wohnobjekte überdimensioniert")) }
        if p.usesWireless { f.append(ScoreFactor(-15, "Akku-/WLAN-Kameras nicht im Fokus")) }
        if p.highCybersecurity {
            f.append(ScoreFactor(-10, "Erhöhte Cybersecurity-Vorgaben: Beschaffungsrichtlinien prüfen"))
            w.append("Bei erhöhten Sicherheitsvorgaben die Beschaffungsrichtlinien des Kunden zu Herkunft und Zertifizierung prüfen.")
        }
        if p.tier == .standard { f.append(ScoreFactor(5, "Solide Standardlösung")) }
    }

    private static func uniview(_ p: ProjectProfile, _ f: inout [ScoreFactor], _ w: inout [String]) {
        if p.tier == .budget || p.tier == .standard || p.tier == .offen {
            f.append(ScoreFactor(10, "Preisbewusste Lösung für KMU"))
        }
        if p.isCommercial { f.append(ScoreFactor(10, "Passend für KMU-Objekte")) }
        if p.usesPoE { f.append(ScoreFactor(10, "PoE-Kameras mit NVR")) }
        if p.continuousRecording || !p.usesWireless { f.append(ScoreFactor(10, "Lokale Aufzeichnung auf NVR")) }
        switch p.totalCameras {
        case 4...64: f.append(ScoreFactor(10, "Skalierbares IP-System"))
        case 1...3: f.append(ScoreFactor(-5, "Sehr kleines System"))
        default: break
        }
        if p.usesWireless { f.append(ScoreFactor(-15, "Keine Akku-/WLAN-Kameras im Fokus")) }
        if p.isResidential && p.totalCameras <= 4 { f.append(ScoreFactor(-5, "Für einfache Wohnobjekte eher technisch")) }
        if p.highCybersecurity {
            f.append(ScoreFactor(-10, "Erhöhte Cybersecurity-Vorgaben: Beschaffungsrichtlinien prüfen"))
            w.append("Bei erhöhten Sicherheitsvorgaben die Beschaffungsrichtlinien des Kunden zu Herkunft und Zertifizierung prüfen.")
        }
        if p.needsVMS { f.append(ScoreFactor(5, "ONVIF-Profile für VMS-Anbindung")) }
    }

    private static func axis(_ p: ProjectProfile, _ f: inout [ScoreFactor], _ w: inout [String]) {
        if p.highCybersecurity { f.append(ScoreFactor(20, "Hohe Cybersecurity (signierte Firmware, Secure Boot)")) }
        if p.multiSite { f.append(ScoreFactor(15, "Mehrstandort-Betrieb mit zentralem VMS")) }
        if p.needsVMS { f.append(ScoreFactor(15, "Native VMS-Integration (AXIS Camera Station, Drittanbieter)")) }
        if p.thirdPartyIntegration { f.append(ScoreFactor(10, "Offene Schnittstellen (VAPIX, ONVIF)")) }
        if p.complianceSensitive { f.append(ScoreFactor(5, "Compliance und Dokumentation gut abbildbar")) }
        if p.usesPoE { f.append(ScoreFactor(5, "PoE-Kameras mit langem Lebenszyklus")) }
        switch p.tier {
        case .premium: f.append(ScoreFactor(15, "Premium-Qualität und Lifecycle-Support"))
        case .budget:
            f.append(ScoreFactor(-25, "Budgetvorgabe mit Axis kaum erreichbar"))
            w.append("Die Budgetvorgabe ist mit Axis-Komponenten kaum einzuhalten.")
        default: break
        }
        if p.isResidential && p.totalCameras <= 4 { f.append(ScoreFactor(-15, "Für kleine Wohnobjekte überdimensioniert")) }
        if p.usesWireless {
            f.append(ScoreFactor(-20, "Keine Akku-/WLAN-Kameras im Sortiment"))
            w.append("Axis bietet keine Akku- oder WLAN-Kameras – Verkabelung zwingend.")
        }
        if p.totalCameras >= 16 { f.append(ScoreFactor(5, "Grosse Installation profitiert von zentralem Management")) }
    }
}
