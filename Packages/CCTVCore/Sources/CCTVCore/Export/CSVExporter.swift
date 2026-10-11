import Foundation

/// CSV-Export der Offertpositionen. Trennzeichen Semikolon, Dezimalpunkt, UTF-8 mit BOM
/// (öffnet in Excel mit Schweizer Regionaleinstellungen korrekt).
public enum CSVExporter {
    public static let separator = ";"
    public static let lineBreak = "\r\n"

    public static func lineItems(project: ProjectRecord, variants: [OfferVariant], includeInternal: Bool) -> String {
        var header = ["Projekt", "Variante", "Hersteller", "Pos.", "Art", "Kategorie", "Artikelnummer", "Beschreibung",
                      "Menge", "Einheit", "Einzelpreis CHF", "Total CHF"]
        if includeInternal {
            header += ["Einkauf Einzelpreis CHF", "Einkauf Total CHF", "Marge CHF", "Marge %"]
        }

        var rows: [[String]] = [header]
        for variant in variants {
            for item in variant.lineItems {
                var row = [
                    project.displayTitle,
                    variant.tier.label,
                    variant.manufacturer.label,
                    String(item.position),
                    item.kind == .material ? "Material" : "Arbeit",
                    item.category,
                    item.articleNumber,
                    item.description,
                    Format.plain(item.quantity, fractionDigits: 2),
                    item.unit.label,
                    Format.plain(item.unitSellPrice),
                    Format.plain(item.totalSell)
                ]
                if includeInternal {
                    row += [
                        Format.plain(item.unitPurchasePrice),
                        Format.plain(item.totalPurchase),
                        Format.plain(item.marginAmount),
                        Format.plain(item.marginPercent, fractionDigits: 1)
                    ]
                }
                rows.append(row)
            }
        }

        let body = rows.map { row in row.map(escape).joined(separator: separator) }.joined(separator: lineBreak)
        return "\u{FEFF}" + body + lineBreak
    }

    /// Maskiert Trennzeichen und Anführungszeichen und verhindert Formel-Injektion in Tabellenprogrammen.
    public static func escape(_ value: String) -> String {
        var text = value
        if let first = text.first, "=+@\t\r".contains(first) || (first == "-" && Double(text) == nil) {
            text = "'" + text
        }
        if text.contains(separator) || text.contains("\"") || text.contains("\n") || text.contains("\r") {
            text = "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return text
    }
}
