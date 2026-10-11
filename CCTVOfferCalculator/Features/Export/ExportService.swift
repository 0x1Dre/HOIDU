import Foundation
import CCTVCore

struct ExportedFile: Identifiable {
    enum Kind {
        case pdf, csv, json

        var symbol: String {
            switch self {
            case .pdf: "doc.richtext"
            case .csv: "tablecells"
            case .json: "curlybraces"
            }
        }
    }

    let id = UUID()
    let url: URL
    let kind: Kind
    let title: String
    let detail: String
}

/// Schreibt Exportdateien in ein temporäres, geschütztes Verzeichnis.
/// Die Dateien verlassen das Gerät nur, wenn der Benutzer sie aktiv teilt.
@MainActor
enum ExportService {
    static var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exporte", isDirectory: true)
    }

    /// Sichtbar in der Dateien-App unter «Auf meinem iPad/iPhone › CCTV Offerte».
    static var backupDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Backups", isDirectory: true)
    }

    static func write(_ data: Data, fileName: String, permanent: Bool = false) throws -> URL {
        let directory = permanent ? backupDirectory : temporaryDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func removeTemporaryExports() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    static func byteCount(of url: URL) -> String {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    static func timestamp(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d%02d%02d-%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }
}
