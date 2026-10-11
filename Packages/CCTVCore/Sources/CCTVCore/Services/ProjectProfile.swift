import Foundation

/// Aus dem Projekt abgeleitete Merkmale für Bewertung und Komponentenauswahl.
public struct ProjectProfile: Sendable, Hashable {
    public let totalCameras: Int
    public let outdoorCameras: Int
    public let isResidential: Bool
    public let isCommercial: Bool
    public let usesPoE: Bool
    public let usesWireless: Bool
    public let usesBattery: Bool
    public let littleCabling: Bool
    public let continuousRecording: Bool
    public let needsVMS: Bool
    public let analyticsFeatureCount: Int
    public let wantsLPR: Bool
    public let wantsPTZ: Bool
    public let wantsAudio: Bool
    public let wantsTwoWayAudio: Bool
    public let wantsColorNight: Bool
    public let multiSite: Bool
    public let highCybersecurity: Bool
    public let thirdPartyIntegration: Bool
    public let complianceSensitive: Bool
    public let tier: SystemTier
    public let userCount: Int
    public let wantsRemoteAccess: Bool
    public let existing: Set<InfrastructureItem>

    public init(project: ProjectRecord) {
        let areas = project.areas
        let infra = project.infrastructure
        let rec = project.recording

        totalCameras = project.totalCameras
        outdoorCameras = areas.filter { $0.location == .aussen }.reduce(0) { $0 + max(0, $1.camera.quantity) }
        isResidential = project.objectType.isResidential
        isCommercial = project.objectType.isCommercial
        usesPoE = infra.connection == .poeLan
        usesWireless = infra.connection.isWireless
        usesBattery = infra.connection.isBatteryPowered
        littleCabling = infra.cabling == .nein || infra.cabling == .unklar
        continuousRecording = rec.mode == .dauer
        needsVMS = rec.access.contains(.vms)
        analyticsFeatureCount = rec.features.filter(\.isAnalytics).count
        wantsLPR = rec.features.contains(.kennzeichenerkennung) || areas.contains { $0.detectionTarget == .kennzeichen }
        wantsPTZ = rec.features.contains(.ptz) || areas.contains { $0.camera.formFactor == .ptz }
        wantsTwoWayAudio = rec.features.contains(.zweiWegeAudio) || areas.contains { $0.audio == .gegensprechen }
        wantsAudio = wantsTwoWayAudio || rec.features.contains(.audio) || areas.contains { $0.audio != .nein }
        wantsColorNight = areas.contains { $0.nightVision == .farbeNacht }
        multiSite = rec.multiSite
        highCybersecurity = rec.highCybersecurity
        thirdPartyIntegration = rec.thirdPartyIntegration
        complianceSensitive = infra.privacyReviewRequired || infra.publicAreaAffected || infra.employeesAffected
        tier = rec.tier
        userCount = rec.userCount
        wantsRemoteAccess = rec.access.contains(.smartphone) || rec.access.contains(.pcBrowser)
        existing = infra.existing
    }
}
