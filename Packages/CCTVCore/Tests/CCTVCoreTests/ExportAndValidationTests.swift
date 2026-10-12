import XCTest
@testable import CCTVCore

final class OfferDocumentTests: XCTestCase {
    private func analysis(for project: ProjectRecord, catalog: ProductCatalog = Fixtures.catalog) -> OfferAnalysis {
        OfferVariantBuilder.analyze(project: project, catalog: catalog, settings: Fixtures.settings)
    }

    private func photoProject() -> ProjectRecord {
        var project = DemoProjects.all()[1]
        let image = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02])
        project.areas[0].photos = [PhotoRecord(caption: "Übersicht Verkaufsraum", imageData: image)]
        project.areas[0].positions = [
            CameraPositionRecord(label: "Kamera 1 – Eingang", mountingHeight: "2.8 m", viewDirection: "Richtung Kasse",
                                 photos: [
                                    PhotoRecord(caption: "Montagepunkt", imageData: image,
                                                markers: [PhotoMarker(kind: .pfeil, startX: 0.2, startY: 0.3, endX: 0.6, endY: 0.5)]),
                                    PhotoRecord(caption: "Nur intern", imageData: image, includeInCustomerPDF: false)
                                 ])
        ]
        return project
    }

    func testCustomerDocumentHidesPurchasePricesAndMargins() {
        var products = SeedCatalog.priceLists().flatMap(\.products)
        // eindeutiger Einkaufspreis, der in keinem Verkaufspreis vorkommt
        for index in products.indices where products[index].role == .kamera {
            products[index].purchasePrice = Decimal("777.77")
        }
        let catalog = ProductCatalog(products: products)
        let project = DemoProjects.all()[1]
        let doc = OfferDocumentBuilder.build(project: project, analysis: analysis(for: project, catalog: catalog), company: CompanyProfile(name: "Sicher AG", city: "Zürich"),
                                             options: DocumentOptions(audience: .customer, offerNumber: "OF-2026-0001"))
        let text = doc.plainText
        XCTAssertFalse(text.contains("777.77"))
        for forbidden in ["Einkauf", "Marge", "Deckungsbeitrag", "DB %", "EK Einzel", "Kostensatz", "INTERN"] {
            XCTAssertFalse(text.contains(forbidden), "Kunden-PDF enthält «\(forbidden)»")
        }
        XCTAssertTrue(text.contains("Total inkl. MWST"))
        XCTAssertTrue(text.contains("Datenschutz"))
        XCTAssertTrue(text.contains(PrivacyText.responsibilityNotice))
        XCTAssertNil(doc.confidentialityNote)
        XCTAssertFalse(text.contains("ß"))
    }

    func testInternalDocumentShowsPurchasePricesMarginsAndAssumptions() {
        let project = DemoProjects.all()[1]
        let doc = OfferDocumentBuilder.build(project: project, analysis: analysis(for: project), company: CompanyProfile(),
                                             options: DocumentOptions(audience: .internal, offerNumber: "OF-2026-0001"))
        let text = doc.plainText
        XCTAssertTrue(text.contains("EK Einzel"))
        XCTAssertTrue(text.contains("Deckungsbeitrag"))
        XCTAssertTrue(text.contains("Annahmen und Berechnungsgrundlagen"))
        XCTAssertTrue(text.contains("Speicher [TB]"))
        XCTAssertNotNil(doc.confidentialityNote)
    }

    func testPhotosAlwaysInInternalAndOptionalInCustomerPDF() {
        let project = photoProject()
        let a = analysis(for: project)
        let internalDoc = OfferDocumentBuilder.build(project: project, analysis: a, company: CompanyProfile(),
                                                     options: DocumentOptions(audience: .internal, offerNumber: "1"))
        XCTAssertEqual(internalDoc.photoCount, 3)

        let customerWithout = OfferDocumentBuilder.build(project: project, analysis: a, company: CompanyProfile(),
                                                         options: DocumentOptions(audience: .customer, offerNumber: "1", includePhotosInCustomerPDF: false))
        XCTAssertEqual(customerWithout.photoCount, 0)
        XCTAssertTrue(customerWithout.plainText.contains("Kamera 1 – Eingang"))

        let customerWith = OfferDocumentBuilder.build(project: project, analysis: a, company: CompanyProfile(),
                                                      options: DocumentOptions(audience: .customer, offerNumber: "1", includePhotosInCustomerPDF: true))
        XCTAssertEqual(customerWith.photoCount, 2)
        XCTAssertTrue(customerWith.plainText.contains("Montagehöhe: 2.8 m"))
        XCTAssertFalse(customerWith.plainText.contains("Nur intern"))
    }
}

final class ProjectExchangeTests: XCTestCase {
    private func sampleProject() -> ProjectRecord {
        var project = DemoProjects.all()[0]
        project.discountPercent = Decimal("7.5")
        project.areas[0].positions[0].photos = [
            PhotoRecord(caption: "Kamera 1 – Nordfassade", note: "Montage unter Dachvorsprung",
                        capturedAt: Date(timeIntervalSince1970: 1_791_000_000.5), imageData: Data(repeating: 0xAB, count: 32),
                        markers: [PhotoMarker(kind: .kreis, startX: 0.5, startY: 0.5, endX: 0.6, endY: 0.5)])
        ]
        return project
    }

    func testRoundTripIncludingPhotosAsBase64() throws {
        let project = sampleProject()
        let data = try ProjectExchange.export(project, appVersion: "1.0")
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains(ProjectExchangeFile.formatIdentifier))
        XCTAssertTrue(json.contains(Data(repeating: 0xAB, count: 32).base64EncodedString()))

        let file = try ProjectExchange.importProject(data)
        XCTAssertTrue(file.includesPhotos)
        XCTAssertEqual(file.project.id, project.id)
        XCTAssertEqual(file.project.reference, project.reference)
        XCTAssertEqual(file.project.areas, project.areas)
        XCTAssertEqual(file.project.discountPercent, Decimal("7.5"))
        XCTAssertEqual(file.project.areas[0].positions[0].photos[0].markers[0].kind, .kreis)
        XCTAssertEqual(file.project.createdAt.timeIntervalSince1970, project.createdAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testExportWithoutPhotosStripsImageDataButKeepsCaptions() throws {
        let data = try ProjectExchange.export(sampleProject(), appVersion: "1.0", includePhotos: false)
        let file = try ProjectExchange.importProject(data)
        XCTAssertFalse(file.includesPhotos)
        let photo = file.project.areas[0].positions[0].photos[0]
        XCTAssertNil(photo.imageData)
        XCTAssertEqual(photo.caption, "Kamera 1 – Nordfassade")
    }

    func testInvalidFilesProduceGermanErrors() {
        XCTAssertThrowsError(try ProjectExchange.importProject(Data())) { XCTAssertEqual($0 as? ExchangeError, .emptyFile) }
        XCTAssertThrowsError(try ProjectExchange.importProject(Data("kein json".utf8))) { XCTAssertEqual($0 as? ExchangeError, .notJSON) }
        XCTAssertThrowsError(try ProjectExchange.importProject(Data(#"{"format":"anderes"}"#.utf8))) {
            XCTAssertEqual($0 as? ExchangeError, .wrongFormat)
            XCTAssertEqual(($0 as? ExchangeError)?.errorDescription, "Die Datei ist keine Projektdatei der Ostsicht-Offerten-App.")
        }
        let future = #"{"format":"ch.cctv-offer-calculator.project","schemaVersion":99}"#
        XCTAssertThrowsError(try ProjectExchange.importProject(Data(future.utf8))) { XCTAssertEqual($0 as? ExchangeError, .unsupportedVersion(99)) }
        let incomplete = #"{"format":"ch.cctv-offer-calculator.project","schemaVersion":1}"#
        XCTAssertThrowsError(try ProjectExchange.importProject(Data(incomplete.utf8))) {
            guard case .damaged = $0 as? ExchangeError else { return XCTFail("erwartet: damaged") }
        }
    }

    func testOlderFilesWithoutPositionsAndMarkersStillDecode() throws {
        var json = String(decoding: try ProjectExchange.export(DemoProjects.all()[1], appVersion: "1.0"), as: UTF8.self)
        json = json.replacingOccurrences(of: "\"positions\" : [\n\n          ],", with: "")
        json = json.replacingOccurrences(of: "\"positions\" : [],", with: "")
        let file = try ProjectExchange.importProject(Data(json.utf8))
        XCTAssertEqual(file.project.areas.count, 3)
        XCTAssertTrue(file.project.areas.allSatisfy { $0.positions.isEmpty })
    }

    func testBackupRoundTrip() throws {
        let backup = BackupFile(projects: DemoProjects.all(), priceLists: SeedCatalog.priceLists(), settings: AppSettings(), appVersion: "1.0")
        let restored = try ProjectExchange.importBackup(try ProjectExchange.exportBackup(backup))
        XCTAssertEqual(restored.projects.count, 3)
        XCTAssertEqual(restored.priceLists.count, 6)
        XCTAssertEqual(restored.settings.calculation.vatPercent, Decimal("8.1"))
        XCTAssertThrowsError(try ProjectExchange.importProject(try ProjectExchange.exportBackup(backup)))
    }

    func testDuplicateAssignsNewIdentifiers() {
        let project = sampleProject()
        let copy = ProjectExchange.duplicateWithNewIdentifiers(project)
        XCTAssertNotEqual(copy.id, project.id)
        XCTAssertNotEqual(copy.areas[0].id, project.areas[0].id)
        XCTAssertNotEqual(copy.areas[0].positions[0].id, project.areas[0].positions[0].id)
        XCTAssertNotEqual(copy.areas[0].positions[0].photos[0].id, project.areas[0].positions[0].photos[0].id)
        XCTAssertEqual(copy.areas[0].positions[0].photos[0].imageData, project.areas[0].positions[0].photos[0].imageData)
        XCTAssertTrue(copy.reference.hasSuffix("(Import)"))
    }

    func testSuggestedFileName() {
        var project = ProjectRecord(reference: "Bäckerei / Filiale: Bahnhof")
        XCTAssertEqual(ProjectExchange.suggestedFileName(for: project, suffix: "Kunde", fileExtension: "pdf"), "Bäckerei__Filiale_Bahnhof_Kunde.pdf")
        project.reference = "///"
        XCTAssertEqual(ProjectExchange.suggestedFileName(for: project, suffix: "Projekt", fileExtension: "json"), "Projekt_Projekt.json")
    }
}

final class CSVExporterTests: XCTestCase {
    func testCustomerAndInternalColumns() {
        let project = DemoProjects.all()[1]
        let analysis = OfferVariantBuilder.analyze(project: project, catalog: Fixtures.catalog, settings: Fixtures.settings)
        let customer = CSVExporter.lineItems(project: project, variants: analysis.variants, includeInternal: false)
        let internalCSV = CSVExporter.lineItems(project: project, variants: analysis.variants, includeInternal: true)
        XCTAssertTrue(customer.hasPrefix("\u{FEFF}Projekt;Variante;Hersteller"))
        XCTAssertFalse(customer.contains("Einkauf"))
        XCTAssertTrue(internalCSV.contains("Einkauf Einzelpreis CHF"))
        let rows = customer.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(rows.count, 1 + analysis.variants.reduce(0) { $0 + $1.lineItems.count })
        XCTAssertEqual(rows[0].components(separatedBy: ";").count, 12)
    }

    func testEscapingAndFormulaInjection() {
        XCTAssertEqual(CSVExporter.escape("Kamera; aussen"), "\"Kamera; aussen\"")
        XCTAssertEqual(CSVExporter.escape("Zoll \"24\""), "\"Zoll \"\"24\"\"\"")
        XCTAssertEqual(CSVExporter.escape("=SUMME(A1)"), "'=SUMME(A1)")
        XCTAssertEqual(CSVExporter.escape("-12.50"), "-12.50")
        XCTAssertEqual(CSVExporter.escape("-Rabatt"), "'-Rabatt")
        XCTAssertEqual(CSVExporter.escape("Zeile 1\nZeile 2"), "\"Zeile 1\nZeile 2\"")
    }
}

final class ProjectValidatorTests: XCTestCase {
    func testEmptyProjectHasErrorsOnRequiredSteps() {
        let issues = ProjectValidator.validate(ProjectRecord())
        let steps = Set(issues.map(\.step))
        XCTAssertTrue(steps.contains(.kunde))
        XCTAssertTrue(steps.contains(.bereiche))
        XCTAssertTrue(issues.contains { $0.message == "Bitte Firma oder Ansprechpartner erfassen." })
        XCTAssertTrue(issues.contains { $0.message == "Bitte mindestens einen Überwachungsbereich erfassen." })
    }

    func testDemoProjectsAreValid() {
        for project in DemoProjects.all() {
            XCTAssertEqual(ProjectValidator.validate(project), [], project.reference)
        }
    }

    func testContactValidation() {
        XCTAssertTrue(ProjectValidator.isValidEmail("info@sicher-ag.ch"))
        XCTAssertFalse(ProjectValidator.isValidEmail("info@sicher"))
        XCTAssertFalse(ProjectValidator.isValidEmail("info sicher.ch"))
        XCTAssertTrue(ProjectValidator.isValidPhone("+41 44 123 45 67"))
        XCTAssertTrue(ProjectValidator.isValidPhone("079 123 45 67"))
        XCTAssertFalse(ProjectValidator.isValidPhone("12345"))
        XCTAssertFalse(ProjectValidator.isValidPhone("044 12a 45 67"))
        XCTAssertFalse(ProjectValidator.isValidPhone("044+123 45 67"))
        XCTAssertTrue(ProjectValidator.isValidSwissPostalCode("8001"))
        XCTAssertFalse(ProjectValidator.isValidSwissPostalCode("800"))
        XCTAssertFalse(ProjectValidator.isValidSwissPostalCode("0800"))

        var project = Fixtures.project()
        project.customer.email = "falsch"
        project.customer.phone = "abc"
        project.sitePostalCode = "12"
        let messages = ProjectValidator.validate(project, step: .kunde).map(\.message)
        XCTAssertTrue(messages.contains("Die E-Mail-Adresse ist ungültig. Beispiel: name@firma.ch"))
        XCTAssertTrue(messages.contains("Die Telefonnummer ist ungültig. Beispiel: +41 44 123 45 67"))
        XCTAssertTrue(messages.contains("Die Postleitzahl muss vierstellig sein (1000–9999)."))
    }

    func testAreaValidation() {
        var project = Fixtures.project(cameras: 1)
        project.areas[0].positions = [CameraPositionRecord(label: "Kamera 1"), CameraPositionRecord(label: "")]
        project.areas[0].purposes = []
        let messages = ProjectValidator.validate(project, step: .bereiche).map(\.message)
        XCTAssertTrue(messages.contains { $0.contains("2 Kamerapositionen erfasst, aber nur 1 Kameras") })
        XCTAssertTrue(messages.contains { $0.contains("Kameraposition 2 braucht eine Beschriftung") })
        XCTAssertTrue(messages.contains { $0.contains("mindestens einen Zweck") })

        project.areas[0].camera.quantity = 0
        XCTAssertTrue(ProjectValidator.validate(project, step: .bereiche).contains { $0.field.hasSuffix("quantity") })
    }

    func testRecordingAndOfferValidation() {
        var project = Fixtures.project()
        project.recording.retentionDays = 0
        project.recording.userCount = 0
        project.recording.access = []
        project.discountPercent = 50
        XCTAssertEqual(ProjectValidator.validate(project, step: .aufzeichnung).count, 3)
        XCTAssertEqual(ProjectValidator.validate(project, step: .empfehlung).first?.message, "Der Rabatt muss zwischen 0 und 30 % liegen.")
    }
}

final class SeedDataTests: XCTestCase {
    func testPriceListsAreCompleteAndMarkedAsExample() {
        let lists = SeedCatalog.priceLists()
        XCTAssertEqual(Set(lists.map(\.manufacturer)), Set(Manufacturer.allCases))
        for list in lists {
            XCTAssertTrue(list.isExampleData)
            XCTAssertTrue(list.note.contains("Beispielpreise"))
            XCTAssertFalse(list.products.isEmpty)
            for product in list.products {
                XCTAssertGreaterThan(product.purchasePrice, 0, product.name)
                XCTAssertGreaterThan(product.sellPrice, product.purchasePrice, product.name)
                XCTAssertEqual(product.manufacturer, list.manufacturer)
                XCTAssertFalse(product.name.contains("ß"))
            }
        }
        let catalog = ProductCatalog(priceLists: lists)
        for m in Manufacturer.scored {
            XCTAssertTrue(catalog.hasCameras(for: m), m.label)
            XCTAssertFalse(catalog.products(of: m, role: .rekorder).isEmpty, m.label)
        }
        for role in [ComponentRole.festplatte, .poeSwitch, .usv, .kabel, .schildKlein, .schildGross, .halterung, .hebebuehne] {
            XCTAssertFalse(catalog.products(of: .neutral, role: role).isEmpty, role.label)
        }
    }

    func testManufacturerProfilesExistForScoredManufacturers() {
        XCTAssertEqual(ManufacturerProfiles.all.map(\.manufacturer), Manufacturer.scored)
    }

    func testAllOptionLabelsUseSwissSpelling() {
        func labels<T: LabeledOption>(_ type: T.Type) -> [String] { T.allCases.map(\.label) }
        let all = labels(ObjectType.self) + labels(AreaPurpose.self) + labels(DetectionTarget.self) + labels(NightVision.self)
            + labels(AudioMode.self) + labels(CablingStatus.self) + labels(MountingAccess.self) + labels(LightingCondition.self)
            + labels(RecordingMode.self) + labels(AccessChannel.self) + labels(SystemFeature.self) + labels(ProductCategory.self)
            + labels(ComponentRole.self) + labels(LaborKind.self) + labels(PhotoMarkerKind.self)
        XCTAssertFalse(all.joined().contains("ß"))
        XCTAssertTrue(labels(AreaLocation.self).contains("Aussen"))
        XCTAssertTrue(labels(LightingCondition.self).contains("Zusätzliche Beleuchtung nötig"))
    }

    func testPhotoMarkerClampsCoordinates() {
        let marker = PhotoMarker(kind: .pfeil, startX: -1, startY: 2, endX: .nan, endY: 0.5)
        XCTAssertEqual(marker.startX, 0)
        XCTAssertEqual(marker.startY, 1)
        XCTAssertEqual(marker.endX, 0)
        XCTAssertEqual(PhotoMarker(kind: .kreis, startX: 0.5, startY: 0.5, endX: 0.8, endY: 0.9).radius, 0.5, accuracy: 1e-9)
    }
}
