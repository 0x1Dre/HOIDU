import Foundation
import SwiftData
import CCTVCore

@Model
final class Project {
    var id: UUID = UUID()
    var reference: String = ""
    var surveyDate: Date = Date()
    var objectTypeRaw: String = ObjectType.eigenheim.rawValue
    var siteStreet: String = ""
    var sitePostalCode: String = ""
    var siteCity: String = ""
    var notes: String = ""
    var statusRaw: String = ProjectStatus.entwurf.rawValue
    var isDemo: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Rabatt in Hundertstelprozent (750 = 7.5 %).
    var discountBasisPoints: Int = 0

    // Infrastruktur
    var cablingRaw: String = CablingStatus.unklar.rawValue
    var powerRaw: String = Clarification.abzuklaeren.rawValue
    var internetRaw: String = Clarification.abzuklaeren.rawValue
    var connectionRaw: String = ConnectionType.poeLan.rawValue
    var mountingAccessRaw: String = MountingAccess.leiter.rawValue
    var lightingRaw: String = LightingCondition.schwach.rawValue
    var existingInfrastructureRaw: [String] = []
    var existingCameras: String = ""
    var privacyReviewRequired: Bool = false
    var publicAreaAffected: Bool = false
    var employeesAffected: Bool = false
    var neighborPropertyAffected: Bool = false

    // Aufzeichnung und Funktionen
    var recordingModeRaw: String = RecordingMode.ereignis.rawValue
    var scheduleHoursPerDay: Int = 12
    var retentionDays: Int = 14
    var userCount: Int = 2
    var accessRaw: [String] = [AccessChannel.smartphone.rawValue]
    var featuresRaw: [String] = []
    var systemTierRaw: String = SystemTier.offen.rawValue
    var multiSite: Bool = false
    var highCybersecurity: Bool = false
    var thirdPartyIntegration: Bool = false
    var framesPerSecond: Int = 15
    var codecRaw: String = VideoCodec.h265.rawValue

    // Manuelle Herstellerwahl je Variante
    var budgetManufacturerRaw: String?
    var standardManufacturerRaw: String?
    var premiumManufacturerRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \Customer.project)
    var customer: Customer?
    @Relationship(deleteRule: .cascade, inverse: \SiteArea.project)
    var areas: [SiteArea] = []
    @Relationship(deleteRule: .cascade, inverse: \MaintenancePlan.project)
    var maintenancePlan: MaintenancePlan?
    @Relationship(deleteRule: .cascade, inverse: \Offer.project)
    var offers: [Offer] = []

    init(id: UUID = UUID()) {
        self.id = id
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .entwurf }
        set { statusRaw = newValue.rawValue }
    }

    var objectType: ObjectType {
        ObjectType(rawValue: objectTypeRaw) ?? .sonstiges
    }

    var displayTitle: String {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Projekt ohne Referenz" : trimmed
    }

    var customerName: String {
        customer?.record.displayName ?? "Ohne Kundenangabe"
    }

    var totalCameras: Int {
        areas.reduce(0) { $0 + max(0, $1.cameraRequirement?.quantity ?? 0) }
    }

    var latestOffer: Offer? {
        offers.max { $0.createdAt < $1.createdAt }
    }

    // MARK: - Abbildung auf das Domänenmodell

    var record: ProjectRecord {
        ProjectRecord(
            id: id,
            reference: reference,
            surveyDate: surveyDate,
            objectType: objectType,
            siteStreet: siteStreet,
            sitePostalCode: sitePostalCode,
            siteCity: siteCity,
            notes: notes,
            customer: customer?.record ?? CustomerRecord(),
            areas: areas.sorted { $0.sortIndex < $1.sortIndex }.map(\.record),
            infrastructure: InfrastructureRecord(
                cabling: CablingStatus(rawValue: cablingRaw) ?? .unklar,
                power: Clarification(rawValue: powerRaw) ?? .abzuklaeren,
                internet: Clarification(rawValue: internetRaw) ?? .abzuklaeren,
                connection: ConnectionType(rawValue: connectionRaw) ?? .poeLan,
                mountingAccess: MountingAccess(rawValue: mountingAccessRaw) ?? .leiter,
                lighting: LightingCondition(rawValue: lightingRaw) ?? .schwach,
                existing: Set(existingInfrastructureRaw.compactMap(InfrastructureItem.init(rawValue:))),
                existingCameras: existingCameras,
                privacyReviewRequired: privacyReviewRequired,
                publicAreaAffected: publicAreaAffected,
                employeesAffected: employeesAffected,
                neighborPropertyAffected: neighborPropertyAffected
            ),
            recording: RecordingRecord(
                mode: RecordingMode(rawValue: recordingModeRaw) ?? .ereignis,
                scheduleHoursPerDay: scheduleHoursPerDay,
                retentionDays: retentionDays,
                userCount: userCount,
                access: Set(accessRaw.compactMap(AccessChannel.init(rawValue:))),
                features: Set(featuresRaw.compactMap(SystemFeature.init(rawValue:))),
                tier: SystemTier(rawValue: systemTierRaw) ?? .offen,
                multiSite: multiSite,
                highCybersecurity: highCybersecurity,
                thirdPartyIntegration: thirdPartyIntegration,
                framesPerSecond: framesPerSecond,
                codec: VideoCodec(rawValue: codecRaw) ?? .h265
            ),
            maintenance: MaintenanceSelection(
                package: maintenancePlan.flatMap { $0.packageRaw.flatMap(MaintenancePackage.init(rawValue:)) },
                includeOnSiteCheck: maintenancePlan?.includeOnSiteCheck ?? false
            ),
            variantSelection: VariantSelection(
                budget: budgetManufacturerRaw.flatMap(Manufacturer.init(rawValue:)),
                standard: standardManufacturerRaw.flatMap(Manufacturer.init(rawValue:)),
                premium: premiumManufacturerRaw.flatMap(Manufacturer.init(rawValue:))
            ),
            discountPercent: Decimal(discountBasisPoints) / 100,
            status: status,
            isDemo: isDemo,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ r: ProjectRecord, context: ModelContext) {
        reference = r.reference
        surveyDate = r.surveyDate
        objectTypeRaw = r.objectType.rawValue
        siteStreet = r.siteStreet
        sitePostalCode = r.sitePostalCode
        siteCity = r.siteCity
        notes = r.notes
        statusRaw = r.status.rawValue
        isDemo = r.isDemo
        createdAt = r.createdAt
        updatedAt = r.updatedAt
        discountBasisPoints = NSDecimalNumber(decimal: (r.discountPercent * 100).roundedTo(scale: 0)).intValue

        let infra = r.infrastructure
        cablingRaw = infra.cabling.rawValue
        powerRaw = infra.power.rawValue
        internetRaw = infra.internet.rawValue
        connectionRaw = infra.connection.rawValue
        mountingAccessRaw = infra.mountingAccess.rawValue
        lightingRaw = infra.lighting.rawValue
        existingInfrastructureRaw = infra.existing.ordered.map(\.rawValue)
        existingCameras = infra.existingCameras
        privacyReviewRequired = infra.privacyReviewRequired
        publicAreaAffected = infra.publicAreaAffected
        employeesAffected = infra.employeesAffected
        neighborPropertyAffected = infra.neighborPropertyAffected

        let rec = r.recording
        recordingModeRaw = rec.mode.rawValue
        scheduleHoursPerDay = rec.scheduleHoursPerDay
        retentionDays = rec.retentionDays
        userCount = rec.userCount
        accessRaw = rec.access.ordered.map(\.rawValue)
        featuresRaw = rec.features.ordered.map(\.rawValue)
        systemTierRaw = rec.tier.rawValue
        multiSite = rec.multiSite
        highCybersecurity = rec.highCybersecurity
        thirdPartyIntegration = rec.thirdPartyIntegration
        framesPerSecond = rec.framesPerSecond
        codecRaw = rec.codec.rawValue

        budgetManufacturerRaw = r.variantSelection.budget?.rawValue
        standardManufacturerRaw = r.variantSelection.standard?.rawValue
        premiumManufacturerRaw = r.variantSelection.premium?.rawValue

        if customer == nil {
            let newCustomer = Customer()
            context.insert(newCustomer)
            customer = newCustomer
        }
        customer?.apply(r.customer)

        if maintenancePlan == nil {
            let plan = MaintenancePlan()
            context.insert(plan)
            maintenancePlan = plan
        }
        maintenancePlan?.packageRaw = r.maintenance.package?.rawValue
        maintenancePlan?.includeOnSiteCheck = r.maintenance.includeOnSiteCheck

        areas = ModelSync.sync(
            areas, with: r.areas, context: context,
            id: { $0.id },
            create: { SiteArea(id: $0.id) },
            update: { model, area, index in model.apply(area, index: index, context: context) }
        )
    }
}
