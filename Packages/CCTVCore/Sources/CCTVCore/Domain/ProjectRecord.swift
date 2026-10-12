import Foundation

public struct CustomerRecord: Codable, Hashable, Sendable {
    public var company: String
    public var contactPerson: String
    public var phone: String
    public var email: String

    public init(company: String = "", contactPerson: String = "", phone: String = "", email: String = "") {
        self.company = company
        self.contactPerson = contactPerson
        self.phone = phone
        self.email = email
    }

    public var displayName: String {
        let company = company.trimmingCharacters(in: .whitespaces)
        let contact = contactPerson.trimmingCharacters(in: .whitespaces)
        if !company.isEmpty { return company }
        if !contact.isEmpty { return contact }
        return "Ohne Kundenangabe"
    }
}

public struct CameraRequirementRecord: Codable, Hashable, Sendable {
    public var quantity: Int
    public var formFactor: CameraFormFactor
    /// 0 bedeutet: aus dem Erkennungsziel ableiten.
    public var preferredMegapixels: Int
    public var distanceMeters: Int

    public init(quantity: Int = 1, formFactor: CameraFormFactor = .automatisch, preferredMegapixels: Int = 0, distanceMeters: Int = 10) {
        self.quantity = quantity
        self.formFactor = formFactor
        self.preferredMegapixels = preferredMegapixels
        self.distanceMeters = distanceMeters
    }
}

public enum PhotoMarkerKind: String, LabeledOption {
    case pfeil, kreis

    public var label: String {
        switch self {
        case .pfeil: "Pfeil (Blickrichtung)"
        case .kreis: "Kreis (Montagepunkt)"
        }
    }
}

/// Markierung auf einem Foto. Koordinaten sind relativ zur Bildgrösse (0…1),
/// damit sie unabhängig von Auflösung und Darstellung bleiben. Das Originalbild wird nicht verändert.
public struct PhotoMarker: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: PhotoMarkerKind
    public var startX: Double
    public var startY: Double
    /// Pfeilspitze bzw. Randpunkt des Kreises.
    public var endX: Double
    public var endY: Double

    public init(id: UUID = UUID(), kind: PhotoMarkerKind, startX: Double, startY: Double, endX: Double, endY: Double) {
        self.id = id
        self.kind = kind
        self.startX = PhotoMarker.clamp(startX)
        self.startY = PhotoMarker.clamp(startY)
        self.endX = PhotoMarker.clamp(endX)
        self.endY = PhotoMarker.clamp(endY)
    }

    public static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    /// Kreisradius relativ zur Bildbreite.
    public var radius: Double {
        let dx = endX - startX
        let dy = endY - startY
        return (dx * dx + dy * dy).squareRoot()
    }
}

public struct PhotoRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var caption: String
    public var note: String
    public var capturedAt: Date
    /// JPEG, verkleinert. Im JSON-Export als Base64 eingebettet.
    public var imageData: Data?
    public var markers: [PhotoMarker]
    public var includeInCustomerPDF: Bool

    public init(
        id: UUID = UUID(),
        caption: String = "",
        note: String = "",
        capturedAt: Date = Date(),
        imageData: Data? = nil,
        markers: [PhotoMarker] = [],
        includeInCustomerPDF: Bool = true
    ) {
        self.id = id
        self.caption = caption
        self.note = note
        self.capturedAt = capturedAt
        self.imageData = imageData
        self.markers = markers
        self.includeInCustomerPDF = includeInCustomerPDF
    }

    enum CodingKeys: String, CodingKey {
        case id, caption, note, capturedAt, imageData, markers, includeInCustomerPDF
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        caption = try c.decodeIfPresent(String.self, forKey: .caption) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        capturedAt = try c.decodeIfPresent(Date.self, forKey: .capturedAt) ?? Date()
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        markers = try c.decodeIfPresent([PhotoMarker].self, forKey: .markers) ?? []
        includeInCustomerPDF = try c.decodeIfPresent(Bool.self, forKey: .includeInCustomerPDF) ?? true
    }
}

/// Konkrete Montageposition einer Kamera innerhalb eines Bereichs (z. B. «Kamera 1 – Nordfassade»).
public struct CameraPositionRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var label: String
    public var mountingHeight: String
    public var viewDirection: String
    public var note: String
    public var photos: [PhotoRecord]

    public init(
        id: UUID = UUID(),
        label: String = "",
        mountingHeight: String = "",
        viewDirection: String = "",
        note: String = "",
        photos: [PhotoRecord] = []
    ) {
        self.id = id
        self.label = label
        self.mountingHeight = mountingHeight
        self.viewDirection = viewDirection
        self.note = note
        self.photos = photos
    }

    public var detailLines: [String] {
        [
            mountingHeight.isEmpty ? nil : "Montagehöhe: \(mountingHeight)",
            viewDirection.isEmpty ? nil : "Blickrichtung: \(viewDirection)",
            note.isEmpty ? nil : note
        ].compactMap { $0 }
    }
}

public struct SiteAreaRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var location: AreaLocation
    public var purposes: Set<AreaPurpose>
    public var detectionTarget: DetectionTarget
    public var nightVision: NightVision
    public var audio: AudioMode
    public var camera: CameraRequirementRecord
    public var photos: [PhotoRecord]
    public var positions: [CameraPositionRecord]
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String = "",
        location: AreaLocation = .aussen,
        purposes: Set<AreaPurpose> = [.abschreckung],
        detectionTarget: DetectionTarget = .person,
        nightVision: NightVision = .infrarot,
        audio: AudioMode = .nein,
        camera: CameraRequirementRecord = CameraRequirementRecord(),
        photos: [PhotoRecord] = [],
        positions: [CameraPositionRecord] = [],
        notes: String = ""
    ) {
        self.positions = positions
        self.id = id
        self.name = name
        self.location = location
        self.purposes = purposes
        self.detectionTarget = detectionTarget
        self.nightVision = nightVision
        self.audio = audio
        self.camera = camera
        self.photos = photos
        self.notes = notes
    }

    public var requiredMegapixels: Int {
        max(camera.preferredMegapixels, detectionTarget.minimumMegapixels)
    }

    public var allPhotos: [PhotoRecord] {
        photos + positions.flatMap(\.photos)
    }

    /// Vorschlag für die Beschriftung der nächsten Kameraposition.
    public var nextPositionLabel: String {
        let base = "Kamera \(positions.count + 1)"
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? base : "\(base) – \(trimmed)"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, location, purposes, detectionTarget, nightVision, audio, camera, photos, positions, notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        location = try c.decode(AreaLocation.self, forKey: .location)
        purposes = try c.decode(Set<AreaPurpose>.self, forKey: .purposes)
        detectionTarget = try c.decode(DetectionTarget.self, forKey: .detectionTarget)
        nightVision = try c.decode(NightVision.self, forKey: .nightVision)
        audio = try c.decode(AudioMode.self, forKey: .audio)
        camera = try c.decode(CameraRequirementRecord.self, forKey: .camera)
        photos = try c.decodeIfPresent([PhotoRecord].self, forKey: .photos) ?? []
        positions = try c.decodeIfPresent([CameraPositionRecord].self, forKey: .positions) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

public struct InfrastructureRecord: Codable, Hashable, Sendable {
    public var cabling: CablingStatus
    public var power: Clarification
    public var internet: Clarification
    public var connection: ConnectionType
    public var mountingAccess: MountingAccess
    public var lighting: LightingCondition
    public var existing: Set<InfrastructureItem>
    public var existingCameras: String
    public var privacyReviewRequired: Bool
    public var publicAreaAffected: Bool
    public var employeesAffected: Bool
    public var neighborPropertyAffected: Bool

    public init(
        cabling: CablingStatus = .unklar,
        power: Clarification = .abzuklaeren,
        internet: Clarification = .abzuklaeren,
        connection: ConnectionType = .poeLan,
        mountingAccess: MountingAccess = .leiter,
        lighting: LightingCondition = .schwach,
        existing: Set<InfrastructureItem> = [],
        existingCameras: String = "",
        privacyReviewRequired: Bool = false,
        publicAreaAffected: Bool = false,
        employeesAffected: Bool = false,
        neighborPropertyAffected: Bool = false
    ) {
        self.cabling = cabling
        self.power = power
        self.internet = internet
        self.connection = connection
        self.mountingAccess = mountingAccess
        self.lighting = lighting
        self.existing = existing
        self.existingCameras = existingCameras
        self.privacyReviewRequired = privacyReviewRequired
        self.publicAreaAffected = publicAreaAffected
        self.employeesAffected = employeesAffected
        self.neighborPropertyAffected = neighborPropertyAffected
    }
}

public struct RecordingRecord: Codable, Hashable, Sendable {
    public static let retentionPresets = [7, 14, 30, 60, 90]

    public var mode: RecordingMode
    public var scheduleHoursPerDay: Int
    public var retentionDays: Int
    public var userCount: Int
    public var access: Set<AccessChannel>
    public var features: Set<SystemFeature>
    public var tier: SystemTier
    public var multiSite: Bool
    public var highCybersecurity: Bool
    public var thirdPartyIntegration: Bool
    public var framesPerSecond: Int
    public var codec: VideoCodec

    public init(
        mode: RecordingMode = .ereignis,
        scheduleHoursPerDay: Int = 12,
        retentionDays: Int = 14,
        userCount: Int = 2,
        access: Set<AccessChannel> = [.smartphone],
        features: Set<SystemFeature> = [.pushMeldungen],
        tier: SystemTier = .offen,
        multiSite: Bool = false,
        highCybersecurity: Bool = false,
        thirdPartyIntegration: Bool = false,
        framesPerSecond: Int = 15,
        codec: VideoCodec = .h265
    ) {
        self.mode = mode
        self.scheduleHoursPerDay = scheduleHoursPerDay
        self.retentionDays = retentionDays
        self.userCount = userCount
        self.access = access
        self.features = features
        self.tier = tier
        self.multiSite = multiSite
        self.highCybersecurity = highCybersecurity
        self.thirdPartyIntegration = thirdPartyIntegration
        self.framesPerSecond = framesPerSecond
        self.codec = codec
    }
}

/// Vom Anwender gewählter Hersteller je Variante (überschreibt die automatische Wahl).
public struct VariantSelection: Codable, Hashable, Sendable {
    public var budget: Manufacturer?
    public var standard: Manufacturer?
    public var premium: Manufacturer?

    public init(budget: Manufacturer? = nil, standard: Manufacturer? = nil, premium: Manufacturer? = nil) {
        self.budget = budget
        self.standard = standard
        self.premium = premium
    }

    public subscript(tier: OfferTier) -> Manufacturer? {
        get {
            switch tier {
            case .budget: budget
            case .standard: standard
            case .premium: premium
            }
        }
        set {
            switch tier {
            case .budget: budget = newValue
            case .standard: standard = newValue
            case .premium: premium = newValue
            }
        }
    }
}

public struct MaintenanceSelection: Codable, Hashable, Sendable {
    public var package: MaintenancePackage?
    public var includeOnSiteCheck: Bool

    public init(package: MaintenancePackage? = .business, includeOnSiteCheck: Bool = false) {
        self.package = package
        self.includeOnSiteCheck = includeOnSiteCheck
    }
}

public struct ProjectRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var reference: String
    public var surveyDate: Date
    public var objectType: ObjectType
    public var siteStreet: String
    public var sitePostalCode: String
    public var siteCity: String
    public var notes: String
    public var customer: CustomerRecord
    public var areas: [SiteAreaRecord]
    public var infrastructure: InfrastructureRecord
    public var recording: RecordingRecord
    public var maintenance: MaintenanceSelection
    public var variantSelection: VariantSelection
    public var discountPercent: Decimal
    public var status: ProjectStatus
    public var isDemo: Bool
    public var createdAt: Date
    public var updatedAt: Date
    /// 3D-Scans mit platzierten Kameras.
    public var scans: [SiteScanRecord]

    public init(
        id: UUID = UUID(),
        reference: String = "",
        surveyDate: Date = Date(),
        objectType: ObjectType = .eigenheim,
        siteStreet: String = "",
        sitePostalCode: String = "",
        siteCity: String = "",
        notes: String = "",
        customer: CustomerRecord = CustomerRecord(),
        areas: [SiteAreaRecord] = [],
        infrastructure: InfrastructureRecord = InfrastructureRecord(),
        recording: RecordingRecord = RecordingRecord(),
        maintenance: MaintenanceSelection = MaintenanceSelection(),
        variantSelection: VariantSelection = VariantSelection(),
        discountPercent: Decimal = 0,
        status: ProjectStatus = .entwurf,
        isDemo: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        scans: [SiteScanRecord] = []
    ) {
        self.id = id
        self.reference = reference
        self.surveyDate = surveyDate
        self.objectType = objectType
        self.siteStreet = siteStreet
        self.sitePostalCode = sitePostalCode
        self.siteCity = siteCity
        self.notes = notes
        self.customer = customer
        self.areas = areas
        self.infrastructure = infrastructure
        self.recording = recording
        self.maintenance = maintenance
        self.variantSelection = variantSelection
        self.discountPercent = discountPercent
        self.status = status
        self.isDemo = isDemo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scans = scans
    }

    enum CodingKeys: String, CodingKey {
        case id, reference, surveyDate, objectType, siteStreet, sitePostalCode, siteCity, notes, customer, areas
        case infrastructure, recording, maintenance, variantSelection, discountPercent, status, isDemo, createdAt, updatedAt, scans
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reference = try c.decode(String.self, forKey: .reference)
        surveyDate = try c.decode(Date.self, forKey: .surveyDate)
        objectType = try c.decode(ObjectType.self, forKey: .objectType)
        siteStreet = try c.decode(String.self, forKey: .siteStreet)
        sitePostalCode = try c.decode(String.self, forKey: .sitePostalCode)
        siteCity = try c.decode(String.self, forKey: .siteCity)
        notes = try c.decode(String.self, forKey: .notes)
        customer = try c.decode(CustomerRecord.self, forKey: .customer)
        areas = try c.decode([SiteAreaRecord].self, forKey: .areas)
        infrastructure = try c.decode(InfrastructureRecord.self, forKey: .infrastructure)
        recording = try c.decode(RecordingRecord.self, forKey: .recording)
        maintenance = try c.decode(MaintenanceSelection.self, forKey: .maintenance)
        variantSelection = try c.decode(VariantSelection.self, forKey: .variantSelection)
        discountPercent = try c.decode(Decimal.self, forKey: .discountPercent)
        status = try c.decode(ProjectStatus.self, forKey: .status)
        isDemo = try c.decode(Bool.self, forKey: .isDemo)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        // Neu ab Scan-Funktion: ältere Dateien enthalten keine Scans.
        scans = try c.decodeIfPresent([SiteScanRecord].self, forKey: .scans) ?? []
    }

    public var totalCameras: Int {
        areas.reduce(0) { $0 + max(0, $1.camera.quantity) }
    }

    public var photoCount: Int {
        areas.reduce(0) { $0 + $1.allPhotos.count }
    }

    /// Kopie ohne Bilddaten (z. B. für einen kompakten JSON-Export).
    public func strippingImageData() -> ProjectRecord {
        var copy = self
        copy.areas = areas.map { area in
            var area = area
            area.photos = area.photos.map { var p = $0; p.imageData = nil; return p }
            area.positions = area.positions.map { position in
                var position = position
                position.photos = position.photos.map { var p = $0; p.imageData = nil; return p }
                return position
            }
            return area
        }
        copy.scans = scans.map { scan in
            var scan = scan
            scan.modelData = nil
            scan.floorPlan = nil
            scan.photos = scan.photos.map { var p = $0; p.imageData = nil; return p }
            return scan
        }
        return copy
    }

    public var siteAddressLine: String {
        let cityLine = [sitePostalCode, siteCity]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [siteStreet.trimmingCharacters(in: .whitespaces), cityLine]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    public var displayTitle: String {
        let trimmed = reference.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Projekt ohne Referenz" : trimmed
    }
}
