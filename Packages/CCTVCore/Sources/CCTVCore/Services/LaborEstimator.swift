import Foundation

public struct LaborEstimate: Codable, Hashable, Sendable {
    public var kind: LaborKind
    public var hours: Decimal
    public var basis: String
}

/// Schätzt Arbeitsstunden aus Projekt und Komponentenauswahl. Stunden werden auf 0.25 h aufgerundet.
public enum LaborEstimator {
    public static func estimate(project: ProjectRecord, selection: ComponentSelection) -> [LaborEstimate] {
        let cams = Decimal(selection.cameraCount)
        guard selection.cameraCount > 0 else { return [] }
        let profile = ProjectProfile(project: project)
        let access = project.infrastructure.mountingAccess

        let survey: Decimal = selection.cameraCount > 8 ? Decimal(15) / 10 : 1

        var mounting = cams * access.hoursPerCamera
        if selection.recorderCount > 0 { mounting += Decimal(selection.recorderCount) }
        mounting += Decimal(selection.switchCount) * Decimal(5) / 10
        if selection.hasUPS { mounting += Decimal(5) / 10 }
        if selection.hasRack { mounting += Decimal(15) / 10 }

        let cabling = Decimal(selection.cableMeters) / 20

        var configuration = 1 + cams * Decimal(25) / 100
        if profile.analyticsFeatureCount > 0 { configuration += cams * Decimal(1) / 10 }
        if profile.needsVMS { configuration += 2 }
        if profile.wantsRemoteAccess { configuration += Decimal(5) / 10 }
        if profile.multiSite { configuration += 1 }

        var test = Decimal(5) / 10 + cams * Decimal(1) / 10
        var documentation = 1 + cams * Decimal(1) / 10
        if selection.tier == .premium {
            test += Decimal(5) / 10
            documentation += 1
        }

        return [
            LaborEstimate(kind: .begehung, hours: roundUpQuarter(survey), basis: "Pauschal \(selection.cameraCount > 8 ? "1.5" : "1.0") h"),
            LaborEstimate(kind: .montage, hours: roundUpQuarter(mounting), basis: "\(Format.number(access.hoursPerCamera, fractionDigits: 2)) h pro Kamera (\(access.label)) plus Zentrale"),
            LaborEstimate(kind: .verkabelung, hours: roundUpQuarter(cabling), basis: "\(selection.cableMeters) m à 20 m pro Stunde"),
            LaborEstimate(kind: .konfiguration, hours: roundUpQuarter(configuration), basis: "1 h plus 0.25 h pro Kamera, Zuschläge für Analyse, VMS, Fernzugriff"),
            LaborEstimate(kind: .test, hours: roundUpQuarter(test), basis: "0.5 h plus 0.1 h pro Kamera"),
            LaborEstimate(kind: .dokumentation, hours: roundUpQuarter(documentation), basis: "1 h plus 0.1 h pro Kamera")
        ].filter { $0.hours > 0 }
    }

    public static func lineItems(for estimates: [LaborEstimate], settings: CalculationSettings) -> [OfferLineItem] {
        var items = estimates.map { estimate in
            OfferLineItem(
                kind: .labor,
                category: "Arbeit",
                description: estimate.kind.label,
                quantity: estimate.hours,
                unit: .stunde,
                unitPurchasePrice: settings.internalHourlyCost,
                unitSellPrice: settings.hourlyRate
            )
        }
        if !estimates.isEmpty && settings.travelFlatFee > 0 {
            items.append(OfferLineItem(
                kind: .labor,
                category: "Arbeit",
                description: "\(LaborKind.anfahrt.label) (Pauschale)",
                quantity: 1,
                unit: .pauschal,
                unitPurchasePrice: settings.travelInternalCost,
                unitSellPrice: settings.travelFlatFee
            ))
        }
        return items
    }

    static func roundUpQuarter(_ value: Decimal) -> Decimal {
        (value * 4).roundedTo(scale: 0, mode: .up) / 4
    }
}
