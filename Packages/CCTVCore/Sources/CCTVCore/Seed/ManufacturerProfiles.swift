import Foundation

public struct ManufacturerProfile: Sendable, Hashable, Identifiable {
    public var manufacturer: Manufacturer
    public var tagline: String
    public var segment: String
    public var strengths: [String]
    public var limitations: [String]
    public var preferredWhen: [String]
    public var avoidWhen: [String]
    public var typicalSize: String
    public var ecosystem: String

    public var id: String { manufacturer.rawValue }
}

/// Neutrale Kurzprofile für die Beratung. Sie beschreiben Einsatzschwerpunkte, keine Produktgarantien.
public enum ManufacturerProfiles {
    public static let all: [ManufacturerProfile] = [
        ManufacturerProfile(
            manufacturer: .eufy,
            tagline: "Einfache Akku- und WLAN-Kameras für Privatkunden",
            segment: "Consumer / Smart Home",
            strengths: ["Akku- und Solarbetrieb ohne Verkabelung", "Lokale Speicherung in der HomeBase, keine Abo-Pflicht", "Sehr einfache App-Bedienung"],
            limitations: ["Keine Daueraufnahme mit Akkukameras", "Kein ONVIF/VMS", "Begrenzte Benutzer- und Rechteverwaltung"],
            preferredWhen: ["1–4 Kameras", "Eigenheim oder kleines Mehrfamilienhaus", "Wenig oder keine Verkabelung möglich"],
            avoidWhen: ["24/7-Aufzeichnung", "Viele Kameras oder mehrere Standorte", "Gewerbliche Compliance-Anforderungen"],
            typicalSize: "1–4 Kameras",
            ecosystem: "eufy Security App, HomeBase"
        ),
        ManufacturerProfile(
            manufacturer: .reolink,
            tagline: "Preis-Leistungs-Sieger für PoE- und WLAN-Systeme",
            segment: "Prosumer / kleines Gewerbe",
            strengths: ["Sehr gutes Preis-Leistungs-Verhältnis", "PoE-Kameras mit NVR, lokale Speicherung", "Personen- und Fahrzeugerkennung integriert"],
            limitations: ["ONVIF nur teilweise", "Keine Enterprise-VMS-Funktionen", "Eingeschränkte Compliance-Dokumentation"],
            preferredWhen: ["2–16 Kameras", "Kleineres Gewerbe oder anspruchsvolles Eigenheim", "Lokale Aufzeichnung ohne Cloud"],
            avoidWhen: ["Enterprise-VMS", "Hohe Integrations- oder Compliance-Anforderungen"],
            typicalSize: "2–16 Kameras",
            ecosystem: "Reolink App und Client, RLN-NVR"
        ),
        ManufacturerProfile(
            manufacturer: .dahua,
            tagline: "Breites Profi-Sortiment mit KI-Funktionen für KMU",
            segment: "KMU / Professional",
            strengths: ["Grosses Sortiment inkl. PTZ und Kennzeichenkameras", "Zuverlässige NVR mit Daueraufnahme", "WizSense-Analyse für Personen und Fahrzeuge"],
            limitations: ["Konfiguration anspruchsvoller", "Beschaffungsrichtlinien einzelner Kunden prüfen"],
            preferredWhen: ["Mehrere Kameras im KMU-Umfeld", "PoE mit NVR und Daueraufnahme", "Analysefunktionen gewünscht"],
            avoidWhen: ["Reine Akku-/WLAN-Lösungen", "Kundenvorgaben zu Herkunft und Zertifizierung"],
            typicalSize: "4–64 Kameras",
            ecosystem: "DMSS App, SmartPSS, DSS"
        ),
        ManufacturerProfile(
            manufacturer: .uniview,
            tagline: "Preisbewusste, skalierbare IP-Systeme",
            segment: "KMU / Professional",
            strengths: ["Günstige professionelle PoE-Kameras", "Skalierbare NVR mit lokaler Aufzeichnung", "ONVIF-Profile für Drittsysteme"],
            limitations: ["Kleineres Zubehörsortiment", "Beschaffungsrichtlinien einzelner Kunden prüfen"],
            preferredWhen: ["Preisbewusste KMU", "PoE mit NVR", "Wachsende Anlagen"],
            avoidWhen: ["Akku-/WLAN-Lösungen", "Hohe Cybersecurity-Vorgaben"],
            typicalSize: "4–64 Kameras",
            ecosystem: "EZView App, EZStation, UNV NVR"
        ),
        ManufacturerProfile(
            manufacturer: .axis,
            tagline: "Premium-Lösungen mit hoher Cybersecurity und langem Lebenszyklus",
            segment: "Enterprise / Premium",
            strengths: ["Signierte Firmware, Secure Boot, langfristiger Support", "Offene Schnittstellen (VAPIX, ONVIF), breite VMS-Unterstützung", "Mehrstandort-Betrieb und Compliance"],
            limitations: ["Höheres Preisniveau", "Keine Akku- oder WLAN-Kameras"],
            preferredWhen: ["Hohe Cybersecurity- oder Compliance-Anforderungen", "VMS-Integration und mehrere Standorte", "Premium-Budget mit Lifecycle-Fokus"],
            avoidWhen: ["Knappes Budget", "Kleine Wohnobjekte ohne Verkabelung"],
            typicalSize: "ab 4 Kameras bis Enterprise",
            ecosystem: "AXIS Camera Station Pro, Drittanbieter-VMS"
        )
    ]

    public static func profile(for manufacturer: Manufacturer) -> ManufacturerProfile? {
        all.first { $0.manufacturer == manufacturer }
    }
}
