import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CCTVCore

struct ProjectListView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router

    @State private var searchText = ""
    @State private var statusFilter: ProjectStatus?
    @State private var isImporting = false
    @State private var pendingDelete: Project?
    @State private var alert: AlertMessage?

    private var filtered: [Project] {
        projects.filter { project in
            if let statusFilter, project.status != statusFilter { return false }
            let query = searchText.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return true }
            return [project.reference, project.customerName, project.siteCity, project.siteStreet]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { project in
                NavigationLink(value: ProjectRoute(id: project.id)) {
                    ProjectRow(project: project)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = project
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                    Button {
                        duplicate(project)
                    } label: {
                        Label("Duplizieren", systemImage: "plus.square.on.square")
                    }
                    .tint(Theme.anthrazitSolid)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Projekte", systemImage: "folder.badge.plus")
                } description: {
                    Text("Starten Sie die Bedarfsaufnahme mit «Neues Projekt» oder importieren Sie eine Projektdatei.")
                } actions: {
                    Button("Neues Projekt") { router.startNewProject() }
                        .buttonStyle(.primaryAction)
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Projekt, Kunde oder Ort suchen")
        .navigationTitle("Projekte")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("Alle").tag(ProjectStatus?.none)
                        ForEach(ProjectStatus.allCases) { status in
                            Text(status.label).tag(ProjectStatus?.some(status))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: statusFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
                Button {
                    isImporting = true
                } label: {
                    Label("Importieren", systemImage: "square.and.arrow.down")
                }
                Button {
                    router.startNewProject()
                } label: {
                    Label("Neues Projekt", systemImage: "plus")
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            importProject(result)
        }
        .task(id: router.pendingProjectDeletion) {
            guard let id = router.pendingProjectDeletion else { return }
            try? await Task.sleep(for: .milliseconds(400))
            if let project = repository.project(id: id) {
                delete(project)
            }
            router.pendingProjectDeletion = nil
        }
        .confirmationDialog(
            "Projekt löschen?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { project in
            Button("«\(project.displayTitle)» löschen", role: .destructive) { delete(project) }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Das Projekt mit allen Bereichen, Fotos und Offerten wird endgültig von diesem Gerät entfernt.")
        }
        .messageAlert($alert)
    }

    private var repository: ProjectRepository { ProjectRepository(context: modelContext) }

    private func duplicate(_ project: Project) {
        do {
            let copy = try repository.duplicate(project)
            router.openProject(copy.id)
        } catch {
            alert = AlertMessage(title: "Duplizieren fehlgeschlagen", text: error.localizedDescription)
        }
    }

    private func delete(_ project: Project) {
        do {
            try repository.delete(project)
        } catch {
            alert = AlertMessage(title: "Löschen fehlgeschlagen", text: error.localizedDescription)
        }
    }

    private func importProject(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let project = try repository.importProject(from: data)
            alert = AlertMessage(title: "Projekt importiert", text: "«\(project.displayTitle)» wurde übernommen.")
        } catch {
            alert = AlertMessage(title: "Import fehlgeschlagen", text: error.localizedDescription)
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: project.objectType.systemImage)
                .font(.brand(.title2))
                .foregroundStyle(Theme.gruen)
                .frame(width: 40, height: 40)
                .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.displayTitle)
                        .font(.brand(.headline))
                        .lineLimit(2)
                    if project.isDemo {
                        Text("Demo")
                            .font(.brand(.caption2).weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.grau.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                            .foregroundStyle(Theme.grau)
                    }
                }
                Text([project.customerName, project.siteCity].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    StatusBadge(status: project.status)
                    Label("\(project.totalCameras)", systemImage: "video")
                        .accessibilityLabel("\(project.totalCameras) Kameras")
                    if let offer = project.latestOffer {
                        Text(Format.chf(offer.recommendedTotal))
                            .monospacedDigit()
                    }
                    Text(project.updatedAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.brand(.caption))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

extension ObjectType {
    var systemImage: String {
        switch self {
        case .eigenheim: "house"
        case .mehrfamilienhaus: "building"
        case .laden: "storefront"
        case .buero: "briefcase"
        case .lager: "shippingbox"
        case .werkstatt: "wrench.and.screwdriver"
        case .baustelle: "hammer"
        case .sonstiges: "mappin.circle"
        }
    }
}

/// Lädt ein Projekt anhand der ID für die Navigation.
struct ProjectDetailLoader: View {
    @Query private var projects: [Project]

    init(id: UUID) {
        _projects = Query(filter: #Predicate<Project> { $0.id == id })
    }

    var body: some View {
        if let project = projects.first {
            ProjectDetailView(project: project)
        } else {
            ContentUnavailableView("Projekt nicht gefunden", systemImage: "questionmark.folder", description: Text("Das Projekt wurde gelöscht oder ist nicht mehr verfügbar."))
        }
    }
}
