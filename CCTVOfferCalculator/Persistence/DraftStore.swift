import Foundation
import CCTVCore

/// Sichert den Entwurf des Projektassistenten lokal, damit vor Ort erfasste Daten
/// (inklusive Fotos) auch nach einem Abbruch der App erhalten bleiben.
@MainActor
enum DraftStore {
    private static var fileURL: URL? {
        try? PersistenceController.storeDirectory().appendingPathComponent("Entwurf-Neues-Projekt.json")
    }

    static func save(_ draft: ProjectRecord) {
        guard let url = fileURL, let data = try? ProjectExchange.makeEncoder().encode(draft) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func load() -> ProjectRecord? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? ProjectExchange.makeDecoder().decode(ProjectRecord.self, from: data)
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
