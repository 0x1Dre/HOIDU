import Foundation

/// Wie gut ein Hersteller einen Wunsch aus der Erfassung erfüllt.
public enum RequirementStatus: String, Codable, Hashable, Sendable, Comparable {
    case nichtMoeglich, teilweise, erfuellt

    public var label: String {
        switch self {
        case .erfuellt: "Erfüllt"
        case .teilweise: "Mit Einschränkungen"
        case .nichtMoeglich: "Nicht möglich"
        }
    }

    private var order: Int {
        switch self {
        case .nichtMoeglich: 0
        case .teilweise: 1
        case .erfuellt: 2
        }
    }

    public static func < (lhs: RequirementStatus, rhs: RequirementStatus) -> Bool { lhs.order < rhs.order }
}

/// Abgleich eines einzelnen Kundenwunschs mit einem Hersteller.
public struct RequirementCheck: Hashable, Sendable, Identifiable {
    /// Bereich, z. B. «Aufzeichnung».
    public var title: String
    /// Was im Projekt erfasst wurde, z. B. «Daueraufnahme 24/7».
    public var wish: String
    public var status: RequirementStatus
    /// Begründung in Alltagssprache.
    public var explanation: String
    /// Vorschlag, wenn der Wunsch nicht oder nur teilweise erfüllt wird.
    public var alternative: String?

    public var id: String { title + "|" + wish }

    public init(title: String, wish: String, status: RequirementStatus, explanation: String, alternative: String? = nil) {
        self.title = title
        self.wish = wish
        self.status = status
        self.explanation = explanation
        self.alternative = alternative
    }
}

/// Prüft die erfassten Wünsche eines Projekts gegen die Möglichkeiten eines Herstellers.
/// Die Aussagen sind bewusst allgemein (Sortimentsschwerpunkte) und passen zur Punktebewertung.
public enum RequirementMatcher {
    public static func checks(for manufacturer: Manufacturer, project: ProjectRecord) -> [RequirementCheck] {
        guard manufacturer != .neutral else { return [] }
        let p = ProjectProfile(project: project)
        let rec = project.recording
        let connection = project.infrastructure.connection
        var result: [RequirementCheck] = []

        result.append(size(manufacturer, p))
        result.append(connectionCheck(manufacturer, connection))
        result.append(recordingCheck(manufacturer, rec.mode, connection: connection, hoursPerDay: rec.scheduleHoursPerDay))

        for channel in AccessChannel.allCases where rec.access.contains(channel) {
            result.append(accessCheck(manufacturer, channel))
        }
        if rec.features.contains(.personenerkennung) {
            result.append(analytics(manufacturer, wish: "Personenerkennung"))
        }
        if rec.features.contains(.fahrzeugerkennung) {
            result.append(analytics(manufacturer, wish: "Fahrzeugerkennung"))
        }
        if p.wantsLPR { result.append(lpr(manufacturer)) }
        if p.wantsPTZ { result.append(ptz(manufacturer)) }
        if p.wantsTwoWayAudio {
            result.append(audio(manufacturer, twoWay: true))
        } else if p.wantsAudio {
            result.append(audio(manufacturer, twoWay: false))
        }
        if p.wantsColorNight { result.append(colorNight(manufacturer)) }
        if p.multiSite { result.append(multiSite(manufacturer)) }
        if p.highCybersecurity { result.append(cybersecurity(manufacturer)) }
        if p.thirdPartyIntegration { result.append(integration(manufacturer)) }
        if rec.tier == .budget || rec.tier == .premium { result.append(tier(manufacturer, rec.tier)) }
        return result
    }

    // MARK: - Einzelne Anforderungen

    private static func size(_ m: Manufacturer, _ p: ProjectProfile) -> RequirementCheck {
        let n = p.totalCameras
        let title = "Systemgrösse"
        let wish = n == 1 ? "1 Kamera" : "\(n) Kameras"
        switch m {
        case .eufy:
            if n <= 4 { return .init(title: title, wish: wish, status: .erfuellt, explanation: "Eufy ist für kleine Systeme mit 1–4 Kameras gemacht.") }
            if n <= 8 { return .init(title: title, wish: wish, status: .teilweise, explanation: "Bis 8 Kameras machbar, aber Speicher in der HomeBase und Übersicht in der App werden knapp.", alternative: "Ab 5 Kameras ist ein System mit Rekorder (Reolink, Uniview) übersichtlicher.") }
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Eufy hat keinen Rekorder für grössere Anlagen. Mehr als 8 Kameras lassen sich nicht sinnvoll verwalten.", alternative: "Reolink (bis 16 Kameras) oder Dahua/Uniview mit Netzwerkrekorder.")
        case .reolink:
            if n <= 16 { return .init(title: title, wish: wish, status: .erfuellt, explanation: "Reolink deckt 1–16 Kameras mit einem Rekorder gut ab.") }
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Rekorder mit mehr Kanälen gibt es, aber ohne zentrale Verwaltungssoftware wird es bei vielen Kameras aufwendig.", alternative: "Dahua, Uniview oder Axis für grössere Anlagen.")
        case .dahua, .uniview:
            if n <= 3 { return .init(title: title, wish: wish, status: .teilweise, explanation: "Möglich, aber für sehr kleine Anlagen eher technisch und überdimensioniert.") }
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Skalierbare Rekorder von kleinen bis grossen Anlagen.")
        case .axis:
            if n <= 4 && p.isResidential { return .init(title: title, wish: wish, status: .teilweise, explanation: "Technisch problemlos, für ein kleines Wohnobjekt aber deutlich teurer als nötig.", alternative: "Eufy oder Reolink reichen für kleine Wohnobjekte.") }
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Axis skaliert von einzelnen Kameras bis zu grossen Anlagen mit zentraler Verwaltung.")
        case .neutral:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "")
        }
    }

    private static func connectionCheck(_ m: Manufacturer, _ c: ConnectionType) -> RequirementCheck {
        let title = "Anschluss"
        let wish = c.label
        let cableAlternative = "Wenn Kabel gezogen werden können: PoE-Kameras (ein Kabel für Strom und Daten)."
        switch (m, c) {
        case (.eufy, .poeLan):
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Eufy hat nur wenige kabelgebundene Modelle; das Sortiment ist auf Akku und WLAN ausgerichtet.", alternative: "Für PoE: Reolink, Dahua, Uniview oder Axis.")
        case (.eufy, _), (.reolink, _):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: c == .poeLan ? "PoE-Kameras mit Rekorder sind verfügbar." : "Modelle für \(c.label)-Betrieb sind im Sortiment.")
        case (.dahua, .poeLan), (.uniview, .poeLan), (.axis, .poeLan):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "PoE ist der Standard: ein Kabel für Strom und Daten, stabil und wartungsarm.")
        case (.dahua, .wlan), (.uniview, .wlan):
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Es gibt einzelne WLAN-Modelle, der Schwerpunkt liegt aber auf kabelgebundenen Kameras.", alternative: cableAlternative)
        case (.dahua, _), (.uniview, _):
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Im Profi-Sortiment gibt es keine Akku- oder Solarkameras.", alternative: "Eufy oder Reolink (Akku/Solar) – oder Kabel ziehen und PoE verwenden.")
        case (.axis, _):
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Axis bietet keine Akku- oder WLAN-Kameras. Jede Kamera braucht ein Netzwerkkabel (PoE).", alternative: "Eufy oder Reolink für kabellose Montage – oder Kabel ziehen.")
        case (.neutral, _):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "")
        }
    }

    private static func recordingCheck(_ m: Manufacturer, _ mode: RecordingMode, connection: ConnectionType, hoursPerDay: Int) -> RequirementCheck {
        let title = "Aufzeichnung"
        let wish: String = switch mode {
        case .dauer: "Daueraufnahme 24/7"
        case .ereignis: "Nur bei Ereignissen"
        case .zeitplan: "Nach Zeitplan (\(hoursPerDay) h pro Tag)"
        }
        if mode != .ereignis && connection.isBatteryPowered {
            return .init(title: title, wish: wish, status: .nichtMoeglich,
                         explanation: "Akku- und Solarkameras wachen nur bei Bewegung auf. Eine durchgehende Aufnahme würde den Akku innert Stunden leeren – das gilt für alle Hersteller.",
                         alternative: "Kameras mit Stromanschluss (PoE) und Rekorder – oder auf Ereignisaufnahme wechseln.")
        }
        switch (m, mode) {
        case (_, .ereignis):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Aufnahme bei Bewegung oder erkannter Person/Fahrzeug wird unterstützt.")
        case (.eufy, _):
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Nur einzelne Eufy-Modelle mit Stromanschluss zeichnen durchgehend auf, und der Speicher der HomeBase ist begrenzt.", alternative: "Reolink, Dahua oder Uniview mit Netzwerkrekorder.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Durchgehende Aufnahme auf einen Netzwerkrekorder (NVR) mit Festplatten vor Ort.")
        }
    }

    private static func accessCheck(_ m: Manufacturer, _ channel: AccessChannel) -> RequirementCheck {
        let title = "Zugriff"
        let wish = channel.label
        switch (m, channel) {
        case (_, .smartphone):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Live-Bild und Aufnahmen in der Hersteller-App.")
        case (.eufy, .pcBrowser):
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Web-Portal vorhanden, aber mit weniger Funktionen als die App.")
        case (.eufy, .monitorVorOrt):
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Eufy hat keinen Rekorder mit Bildschirmanschluss; ein fest installierter Monitor ist nicht vorgesehen.", alternative: "Rekorder mit HDMI-Ausgang (Reolink, Dahua, Uniview, Axis).")
        case (.eufy, .vms):
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Eufy unterstützt den Standard ONVIF nicht. Die Kameras lassen sich daher nicht in eine Videomanagement-Software einbinden.", alternative: "Axis, Dahua oder Uniview (ONVIF, offene Schnittstellen).")
        case (.reolink, .vms):
            return .init(title: title, wish: wish, status: .teilweise, explanation: "ONVIF wird nur von einem Teil der Modelle und nicht vollständig unterstützt. Die Einbindung muss vorher mit dem VMS getestet werden.", alternative: "Axis, Dahua oder Uniview für sichere VMS-Anbindung.")
        case (_, .vms):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Anbindung an Videomanagement-Software über ONVIF bzw. herstellereigene Software.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: channel == .monitorVorOrt ? "Rekorder mit HDMI-Ausgang für einen Monitor vor Ort." : "Zugriff über Browser bzw. PC-Software.")
        }
    }

    private static func analytics(_ m: Manufacturer, wish: String) -> RequirementCheck {
        let title = "KI-Erkennung"
        switch m {
        case .eufy where wish == "Fahrzeugerkennung":
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Personenerkennung ist gut, Fahrzeuge werden nur bei einzelnen Modellen unterschieden.")
        case .eufy, .reolink:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Die Kameras unterscheiden Personen und Fahrzeuge direkt in der Kamera – weniger Fehlalarme durch Tiere oder Bäume.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "KI-Analyse in Kamera oder Rekorder, mit Regeln wie Linienüberschreitung oder Bereichsüberwachung.")
        }
    }

    private static func lpr(_ m: Manufacturer) -> RequirementCheck {
        let title = "Kennzeichenerkennung"
        let wish = "Autonummern erkennen"
        switch m {
        case .eufy, .reolink:
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "\(m.label) hat keine Kameras mit Kennzeichenerkennung. Autonummern sind höchstens auf dem Bild lesbar, werden aber nicht ausgewertet.", alternative: "Dahua, Uniview oder Axis mit spezieller LPR-Kamera an der Einfahrt.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Spezielle Kameras lesen Kennzeichen aus und können z. B. eine Liste erlaubter Fahrzeuge prüfen. Wichtig: flacher Blickwinkel und gute Beleuchtung an der Zufahrt.")
        }
    }

    private static func ptz(_ m: Manufacturer) -> RequirementCheck {
        let title = "Schwenk-/Neigekamera"
        let wish = "PTZ"
        if m == .eufy {
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Schwenkbare Kameras für den Heimbereich, aber ohne optischen Zoom und ohne automatische Verfolgung über grosse Distanzen.", alternative: "Reolink, Dahua, Uniview oder Axis für PTZ mit optischem Zoom.")
        }
        return .init(title: title, wish: wish, status: .erfuellt, explanation: "PTZ-Kameras mit optischem Zoom sind im Sortiment.")
    }

    private static func audio(_ m: Manufacturer, twoWay: Bool) -> RequirementCheck {
        let title = "Audio"
        let wish = twoWay ? "Gegensprechen" : "Mithören"
        return .init(title: title, wish: wish, status: .erfuellt,
                     explanation: (twoWay ? "Kameras mit Mikrofon und Lautsprecher sind verfügbar." : "Kameras mit Mikrofon sind verfügbar.")
                        + " Hinweis: Tonaufnahmen sind datenschutzrechtlich heikel und brauchen eine klare Rechtfertigung.")
    }

    private static func colorNight(_ m: Manufacturer) -> RequirementCheck {
        let title = "Nachtsicht"
        let wish = "Farbbild bei Nacht"
        let technology: String = switch m {
        case .eufy: "mit eingebautem Scheinwerfer"
        case .reolink: "(ColorX bzw. Scheinwerfer)"
        case .dahua: "(Full-Color)"
        case .uniview: "(ColorHunter)"
        case .axis: "(Lightfinder)"
        case .neutral: ""
        }
        return .init(title: title, wish: wish, status: .erfuellt, explanation: "Farbbild bei wenig Licht \(technology). Bei völliger Dunkelheit braucht es zusätzliches Licht.")
    }

    private static func multiSite(_ m: Manufacturer) -> RequirementCheck {
        let title = "Mehrere Standorte"
        let wish = "Zentral verwalten"
        switch m {
        case .eufy:
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Jeder Standort ist ein eigenes System in der App. Es gibt keine zentrale Verwaltung mit Rechten und Übersicht über alle Standorte.", alternative: "Axis (zentrales VMS) oder Dahua mit Verwaltungssoftware.")
        case .reolink, .uniview:
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Mehrere Rekorder lassen sich in der App oder Client-Software zusammenfassen, aber ohne vollwertige zentrale Verwaltung.", alternative: "Axis oder Dahua für echte Mehrstandort-Verwaltung.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Zentrale Software verwaltet mehrere Standorte mit Benutzerrechten.")
        }
    }

    private static func cybersecurity(_ m: Manufacturer) -> RequirementCheck {
        let title = "Cybersecurity"
        let wish = "Erhöhte Anforderungen"
        switch m {
        case .eufy:
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Als Consumer-Produkt fehlen Nachweise wie signierte Firmware, Härtungsanleitungen oder Zertifizierungen, die Compliance-Vorgaben verlangen.", alternative: "Axis (Secure Boot, signierte Firmware, langer Update-Support).")
        case .reolink:
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Grundlegende Sicherheitsfunktionen sind vorhanden, formale Nachweise für hohe Anforderungen fehlen.", alternative: "Axis für nachweisbare Cybersecurity.")
        case .dahua, .uniview:
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Technisch sind Verschlüsselung und Härtung möglich. Manche Organisationen schliessen diese Hersteller aber in ihren Beschaffungsrichtlinien aus – das vorher mit dem Kunden klären.", alternative: "Axis, wenn Herkunft oder Zertifizierung vorgeschrieben ist.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Signierte Firmware, Secure Boot, langer Update-Support und dokumentierte Härtung.")
        }
    }

    private static func integration(_ m: Manufacturer) -> RequirementCheck {
        let title = "Integration"
        let wish = "Drittsysteme (Alarm, Zutritt, VMS)"
        switch m {
        case .eufy:
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Eufy hat keine offenen Schnittstellen für Alarm-, Zutritts- oder Gebäudesysteme.", alternative: "Axis, Dahua oder Uniview mit offenen Schnittstellen.")
        case .reolink:
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Einfache Anbindungen (z. B. RTSP-Stream) sind möglich, weitergehende Schnittstellen fehlen.", alternative: "Axis für umfangreiche Integration.")
        default:
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Offene Schnittstellen (ONVIF, SDK bzw. VAPIX) für die Anbindung an andere Systeme.")
        }
    }

    private static func tier(_ m: Manufacturer, _ tier: SystemTier) -> RequirementCheck {
        let title = "Preisrahmen"
        let wish = tier.label
        switch (m, tier) {
        case (.axis, .budget):
            return .init(title: title, wish: wish, status: .nichtMoeglich, explanation: "Axis-Komponenten kosten ein Mehrfaches vergleichbarer Geräte. Eine Budgetvorgabe lässt sich damit kaum einhalten.", alternative: "Reolink oder Uniview für ein günstiges Gesamtsystem.")
        case (_, .budget):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Gutes Preis-Leistungs-Verhältnis.")
        case (.axis, .premium):
            return .init(title: title, wish: wish, status: .erfuellt, explanation: "Premium-Qualität mit langem Produkt- und Update-Support.")
        case (.eufy, .premium):
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Consumer-Produkte erfüllen einen Premium-Anspruch an Langlebigkeit und Support nur bedingt.", alternative: "Axis für Premium-Anlagen.")
        default:
            return .init(title: title, wish: wish, status: .teilweise, explanation: "Solide Qualität, aber nicht im obersten Preis- und Supportsegment.", alternative: "Axis für Premium-Anlagen.")
        }
    }
}
