import Foundation
import SwiftData
import CCTVCore

/// Gewähltes Wartungspaket eines Projekts inklusive der zuletzt berechneten Beträge.
@Model
final class MaintenancePlan {
    var packageRaw: String?
    var includeOnSiteCheck: Bool = false
    var cameraCount: Int = 0
    var recorderCount: Int = 0
    var monthlyNetRappen: Int = 0
    var yearlyNetRappen: Int = 0
    var calculatedAt: Date?
    var project: Project?

    init() {}

    var package: MaintenancePackage? {
        packageRaw.flatMap(MaintenancePackage.init(rawValue:))
    }

    func applySnapshot(_ quote: MaintenanceQuote) {
        cameraCount = quote.cameras
        recorderCount = quote.recorders
        monthlyNetRappen = Money.toRappen(quote.monthlyNet)
        yearlyNetRappen = Money.toRappen(quote.yearlyNet)
        calculatedAt = Date()
    }
}
