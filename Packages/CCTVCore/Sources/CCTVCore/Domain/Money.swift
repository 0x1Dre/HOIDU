import Foundation

/// Geldbeträge werden als `Decimal` in CHF geführt, damit keine Rundungsfehler
/// aus Fliesskommazahlen entstehen. `Decimal`-Literale mit Nachkommastellen
/// laufen über `Double` und sind deshalb zu vermeiden – stattdessen `Money.rappen(_:)`.
public enum Money {
    public static func rappen(_ value: Int) -> Decimal {
        Decimal(value) / 100
    }

    public static func toRappen(_ value: Decimal) -> Int {
        NSDecimalNumber(decimal: (value * 100).roundedTo(scale: 0)).intValue
    }

    public static func percent(tenths: Int) -> Decimal {
        Decimal(tenths) / 10
    }

    public static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "CHF", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned) else { return nil }
        return value
    }
}

public extension Decimal {
    func roundedTo(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    /// Schweizer Rappenrundung auf 5 Rappen.
    var roundedToFiveRappen: Decimal {
        (self * 20).roundedTo(scale: 0) / 20
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    func clamped(to range: ClosedRange<Decimal>) -> Decimal {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Deterministische Formatierung im Schweizer Stil (1’234.50), unabhängig von der Gerätesprache.
public enum Format {
    public static let groupingSeparator = "’"

    public static func chf(_ value: Decimal) -> String {
        "CHF " + number(value, fractionDigits: 2)
    }

    public static func number(_ value: Decimal, fractionDigits: Int, grouping: Bool = true) -> String {
        let digits = Swift.max(0, fractionDigits)
        let rounded = value.roundedTo(scale: digits)
        let isNegative = rounded < 0
        var scale = Decimal(1)
        for _ in 0..<digits { scale *= 10 }
        let scaled = NSDecimalNumber(decimal: (isNegative ? -rounded : rounded) * scale).int64Value
        let divisor = Int64(NSDecimalNumber(decimal: scale).int64Value)
        let integerPart = scaled / divisor
        let fractionPart = scaled % divisor

        var integerText = String(integerPart)
        if grouping, integerText.count > 3 {
            var grouped: [String] = []
            while integerText.count > 3 {
                grouped.insert(String(integerText.suffix(3)), at: 0)
                integerText.removeLast(3)
            }
            grouped.insert(integerText, at: 0)
            integerText = grouped.joined(separator: groupingSeparator)
        }

        var result = (isNegative ? "-" : "") + integerText
        if digits > 0 {
            var fractionText = String(fractionPart)
            while fractionText.count < digits { fractionText = "0" + fractionText }
            result += "." + fractionText
        }
        return result
    }

    public static func number(_ value: Double, fractionDigits: Int) -> String {
        guard value.isFinite else { return "–" }
        return number(Decimal(string: String(format: "%.\(Swift.max(0, fractionDigits))f", value)) ?? 0,
                      fractionDigits: fractionDigits)
    }

    public static func percent(_ value: Decimal, fractionDigits: Int = 1) -> String {
        number(value, fractionDigits: fractionDigits, grouping: false) + " %"
    }

    /// Betrag ohne Tausendertrennzeichen mit Punkt als Dezimaltrennzeichen (für CSV).
    public static func plain(_ value: Decimal, fractionDigits: Int = 2) -> String {
        number(value, fractionDigits: fractionDigits, grouping: false)
    }

    public static func date(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        let day = components.day ?? 1
        let month = components.month ?? 1
        let year = components.year ?? 2000
        return String(format: "%02d.%02d.%04d", day, month, year)
    }

    public static func hours(_ value: Decimal) -> String {
        number(value, fractionDigits: 2, grouping: false) + " h"
    }
}
