import Foundation

public struct CompanyProfile: Codable, Hashable, Sendable {
    public var name: String
    public var street: String
    public var postalCode: String
    public var city: String
    public var phone: String
    public var email: String
    public var website: String
    public var vatNumber: String
    public var offerFooter: String

    public init(
        name: String = "",
        street: String = "",
        postalCode: String = "",
        city: String = "",
        phone: String = "",
        email: String = "",
        website: String = "",
        vatNumber: String = "",
        offerFooter: String = "Wir danken für Ihre Anfrage und freuen uns auf die Zusammenarbeit."
    ) {
        self.name = name
        self.street = street
        self.postalCode = postalCode
        self.city = city
        self.phone = phone
        self.email = email
        self.website = website
        self.vatNumber = vatNumber
        self.offerFooter = offerFooter
    }

    public var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var letterheadLines: [String] {
        let cityLine = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        let contact = [phone, email].filter { !$0.isEmpty }.joined(separator: " · ")
        return [name, street, cityLine, contact, website, vatNumber.isEmpty ? "" : "MWST-Nr. \(vatNumber)"]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Kontaktdaten in einer Zeile für die Fusszeile der Offerte.
    public var footerLine: String {
        let address = [street, [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return [name, address, phone, email, website]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

public struct MaintenancePackageConfig: Codable, Hashable, Sendable, Identifiable {
    public var package: MaintenancePackage
    public var monthlyBaseFee: Decimal
    public var pricePerCamera: Decimal
    public var pricePerRecorder: Decimal
    public var includedRemoteMinutes: Int
    public var onSiteCheckIncluded: Bool
    public var yearlyOnSiteCheckPrice: Decimal
    public var responseTime: String
    public var services: [String]

    public var id: String { package.rawValue }

    public init(
        package: MaintenancePackage,
        monthlyBaseFee: Decimal,
        pricePerCamera: Decimal,
        pricePerRecorder: Decimal,
        includedRemoteMinutes: Int,
        onSiteCheckIncluded: Bool,
        yearlyOnSiteCheckPrice: Decimal,
        responseTime: String,
        services: [String]
    ) {
        self.package = package
        self.monthlyBaseFee = monthlyBaseFee
        self.pricePerCamera = pricePerCamera
        self.pricePerRecorder = pricePerRecorder
        self.includedRemoteMinutes = includedRemoteMinutes
        self.onSiteCheckIncluded = onSiteCheckIncluded
        self.yearlyOnSiteCheckPrice = yearlyOnSiteCheckPrice
        self.responseTime = responseTime
        self.services = services
    }

    public static let basicServices = [
        "Statusprüfung von Kameras und Aufzeichnung",
        "Prüfung verfügbarer Firmware- und Software-Updates",
        "Monatlicher Statusbericht"
    ]

    public static let businessServices = basicServices + [
        "Geplante Updates (Firmware/Software) im Wartungsfenster",
        "Prüfung der Benutzer und Berechtigungen",
        "Fernsupport im definierten Umfang"
    ]

    public static let premiumServices = businessServices + [
        "Priorisierte Reaktionszeit",
        "Regelmässiger Security-Check (Passwörter, Ports, Firmware-Stand)",
        "Jährlicher Service vor Ort"
    ]

    public static let defaults: [MaintenancePackageConfig] = [
        MaintenancePackageConfig(
            package: .basic,
            monthlyBaseFee: 29,
            pricePerCamera: 4,
            pricePerRecorder: 10,
            includedRemoteMinutes: 0,
            onSiteCheckIncluded: false,
            yearlyOnSiteCheckPrice: 290,
            responseTime: "Nächster Arbeitstag",
            services: basicServices
        ),
        MaintenancePackageConfig(
            package: .business,
            monthlyBaseFee: 59,
            pricePerCamera: 6,
            pricePerRecorder: 15,
            includedRemoteMinutes: 60,
            onSiteCheckIncluded: false,
            yearlyOnSiteCheckPrice: 290,
            responseTime: "Innert 8 Arbeitsstunden",
            services: businessServices
        ),
        MaintenancePackageConfig(
            package: .premium,
            monthlyBaseFee: 119,
            pricePerCamera: 9,
            pricePerRecorder: 25,
            includedRemoteMinutes: 180,
            onSiteCheckIncluded: true,
            yearlyOnSiteCheckPrice: 0,
            responseTime: "Innert 4 Stunden (Mo–Fr)",
            services: premiumServices
        )
    ]
}

public struct CalculationSettings: Codable, Hashable, Sendable {
    public var hourlyRate: Decimal
    public var internalHourlyCost: Decimal
    public var travelFlatFee: Decimal
    public var travelInternalCost: Decimal
    public var vatPercent: Decimal
    public var cableMetersPerCamera: Int
    public var defaultDiskSizeTB: Int
    public var storageSafetyMarginPercent: Int
    public var eventRecordingSharePercent: Int
    public var offerValidityDays: Int
    public var maintenancePackages: [MaintenancePackageConfig]

    public init(
        hourlyRate: Decimal = 125,
        internalHourlyCost: Decimal = 72,
        travelFlatFee: Decimal = 95,
        travelInternalCost: Decimal = 45,
        vatPercent: Decimal = CalculationSettings.swissVATPercent,
        cableMetersPerCamera: Int = 25,
        defaultDiskSizeTB: Int = 8,
        storageSafetyMarginPercent: Int = 20,
        eventRecordingSharePercent: Int = 30,
        offerValidityDays: Int = 30,
        maintenancePackages: [MaintenancePackageConfig] = MaintenancePackageConfig.defaults
    ) {
        self.hourlyRate = hourlyRate
        self.internalHourlyCost = internalHourlyCost
        self.travelFlatFee = travelFlatFee
        self.travelInternalCost = travelInternalCost
        self.vatPercent = vatPercent
        self.cableMetersPerCamera = cableMetersPerCamera
        self.defaultDiskSizeTB = defaultDiskSizeTB
        self.storageSafetyMarginPercent = storageSafetyMarginPercent
        self.eventRecordingSharePercent = eventRecordingSharePercent
        self.offerValidityDays = offerValidityDays
        self.maintenancePackages = maintenancePackages
    }

    /// Normalsatz MWST Schweiz seit 1.1.2024.
    public static let swissVATPercent: Decimal = Money.percent(tenths: 81)

    public func maintenanceConfig(for package: MaintenancePackage) -> MaintenancePackageConfig {
        maintenancePackages.first { $0.package == package }
            ?? MaintenancePackageConfig.defaults.first { $0.package == package }!
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var company: CompanyProfile
    public var calculation: CalculationSettings

    public init(company: CompanyProfile = CompanyProfile(), calculation: CalculationSettings = CalculationSettings()) {
        self.company = company
        self.calculation = calculation
    }
}
