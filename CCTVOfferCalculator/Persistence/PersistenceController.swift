import Foundation
import SwiftData
import CCTVCore

/// Lokale SwiftData-Datenbank im geschützten Application-Support-Verzeichnis der App.
/// Es gibt keine Cloud-Synchronisation; Daten verlassen das Gerät nur über Export/Teilen.
@MainActor
enum PersistenceController {
    static let schema = Schema([
        Customer.self,
        Project.self,
        SiteArea.self,
        CameraRequirement.self,
        CameraPosition.self,
        PhotoAttachment.self,
        Product.self,
        PriceList.self,
        Calculation.self,
        MaintenancePlan.self,
        Offer.self
    ])

    struct Result {
        let container: ModelContainer
        let errorMessage: String?
    }

    static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("CCTVOfferCalculator", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Datei bleibt geschützt, solange das Gerät gesperrt ist; bereits geöffnete Dateien dürfen weiterschreiben.
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: directory.path)
        return directory
    }

    static func makeContainer() -> Result {
        do {
            let url = try storeDirectory().appendingPathComponent("Projekte.store")
            let configuration = ModelConfiguration("Projekte", schema: schema, url: url, allowsSave: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return Result(container: container, errorMessage: nil)
        } catch {
            let configuration = ModelConfiguration("Notfall", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            // Ein In-Memory-Container mit gültigem Schema kann nicht fehlschlagen.
            let container = try! ModelContainer(for: schema, configurations: [configuration])
            return Result(
                container: container,
                errorMessage: "Die lokale Datenbank konnte nicht geöffnet werden. Änderungen werden in dieser Sitzung nicht gespeichert. Bitte die App neu starten oder ein Backup einspielen. (\(error.localizedDescription))"
            )
        }
    }

    /// Legt beim ersten Start Beispielpreislisten und Demo-Projekte an.
    static func seedIfNeeded(context: ModelContext, settings: SettingsStore) {
        let priceListCount = (try? context.fetchCount(FetchDescriptor<PriceList>())) ?? 0
        if priceListCount == 0 {
            insertSeedPriceLists(context: context)
            settings.seededCatalogVersion = SeedCatalog.version
        }
        if !settings.demoProjectsSeeded {
            insertDemoProjects(context: context)
            settings.demoProjectsSeeded = true
        }
        try? context.save()
    }

    static func insertSeedPriceLists(context: ModelContext) {
        for record in SeedCatalog.priceLists() {
            let list = PriceList(id: record.id)
            context.insert(list)
            list.apply(record, context: context)
        }
    }

    static func insertDemoProjects(context: ModelContext) {
        for record in DemoProjects.all() {
            let project = Project(id: record.id)
            context.insert(project)
            project.apply(record, context: context)
        }
    }

    /// Ersetzt alle als Beispieldaten markierten Preislisten durch die mitgelieferten Beispielpreise.
    static func resetExamplePriceLists(context: ModelContext) throws {
        let lists = try context.fetch(FetchDescriptor<PriceList>())
        for list in lists where list.isExampleData {
            context.delete(list)
        }
        insertSeedPriceLists(context: context)
        try context.save()
    }
}
