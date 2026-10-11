import Foundation

public enum WarningSeverity: String, Codable, Hashable, Sendable, Comparable {
    case info, warnung, kritisch

    public var label: String {
        switch self {
        case .info: "Hinweis"
        case .warnung: "Warnung"
        case .kritisch: "Kritisch"
        }
    }

    private var rank: Int {
        switch self {
        case .info: 0
        case .warnung: 1
        case .kritisch: 2
        }
    }

    public static func < (lhs: WarningSeverity, rhs: WarningSeverity) -> Bool { lhs.rank < rhs.rank }
}

public enum WarningCategory: String, Codable, Hashable, Sendable {
    case datenschutz, technik, infrastruktur

    public var label: String {
        switch self {
        case .datenschutz: "Datenschutz"
        case .technik: "Technik"
        case .infrastruktur: "Infrastruktur"
        }
    }
}

public struct ProjectWarning: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var severity: WarningSeverity
    public var category: WarningCategory
    public var title: String
    public var message: String

    public init(id: String, severity: WarningSeverity, category: WarningCategory, title: String, message: String) {
        self.id = id
        self.severity = severity
        self.category = category
        self.title = title
        self.message = message
    }
}

public enum PrivacyText {
    /// Hinweis, der bei jedem Projekt angezeigt wird.
    public static let responsibilityNotice = "Die Verantwortung für den Betrieb der Videoüberwachung liegt beim Kunden: Er legt den Zweck fest, bestimmt die Ausrichtung der Kameras, erfüllt die Informationspflicht (z. B. Hinweisschilder), holt nötige Bewilligungen ein und definiert die Aufbewahrungsdauer. Die Empfehlung in dieser Offerte ersetzt keine rechtliche Beratung."

    /// Neutraler Datenschutzabschnitt für das PDF.
    public static let documentSection: [String] = [
        "Videoüberwachung bearbeitet Personendaten. In der Schweiz gelten insbesondere das Datenschutzgesetz (DSG) und – sofern Mitarbeitende betroffen sind – das Arbeitsgesetz.",
        "Die Überwachung muss einem klar definierten Zweck dienen und verhältnismässig sein. Es soll nur erfasst werden, was für diesen Zweck nötig ist.",
        "Betroffene Personen sind vorgängig gut sichtbar zu informieren, zum Beispiel mit Hinweisschildern an den Zugängen.",
        "Öffentlicher Grund und Nachbargrundstücke dürfen grundsätzlich nicht erfasst werden; nötigenfalls sind Privatzonen zu maskieren.",
        "Aufnahmen sind nur so lange aufzubewahren, wie es der Zweck erfordert, und vor unbefugtem Zugriff zu schützen.",
        "Zweck, Kameraausrichtung, Informationspflicht, Bewilligungen und Aufbewahrungsdauer liegen in der Verantwortung des Betreibers (Kunde)."
    ]
}

public enum ProjectWarningService {
    public static func warnings(for project: ProjectRecord) -> [ProjectWarning] {
        var result: [ProjectWarning] = []
        let infra = project.infrastructure
        let rec = project.recording
        let profile = ProjectProfile(project: project)

        // MARK: Datenschutz
        if infra.publicAreaAffected {
            result.append(ProjectWarning(
                id: "privacy.public", severity: .kritisch, category: .datenschutz,
                title: "Öffentlicher Raum betroffen",
                message: "Kameras so ausrichten oder maskieren, dass öffentlicher Grund nicht oder nur minimal erfasst wird. Die Zulässigkeit muss der Kunde klären."
            ))
        }
        if infra.neighborPropertyAffected {
            result.append(ProjectWarning(
                id: "privacy.neighbor", severity: .kritisch, category: .datenschutz,
                title: "Nachbargrundstück betroffen",
                message: "Nachbarliegenschaften dürfen nicht überwacht werden. Privatzonen-Maskierung einrichten und Ausrichtung dokumentieren."
            ))
        }
        if profile.wantsAudio {
            result.append(ProjectWarning(
                id: "privacy.audio", severity: .kritisch, category: .datenschutz,
                title: "Audio vorgesehen",
                message: "Das Mithören oder Aufzeichnen von Gesprächen ist rechtlich besonders heikel. Audio nur einsetzen, wenn der Kunde die Zulässigkeit geklärt hat; Gegensprechen ohne Aufzeichnung bevorzugen."
            ))
        }
        if infra.employeesAffected {
            result.append(ProjectWarning(
                id: "privacy.employees", severity: .warnung, category: .datenschutz,
                title: "Mitarbeitende betroffen",
                message: "Eine Überwachung des Verhaltens am Arbeitsplatz ist nicht zulässig (ArGV 3, Art. 26). Mitarbeitende vorgängig informieren und Kameras nicht auf feste Arbeitsplätze ausrichten."
            ))
        }
        if infra.privacyReviewRequired {
            result.append(ProjectWarning(
                id: "privacy.review", severity: .info, category: .datenschutz,
                title: "Datenschutzprüfung vorgesehen",
                message: "Zweck, Verhältnismässigkeit, Informationspflicht und Aufbewahrung vor Inbetriebnahme mit dem Kunden dokumentieren."
            ))
        }
        if rec.retentionDays > 30 {
            result.append(ProjectWarning(
                id: "privacy.retention", severity: .warnung, category: .datenschutz,
                title: "Lange Aufbewahrung",
                message: "\(rec.retentionDays) Tage Aufbewahrung müssen durch den Zweck begründet sein. Kürzere Fristen sind datenschutzfreundlicher und reduzieren den Speicherbedarf."
            ))
        }
        if project.areas.contains(where: { $0.detectionTarget == .gesicht || $0.detectionTarget == .kennzeichen }) {
            result.append(ProjectWarning(
                id: "privacy.identification", severity: .info, category: .datenschutz,
                title: "Identifizierende Aufnahmen",
                message: "Gesichts- oder Kennzeichenaufnahmen erhöhen die Anforderungen an Zweckbindung und Zugriffsschutz."
            ))
        }

        // MARK: Infrastruktur
        if infra.power != .ja {
            result.append(ProjectWarning(
                id: "infra.power", severity: infra.power == .nein ? .warnung : .info, category: .infrastruktur,
                title: "Stromversorgung",
                message: infra.power == .nein
                    ? "Kein Stromanschluss vorhanden: Für NVR, Switch und Router wird ein 230-V-Anschluss benötigt (Elektroinstallateur beiziehen)."
                    : "Stromversorgung für NVR, Switch und Router bei der Begehung abklären."
            ))
        }
        if profile.wantsRemoteAccess && infra.internet == .nein {
            result.append(ProjectWarning(
                id: "infra.internet", severity: .warnung, category: .infrastruktur,
                title: "Kein Internet",
                message: "Fernzugriff per Smartphone oder PC ist ohne Internetanschluss nicht möglich. Alternativ Mobilfunk-Router einplanen."
            ))
        } else if profile.wantsRemoteAccess && infra.internet == .abzuklaeren {
            result.append(ProjectWarning(
                id: "infra.internet", severity: .info, category: .infrastruktur,
                title: "Internet abklären",
                message: "Für Fernzugriff Internetanschluss und Upload-Bandbreite prüfen."
            ))
        }
        if infra.cabling == .unklar && infra.connection == .poeLan {
            result.append(ProjectWarning(
                id: "infra.cabling", severity: .info, category: .infrastruktur,
                title: "Verkabelung unklar",
                message: "Kabelwege bei der Begehung prüfen. Die Kabelmeter in der Kalkulation sind geschätzt."
            ))
        }
        if infra.mountingAccess == .hebebuehne || infra.mountingAccess == .spezialzugang {
            result.append(ProjectWarning(
                id: "infra.access", severity: .info, category: .infrastruktur,
                title: "Erschwerter Montagezugang",
                message: "\(infra.mountingAccess.label) verursacht Zusatzkosten und Terminabhängigkeiten."
            ))
        }
        if !infra.existingCameras.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || infra.existing.contains(.nvr) {
            result.append(ProjectWarning(
                id: "infra.existing", severity: .info, category: .infrastruktur,
                title: "Bestehende Anlage",
                message: "Kompatibilität bestehender Komponenten (ONVIF, Codec, Kanäle, Firmware-Stand) vor Offertabgabe prüfen."
            ))
        }
        if rec.multiSite && !infra.existing.contains(.vpn) {
            result.append(ProjectWarning(
                id: "infra.multisite", severity: .info, category: .infrastruktur,
                title: "Mehrere Standorte",
                message: "Für den Zugriff über mehrere Standorte VPN oder ein zentrales VMS einplanen."
            ))
        }
        if (profile.needsVMS || profile.highCybersecurity || profile.totalCameras > 8) && !infra.existing.contains(.vlan) && infra.connection == .poeLan {
            result.append(ProjectWarning(
                id: "infra.vlan", severity: .info, category: .infrastruktur,
                title: "Netzwerksegmentierung",
                message: "Kameras in ein eigenes VLAN legen und Internetzugriff der Kameras sperren."
            ))
        }

        // MARK: Technik
        if profile.usesBattery && profile.continuousRecording {
            result.append(ProjectWarning(
                id: "tech.battery.continuous", severity: .kritisch, category: .technik,
                title: "Akku und Daueraufnahme",
                message: "Akku- und Solarkameras unterstützen keine Daueraufnahme. Für 24/7-Aufzeichnung PoE-Kameras einsetzen."
            ))
        }
        if infra.connection == .wlan && profile.totalCameras > 6 {
            result.append(ProjectWarning(
                id: "tech.wifi.many", severity: .warnung, category: .technik,
                title: "Viele WLAN-Kameras",
                message: "Funkabdeckung und Bandbreite vor Ort messen. Bei mehr als 6 Kameras ist PoE deutlich zuverlässiger."
            ))
        }
        let darkAreas = project.areas.filter { $0.nightVision == .keine }
        if (infra.lighting == .keine || infra.lighting == .schwach) && !darkAreas.isEmpty {
            let names = darkAreas.map { "«\($0.name)»" }.joined(separator: ", ")
            result.append(ProjectWarning(
                id: "tech.lighting", severity: .warnung, category: .technik,
                title: "Nachtsicht fehlt",
                message: "Bei \(infra.lighting == .keine ? "fehlender" : "schwacher") Beleuchtung sind Nachtaufnahmen ohne Nachtsicht unbrauchbar: \(names)."
            ))
        }
        if infra.lighting == .zusaetzlich {
            result.append(ProjectWarning(
                id: "tech.lighting.extra", severity: .info, category: .technik,
                title: "Zusätzliche Beleuchtung",
                message: "Zusätzliche Beleuchtung ist nicht Teil dieser Offerte und separat durch einen Elektroinstallateur zu offerieren."
            ))
        }
        if profile.wantsLPR {
            result.append(ProjectWarning(
                id: "tech.lpr", severity: .warnung, category: .technik,
                title: "Kennzeichenerkennung",
                message: "Kennzeichenerkennung erfordert spezielle Kameras, korrekte Montagehöhe und -winkel sowie gute Ausleuchtung."
            ))
        }
        if project.areas.contains(where: { $0.camera.distanceMeters > 20 && $0.camera.formFactor != .ptz }) {
            result.append(ProjectWarning(
                id: "tech.distance", severity: .info, category: .technik,
                title: "Grosse Distanz",
                message: "Bei Distanzen über 20 m Varifokal- oder Tele-Objektive einplanen und die Pixeldichte prüfen."
            ))
        }
        if profile.totalCameras == 0 {
            result.append(ProjectWarning(
                id: "tech.nocameras", severity: .kritisch, category: .technik,
                title: "Keine Kameras",
                message: "Es sind noch keine Kameras erfasst. Ohne Kameras kann keine Offerte berechnet werden."
            ))
        }

        return result.sorted {
            $0.severity == $1.severity ? $0.category.rawValue < $1.category.rawValue : $0.severity > $1.severity
        }
    }
}
