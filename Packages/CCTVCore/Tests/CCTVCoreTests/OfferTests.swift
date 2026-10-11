import XCTest
@testable import CCTVCore

final class ComponentSelectorTests: XCTestCase {
    private func select(_ project: ProjectRecord, _ m: Manufacturer, _ tier: OfferTier = .standard) -> ComponentSelection {
        ComponentSelector.select(project: project, manufacturer: m, tier: tier, catalog: Fixtures.catalog, settings: Fixtures.settings)
    }

    private func roles(_ selection: ComponentSelection) -> [ComponentRole] {
        selection.materialItems.compactMap { item in Fixtures.catalog.products.first { $0.id == item.productID }?.role }
    }

    func testTenPoECamerasUseSixteenChannelNVRWithoutSwitch() {
        let selection = select(Fixtures.project(cameras: 10), .reolink)
        XCTAssertEqual(selection.cameraCount, 10)
        XCTAssertEqual(selection.recorderCount, 1)
        XCTAssertTrue(selection.materialItems.contains { $0.articleNumber == "RLN16-410" })
        XCTAssertEqual(selection.switchCount, 0)
        XCTAssertNotNil(selection.storage)
        XCTAssertTrue(roles(selection).contains(.festplatte))
    }

    func testLargeSystemAddsSwitchWhenRecorderHasNoPoE() {
        let selection = select(Fixtures.project(cameras: 20), .reolink)
        XCTAssertTrue(selection.materialItems.contains { $0.articleNumber == "RLN36" })
        XCTAssertEqual(selection.switchCount, 1)
        XCTAssertTrue(selection.materialItems.contains { $0.articleNumber == "SW-POE-24" })
        XCTAssertTrue(selection.hasRack)
    }

    func testExistingNVRAndSwitchAreReused() {
        let selection = select(Fixtures.project(cameras: 6, existing: [.nvr, .poeSwitch, .usv]), .dahua)
        XCTAssertEqual(selection.recorderCount, 0)
        XCTAssertFalse(roles(selection).contains(.rekorder))
        XCTAssertFalse(roles(selection).contains(.poeSwitch))
        XCTAssertFalse(selection.hasUPS)
        XCTAssertTrue(selection.notes.contains { $0.contains("Bestehender NVR") })
    }

    func testBatteryEufySystemUsesHomeBaseAndNoCable() {
        let project = Fixtures.project(objectType: .eigenheim, cameras: 3, connection: .akku, mode: .ereignis, tier: .budget)
        let selection = select(project, .eufy, .budget)
        XCTAssertTrue(selection.materialItems.contains { $0.articleNumber == "T8030" })
        XCTAssertEqual(selection.cableMeters, 0)
        XCTAssertFalse(roles(selection).contains(.kabel))
        let camera = selection.materialItems.first!
        XCTAssertEqual(camera.manufacturer, .eufy)
    }

    func testCableMetersDependOnExistingCabling() {
        XCTAssertEqual(select(Fixtures.project(cameras: 4, cabling: .nein), .uniview).cableMeters, 100)
        XCTAssertEqual(select(Fixtures.project(cameras: 4, cabling: .teilweise), .uniview).cableMeters, 50)
        XCTAssertEqual(select(Fixtures.project(cameras: 4, cabling: .unklar), .uniview).cableMeters, 75)
        XCTAssertEqual(select(Fixtures.project(cameras: 4, cabling: .ja), .uniview).cableMeters, 0)
    }

    func testSignageIsAlwaysIncludedAndLiftForHebebuehne() {
        let selection = select(Fixtures.project(cameras: 4, mounting: .hebebuehne), .dahua)
        XCTAssertTrue(roles(selection).contains(.schildGross))
        XCTAssertTrue(roles(selection).contains(.hebebuehne))
        let budget = select(Fixtures.project(cameras: 4), .dahua, .budget)
        XCTAssertTrue(roles(budget).contains(.schildKlein))
    }

    func testLicensePlateTargetPicksLPRCamera() {
        let selection = select(Fixtures.project(cameras: 2, detection: .kennzeichen), .dahua, .premium)
        XCTAssertTrue(selection.materialItems.contains { $0.articleNumber == "ITC413-PW4D-IZ1" })
    }

    func testAxisWithoutWirelessCamerasReportsCompromise() {
        let selection = select(Fixtures.project(cameras: 2, connection: .akku, mode: .ereignis), .axis)
        XCTAssertEqual(selection.cameraCount, 2)
        XCTAssertTrue(selection.warnings.contains { $0.contains("Anschlussart") })
    }

    func testAxisVMSAddsLicensePerCamera() {
        let selection = select(Fixtures.project(cameras: 5, access: [.vms]), .axis)
        let license = selection.materialItems.first { $0.articleNumber == "02848-001" }
        XCTAssertEqual(license?.quantity, 5)
    }

    func testStorageExceedingCapacityWarns() {
        let project = Fixtures.project(cameras: 8, retention: 365)
        let selection = select(project, .reolink, .budget)
        XCTAssertTrue(selection.warnings.contains { $0.contains("übersteigt die Rekorderkapazität") })
    }

    func testCamerasAreAggregatedPerProduct() {
        var project = Fixtures.project(cameras: 2)
        project.areas.append(SiteAreaRecord(name: "Bereich B", location: .aussen, camera: CameraRequirementRecord(quantity: 3)))
        let selection = select(project, .reolink)
        let cameraLines = selection.materialItems.filter { $0.category == ProductCategory.kamera.label }
        XCTAssertEqual(cameraLines.count, 1)
        XCTAssertEqual(cameraLines[0].quantity, 5)
        XCTAssertTrue(cameraLines[0].description.contains("Bereich A, Bereich B"))
    }
}

final class OfferVariantBuilderTests: XCTestCase {
    func testDemoProjectsProduceThreeVariants() {
        for project in DemoProjects.all() {
            let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
            XCTAssertEqual(analysis.variants.map(\.tier), [.budget, .standard, .premium], project.reference)
            XCTAssertEqual(analysis.comparison.count, 5)
            XCTAssertEqual(analysis.maintenanceQuotes.count, 3)
            XCTAssertFalse(analysis.technicalRecommendation.isEmpty)
            for variant in analysis.variants {
                XCTAssertGreaterThan(variant.totals.totalInclVAT, 0)
                XCTAssertEqual(variant.selection.cameraCount, project.totalCameras)
            }
        }
    }

    func testDemoRecommendations() {
        let demos = DemoProjects.all()
        let home = OfferVariantBuilder.analyze(project: demos[0], catalog: Fixtures.catalog, settings: Fixtures.settings)
        XCTAssertEqual(home.recommendedTier, .budget)
        XCTAssertEqual(home.recommendedVariant?.manufacturer, .eufy)

        let logistics = OfferVariantBuilder.analyze(project: demos[2], catalog: Fixtures.catalog, settings: Fixtures.settings)
        XCTAssertEqual(logistics.recommendedTier, .premium)
        XCTAssertEqual(logistics.recommendedVariant?.manufacturer, .axis)
    }

    func testTotalsAreConsistentWithLineItems() {
        let project = DemoProjects.all()[1]
        let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
        for variant in analysis.variants {
            let t = variant.totals
            let sum = variant.lineItems.reduce(Decimal(0)) { $0 + $1.totalSell }
            XCTAssertEqual(t.subtotal, sum)
            XCTAssertEqual(t.discountPercent, 5)
            XCTAssertEqual(t.discountAmount, (sum * 5 / 100).roundedTo(scale: 2))
            XCTAssertEqual(t.vatAmount, (t.netAfterDiscount * Decimal("8.1") / 100).roundedTo(scale: 2))
            XCTAssertEqual(t.totalInclVAT, (t.netAfterDiscount + t.vatAmount).roundedToFiveRappen)
            XCTAssertEqual(variant.lineItems.map(\.position), Array(1...variant.lineItems.count))
            XCTAssertTrue(variant.laborItems.contains { $0.description.contains("Anfahrt") })
        }
    }

    func testBudgetIsCheaperThanPremium() {
        let analysis = OfferVariantBuilder.analyze(project: Fixtures.project(cameras: 8, tier: .offen), catalog: Fixtures.catalog, settings: Fixtures.settings)
        let budget = analysis.variant(.budget)!.totals.totalInclVAT
        let premium = analysis.variant(.premium)!.totals.totalInclVAT
        XCTAssertLessThan(budget, premium)
        XCTAssertEqual(analysis.recommendedTier, .standard)
    }

    func testManualManufacturerSelectionIsRespected() {
        var project = Fixtures.project(cameras: 6)
        project.variantSelection[.standard] = .axis
        let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
        XCTAssertEqual(analysis.variant(.standard)?.manufacturer, .axis)
        XCTAssertEqual(analysis.variant(.standard)?.isManualSelection, true)
    }

    func testNoCamerasMeansNoVariants() {
        let analysis = OfferVariantBuilder.analyze(project: Fixtures.project(cameras: 0), catalog: Fixtures.catalog, settings: Fixtures.settings)
        XCTAssertFalse(analysis.isCalculable)
        XCTAssertNil(analysis.recommendedVariant)
        XCTAssertTrue(analysis.warnings.contains { $0.id == "tech.nocameras" })
        XCTAssertTrue(analysis.technicalRecommendation[0].contains("keine Empfehlung"))
    }

    func testEmptyCatalogDoesNotCrash() {
        let analysis = OfferVariantBuilder.analyze(project: Fixtures.project(), catalog: ProductCatalog(products: []), settings: Fixtures.settings)
        XCTAssertTrue(analysis.variants.isEmpty)
        XCTAssertEqual(analysis.comparison.count, 5)
        XCTAssertNil(analysis.comparison[0].cell(.standard)?.totalInclVAT)
    }

    func testCustomVATRateIsApplied() {
        var settings = Fixtures.settings
        settings.vatPercent = Decimal("7.7")
        let analysis = OfferVariantBuilder.analyze(project: Fixtures.project(), catalog: Fixtures.catalog, settings: settings)
        let t = analysis.variants[0].totals
        XCTAssertEqual(t.vatPercent, Decimal("7.7"))
        XCTAssertEqual(t.vatAmount, (t.netAfterDiscount * Decimal("7.7") / 100).roundedTo(scale: 2))
    }

    func testLaborUsesConfiguredRates() {
        var settings = Fixtures.settings
        settings.hourlyRate = 140
        settings.travelFlatFee = 120
        let variant = OfferVariantBuilder.analyze(project: Fixtures.project(), catalog: Fixtures.catalog, settings: settings).variants[0]
        XCTAssertTrue(variant.laborItems.filter { $0.unit == .stunde }.allSatisfy { $0.unitSellPrice == 140 })
        XCTAssertEqual(variant.laborItems.first { $0.unit == .pauschal }?.unitSellPrice, 120)
        let montage = variant.labor.first { $0.kind == .montage }!
        XCTAssertTrue(variant.selection.hasUPS)
        XCTAssertEqual(montage.hours, Decimal("5.5")) // 4 Kameras × 1 h (Leiter) + 1 h Rekorder + 0.5 h USV
    }

    func testLaborHoursRoundUpToQuarterHours() {
        XCTAssertEqual(LaborEstimator.roundUpQuarter(Decimal("1.1")), Decimal("1.25"))
        XCTAssertEqual(LaborEstimator.roundUpQuarter(Decimal("2")), 2)
    }
}
