import XCTest
@testable import CCTVCore

final class ManufacturerScoringTests: XCTestCase {
    private func top(_ project: ProjectRecord) -> Manufacturer {
        ManufacturerScoring.scores(for: project)[0].manufacturer
    }

    private func score(_ m: Manufacturer, _ project: ProjectRecord) -> Int {
        ManufacturerScoring.scores(for: project).first { $0.manufacturer == m }!.score
    }

    func testResidentialBatteryProjectPrefersEufy() {
        let project = Fixtures.project(objectType: .eigenheim, cameras: 2, connection: .akku, cabling: .nein, mode: .ereignis, tier: .budget)
        XCTAssertEqual(top(project), .eufy)
        XCTAssertLessThan(score(.axis, project), 30)
    }

    func testSmallBusinessPoEPrefersReolinkDahuaOrUniview() {
        let project = Fixtures.project(objectType: .laden, cameras: 10, connection: .poeLan, mode: .dauer, tier: .standard,
                                       features: [.personenerkennung, .fahrzeugerkennung])
        XCTAssertTrue([.reolink, .dahua, .uniview].contains(top(project)))
        XCTAssertLessThan(score(.eufy, project), 20)
        XCTAssertGreaterThanOrEqual(score(.dahua, project), 75)
    }

    func testEnterpriseCompliancePrefersAxis() {
        var project = Fixtures.project(objectType: .lager, cameras: 20, connection: .poeLan, mode: .dauer, tier: .premium,
                                       access: [.vms, .pcBrowser])
        project.recording.highCybersecurity = true
        project.recording.multiSite = true
        project.recording.thirdPartyIntegration = true
        XCTAssertEqual(top(project), .axis)
        XCTAssertEqual(score(.axis, project), 100)
        XCTAssertEqual(score(.eufy, project), 0)
    }

    func testEufyPenaltiesForContinuousPoEAndVMS() {
        let project = Fixtures.project(objectType: .eigenheim, cameras: 3, connection: .poeLan, mode: .dauer, access: [.vms])
        let eufy = ManufacturerScoring.scores(for: project).first { $0.manufacturer == .eufy }!
        XCTAssertTrue(eufy.cons.contains { $0.contains("Daueraufnahme") })
        XCTAssertTrue(eufy.cons.contains { $0.contains("ONVIF") })
        XCTAssertTrue(eufy.warnings.contains { $0.contains("VMS") })
    }

    func testEufyWarnsAboveEightCameras() {
        let eufy = ManufacturerScoring.scores(for: Fixtures.project(cameras: 12, connection: .wlan))
            .first { $0.manufacturer == .eufy }!
        XCTAssertTrue(eufy.warnings.contains("Eufy ist für mehr als 8 Kameras nicht ausgelegt."))
    }

    func testScoresAlwaysWithinBoundsAndRationaleIsGerman() {
        for connection in ConnectionType.allCases {
            for tier in SystemTier.allCases {
                for cameras in [0, 1, 4, 9, 40] {
                    var project = Fixtures.project(cameras: cameras, connection: connection, tier: tier, access: Set(AccessChannel.allCases),
                                                   features: Set(SystemFeature.allCases))
                    project.recording.highCybersecurity = true
                    project.recording.multiSite = true
                    for s in ManufacturerScoring.scores(for: project) {
                        XCTAssertTrue((0...100).contains(s.score), "\(s.manufacturer) \(s.score)")
                        XCTAssertFalse(s.rationale.isEmpty)
                        XCTAssertFalse(s.rationale.contains("ß"))
                    }
                }
            }
        }
    }

    func testZeroCamerasProducesPreliminaryWarning() {
        let scores = ManufacturerScoring.scores(for: Fixtures.project(cameras: 0))
        XCTAssertEqual(scores.count, 5)
        XCTAssertTrue(scores.allSatisfy { $0.warnings.contains { $0.contains("vorläufig") } })
    }

    func testFitLevels() {
        XCTAssertEqual(FitLevel(score: 80), .sehrGut)
        XCTAssertEqual(FitLevel(score: 60), .geeignet)
        XCTAssertEqual(FitLevel(score: 40), .bedingt)
        XCTAssertEqual(FitLevel(score: 10), .nichtEmpfohlen)
    }
}

final class ProjectWarningTests: XCTestCase {
    func testPrivacyWarnings() {
        var project = Fixtures.project()
        project.infrastructure.publicAreaAffected = true
        project.infrastructure.neighborPropertyAffected = true
        project.infrastructure.employeesAffected = true
        project.areas[0].audio = .mithoeren
        project.recording.retentionDays = 60
        let ids = Set(ProjectWarningService.warnings(for: project).map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["privacy.public", "privacy.neighbor", "privacy.employees", "privacy.audio", "privacy.retention"]))
        XCTAssertEqual(ProjectWarningService.warnings(for: project).first?.severity, .kritisch)
    }

    func testCleanProjectHasNoPrivacyWarnings() {
        let warnings = ProjectWarningService.warnings(for: Fixtures.project())
        XCTAssertFalse(warnings.contains { $0.category == .datenschutz })
    }

    func testTechnicalWarnings() {
        var project = Fixtures.project(cameras: 8, connection: .akku, mode: .dauer, detection: .kennzeichen)
        project.infrastructure.internet = .nein
        project.infrastructure.lighting = .keine
        project.areas[0].nightVision = .keine
        let ids = Set(ProjectWarningService.warnings(for: project).map(\.id))
        XCTAssertTrue(ids.contains("tech.battery.continuous"))
        XCTAssertTrue(ids.contains("infra.internet"))
        XCTAssertTrue(ids.contains("tech.lighting"))
        XCTAssertTrue(ids.contains("tech.lpr"))
    }

    func testPrivacyCopyUsesSwissSpelling() {
        let texts = PrivacyText.documentSection + [PrivacyText.responsibilityNotice]
        XCTAssertFalse(texts.joined().contains("ß"))
        XCTAssertTrue(PrivacyText.responsibilityNotice.contains("Zweck"))
        XCTAssertTrue(PrivacyText.responsibilityNotice.contains("Informationspflicht"))
        XCTAssertTrue(PrivacyText.responsibilityNotice.contains("Aufbewahrungsdauer"))
    }
}
