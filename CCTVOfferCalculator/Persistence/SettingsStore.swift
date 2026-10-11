import Foundation
import Observation
import CCTVCore

/// Einstellungen der App, lokal in den UserDefaults gespeichert.
@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let settings = "settings.v1"
        static let internalMode = "settings.internalMode"
        static let includePhotosInCustomerPDF = "settings.customerPDFPhotos"
        static let includePhotosInJSON = "settings.jsonPhotos"
        static let seededCatalogVersion = "seed.catalogVersion"
        static let demoProjectsSeeded = "seed.demoProjects"
        static func offerCounter(_ year: Int) -> String { "offer.counter.\(year)" }
    }

    private let defaults: UserDefaults

    var settings: AppSettings {
        didSet { persistSettings() }
    }

    /// Zeigt Einkaufspreise, Margen und Deckungsbeiträge in der App an.
    var internalMode: Bool {
        didSet { defaults.set(internalMode, forKey: Keys.internalMode) }
    }

    var includePhotosInCustomerPDF: Bool {
        didSet { defaults.set(includePhotosInCustomerPDF, forKey: Keys.includePhotosInCustomerPDF) }
    }

    var includePhotosInJSON: Bool {
        didSet { defaults.set(includePhotosInJSON, forKey: Keys.includePhotosInJSON) }
    }

    var seededCatalogVersion: Int {
        didSet { defaults.set(seededCatalogVersion, forKey: Keys.seededCatalogVersion) }
    }

    var demoProjectsSeeded: Bool {
        didSet { defaults.set(demoProjectsSeeded, forKey: Keys.demoProjectsSeeded) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.settings),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
        internalMode = defaults.bool(forKey: Keys.internalMode)
        includePhotosInCustomerPDF = defaults.bool(forKey: Keys.includePhotosInCustomerPDF)
        includePhotosInJSON = defaults.object(forKey: Keys.includePhotosInJSON) as? Bool ?? true
        seededCatalogVersion = defaults.integer(forKey: Keys.seededCatalogVersion)
        demoProjectsSeeded = defaults.bool(forKey: Keys.demoProjectsSeeded)
    }

    var calculation: CalculationSettings { settings.calculation }
    var company: CompanyProfile { settings.company }

    /// Fortlaufende Offertnummer pro Jahr, z. B. «OF-2026-0007».
    func nextOfferNumber(date: Date = Date()) -> String {
        let year = Calendar.current.component(.year, from: date)
        let next = defaults.integer(forKey: Keys.offerCounter(year)) + 1
        defaults.set(next, forKey: Keys.offerCounter(year))
        return String(format: "OF-%04d-%04d", year, next)
    }

    func resetCalculationDefaults() {
        settings.calculation = CalculationSettings()
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.settings)
        }
    }
}
