import Foundation

public enum WizardStep: Int, CaseIterable, Codable, Hashable, Sendable, Identifiable, Comparable {
    case kunde = 1, bereiche, infrastruktur, aufzeichnung, empfehlung

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .kunde: "Kunde und Objekt"
        case .bereiche: "Überwachungsbereiche"
        case .infrastruktur: "Infrastruktur"
        case .aufzeichnung: "Aufzeichnung und Funktionen"
        case .empfehlung: "Empfehlung und Kalkulation"
        }
    }

    public var shortTitle: String {
        switch self {
        case .kunde: "Kunde"
        case .bereiche: "Bereiche"
        case .infrastruktur: "Infrastruktur"
        case .aufzeichnung: "Aufzeichnung"
        case .empfehlung: "Empfehlung"
        }
    }

    public static func < (lhs: WizardStep, rhs: WizardStep) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct ValidationIssue: Hashable, Sendable, Identifiable {
    public var step: WizardStep
    public var field: String
    public var message: String

    public var id: String { "\(step.rawValue).\(field).\(message)" }

    public init(step: WizardStep, field: String, message: String) {
        self.step = step
        self.field = field
        self.message = message
    }
}

public enum ProjectValidator {
    public static let maximumCamerasPerArea = 64
    public static let maximumCamerasTotal = 256

    public static func validate(_ project: ProjectRecord) -> [ValidationIssue] {
        WizardStep.allCases.flatMap { validate(project, step: $0) }
    }

    public static func validate(_ project: ProjectRecord, step: WizardStep) -> [ValidationIssue] {
        switch step {
        case .kunde: customerIssues(project)
        case .bereiche: areaIssues(project)
        case .infrastruktur: []
        case .aufzeichnung: recordingIssues(project)
        case .empfehlung: offerIssues(project)
        }
    }

    public static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.range(of: #"^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Akzeptiert Schweizer und internationale Nummern, z. B. «044 123 45 67» oder «+41 79 123 45 67».
    public static func isValidPhone(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet(charactersIn: "+0123456789 ()-/.")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard !trimmed.dropFirst().contains("+") else { return false }
        let digits = trimmed.filter(\.isNumber).count
        return (9...15).contains(digits)
    }

    public static func isValidSwissPostalCode(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count == 4, trimmed.allSatisfy(\.isNumber), let number = Int(trimmed) else { return false }
        return (1000...9999).contains(number)
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func customerIssues(_ p: ProjectRecord) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if isBlank(p.customer.company) && isBlank(p.customer.contactPerson) {
            issues.append(ValidationIssue(step: .kunde, field: "customer", message: "Bitte Firma oder Ansprechpartner erfassen."))
        }
        if isBlank(p.reference) {
            issues.append(ValidationIssue(step: .kunde, field: "reference", message: "Bitte einen Projektnamen oder eine Referenz erfassen."))
        }
        if !isBlank(p.customer.phone) && !isValidPhone(p.customer.phone) {
            issues.append(ValidationIssue(step: .kunde, field: "phone", message: "Die Telefonnummer ist ungültig. Beispiel: +41 44 123 45 67"))
        }
        if !isBlank(p.customer.email) && !isValidEmail(p.customer.email) {
            issues.append(ValidationIssue(step: .kunde, field: "email", message: "Die E-Mail-Adresse ist ungültig. Beispiel: name@firma.ch"))
        }
        if isBlank(p.siteCity) {
            issues.append(ValidationIssue(step: .kunde, field: "siteCity", message: "Bitte mindestens den Ort der Objektadresse erfassen."))
        }
        if !isBlank(p.sitePostalCode) && !isValidSwissPostalCode(p.sitePostalCode) {
            issues.append(ValidationIssue(step: .kunde, field: "sitePostalCode", message: "Die Postleitzahl muss vierstellig sein (1000–9999)."))
        }
        return issues
    }

    private static func areaIssues(_ p: ProjectRecord) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if p.areas.isEmpty {
            issues.append(ValidationIssue(step: .bereiche, field: "areas", message: "Bitte mindestens einen Überwachungsbereich erfassen."))
            return issues
        }
        for (index, area) in p.areas.enumerated() {
            let label = isBlank(area.name) ? "Bereich \(index + 1)" : "Bereich «\(area.name)»"
            if isBlank(area.name) {
                issues.append(ValidationIssue(step: .bereiche, field: "area.\(area.id).name", message: "\(label): Bitte einen Namen erfassen."))
            }
            if !(1...maximumCamerasPerArea).contains(area.camera.quantity) {
                issues.append(ValidationIssue(step: .bereiche, field: "area.\(area.id).quantity", message: "\(label): Die Kameraanzahl muss zwischen 1 und \(maximumCamerasPerArea) liegen."))
            }
            if area.purposes.isEmpty {
                issues.append(ValidationIssue(step: .bereiche, field: "area.\(area.id).purposes", message: "\(label): Bitte mindestens einen Zweck wählen."))
            }
            if area.positions.count > area.camera.quantity {
                issues.append(ValidationIssue(step: .bereiche, field: "area.\(area.id).positions", message: "\(label): Es sind \(area.positions.count) Kamerapositionen erfasst, aber nur \(area.camera.quantity) Kameras vorgesehen. Kameraanzahl erhöhen oder Positionen löschen."))
            }
            for (positionIndex, position) in area.positions.enumerated() where isBlank(position.label) {
                issues.append(ValidationIssue(step: .bereiche, field: "position.\(position.id).label", message: "\(label): Kameraposition \(positionIndex + 1) braucht eine Beschriftung."))
            }
        }
        if p.totalCameras > maximumCamerasTotal {
            issues.append(ValidationIssue(step: .bereiche, field: "areas.total", message: "Insgesamt sind höchstens \(maximumCamerasTotal) Kameras pro Projekt möglich."))
        }
        return issues
    }

    private static func recordingIssues(_ p: ProjectRecord) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let r = p.recording
        if !(1...365).contains(r.retentionDays) {
            issues.append(ValidationIssue(step: .aufzeichnung, field: "retention", message: "Die Aufbewahrungsdauer muss zwischen 1 und 365 Tagen liegen."))
        }
        if !(1...100).contains(r.userCount) {
            issues.append(ValidationIssue(step: .aufzeichnung, field: "users", message: "Die Anzahl Benutzer muss zwischen 1 und 100 liegen."))
        }
        if r.mode == .zeitplan && !(1...24).contains(r.scheduleHoursPerDay) {
            issues.append(ValidationIssue(step: .aufzeichnung, field: "schedule", message: "Der Zeitplan muss zwischen 1 und 24 Stunden pro Tag liegen."))
        }
        if !(1...30).contains(r.framesPerSecond) {
            issues.append(ValidationIssue(step: .aufzeichnung, field: "fps", message: "Die Bildrate muss zwischen 1 und 30 Bildern pro Sekunde liegen."))
        }
        if r.access.isEmpty {
            issues.append(ValidationIssue(step: .aufzeichnung, field: "access", message: "Bitte mindestens eine Zugriffsart wählen."))
        }
        return issues
    }

    private static func offerIssues(_ p: ProjectRecord) -> [ValidationIssue] {
        guard p.discountPercent >= 0, p.discountPercent <= PricingCalculator.maximumDiscountPercent else {
            return [ValidationIssue(step: .empfehlung, field: "discount", message: "Der Rabatt muss zwischen 0 und \(Format.number(PricingCalculator.maximumDiscountPercent, fractionDigits: 0)) % liegen.")]
        }
        return []
    }
}
