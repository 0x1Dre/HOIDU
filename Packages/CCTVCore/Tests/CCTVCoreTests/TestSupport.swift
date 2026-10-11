import Foundation
@testable import CCTVCore

enum Fixtures {
    static let catalog = ProductCatalog(priceLists: SeedCatalog.priceLists())
    static let settings = CalculationSettings()

    static func project(
        objectType: ObjectType = .buero,
        cameras: Int = 4,
        location: AreaLocation = .aussen,
        connection: ConnectionType = .poeLan,
        cabling: CablingStatus = .nein,
        mode: RecordingMode = .dauer,
        tier: SystemTier = .standard,
        access: Set<AccessChannel> = [.smartphone],
        features: Set<SystemFeature> = [],
        existing: Set<InfrastructureItem> = [],
        mounting: MountingAccess = .leiter,
        detection: DetectionTarget = .person,
        retention: Int = 14
    ) -> ProjectRecord {
        ProjectRecord(
            reference: "Testprojekt",
            objectType: objectType,
            siteCity: "Zürich",
            customer: CustomerRecord(company: "Test AG"),
            areas: cameras > 0 ? [
                SiteAreaRecord(
                    name: "Bereich A",
                    location: location,
                    detectionTarget: detection,
                    camera: CameraRequirementRecord(quantity: cameras)
                )
            ] : [],
            infrastructure: InfrastructureRecord(cabling: cabling, power: .ja, internet: .ja, connection: connection, mountingAccess: mounting, existing: existing),
            recording: RecordingRecord(mode: mode, retentionDays: retention, access: access, features: features, tier: tier)
        )
    }
}

extension Decimal {
    init(_ string: String) {
        self = Decimal(string: string)!
    }
}
