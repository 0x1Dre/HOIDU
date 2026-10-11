import Foundation
import Observation
import CCTVCore

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard, projects, newProject, priceLists, manufacturers, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .projects: "Projekte"
        case .newProject: "Neues Projekt"
        case .priceLists: "Preislisten"
        case .manufacturers: "Herstellerprofile"
        case .settings: "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .projects: "folder"
        case .newProject: "plus.rectangle.on.folder"
        case .priceLists: "list.bullet.rectangle"
        case .manufacturers: "building.2"
        case .settings: "gearshape"
        }
    }
}

struct ProjectRoute: Hashable {
    let id: UUID
}

@MainActor
@Observable
final class AppRouter {
    var section: AppSection = .dashboard
    var projectPath: [ProjectRoute] = []
    var pendingProjectDeletion: UUID?
    var newProjectWizard: WizardViewModel

    init() {
        if let restored = DraftStore.load() {
            newProjectWizard = WizardViewModel(draft: restored, mode: .create, wasRestored: true)
        } else {
            newProjectWizard = WizardViewModel(draft: .newDraft(), mode: .create)
        }
    }

    func openProject(_ id: UUID) {
        section = .projects
        projectPath = [ProjectRoute(id: id)]
    }

    func startNewProject() {
        section = .newProject
    }

    func resetNewProject() {
        DraftStore.clear()
        newProjectWizard = WizardViewModel(draft: .newDraft(), mode: .create)
    }

    func persistDraft() {
        let draft = newProjectWizard.draft
        if newProjectWizard.hasContent {
            DraftStore.save(draft)
        }
    }
}

extension ProjectRecord {
    static func newDraft() -> ProjectRecord {
        ProjectRecord(surveyDate: Date(), status: .entwurf)
    }
}
