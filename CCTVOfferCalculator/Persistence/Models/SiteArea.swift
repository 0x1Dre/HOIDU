import Foundation
import SwiftData
import CCTVCore

@Model
final class SiteArea {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var name: String = ""
    var locationRaw: String = AreaLocation.aussen.rawValue
    var purposesRaw: [String] = []
    var detectionTargetRaw: String = DetectionTarget.person.rawValue
    var nightVisionRaw: String = NightVision.infrarot.rawValue
    var audioRaw: String = AudioMode.nein.rawValue
    var notes: String = ""
    var project: Project?
    @Relationship(deleteRule: .cascade, inverse: \CameraRequirement.area)
    var cameraRequirement: CameraRequirement?
    @Relationship(deleteRule: .cascade, inverse: \CameraPosition.area)
    var positions: [CameraPosition] = []
    @Relationship(deleteRule: .cascade, inverse: \PhotoAttachment.area)
    var photos: [PhotoAttachment] = []

    init(id: UUID) {
        self.id = id
    }

    var record: SiteAreaRecord {
        SiteAreaRecord(
            id: id,
            name: name,
            location: AreaLocation(rawValue: locationRaw) ?? .aussen,
            purposes: Set(purposesRaw.compactMap(AreaPurpose.init(rawValue:))),
            detectionTarget: DetectionTarget(rawValue: detectionTargetRaw) ?? .person,
            nightVision: NightVision(rawValue: nightVisionRaw) ?? .infrarot,
            audio: AudioMode(rawValue: audioRaw) ?? .nein,
            camera: cameraRequirement?.record ?? CameraRequirementRecord(),
            photos: photos.sorted { $0.sortIndex < $1.sortIndex }.map(\.record),
            positions: positions.sorted { $0.sortIndex < $1.sortIndex }.map(\.record),
            notes: notes
        )
    }

    func apply(_ record: SiteAreaRecord, index: Int, context: ModelContext) {
        sortIndex = index
        name = record.name
        locationRaw = record.location.rawValue
        purposesRaw = record.purposes.ordered.map(\.rawValue)
        detectionTargetRaw = record.detectionTarget.rawValue
        nightVisionRaw = record.nightVision.rawValue
        audioRaw = record.audio.rawValue
        notes = record.notes

        if cameraRequirement == nil {
            let requirement = CameraRequirement()
            context.insert(requirement)
            cameraRequirement = requirement
        }
        cameraRequirement?.apply(record.camera)

        positions = ModelSync.sync(
            positions, with: record.positions, context: context,
            id: { $0.id },
            create: { CameraPosition(id: $0.id) },
            update: { model, position, index in model.apply(position, index: index, context: context) }
        )
        photos = ModelSync.sync(
            photos, with: record.photos, context: context,
            id: { $0.id },
            create: { PhotoAttachment(id: $0.id) },
            update: { model, photo, index in model.apply(photo, index: index) }
        )
    }
}
