import Foundation

public struct MaintenanceQuote: Codable, Hashable, Sendable {
    public var package: MaintenancePackage
    public var cameras: Int
    public var recorders: Int
    public var monthlyBaseFee: Decimal
    public var monthlyCameraFee: Decimal
    public var monthlyRecorderFee: Decimal
    public var monthlyOnSiteShare: Decimal
    public var monthlyNet: Decimal
    public var yearlyNet: Decimal
    public var vatPercent: Decimal
    public var monthlyInclVAT: Decimal
    public var yearlyInclVAT: Decimal
    public var includedRemoteMinutes: Int
    public var onSiteCheck: Bool
    public var responseTime: String
    public var services: [String]
}

public enum MaintenanceCalculator {
    public static func quote(
        config: MaintenancePackageConfig,
        cameras: Int,
        recorders: Int,
        includeOnSiteCheck: Bool,
        vatPercent: Decimal
    ) -> MaintenanceQuote {
        let cameraCount = max(0, cameras)
        let recorderCount = max(0, recorders)
        let onSite = config.onSiteCheckIncluded || includeOnSiteCheck
        let onSiteShare = (!config.onSiteCheckIncluded && includeOnSiteCheck)
            ? (config.yearlyOnSiteCheckPrice / 12).roundedTo(scale: 2)
            : 0

        let cameraFee = config.pricePerCamera * Decimal(cameraCount)
        let recorderFee = config.pricePerRecorder * Decimal(recorderCount)
        let monthly = (config.monthlyBaseFee + cameraFee + recorderFee + onSiteShare).roundedToFiveRappen
        let yearly = monthly * 12
        let monthlyGross = (monthly + PricingCalculator.vat(on: monthly, percent: vatPercent)).roundedToFiveRappen
        let yearlyGross = (yearly + PricingCalculator.vat(on: yearly, percent: vatPercent)).roundedToFiveRappen

        var services = config.services
        if includeOnSiteCheck && !config.onSiteCheckIncluded {
            services.append("Jährlicher Check vor Ort (Option)")
        }
        if config.includedRemoteMinutes > 0 {
            services.append("Inklusive \(config.includedRemoteMinutes) Minuten Fernsupport pro Monat")
        }

        return MaintenanceQuote(
            package: config.package,
            cameras: cameraCount,
            recorders: recorderCount,
            monthlyBaseFee: config.monthlyBaseFee,
            monthlyCameraFee: cameraFee,
            monthlyRecorderFee: recorderFee,
            monthlyOnSiteShare: onSiteShare,
            monthlyNet: monthly,
            yearlyNet: yearly,
            vatPercent: vatPercent,
            monthlyInclVAT: monthlyGross,
            yearlyInclVAT: yearlyGross,
            includedRemoteMinutes: config.includedRemoteMinutes,
            onSiteCheck: onSite,
            responseTime: config.responseTime,
            services: services
        )
    }

    public static func quotes(
        settings: CalculationSettings,
        cameras: Int,
        recorders: Int,
        includeOnSiteCheck: Bool
    ) -> [MaintenanceQuote] {
        MaintenancePackage.allCases.map {
            quote(
                config: settings.maintenanceConfig(for: $0),
                cameras: cameras,
                recorders: recorders,
                includeOnSiteCheck: includeOnSiteCheck,
                vatPercent: settings.vatPercent
            )
        }
    }
}
