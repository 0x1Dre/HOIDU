import XCTest
@testable import CCTVCore

final class RequirementCheckTests: XCTestCase {
    private func check(_ checks: [RequirementCheck], _ title: String) -> RequirementCheck? {
        checks.first { $0.title == title }
    }

    func testBatteryWithContinuousRecordingIsImpossibleForEveryone() throws {
        let project = Fixtures.project(cameras: 3, connection: .akku, mode: .dauer)
        for manufacturer in Manufacturer.scored {
            let recording = try XCTUnwrap(check(RequirementMatcher.checks(for: manufacturer, project: project), "Aufzeichnung"))
            XCTAssertEqual(recording.status, .nichtMoeglich, "\(manufacturer)")
            XCTAssertNotNil(recording.alternative)
        }
    }

    func testAxisRejectsWirelessAndBudget() throws {
        let project = Fixtures.project(cameras: 6, connection: .wlan, mode: .ereignis, tier: .budget)
        let checks = RequirementMatcher.checks(for: .axis, project: project)
        XCTAssertEqual(check(checks, "Anschluss")?.status, .nichtMoeglich)
        XCTAssertEqual(check(checks, "Preisrahmen")?.status, .nichtMoeglich)
    }

    func testEufyCannotDoVMSOrLicensePlates() {
        let project = Fixtures.project(cameras: 4, access: [.smartphone, .vms], features: [.kennzeichenerkennung])
        let checks = RequirementMatcher.checks(for: .eufy, project: project)
        XCTAssertEqual(checks.first { $0.title == "Zugriff" && $0.wish == "VMS" }?.status, .nichtMoeglich)
        XCTAssertEqual(check(checks, "Kennzeichenerkennung")?.status, .nichtMoeglich)
        XCTAssertEqual(checks.first { $0.title == "Zugriff" && $0.wish == "Smartphone" }?.status, .erfuellt)
    }

    func testOnlyRequestedWishesAreListed() {
        let project = Fixtures.project(cameras: 4, mode: .ereignis, tier: .standard, access: [.smartphone], features: [])
        let titles = Set(RequirementMatcher.checks(for: .dahua, project: project).map(\.title))
        XCTAssertEqual(titles, ["Systemgrösse", "Anschluss", "Aufzeichnung", "Zugriff"])
        XCTAssertTrue(RequirementMatcher.checks(for: .neutral, project: project).isEmpty)
    }

    func testStatusOrdering() {
        XCTAssertLessThan(RequirementStatus.nichtMoeglich, .teilweise)
        XCTAssertLessThan(RequirementStatus.teilweise, .erfuellt)
    }
}
