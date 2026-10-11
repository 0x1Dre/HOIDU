import XCTest
@testable import CCTVCore

final class StorageCalculatorTests: XCTestCase {
    func testContinuousRecordingReferenceCase() throws {
        // 4 Kameras, 4 MP, 15 fps, H.265 → 4 × 15 × 48 = 2880 kbit/s pro Kamera
        let input = StorageInput(cameras: 4, megapixels: 4, framesPerSecond: 15, codec: .h265, mode: .dauer,
                                 retentionDays: 14, safetyMarginPercent: 20, diskSizeTB: 8)
        let result = try StorageCalculator.calculate(input)
        XCTAssertEqual(result.bitratePerCameraKbps, 2880)
        XCTAssertFalse(result.bitrateIsManual)
        XCTAssertEqual(result.effectiveHoursPerDay, 24)
        XCTAssertEqual(result.dailyTB, 0.124416, accuracy: 1e-9)
        XCTAssertEqual(result.requiredTB, 1.741824, accuracy: 1e-9)
        XCTAssertEqual(result.requiredTBWithMargin, 2.0901888, accuracy: 1e-9)
        XCTAssertEqual(result.usableTBPerDisk, 7.2, accuracy: 1e-9)
        XCTAssertEqual(result.recommendedDisks, 1)
        XCTAssertTrue(result.formula.contains("Speicher [TB]"))
        XCTAssertFalse(result.assumptions.isEmpty)
    }

    func testH264NeedsMoreStorageThanH265() throws {
        let h264 = try StorageCalculator.calculate(StorageInput(codec: .h264))
        let h265 = try StorageCalculator.calculate(StorageInput(codec: .h265))
        XCTAssertGreaterThan(h264.requiredTB, h265.requiredTB)
        XCTAssertEqual(h264.bitratePerCameraKbps / h265.bitratePerCameraKbps, 80.0 / 48.0, accuracy: 1e-9)
    }

    func testEventAndScheduleModesReduceHours() throws {
        let event = try StorageCalculator.calculate(StorageInput(mode: .ereignis, eventSharePercent: 25))
        XCTAssertEqual(event.effectiveHoursPerDay, 6, accuracy: 1e-9)
        let schedule = try StorageCalculator.calculate(StorageInput(mode: .zeitplan, scheduleHoursPerDay: 10))
        XCTAssertEqual(schedule.effectiveHoursPerDay, 10, accuracy: 1e-9)
        let continuous = try StorageCalculator.calculate(StorageInput(mode: .dauer))
        XCTAssertEqual(event.requiredTB * 4, continuous.requiredTB, accuracy: 1e-9)
    }

    func testManualBitrateAndMultipleDisks() throws {
        // 16 Kameras × 8192 kbit/s × 24 h × 30 Tage
        let input = StorageInput(cameras: 16, megapixels: 8, framesPerSecond: 25, codec: .h264, manualBitrateKbps: 8192,
                                 mode: .dauer, retentionDays: 30, safetyMarginPercent: 20, diskSizeTB: 8)
        let result = try StorageCalculator.calculate(input)
        XCTAssertTrue(result.bitrateIsManual)
        XCTAssertEqual(result.bitratePerCameraKbps, 8192)
        let expected = 8192.0 * 1000 / 8 * 3600 * 24 * 16 * 30 / 1e12 * 1.2
        XCTAssertEqual(result.requiredTBWithMargin, expected, accuracy: 1e-9)
        XCTAssertEqual(result.recommendedDisks, Int((expected / 7.2).rounded(.up)))
    }

    func testRedundancyAddsOneDisk() throws {
        let plain = try StorageCalculator.calculate(StorageInput(redundancyDisk: false))
        let raid = try StorageCalculator.calculate(StorageInput(redundancyDisk: true))
        XCTAssertEqual(raid.recommendedDisks, plain.recommendedDisks + 1)
    }

    func testMinimumBitrateFloor() {
        XCTAssertEqual(StorageCalculator.defaultBitrateKbps(megapixels: 1, framesPerSecond: 1, codec: .h265), 512)
    }

    func testValidationErrors() {
        XCTAssertThrowsError(try StorageCalculator.calculate(StorageInput(cameras: 0))) {
            XCTAssertEqual($0 as? StorageCalculatorError, .invalidCameraCount)
        }
        XCTAssertThrowsError(try StorageCalculator.calculate(StorageInput(retentionDays: 0))) {
            XCTAssertEqual($0 as? StorageCalculatorError, .invalidRetention)
        }
        XCTAssertThrowsError(try StorageCalculator.calculate(StorageInput(framesPerSecond: 0)))
        XCTAssertThrowsError(try StorageCalculator.calculate(StorageInput(megapixels: 0.5)))
        XCTAssertThrowsError(try StorageCalculator.calculate(StorageInput(diskSizeTB: 0)))
        XCTAssertThrowsError(try StorageCalculator.calculate(StorageInput(manualBitrateKbps: 50)))
        XCTAssertEqual(StorageCalculatorError.invalidRetention.errorDescription, "Die Aufbewahrungsdauer muss zwischen 1 und 365 Tagen liegen.")
    }
}

final class MaintenanceCalculatorTests: XCTestCase {
    let settings = CalculationSettings()

    func testBusinessPackage() {
        let quote = MaintenanceCalculator.quote(config: settings.maintenanceConfig(for: .business), cameras: 6, recorders: 1,
                                                includeOnSiteCheck: false, vatPercent: Decimal("8.1"))
        XCTAssertEqual(quote.monthlyNet, 110) // 59 + 6 × 6 + 15
        XCTAssertEqual(quote.yearlyNet, 1320)
        XCTAssertEqual(quote.monthlyInclVAT, Decimal("118.90")) // 118.91 → 118.90
        XCTAssertEqual(quote.yearlyInclVAT, Decimal("1426.90")) // 1320 + 106.92 = 1426.92 → 1426.90
        XCTAssertEqual(quote.includedRemoteMinutes, 60)
        XCTAssertFalse(quote.onSiteCheck)
        XCTAssertTrue(quote.services.contains("Prüfung der Benutzer und Berechtigungen"))
        XCTAssertTrue(quote.services.contains("Statusprüfung von Kameras und Aufzeichnung"))
    }

    func testOptionalOnSiteCheckIsSpreadMonthly() {
        let quote = MaintenanceCalculator.quote(config: settings.maintenanceConfig(for: .business), cameras: 6, recorders: 1,
                                                includeOnSiteCheck: true, vatPercent: Decimal("8.1"))
        XCTAssertEqual(quote.monthlyOnSiteShare, Decimal("24.17"))
        XCTAssertEqual(quote.monthlyNet, Decimal("134.15")) // 134.17 → 134.15
        XCTAssertTrue(quote.onSiteCheck)
        XCTAssertTrue(quote.services.contains("Jährlicher Check vor Ort (Option)"))
    }

    func testPremiumIncludesOnSiteVisitWithoutSurcharge() {
        let quote = MaintenanceCalculator.quote(config: settings.maintenanceConfig(for: .premium), cameras: 10, recorders: 1,
                                                includeOnSiteCheck: true, vatPercent: Decimal("8.1"))
        XCTAssertEqual(quote.monthlyOnSiteShare, 0)
        XCTAssertEqual(quote.monthlyNet, 234) // 119 + 90 + 25
        XCTAssertTrue(quote.onSiteCheck)
        XCTAssertTrue(quote.services.contains("Jährlicher Service vor Ort"))
        XCTAssertTrue(quote.services.contains("Priorisierte Reaktionszeit"))
        XCTAssertTrue(quote.services.contains("Geplante Updates (Firmware/Software) im Wartungsfenster"))
    }

    func testBasicPackageAndNegativeInputs() {
        let quote = MaintenanceCalculator.quote(config: settings.maintenanceConfig(for: .basic), cameras: -3, recorders: -1,
                                                includeOnSiteCheck: false, vatPercent: Decimal("8.1"))
        XCTAssertEqual(quote.cameras, 0)
        XCTAssertEqual(quote.monthlyNet, 29)
        XCTAssertEqual(quote.services.count, 3)
    }

    func testAllPackagesAreOrderedByPrice() {
        let quotes = MaintenanceCalculator.quotes(settings: settings, cameras: 8, recorders: 1, includeOnSiteCheck: false)
        XCTAssertEqual(quotes.map(\.package), [.basic, .business, .premium])
        XCTAssertLessThan(quotes[0].monthlyNet, quotes[1].monthlyNet)
        XCTAssertLessThan(quotes[1].monthlyNet, quotes[2].monthlyNet)
    }
}
