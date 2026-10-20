import XCTest
@testable import CCTVCore

final class ScanTests: XCTestCase {
    private func projectWithScan() -> ProjectRecord {
        var project = Fixtures.project(cameras: 2)
        project.areas[0].positions = [
            CameraPositionRecord(label: "Kamera 1 – Einfahrt"),
            CameraPositionRecord(label: "Kamera 2 – Lager")
        ]
        let positionID = project.areas[0].positions[1].id
        project.scans = [
            SiteScanRecord(
                name: "Werkstatt",
                kind: .raum,
                modelData: Data(repeating: 0x01, count: 64),
                floorPlan: ScanFloorPlan(imageData: Data(repeating: 0x02, count: 16),
                                         bounds: ScanBounds(minX: -2, maxX: 6, minZ: -1, maxZ: 3)),
                placements: [
                    ScanCameraPlacement(positionID: positionID, x: 1, y: 2.5, z: 0, yawDegrees: 90),
                    ScanCameraPlacement(label: "Reserve", x: 4, y: 2.5, z: 2, yawDegrees: -90, fieldOfViewDegrees: 300, rangeMeters: 0)
                ]
            )
        ]
        return project
    }

    func testPlacementClampsAndNormalizesValues() {
        let placement = projectWithScan().scans[0].placements[1]
        XCTAssertEqual(placement.yawDegrees, 270, accuracy: 0.0001)
        XCTAssertEqual(placement.fieldOfViewDegrees, 180)
        XCTAssertEqual(placement.rangeMeters, 1)
        XCTAssertEqual(ScanCameraPlacement.normalizedYaw(725), 5, accuracy: 0.0001)
    }

    func testPlanReachIsLimitedByRangeAndDecodesWhenMissing() throws {
        let placement = ScanCameraPlacement(x: 0, y: 0, z: 0, rangeMeters: 5, planReach: [2, 8, .nan])
        XCTAssertEqual(placement.effectivePlanReach, [2, 5, 0])
        XCTAssertEqual(ScanCameraPlacement(x: 0, y: 0, z: 0, planReach: [3]).effectivePlanReach, [])

        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","x":1,"z":2}"#
        let decoded = try JSONDecoder().decode(ScanCameraPlacement.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.planReach, [])
        XCTAssertEqual(decoded.rangeMeters, ScanCameraPlacement.defaultRange)
    }

    func testYawFromWallNormalLooksAwayFromWall() throws {
        // Wand mit Normale nach +x (Kamera schaut nach rechts) → 90°
        XCTAssertEqual(try XCTUnwrap(ScanCameraPlacement.yaw(fromNormalX: 1, normalZ: 0)), 90, accuracy: 0.0001)
        // Normale nach −z (im Grundriss nach oben) → 0°
        XCTAssertEqual(try XCTUnwrap(ScanCameraPlacement.yaw(fromNormalX: 0, normalZ: -1)), 0, accuracy: 0.0001)
        // Normale nach +z (nach unten) → 180°
        XCTAssertEqual(try XCTUnwrap(ScanCameraPlacement.yaw(fromNormalX: 0, normalZ: 1)), 180, accuracy: 0.0001)
        // Boden oder Decke: keine Richtung
        XCTAssertNil(ScanCameraPlacement.yaw(fromNormalX: 0.05, normalZ: 0.05))

        let right = ScanCameraPlacement(x: 0, y: 0, z: 0, yawDegrees: 90).planDirection
        XCTAssertEqual(right.x, 1, accuracy: 0.0001)
        XCTAssertEqual(right.z, 0, accuracy: 0.0001)
    }

    func testBoundsMapToRelativeCoordinates() {
        let bounds = ScanBounds(minX: -2, maxX: 6, minZ: -1, maxZ: 3)
        let relative = bounds.relative(x: 2, z: 1)
        XCTAssertEqual(relative.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(relative.y, 0.5, accuracy: 0.0001)
        XCTAssertEqual(bounds.padded(by: 1).width, 10, accuracy: 0.0001)
    }

    func testDisplayLabelsUseLinkedPositionOrFallback() {
        let project = projectWithScan()
        let placements = project.scans[0].placements
        XCTAssertEqual(project.displayLabel(for: placements[0], number: 1), "Kamera 2 – Lager")
        XCTAssertEqual(project.areaName(for: placements[0]), "Bereich A")
        XCTAssertEqual(project.displayLabel(for: placements[1], number: 2), "Reserve")
        XCTAssertEqual(project.displayLabel(for: ScanCameraPlacement(x: 0, y: 0, z: 0), number: 7), "Kamera 7")
        XCTAssertEqual(project.placedCameraCount, 2)
    }

    func testRoundTripKeepsScans() throws {
        let project = projectWithScan()
        let file = try ProjectExchange.importProject(try ProjectExchange.export(project, appVersion: "1.0"))
        XCTAssertEqual(file.project.scans, project.scans)
    }

    func testExportWithoutPhotosStripsModelAndFloorPlan() throws {
        let file = try ProjectExchange.importProject(try ProjectExchange.export(projectWithScan(), appVersion: "1.0", includePhotos: false))
        let scan = try XCTUnwrap(file.project.scans.first)
        XCTAssertNil(scan.modelData)
        XCTAssertNil(scan.floorPlan)
        XCTAssertEqual(scan.placements.count, 2)
    }

    func testOlderFilesWithoutScansStillDecode() throws {
        let data = try ProjectExchange.export(Fixtures.project(), appVersion: "1.0")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var project = try XCTUnwrap(object["project"] as? [String: Any])
        project.removeValue(forKey: "scans")
        object["project"] = project
        let file = try ProjectExchange.importProject(try JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(file.project.scans, [])
    }

    func testDuplicateRemapsLinkedPositions() {
        let original = projectWithScan()
        let copy = ProjectExchange.duplicateWithNewIdentifiers(original)
        let newPositionIDs = Set(copy.areas.flatMap(\.positions).map(\.id))
        XCTAssertNotEqual(copy.scans[0].id, original.scans[0].id)
        XCTAssertNotEqual(copy.scans[0].placements[0].id, original.scans[0].placements[0].id)
        let linked = try? XCTUnwrap(copy.scans[0].placements[0].positionID)
        XCTAssertTrue(linked.map(newPositionIDs.contains) ?? false)
        XCTAssertEqual(copy.displayLabel(for: copy.scans[0].placements[0], number: 1), "Kamera 2 – Lager")
        XCTAssertNil(copy.scans[0].placements[1].positionID)
    }

    func testOfferContainsFloorPlanSectionWithNumberedCameras() {
        let project = projectWithScan()
        let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
        let document = OfferDocumentBuilder.build(project: project, analysis: analysis, company: CompanyProfile(name: "Ostsicht"),
                                                  options: DocumentOptions(audience: .customer, offerNumber: "1"))
        let section = document.sections.first { $0.title == "Grundriss und Kamerastandorte" }
        XCTAssertNotNil(section)
        guard case .floorPlan(let plan)? = section?.blocks.first else { return XCTFail("Grundriss fehlt") }
        XCTAssertEqual(plan.markers.map(\.number), [1, 2])
        XCTAssertEqual(plan.markers.map(\.label), ["Kamera 2 – Lager", "Reserve"])
        XCTAssertTrue(document.plainText.contains("Werkstatt"))
    }

    private func projectWithScanPhotos() -> ProjectRecord {
        var project = projectWithScan()
        let photo = PhotoRecord(caption: "Aufnahme 1", imageData: Data(repeating: 0xCD, count: 24))
        let hidden = PhotoRecord(caption: "Intern", imageData: Data(repeating: 0xEF, count: 24), includeInCustomerPDF: false)
        project.scans[0].areaID = project.areas[0].id
        project.scans[0].photos = [photo, hidden]
        project.scans[0].photoPoses = [ScanPhotoPose(photoID: photo.id, x: 1, y: 1.5, z: 2, yawDegrees: 370)]
        return project
    }

    func testScanPhotosAndAreaSurviveDuplicateWithNewIdentifiers() throws {
        let original = projectWithScanPhotos()
        let copy = ProjectExchange.duplicateWithNewIdentifiers(original)
        let scan = copy.scans[0]
        XCTAssertEqual(scan.areaID, copy.areas[0].id)
        XCTAssertNotEqual(scan.photos[0].id, original.scans[0].photos[0].id)
        let pose = try XCTUnwrap(scan.pose(for: scan.photos[0].id))
        XCTAssertEqual(pose.yawDegrees, 10, accuracy: 0.0001)
        XCTAssertEqual(copy.areaName(for: scan), "Bereich A")
    }

    func testCompactExportStripsScanPhotoData() throws {
        let file = try ProjectExchange.importProject(try ProjectExchange.export(projectWithScanPhotos(), appVersion: "1.0", includePhotos: false))
        XCTAssertEqual(file.project.scans[0].photos.count, 2)
        XCTAssertNil(file.project.scans[0].photos[0].imageData)
        XCTAssertEqual(file.project.scans[0].photoPoses.count, 1)
    }

    func testScanPhotosStayOutOfOffer() {
        let project = projectWithScanPhotos()
        let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
        for audience in [DocumentAudience.customer, .internal] {
            let document = OfferDocumentBuilder.build(project: project, analysis: analysis, company: CompanyProfile(),
                                                      options: DocumentOptions(audience: audience, offerNumber: "1", includePhotosInCustomerPDF: true))
            let titles = document.sections.flatMap(\.blocks).flatMap { block -> [String] in
                if case .photos(let photos) = block { return photos.map(\.title) }
                return []
            }
            XCTAssertFalse(titles.contains("Aufnahme 1"))
            XCTAssertFalse(titles.contains("Intern"))
            XCTAssertNotNil(document.sections.first { $0.title == "Grundriss und Kamerastandorte" })
        }
    }

    func testOfferWithoutFloorPlanHasNoSection() {
        var project = projectWithScan()
        project.scans[0].floorPlan = nil
        let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
        let document = OfferDocumentBuilder.build(project: project, analysis: analysis, company: CompanyProfile(),
                                                  options: DocumentOptions(audience: .internal, offerNumber: "1"))
        XCTAssertFalse(document.sections.contains { $0.title == "Grundriss und Kamerastandorte" })
    }
}
