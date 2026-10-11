import Foundation
import Observation
import CCTVCore

@MainActor
@Observable
final class ProjectDetailViewModel {
    var record: ProjectRecord
    private(set) var analysis: OfferAnalysis?
    var errorMessage: String?

    init(record: ProjectRecord) {
        self.record = record
    }

    func recalculate(catalog: ProductCatalog, settings: CalculationSettings) {
        analysis = OfferVariantBuilder.analyze(project: record, catalog: catalog, settings: settings)
    }

    func persist(using repository: ProjectRepository, catalog: ProductCatalog, settings: CalculationSettings) {
        do {
            try repository.save(record)
            recalculate(catalog: catalog, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var storageInput: StorageInput {
        let variant = analysis?.recommendedVariant
        return StorageInput(
            cameras: max(1, variant?.selection.cameraCount ?? record.totalCameras),
            megapixels: max(1, variant?.selection.averageMegapixels ?? 4),
            framesPerSecond: record.recording.framesPerSecond,
            codec: record.recording.codec,
            mode: record.recording.mode,
            eventSharePercent: Double(analysis?.settings.eventRecordingSharePercent ?? 30),
            scheduleHoursPerDay: Double(record.recording.scheduleHoursPerDay),
            retentionDays: record.recording.retentionDays,
            safetyMarginPercent: Double(analysis?.settings.storageSafetyMarginPercent ?? 20),
            diskSizeTB: variant?.selection.storage?.diskSizeTB ?? (analysis?.settings.defaultDiskSizeTB ?? 8)
        )
    }
}
