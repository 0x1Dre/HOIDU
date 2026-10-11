import Foundation
import SwiftData
import CCTVCore

enum RepositoryError: LocalizedError {
    case saveFailed(String)
    case projectNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let detail): "Die Daten konnten nicht gespeichert werden (\(detail))."
        case .projectNotFound: "Das Projekt wurde nicht gefunden. Möglicherweise wurde es gelöscht."
        }
    }
}

/// Zugriff auf Projekte und Preislisten. Views und ViewModels arbeiten mit Domänenobjekten,
/// die Abbildung auf SwiftData erfolgt ausschliesslich hier und in den Modellklassen.
@MainActor
struct ProjectRepository {
    let context: ModelContext

    func project(id: UUID) -> Project? {
        var descriptor = FetchDescriptor<Project>(predicate: #Predicate<Project> { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func catalog() -> ProductCatalog {
        let lists = (try? context.fetch(FetchDescriptor<PriceList>())) ?? []
        return ProductCatalog(priceLists: lists.map(\.record))
    }

    @discardableResult
    func save(_ record: ProjectRecord, touch: Bool = true) throws -> Project {
        var updated = record
        if touch { updated.updatedAt = Date() }
        let model: Project
        if let existing = project(id: record.id) {
            model = existing
        } else {
            model = Project(id: record.id)
            context.insert(model)
        }
        model.apply(updated, context: context)
        try commit()
        return model
    }

    func delete(_ project: Project) throws {
        context.delete(project)
        try commit()
    }

    @discardableResult
    func duplicate(_ project: Project) throws -> Project {
        var copy = ProjectExchange.duplicateWithNewIdentifiers(project.record, referenceSuffix: " (Kopie)")
        copy.status = .entwurf
        copy.isDemo = false
        copy.createdAt = Date()
        copy.variantSelection = VariantSelection()
        return try save(copy)
    }

    /// Importiert ein Projekt. Existiert die ID bereits, wird eine Kopie mit neuen IDs angelegt.
    @discardableResult
    func importProject(from data: Data) throws -> Project {
        let file = try ProjectExchange.importProject(data)
        var record = file.project
        if project(id: record.id) != nil {
            record = ProjectExchange.duplicateWithNewIdentifiers(record)
        }
        return try save(record, touch: false)
    }

    func backup(settings: AppSettings, appVersion: String) throws -> Data {
        let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt)]))
        let lists = try context.fetch(FetchDescriptor<PriceList>())
        return try ProjectExchange.exportBackup(BackupFile(
            projects: projects.map(\.record),
            priceLists: lists.map(\.record),
            settings: settings,
            appVersion: appVersion
        ))
    }

    struct RestoreSummary {
        var importedProjects: Int
        var skippedProjects: Int
        var priceLists: Int
    }

    /// Spielt ein Backup ein: Projekte werden ergänzt (bestehende IDs übersprungen),
    /// Preislisten ersetzt und die Einstellungen übernommen.
    func restore(from data: Data, settings: SettingsStore) throws -> RestoreSummary {
        let backup = try ProjectExchange.importBackup(data)
        var imported = 0
        var skipped = 0
        for record in backup.projects {
            if project(id: record.id) != nil {
                skipped += 1
                continue
            }
            let model = Project(id: record.id)
            context.insert(model)
            model.apply(record, context: context)
            imported += 1
        }
        for list in try context.fetch(FetchDescriptor<PriceList>()) {
            context.delete(list)
        }
        for record in backup.priceLists {
            let list = PriceList(id: record.id)
            context.insert(list)
            list.apply(record, context: context)
        }
        settings.settings = backup.settings
        try commit()
        return RestoreSummary(importedProjects: imported, skippedProjects: skipped, priceLists: backup.priceLists.count)
    }

    /// Legt eine neue Offertversion an, wenn das Projekt seit der letzten Offerte geändert wurde.
    func offer(for project: Project, analysis: OfferAnalysis, settings: SettingsStore) throws -> Offer {
        if let latest = project.latestOffer, latest.createdAt >= project.updatedAt {
            return latest
        }
        let now = Date()
        let offer = Offer(number: settings.nextOfferNumber(date: now))
        context.insert(offer)
        offer.createdAt = now
        offer.validUntil = Calendar.current.date(byAdding: .day, value: settings.calculation.offerValidityDays, to: now) ?? now
        offer.recommendedTierRaw = analysis.recommendedTier.rawValue
        offer.discountBasisPoints = project.discountBasisPoints
        offer.recommendedTotalRappen = Money.toRappen(analysis.recommendedVariant?.totals.totalInclVAT ?? 0)
        var calculations: [Calculation] = []
        for variant in analysis.variants {
            let calculation = Calculation(variant: variant)
            context.insert(calculation)
            calculations.append(calculation)
        }
        offer.calculations = calculations
        offer.project = project
        if let quote = analysis.recommendedVariant?.maintenance {
            project.maintenancePlan?.applySnapshot(quote)
        }
        if project.status == .entwurf || project.status == .erfasst {
            project.status = .offeriert
        }
        try commit()
        return offer
    }

    func commit() throws {
        do {
            try context.save()
        } catch {
            throw RepositoryError.saveFailed(error.localizedDescription)
        }
    }
}
