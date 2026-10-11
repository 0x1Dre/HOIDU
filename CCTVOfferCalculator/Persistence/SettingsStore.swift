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

    // Gespeicherte Werte; die öffentlichen Eigenschaften schreiben bei jeder Änderung in die UserDefaults.
    private var storedSettings: AppSettings
    private var storedInternalMode: Bool
    private var storedPhotosInCustomerPDF: Bool
    private var storedPhotosInJSON: Bool
    private var storedCatalogVersion: Int
    private var storedDemoProjectsSeeded: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.settings),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            storedSettings = decoded
        } else {
            storedSettings = AppSettings()
        }
        storedInternalMode = defaults.bool(forKey: Keys.internalMode)
        storedPhotosInCustomerPDF = defaults.bool(forKey: Keys.includePhotosInCustomerPDF)
        storedPhotosInJSON = defaults.object(forKey: Keys.includePhotosInJSON) as? Bool ?? true
        storedCatalogVersion = defaults.integer(forKey: Keys.seededCatalogVersion)
        storedDemoProjectsSeeded = defaults.bool(forKey: Keys.demoProjectsSeeded)
    }

    var settings: AppSettings {
        get { storedSettings }
        set {
            storedSettings = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.settings)
            }
        }
    }

    /// Zeigt Einkaufspreise, Margen und Deckungsbeiträge in der App an.
    var internalMode: Bool {
        get { storedInternalMode }
        set {
            storedInternalMode = newValue
            defaults.set(newValue, forKey: Keys.internalMode)
        }
    }

    var includePhotosInCustomerPDF: Bool {
        get { storedPhotosInCustomerPDF }
        set {
            storedPhotosInCustomerPDF = newValue
            defaults.set(newValue, forKey: Keys.includePhotosInCustomerPDF)
        }
    }

    var includePhotosInJSON: Bool {
        get { storedPhotosInJSON }
        set {
            storedPhotosInJSON = newValue
            defaults.set(newValue, forKey: Keys.includePhotosInJSON)
        }
    }

    var seededCatalogVersion: Int {
        get { storedCatalogVersion }
        set {
            storedCatalogVersion = newValue
            defaults.set(newValue, forKey: Keys.seededCatalogVersion)
        }
    }

    var demoProjectsSeeded: Bool {
        get { storedDemoProjectsSeeded }
        set {
            storedDemoProjectsSeeded = newValue
            defaults.set(newValue, forKey: Keys.demoProjectsSeeded)
        }
    }

    var calculation: CalculationSettings { storedSettings.calculation }
    var company: CompanyProfile { storedSettings.company }

    /// Fortlaufende Offertnummer pro Jahr, z. B. «OF-2026-0007».
    func nextOfferNumber(date: Date = Date()) -> String {
        let year = Calendar.current.component(.year, from: date)
        let next = defaults.integer(forKey: Keys.offerCounter(year)) + 1
        defaults.set(next, forKey: Keys.offerCounter(year))
        return String(format: "OF-%04d-%04d", year, next)
    }

    func resetCalculationDefaults() {
        var updated = settings
        updated.calculation = CalculationSettings()
        settings = updated
    }
}
