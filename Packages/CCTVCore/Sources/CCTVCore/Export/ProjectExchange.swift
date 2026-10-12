import Foundation

/// Austauschformat für einzelne Projekte. Fotos werden – sofern gewünscht – als Base64
/// im Feld `imageData` der jeweiligen Fotos eingebettet. Markierungen werden als relative
/// Koordinaten exportiert; das Originalbild bleibt unverändert.
public struct ProjectExchangeFile: Codable, Sendable {
    public static let formatIdentifier = "ch.cctv-offer-calculator.project"
    public static let currentSchemaVersion = 1

    public var format: String
    public var schemaVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var includesPhotos: Bool
    public var project: ProjectRecord

    public init(project: ProjectRecord, appVersion: String, includesPhotos: Bool, exportedAt: Date = Date()) {
        self.format = Self.formatIdentifier
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.includesPhotos = includesPhotos
        self.project = includesPhotos ? project : project.strippingImageData()
    }
}

/// Vollständige Datensicherung aller Projekte, Preislisten und Einstellungen.
public struct BackupFile: Codable, Sendable {
    public static let formatIdentifier = "ch.cctv-offer-calculator.backup"
    public static let currentSchemaVersion = 1

    public var format: String
    public var schemaVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var projects: [ProjectRecord]
    public var priceLists: [PriceListRecord]
    public var settings: AppSettings

    public init(projects: [ProjectRecord], priceLists: [PriceListRecord], settings: AppSettings, appVersion: String, exportedAt: Date = Date()) {
        self.format = Self.formatIdentifier
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.projects = projects
        self.priceLists = priceLists
        self.settings = settings
    }
}

public enum ExchangeError: Error, Equatable, LocalizedError, Sendable {
    case emptyFile
    case notJSON
    case wrongFormat
    case unsupportedVersion(Int)
    case damaged(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFile: "Die Datei ist leer."
        case .notJSON: "Die Datei ist keine gültige JSON-Datei."
        case .wrongFormat: "Die Datei ist keine Projektdatei der Ostsicht-Offerten-App."
        case .unsupportedVersion(let version): "Die Datei wurde mit einer neueren App-Version erstellt (Format \(version)). Bitte die App aktualisieren."
        case .damaged(let detail): "Die Datei ist beschädigt oder unvollständig (\(detail))."
        }
    }
}

public enum ProjectExchange {
    private static func isoFormatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoFormatter(fractional: true).string(from: date))
        }
        encoder.dataEncodingStrategy = .base64
        return encoder
    }

    /// Akzeptiert ISO-8601-Daten mit und ohne Sekundenbruchteile.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = isoFormatter(fractional: true).date(from: text) ?? isoFormatter(fractional: false).date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ungültiges Datum: \(text)")
        }
        decoder.dataDecodingStrategy = .base64
        return decoder
    }

    public static func export(_ project: ProjectRecord, appVersion: String, includePhotos: Bool = true) throws -> Data {
        try makeEncoder().encode(ProjectExchangeFile(project: project, appVersion: appVersion, includesPhotos: includePhotos))
    }

    public static func exportBackup(_ backup: BackupFile) throws -> Data {
        try makeEncoder().encode(backup)
    }

    private struct Header: Decodable {
        var format: String?
        var schemaVersion: Int?
    }

    private static func checkHeader(_ data: Data, expected: String, currentVersion: Int) throws(ExchangeError) {
        guard !data.isEmpty else { throw .emptyFile }
        let header: Header
        do {
            header = try JSONDecoder().decode(Header.self, from: data)
        } catch {
            throw .notJSON
        }
        guard header.format == expected else { throw .wrongFormat }
        let version = header.schemaVersion ?? 0
        guard version <= currentVersion else { throw .unsupportedVersion(version) }
    }

    public static func importProject(_ data: Data) throws(ExchangeError) -> ProjectExchangeFile {
        try checkHeader(data, expected: ProjectExchangeFile.formatIdentifier, currentVersion: ProjectExchangeFile.currentSchemaVersion)
        do {
            return try makeDecoder().decode(ProjectExchangeFile.self, from: data)
        } catch let error as DecodingError {
            throw .damaged(describe(error))
        } catch {
            throw .damaged(String(describing: error))
        }
    }

    public static func importBackup(_ data: Data) throws(ExchangeError) -> BackupFile {
        try checkHeader(data, expected: BackupFile.formatIdentifier, currentVersion: BackupFile.currentSchemaVersion)
        do {
            return try makeDecoder().decode(BackupFile.self, from: data)
        } catch let error as DecodingError {
            throw .damaged(describe(error))
        } catch {
            throw .damaged(String(describing: error))
        }
    }

    /// Weist einem importierten Projekt neue IDs zu, damit es neben dem Original bestehen kann.
    public static func duplicateWithNewIdentifiers(_ project: ProjectRecord, referenceSuffix: String = " (Import)") -> ProjectRecord {
        var copy = project
        copy.id = UUID()
        copy.reference = project.reference + referenceSuffix
        copy.areas = project.areas.map { area in
            var area = area
            area.id = UUID()
            area.photos = area.photos.map { var p = $0; p.id = UUID(); return p }
            area.positions = area.positions.map { position in
                var position = position
                position.id = UUID()
                position.photos = position.photos.map { var p = $0; p.id = UUID(); return p }
                return position
            }
            return area
        }
        return copy
    }

    public static func suggestedFileName(for project: ProjectRecord, suffix: String, fileExtension: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let base = project.displayTitle
            .replacingOccurrences(of: " ", with: "_")
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        let trimmed = String(base.prefix(60))
        return "\(trimmed.isEmpty ? "Projekt" : trimmed)_\(suffix).\(fileExtension)"
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): "Feld «\(key.stringValue)» fehlt"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            context.codingPath.map(\.stringValue).joined(separator: ".").isEmpty
                ? context.debugDescription
                : "Feld «\(context.codingPath.map(\.stringValue).joined(separator: "."))»"
        @unknown default: "unbekannter Fehler"
        }
    }
}
