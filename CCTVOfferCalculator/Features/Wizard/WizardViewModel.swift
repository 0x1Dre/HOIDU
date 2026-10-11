import Foundation
import Observation
import CCTVCore

@MainActor
@Observable
final class WizardViewModel {
    enum Mode {
        case create
        case edit
    }

    var draft: ProjectRecord
    var step: WizardStep = .kunde
    private(set) var furthestStep: WizardStep = .kunde
    var issues: [ValidationIssue] = []
    private(set) var analysis: OfferAnalysis?
    let mode: Mode
    var wasRestored: Bool

    init(draft: ProjectRecord, mode: Mode, wasRestored: Bool = false, startAt step: WizardStep = .kunde) {
        self.draft = draft
        self.mode = mode
        self.wasRestored = wasRestored
        self.step = step
        self.furthestStep = mode == .edit ? .empfehlung : step
    }

    var progress: Double {
        Double(step.rawValue) / Double(WizardStep.allCases.count)
    }

    var hasContent: Bool {
        !draft.reference.isEmpty || !draft.customer.company.isEmpty || !draft.customer.contactPerson.isEmpty || !draft.areas.isEmpty
    }

    var isLastStep: Bool { step == .empfehlung }

    func message(for field: String) -> String? {
        issues.first { $0.field == field }?.message
    }

    func issues(for step: WizardStep) -> [ValidationIssue] {
        issues.filter { $0.step == step }
    }

    @discardableResult
    func validateCurrentStep() -> Bool {
        let stepIssues = ProjectValidator.validate(draft, step: step)
        issues = issues.filter { $0.step != step } + stepIssues
        return stepIssues.isEmpty
    }

    func next() {
        guard validateCurrentStep(), let following = WizardStep(rawValue: step.rawValue + 1) else { return }
        step = following
        furthestStep = max(furthestStep, following)
        if mode == .create { DraftStore.save(draft) }
    }

    func back() {
        guard let previous = WizardStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func canJump(to target: WizardStep) -> Bool {
        target <= furthestStep
    }

    func jump(to target: WizardStep) {
        guard canJump(to: target) else { return }
        if target > step && !validateCurrentStep() { return }
        step = target
    }

    func refreshAnalysis(catalog: ProductCatalog, settings: CalculationSettings) {
        analysis = OfferVariantBuilder.analyze(project: draft, catalog: catalog, settings: settings)
    }

    /// Prüft alle Schritte. Bei Fehlern wird zum ersten fehlerhaften Schritt gewechselt.
    func finalizedRecord() -> ProjectRecord? {
        let all = ProjectValidator.validate(draft)
        issues = all
        if let firstStep = all.map(\.step).min() {
            step = firstStep
            return nil
        }
        var record = draft
        if record.status == .entwurf {
            record.status = .erfasst
        }
        return record
    }

    // MARK: - Bereiche

    func upsertArea(_ area: SiteAreaRecord) {
        if let index = draft.areas.firstIndex(where: { $0.id == area.id }) {
            draft.areas[index] = area
        } else {
            draft.areas.append(area)
        }
        if !issues(for: .bereiche).isEmpty { validateCurrentStep() }
    }

    func deleteAreas(at offsets: IndexSet) {
        draft.areas.remove(atOffsets: offsets)
    }

    func duplicateArea(_ area: SiteAreaRecord) {
        var copy = area
        copy.id = UUID()
        copy.name = area.name + " (Kopie)"
        copy.photos = []
        copy.positions = []
        draft.areas.append(copy)
    }

    func moveAreas(from source: IndexSet, to destination: Int) {
        draft.areas.move(fromOffsets: source, toOffset: destination)
    }
}
