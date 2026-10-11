import Foundation

public struct OfferVariant: Codable, Hashable, Sendable, Identifiable {
    public var tier: OfferTier
    public var manufacturer: Manufacturer
    public var score: ManufacturerScore
    public var isManualSelection: Bool
    public var lineItems: [OfferLineItem]
    public var totals: OfferTotals
    public var labor: [LaborEstimate]
    public var selection: ComponentSelection
    public var maintenance: MaintenanceQuote?

    public var id: String { tier.rawValue }
    public var materialItems: [OfferLineItem] { lineItems.filter { $0.kind == .material } }
    public var laborItems: [OfferLineItem] { lineItems.filter { $0.kind == .labor } }
}

public struct ComparisonCell: Codable, Hashable, Sendable {
    public var tier: OfferTier
    public var totalInclVAT: Decimal?
    public var netAfterDiscount: Decimal?
    public var contributionMarginPercent: Decimal?
    public var warningCount: Int
}

public struct ComparisonRow: Codable, Hashable, Sendable, Identifiable {
    public var manufacturer: Manufacturer
    public var score: ManufacturerScore
    public var cells: [ComparisonCell]
    public var maintenanceMonthly: Decimal?

    public var id: String { manufacturer.rawValue }

    public func cell(_ tier: OfferTier) -> ComparisonCell? {
        cells.first { $0.tier == tier }
    }
}

public struct OfferAnalysis: Codable, Hashable, Sendable {
    public var projectID: UUID
    public var scores: [ManufacturerScore]
    public var variants: [OfferVariant]
    public var comparison: [ComparisonRow]
    public var warnings: [ProjectWarning]
    public var recommendedTier: OfferTier
    public var maintenanceQuotes: [MaintenanceQuote]
    public var technicalRecommendation: [String]
    public var settings: CalculationSettings

    public var recommendedVariant: OfferVariant? {
        variants.first { $0.tier == recommendedTier } ?? variants.first
    }

    public func variant(_ tier: OfferTier) -> OfferVariant? {
        variants.first { $0.tier == tier }
    }

    public var isCalculable: Bool { !variants.isEmpty }
}

/// Erzeugt die drei Angebotsvarianten (Budget, Standard, Premium) und den Herstellervergleich.
public enum OfferVariantBuilder {
    /// Eignung eines Herstellers für eine Variante, wird zur Projektbewertung addiert.
    public static func tierAffinity(_ manufacturer: Manufacturer, _ tier: OfferTier) -> Int {
        switch (manufacturer, tier) {
        case (.eufy, .budget): 10
        case (.eufy, .standard): 0
        case (.eufy, .premium): -20
        case (.reolink, .budget): 10
        case (.reolink, .standard): 5
        case (.reolink, .premium): -10
        case (.uniview, .budget): 8
        case (.uniview, .standard): 5
        case (.uniview, .premium): -5
        case (.dahua, .budget): 0
        case (.dahua, .standard): 8
        case (.dahua, .premium): 5
        case (.axis, .budget): -20
        case (.axis, .standard): 0
        case (.axis, .premium): 15
        case (.neutral, _): -100
        }
    }

    public static func calculate(
        project: ProjectRecord,
        manufacturer: Manufacturer,
        tier: OfferTier,
        score: ManufacturerScore,
        isManual: Bool = false,
        catalog: ProductCatalog,
        settings: CalculationSettings
    ) -> OfferVariant {
        let selection = ComponentSelector.select(
            project: project, manufacturer: manufacturer, tier: tier, catalog: catalog, settings: settings
        )
        let labor = LaborEstimator.estimate(project: project, selection: selection)
        let items = PricingCalculator.numbered(
            selection.materialItems + LaborEstimator.lineItems(for: labor, settings: settings)
        )
        let totals = PricingCalculator.totals(
            for: items, discountPercent: project.discountPercent, vatPercent: settings.vatPercent
        )
        let maintenance = project.maintenance.package.map { package in
            MaintenanceCalculator.quote(
                config: settings.maintenanceConfig(for: package),
                cameras: selection.cameraCount,
                recorders: max(selection.recorderCount, project.infrastructure.existing.contains(.nvr) ? 1 : 0),
                includeOnSiteCheck: project.maintenance.includeOnSiteCheck,
                vatPercent: settings.vatPercent
            )
        }
        return OfferVariant(
            tier: tier,
            manufacturer: manufacturer,
            score: score,
            isManualSelection: isManual,
            lineItems: items,
            totals: totals,
            labor: labor,
            selection: selection,
            maintenance: maintenance
        )
    }

    public static func analyze(
        project: ProjectRecord,
        catalog: ProductCatalog,
        settings: CalculationSettings
    ) -> OfferAnalysis {
        let scores = ManufacturerScoring.scores(for: project)
        let warnings = ProjectWarningService.warnings(for: project)
        let recommendedTier = project.recording.tier.preferredOfferTier

        var matrix: [Manufacturer: [OfferTier: OfferVariant]] = [:]
        if project.totalCameras > 0 {
            for score in scores where catalog.hasCameras(for: score.manufacturer) {
                for tier in OfferTier.allCases {
                    let variant = calculate(
                        project: project, manufacturer: score.manufacturer, tier: tier,
                        score: score, catalog: catalog, settings: settings
                    )
                    if variant.selection.isAvailable {
                        matrix[score.manufacturer, default: [:]][tier] = variant
                    }
                }
            }
        }

        var variants: [OfferVariant] = []
        for tier in OfferTier.allCases {
            if let manual = project.variantSelection[tier], var variant = matrix[manual]?[tier] {
                variant.isManualSelection = true
                variants.append(variant)
                continue
            }
            let candidates = scores.compactMap { score -> (OfferVariant, Int)? in
                guard let variant = matrix[score.manufacturer]?[tier] else { return nil }
                return (variant, score.score + tierAffinity(score.manufacturer, tier))
            }
            let best = candidates.max { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                return a.0.totals.totalInclVAT > b.0.totals.totalInclVAT
            }
            if let best { variants.append(best.0) }
        }

        let comparison = scores.map { score in
            ComparisonRow(
                manufacturer: score.manufacturer,
                score: score,
                cells: OfferTier.allCases.map { tier in
                    let variant = matrix[score.manufacturer]?[tier]
                    return ComparisonCell(
                        tier: tier,
                        totalInclVAT: variant?.totals.totalInclVAT,
                        netAfterDiscount: variant?.totals.netAfterDiscount,
                        contributionMarginPercent: variant?.totals.contributionMarginPercent,
                        warningCount: variant?.selection.warnings.count ?? 0
                    )
                },
                maintenanceMonthly: matrix[score.manufacturer]?[recommendedTier]?.maintenance?.monthlyNet
            )
        }

        let reference = variants.first { $0.tier == recommendedTier } ?? variants.first
        let maintenanceQuotes = MaintenanceCalculator.quotes(
            settings: settings,
            cameras: reference?.selection.cameraCount ?? project.totalCameras,
            recorders: max(reference?.selection.recorderCount ?? 1, 1),
            includeOnSiteCheck: project.maintenance.includeOnSiteCheck
        )

        return OfferAnalysis(
            projectID: project.id,
            scores: scores,
            variants: variants,
            comparison: comparison,
            warnings: warnings,
            recommendedTier: recommendedTier,
            maintenanceQuotes: maintenanceQuotes,
            technicalRecommendation: technicalRecommendation(project: project, variant: reference),
            settings: settings
        )
    }

    static func technicalRecommendation(project: ProjectRecord, variant: OfferVariant?) -> [String] {
        guard let variant else {
            return ["Für dieses Projekt konnte noch keine Empfehlung berechnet werden. Bitte mindestens einen Bereich mit Kameras erfassen."]
        }
        let profile = ProjectProfile(project: project)
        let selection = variant.selection
        var lines: [String] = []
        lines.append("Empfohlen wird ein System von \(variant.manufacturer.label) in der Variante \(variant.tier.label) (\(variant.score.fit.label), \(variant.score.score)/100). \(variant.score.rationale)")

        let architecture: String
        if profile.usesPoE {
            architecture = selection.recorderCount > 0
                ? "\(selection.cameraCount) PoE-Kameras mit \(selection.recorderCount == 1 ? "einem Netzwerkrekorder (NVR)" : "\(selection.recorderCount) Netzwerkrekordern") und lokaler Aufzeichnung."
                : "\(selection.cameraCount) PoE-Kameras mit Aufzeichnung auf der bestehenden Infrastruktur."
        } else if profile.usesBattery {
            architecture = "\(selection.cameraCount) akkubetriebene Kameras (\(project.infrastructure.connection.label)) mit ereignisgesteuerter Aufzeichnung."
        } else {
            architecture = "\(selection.cameraCount) WLAN-Kameras mit lokaler Aufzeichnung."
        }
        lines.append(architecture)

        if let storage = selection.storage {
            lines.append("Speicherbedarf für \(project.recording.retentionDays) Tage (\(project.recording.mode.label), \(project.recording.codec.label)): \(Format.number(storage.requiredTBWithMargin, fractionDigits: 1)) TB inklusive Reserve.")
        }
        if profile.analyticsFeatureCount > 0 {
            lines.append("Intelligente Analyse (\(project.recording.features.filter(\.isAnalytics).labels)) reduziert Fehlalarme gegenüber reiner Bewegungserkennung.")
        }
        if profile.wantsRemoteAccess {
            lines.append("Fernzugriff verschlüsselt über die Hersteller-App bzw. VPN; Standardpasswörter werden bei der Inbetriebnahme ersetzt.")
        }
        if profile.usesPoE && (profile.totalCameras > 8 || profile.highCybersecurity) {
            lines.append("Kameranetz in eigenem VLAN ohne direkten Internetzugang betreiben.")
        }
        return lines
    }
}
