import Foundation

public enum DocumentAudience: String, Codable, Hashable, Sendable {
    case customer
    case `internal`

    public var label: String {
        switch self {
        case .customer: "Kunden-PDF"
        case .internal: "Internes PDF"
        }
    }
}

public struct KeyValue: Hashable, Sendable {
    public var label: String
    public var value: String
    public var emphasized: Bool

    public init(_ label: String, _ value: String, emphasized: Bool = false) {
        self.label = label
        self.value = value
        self.emphasized = emphasized
    }
}

public enum ColumnAlignment: String, Hashable, Sendable {
    case leading, trailing
}

public struct DocumentColumn: Hashable, Sendable {
    public var title: String
    public var weight: Double
    public var alignment: ColumnAlignment

    public init(_ title: String, weight: Double = 1, alignment: ColumnAlignment = .leading) {
        self.title = title
        self.weight = weight
        self.alignment = alignment
    }
}

public struct DocumentTable: Hashable, Sendable {
    public var columns: [DocumentColumn]
    public var rows: [[String]]

    public init(columns: [DocumentColumn], rows: [[String]]) {
        self.columns = columns
        self.rows = rows
    }
}

public struct DocumentPhoto: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var details: [String]
    public var imageData: Data
    public var markers: [PhotoMarker]
}

/// Kamera im Grundriss: Nummer, Lage und Blickfeld.
public struct DocumentFloorPlanMarker: Hashable, Sendable {
    public var number: Int
    public var label: String
    public var x: Double
    public var z: Double
    public var yawDegrees: Double
    public var fieldOfViewDegrees: Double
    public var rangeMeters: Double

    public init(number: Int, label: String, placement: ScanCameraPlacement) {
        self.number = number
        self.label = label
        self.x = placement.x
        self.z = placement.z
        self.yawDegrees = placement.yawDegrees
        self.fieldOfViewDegrees = placement.fieldOfViewDegrees
        self.rangeMeters = placement.rangeMeters
    }
}

/// Grundriss (Draufsicht eines 3D-Scans) mit eingezeichneten Kameras.
public struct DocumentFloorPlan: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var details: [String]
    public var imageData: Data
    public var bounds: ScanBounds
    public var markers: [DocumentFloorPlanMarker]

    public init(id: UUID, title: String, details: [String], imageData: Data, bounds: ScanBounds, markers: [DocumentFloorPlanMarker]) {
        self.id = id
        self.title = title
        self.details = details
        self.imageData = imageData
        self.bounds = bounds
        self.markers = markers
    }
}

public enum DocumentBlock: Hashable, Sendable {
    case paragraph(String)
    case bullets([String])
    case keyValues([KeyValue])
    case table(DocumentTable)
    case notice(title: String, text: String, severity: WarningSeverity)
    case photos([DocumentPhoto])
    case floorPlan(DocumentFloorPlan)
}

public struct DocumentSection: Hashable, Sendable {
    public var title: String
    public var blocks: [DocumentBlock]
    public var startsOnNewPage: Bool

    public init(title: String, blocks: [DocumentBlock], startsOnNewPage: Bool = false) {
        self.title = title
        self.blocks = blocks
        self.startsOnNewPage = startsOnNewPage
    }
}

public struct OfferDocument: Hashable, Sendable {
    public var audience: DocumentAudience
    public var title: String
    public var subtitle: String
    public var confidentialityNote: String?
    public var letterhead: [String]
    public var recipient: [String]
    public var meta: [KeyValue]
    public var sections: [DocumentSection]
    public var footer: String

    /// Gesamter Text des Dokuments (für Tests und Suche).
    public var plainText: String {
        var parts = [title, subtitle, confidentialityNote ?? "", footer] + letterhead + recipient
        parts += meta.flatMap { [$0.label, $0.value] }
        for section in sections {
            parts.append(section.title)
            for block in section.blocks {
                switch block {
                case .paragraph(let text): parts.append(text)
                case .bullets(let items): parts += items
                case .keyValues(let pairs): parts += pairs.flatMap { [$0.label, $0.value] }
                case .table(let table): parts += table.columns.map(\.title) + table.rows.flatMap { $0 }
                case .notice(let title, let text, _): parts += [title, text]
                case .photos(let photos): parts += photos.flatMap { [$0.title] + $0.details }
                case .floorPlan(let plan): parts += [plan.title] + plan.details + plan.markers.map(\.label)
                }
            }
        }
        return parts.joined(separator: "\n")
    }

    public var photoCount: Int {
        sections.flatMap(\.blocks).reduce(0) { count, block in
            if case .photos(let photos) = block { return count + photos.count }
            return count
        }
    }
}

public struct DocumentOptions: Hashable, Sendable {
    public var audience: DocumentAudience
    public var offerNumber: String
    public var offerDate: Date
    public var includePhotosInCustomerPDF: Bool
    public var appVersion: String

    public init(audience: DocumentAudience, offerNumber: String, offerDate: Date = Date(), includePhotosInCustomerPDF: Bool = false, appVersion: String = "1.0") {
        self.audience = audience
        self.offerNumber = offerNumber
        self.offerDate = offerDate
        self.includePhotosInCustomerPDF = includePhotosInCustomerPDF
        self.appVersion = appVersion
    }
}
