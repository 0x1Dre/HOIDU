import Foundation

public struct StorageInput: Codable, Hashable, Sendable {
    public var cameras: Int
    public var megapixels: Double
    public var framesPerSecond: Int
    public var codec: VideoCodec
    /// Manuelle Bitrate pro Kamera in kbit/s; `nil` = konservativer Standardwert.
    public var manualBitrateKbps: Int?
    public var mode: RecordingMode
    public var eventSharePercent: Double
    public var scheduleHoursPerDay: Double
    public var retentionDays: Int
    public var safetyMarginPercent: Double
    public var diskSizeTB: Int
    public var usableCapacityPercent: Double
    public var redundancyDisk: Bool

    public init(
        cameras: Int = 4,
        megapixels: Double = 4,
        framesPerSecond: Int = 15,
        codec: VideoCodec = .h265,
        manualBitrateKbps: Int? = nil,
        mode: RecordingMode = .dauer,
        eventSharePercent: Double = 30,
        scheduleHoursPerDay: Double = 12,
        retentionDays: Int = 14,
        safetyMarginPercent: Double = 20,
        diskSizeTB: Int = 8,
        usableCapacityPercent: Double = 90,
        redundancyDisk: Bool = false
    ) {
        self.cameras = cameras
        self.megapixels = megapixels
        self.framesPerSecond = framesPerSecond
        self.codec = codec
        self.manualBitrateKbps = manualBitrateKbps
        self.mode = mode
        self.eventSharePercent = eventSharePercent
        self.scheduleHoursPerDay = scheduleHoursPerDay
        self.retentionDays = retentionDays
        self.safetyMarginPercent = safetyMarginPercent
        self.diskSizeTB = diskSizeTB
        self.usableCapacityPercent = usableCapacityPercent
        self.redundancyDisk = redundancyDisk
    }
}

public struct StorageResult: Codable, Hashable, Sendable {
    public var bitratePerCameraKbps: Double
    public var bitrateIsManual: Bool
    public var effectiveHoursPerDay: Double
    public var dailyTB: Double
    public var requiredTB: Double
    public var requiredTBWithMargin: Double
    public var diskSizeTB: Int
    public var usableTBPerDisk: Double
    public var recommendedDisks: Int
    public var formula: String
    public var assumptions: [String]
}

public enum StorageCalculatorError: Error, Equatable, LocalizedError, Sendable {
    case invalidCameraCount
    case invalidRetention
    case invalidFrameRate
    case invalidMegapixels
    case invalidDiskSize
    case invalidBitrate

    public var errorDescription: String? {
        switch self {
        case .invalidCameraCount: "Die Kameraanzahl muss zwischen 1 und 256 liegen."
        case .invalidRetention: "Die Aufbewahrungsdauer muss zwischen 1 und 365 Tagen liegen."
        case .invalidFrameRate: "Die Bildrate muss zwischen 1 und 60 Bildern pro Sekunde liegen."
        case .invalidMegapixels: "Die Auflösung muss zwischen 1 und 32 Megapixel liegen."
        case .invalidDiskSize: "Die Festplattengrösse muss mindestens 1 TB betragen."
        case .invalidBitrate: "Die manuelle Bitrate muss zwischen 128 und 50’000 kbit/s liegen."
        }
    }
}

public enum StorageCalculator {
    public static let minimumDefaultBitrateKbps: Double = 512

    public static func defaultBitrateKbps(megapixels: Double, framesPerSecond: Int, codec: VideoCodec) -> Double {
        max(minimumDefaultBitrateKbps, megapixels * Double(framesPerSecond) * codec.kbpsPerMegapixelPerFrame)
    }

    public static func validate(_ input: StorageInput) throws(StorageCalculatorError) {
        guard (1...256).contains(input.cameras) else { throw .invalidCameraCount }
        guard (1...365).contains(input.retentionDays) else { throw .invalidRetention }
        guard (1...60).contains(input.framesPerSecond) else { throw .invalidFrameRate }
        guard input.megapixels >= 1, input.megapixels <= 32 else { throw .invalidMegapixels }
        guard input.diskSizeTB >= 1 else { throw .invalidDiskSize }
        if let manual = input.manualBitrateKbps, !(128...50_000).contains(manual) { throw .invalidBitrate }
    }

    public static func calculate(_ input: StorageInput) throws(StorageCalculatorError) -> StorageResult {
        try validate(input)

        let isManual = input.manualBitrateKbps != nil
        let bitrate = input.manualBitrateKbps.map(Double.init)
            ?? defaultBitrateKbps(megapixels: input.megapixels, framesPerSecond: input.framesPerSecond, codec: input.codec)

        let effectiveHours: Double
        switch input.mode {
        case .dauer:
            effectiveHours = 24
        case .ereignis:
            effectiveHours = 24 * min(max(input.eventSharePercent, 1), 100) / 100
        case .zeitplan:
            effectiveHours = min(max(input.scheduleHoursPerDay, 1), 24)
        }

        // kbit/s → TB (dezimal): kbit × 1000 / 8 = Byte; ÷ 10^12 = TB
        let bytesPerDayPerCamera = bitrate * 1000 / 8 * 3600 * effectiveHours
        let dailyTB = bytesPerDayPerCamera * Double(input.cameras) / 1_000_000_000_000
        let required = dailyTB * Double(input.retentionDays)
        let withMargin = required * (1 + max(0, input.safetyMarginPercent) / 100)
        let usablePerDisk = Double(input.diskSizeTB) * min(max(input.usableCapacityPercent, 50), 100) / 100
        var disks = max(1, Int((withMargin / usablePerDisk).rounded(.up)))
        if input.redundancyDisk { disks += 1 }

        let activity: String
        switch input.mode {
        case .dauer: activity = "Daueraufnahme: 24 h pro Tag"
        case .ereignis: activity = "Ereignisaufnahme: \(Format.number(input.eventSharePercent, fractionDigits: 0)) % Aktivitätsanteil (≈ \(Format.number(effectiveHours, fractionDigits: 1)) h pro Tag)"
        case .zeitplan: activity = "Zeitplan: \(Format.number(effectiveHours, fractionDigits: 1)) h Aufnahme pro Tag"
        }

        var assumptions = [
            isManual
                ? "Bitrate manuell: \(Format.number(bitrate, fractionDigits: 0)) kbit/s pro Kamera"
                : "Bitrate konservativ: \(Format.number(input.megapixels, fractionDigits: 1)) MP × \(input.framesPerSecond) fps × \(Format.number(input.codec.kbpsPerMegapixelPerFrame, fractionDigits: 0)) kbit/s (\(input.codec.label)) = \(Format.number(bitrate, fractionDigits: 0)) kbit/s",
            activity,
            "Aufbewahrung: \(input.retentionDays) Tage",
            "Sicherheitsreserve: \(Format.number(input.safetyMarginPercent, fractionDigits: 0)) %",
            "Nutzbare Kapazität pro Disk: \(Format.number(input.usableCapacityPercent, fractionDigits: 0)) % von \(input.diskSizeTB) TB (Formatierung, Dateisystem)",
            "1 TB = 10¹² Byte (Herstellerangabe)"
        ]
        if input.redundancyDisk {
            assumptions.append("Eine zusätzliche Disk für Redundanz (z. B. RAID 5) eingerechnet")
        }

        return StorageResult(
            bitratePerCameraKbps: bitrate,
            bitrateIsManual: isManual,
            effectiveHoursPerDay: effectiveHours,
            dailyTB: dailyTB,
            requiredTB: required,
            requiredTBWithMargin: withMargin,
            diskSizeTB: input.diskSizeTB,
            usableTBPerDisk: usablePerDisk,
            recommendedDisks: disks,
            formula: "Speicher [TB] = Kameras × Bitrate [kbit/s] × 1000 ÷ 8 × 3600 × Stunden pro Tag × Tage ÷ 10¹² × (1 + Reserve)",
            assumptions: assumptions
        )
    }
}
