import SwiftUI
import SwiftData
import UIKit
import CCTVCore

extension WizardViewModel: Identifiable {}

enum ProjectDetailTab: String, CaseIterable, Identifiable {
    case empfehlung, varianten, vergleich, speicher, wartung, fotos, scans, export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .empfehlung: "Empfehlung"
        case .varianten: "Varianten"
        case .vergleich: "Vergleich"
        case .speicher: "Speicher"
        case .wartung: "Wartung"
        case .fotos: "Fotos"
        case .scans: "3D"
        case .export: "Export"
        }
    }

    var systemImage: String {
        switch self {
        case .empfehlung: "lightbulb"
        case .varianten: "square.stack.3d.up"
        case .vergleich: "tablecells"
        case .speicher: "externaldrive"
        case .wartung: "wrench.and.screwdriver"
        case .fotos: "photo.on.rectangle"
        case .scans: "cube.transparent"
        case .export: "square.and.arrow.up"
        }
    }
}

struct ProjectDetailView: View {
    let project: Project

    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ProjectDetailViewModel?
    @State private var tab: ProjectDetailTab = .empfehlung
    @State private var editWizard: WizardViewModel?
    @State private var confirmDelete = false
    @State private var alert: AlertMessage?

    private var repository: ProjectRepository { ProjectRepository(context: modelContext) }

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView("Projekt wird geladen …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(project.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: project.id) {
            let model = ProjectDetailViewModel(record: project.record)
            model.recalculate(catalog: repository.catalog(), settings: settings.calculation)
            viewModel = model
        }
        .onChange(of: settings.settings) { _, _ in
            viewModel?.recalculate(catalog: repository.catalog(), settings: settings.calculation)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    settings.internalMode.toggle()
                } label: {
                    Label(settings.internalMode ? "Interner Modus aktiv" : "Kundenansicht",
                          systemImage: settings.internalMode ? "eye.trianglebadge.exclamationmark" : "eye")
                }
                .accessibilityHint("Zeigt oder verbirgt Einkaufspreise und Margen")
                Button {
                    startEditing(at: .kunde)
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
                Menu {
                    if let viewModel {
                        Picker("Status", selection: Binding(
                            get: { viewModel.record.status },
                            set: { newValue in
                                viewModel.record.status = newValue
                                save()
                            }
                        )) {
                            ForEach(ProjectStatus.allCases) { status in
                                Text(status.label).tag(status)
                            }
                        }
                    }
                    Button {
                        duplicate()
                    } label: {
                        Label("Duplizieren", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Projekt löschen", systemImage: "trash")
                    }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(item: $editWizard) { wizard in
            NavigationStack {
                ProjectWizardView(
                    viewModel: wizard,
                    onSave: { record in
                        viewModel?.record = record
                        save()
                        editWizard = nil
                    },
                    onDiscard: { editWizard = nil }
                )
            }
        }
        .confirmationDialog("Projekt löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { delete() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Projekt mit allen Fotos und Offerten wird endgültig von diesem Gerät entfernt.")
        }
        .messageAlert($alert)
        .onChange(of: viewModel?.errorMessage) { _, message in
            if let message {
                alert = AlertMessage(title: "Speichern fehlgeschlagen", text: message)
                viewModel?.errorMessage = nil
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ProjectDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProjectHeaderCard(record: viewModel.record, latestOffer: project.latestOffer)
                PrivacyNoticeCard(compact: true)

                ProjectTabBar(selection: $tab)

                if let analysis = viewModel.analysis {
                    switch tab {
                    case .empfehlung: recommendation(analysis)
                    case .varianten: variants(analysis, viewModel: viewModel)
                    case .vergleich: comparison(analysis)
                    case .speicher: StorageSummaryView(input: viewModel.storageInput, result: analysis.recommendedVariant?.selection.storage)
                    case .wartung: maintenance(analysis, viewModel: viewModel)
                    case .fotos: ProjectPhotosOverview(record: viewModel.record) { startEditing(at: .bereiche) }
                    case .scans: scans(viewModel)
                    case .export: ExportPanel(project: project, record: viewModel.record, analysis: analysis)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func recommendation(_ analysis: OfferAnalysis) -> some View {
        if !analysis.isCalculable {
            ContentUnavailableView(
                "Keine Kalkulation möglich",
                systemImage: "exclamationmark.triangle",
                description: Text("Bitte mindestens einen Bereich mit Kameras erfassen.")
            )
        }
        TechnicalRecommendationCard(lines: analysis.technicalRecommendation)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
            ForEach(analysis.scores) { score in
                ScoreCardView(score: score, isRecommended: analysis.recommendedVariant?.manufacturer == score.manufacturer)
            }
        }
        WarningsCard(warnings: analysis.warnings)
    }

    @ViewBuilder
    private func variants(_ analysis: OfferAnalysis, viewModel: ProjectDetailViewModel) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
            ForEach(OfferTier.allCases) { tier in
                VStack(alignment: .leading, spacing: 10) {
                    if let variant = analysis.variant(tier) {
                        NavigationLink {
                            VariantDetailView(variant: variant, internalMode: settings.internalMode)
                        } label: {
                            VariantSummaryCard(variant: variant, isRecommended: tier == analysis.recommendedTier, internalMode: settings.internalMode)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Zeigt alle Positionen der Variante")
                    } else {
                        ContentUnavailableView("Keine Variante \(tier.label)", systemImage: "square.dashed")
                            .card()
                    }
                    Picker("Hersteller \(tier.label)", selection: Binding<Manufacturer?>(
                        get: { viewModel.record.variantSelection[tier] },
                        set: { value in
                            viewModel.record.variantSelection[tier] = value
                            save()
                        }
                    )) {
                        Text("Automatisch").tag(Manufacturer?.none)
                        ForEach(Manufacturer.scored) { manufacturer in
                            Text(manufacturer.label).tag(Manufacturer?.some(manufacturer))
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rabatt auf alle Varianten")
                Spacer()
                Text(Format.percent(viewModel.record.discountPercent))
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            Stepper(
                "Rabatt in 0.5-%-Schritten",
                value: Binding(
                    get: { viewModel.record.discountPercent.asDouble },
                    set: { value in
                        viewModel.record.discountPercent = Decimal(string: String(format: "%.1f", value)) ?? 0
                        save()
                    }
                ),
                in: 0...30,
                step: 0.5
            )
            .frame(minHeight: 44)
        }
        .card()
    }

    @ViewBuilder
    private func comparison(_ analysis: OfferAnalysis) -> some View {
        SectionHeader(title: "Vergleich nach Hersteller", subtitle: "Einmalkosten inkl. MWST; fett = gewählte Variante", systemImage: "tablecells")
        ComparisonTableView(analysis: analysis, internalMode: settings.internalMode)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
            ForEach(analysis.scores) { score in
                ScoreCardView(score: score)
            }
        }
    }

    @ViewBuilder
    private func maintenance(_ analysis: OfferAnalysis, viewModel: ProjectDetailViewModel) -> some View {
        MaintenanceOptionsView(
            quotes: analysis.maintenanceQuotes,
            selection: Binding(
                get: { viewModel.record.maintenance },
                set: { value in
                    viewModel.record.maintenance = value
                    save()
                }
            )
        )
        if let quote = analysis.recommendedVariant?.maintenance {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Berechnung \(quote.package.label)", systemImage: "function")
                LabeledValueRow(label: "Grundgebühr", value: Format.chf(quote.monthlyBaseFee))
                LabeledValueRow(label: "\(quote.cameras) Kameras", value: Format.chf(quote.monthlyCameraFee))
                LabeledValueRow(label: "\(quote.recorders) Rekorder/VMS", value: Format.chf(quote.monthlyRecorderFee))
                if quote.monthlyOnSiteShare > 0 {
                    LabeledValueRow(label: "Anteil Vor-Ort-Check", value: Format.chf(quote.monthlyOnSiteShare))
                }
                Divider()
                LabeledValueRow(label: "Total pro Monat exkl. MWST", value: Format.chf(quote.monthlyNet), emphasized: true)
                LabeledValueRow(label: "Total pro Jahr exkl. MWST", value: Format.chf(quote.yearlyNet))
                LabeledValueRow(label: "Total pro Jahr inkl. MWST", value: Format.chf(quote.yearlyInclVAT))
            }
            .card()
        }
    }

    private func scans(_ viewModel: ProjectDetailViewModel) -> some View {
        ProjectScansView(
            record: viewModel.record,
            onAdd: { scan in
                viewModel.record.scans.append(scan)
                save()
            },
            onUpdate: { id, edits in
                guard let index = viewModel.record.scans.firstIndex(where: { $0.id == id }) else { return }
                var scan = viewModel.record.scans[index]
                let current = ScanEdits(name: scan.name, note: scan.note, placements: scan.placements,
                                        photos: scan.photos, photoPoses: scan.photoPoses, areaID: scan.areaID)
                guard current != edits else { return }
                scan.name = edits.name
                scan.note = edits.note
                scan.placements = edits.placements
                scan.photos = edits.photos
                scan.photoPoses = edits.photoPoses
                scan.areaID = edits.areaID
                viewModel.record.scans[index] = scan
                save()
            },
            onDelete: { id in
                viewModel.record.scans.removeAll { $0.id == id }
                save()
            }
        )
    }

    // MARK: - Aktionen

    private func startEditing(at step: WizardStep) {
        guard let record = viewModel?.record else { return }
        editWizard = WizardViewModel(draft: record, mode: .edit, startAt: step)
    }

    private func save() {
        viewModel?.persist(using: repository, catalog: repository.catalog(), settings: settings.calculation)
    }

    private func duplicate() {
        do {
            let copy = try repository.duplicate(project)
            router.openProject(copy.id)
        } catch {
            alert = AlertMessage(title: "Duplizieren fehlgeschlagen", text: error.localizedDescription)
        }
    }

    /// Navigiert zuerst zurück; die Projektliste löscht danach, damit keine Ansicht mehr auf das gelöschte Modell zugreift.
    private func delete() {
        router.pendingProjectDeletion = project.id
        router.projectPath.removeAll()
    }
}

struct ProjectHeaderCard: View {
    let record: ProjectRecord
    let latestOffer: Offer?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                details
                Spacer()
                summary
            }
            VStack(alignment: .leading, spacing: 12) {
                details
                summary
            }
        }
        .card()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                StatusBadge(status: record.status)
                if record.isDemo {
                    Text("Demo-Projekt").font(.brand(.caption)).foregroundStyle(Theme.grau)
                }
            }
            Text(record.customer.displayName)
                .font(.brand(.title2).weight(.semibold))
            if !record.customer.contactPerson.isEmpty && !record.customer.company.isEmpty {
                Text(record.customer.contactPerson).foregroundStyle(.secondary)
            }
            Text([record.objectType.label, record.siteAddressLine].filter { !$0.isEmpty }.joined(separator: " · "))
                .foregroundStyle(.secondary)
            Text("Begehung \(Format.date(record.surveyDate))")
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)
        }
    }

    private var summary: some View {
        HStack(spacing: 20) {
            metric("\(record.areas.count)", "Bereiche")
            metric("\(record.totalCameras)", "Kameras")
            metric("\(record.photoCount)", "Fotos")
            if let latestOffer {
                metric(latestOffer.number, "Letzte Offerte")
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.brand(.title3).weight(.semibold)).monospacedDigit()
            Text(label).font(.brand(.caption)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Übersicht aller Kamerapositionen und Fotos eines Projekts.
struct ProjectPhotosOverview: View {
    let record: ProjectRecord
    let onEdit: () -> Void

    @State private var selected: PhotoRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Kamerapositionen und Fotos", subtitle: "\(record.photoCount) Fotos in \(record.areas.count) Bereichen", systemImage: "camera")
                Button {
                    onEdit()
                } label: {
                    Label("Fotos erfassen", systemImage: "camera.fill")
                }
                .buttonStyle(.primaryAction)
            }
            if record.photoCount == 0 && !record.areas.contains(where: { !$0.positions.isEmpty }) {
                ContentUnavailableView("Noch keine Fotos", systemImage: "camera.viewfinder",
                                       description: Text("Im Schritt «Überwachungsbereiche» können pro Bereich und Kameraposition Fotos aufgenommen werden."))
            }
            ForEach(record.areas) { area in
                if !area.allPhotos.isEmpty || !area.positions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(area.name).font(.brand(.headline))
                        if !area.photos.isEmpty {
                            photoStrip(area.photos, title: "Übersicht")
                        }
                        ForEach(area.positions) { position in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(position.label).font(.brand(.subheadline).weight(.semibold))
                                if !position.detailLines.isEmpty {
                                    Text(position.detailLines.joined(separator: " · "))
                                        .font(.brand(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                photoStrip(position.photos, title: nil)
                            }
                        }
                    }
                    .card()
                }
            }
        }
        .sheet(item: $selected) { photo in
            NavigationStack {
                PhotoViewer(photo: photo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { selected = nil }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func photoStrip(_ photos: [PhotoRecord], title: String?) -> some View {
        if photos.isEmpty {
            Text("Keine Fotos").font(.brand(.caption)).foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos) { photo in
                        Button {
                            selected = photo
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                PhotoThumbnail(photo: photo, size: 120)
                                Text(photo.caption.isEmpty ? (title ?? "Foto") : photo.caption)
                                    .font(.brand(.caption))
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct PhotoViewer: View {
    let photo: PhotoRecord
    @State private var image: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let image {
                    AnnotatedImageView(image: image, markers: photo.markers)
                } else {
                    ProgressView()
                }
                if !photo.note.isEmpty {
                    Text(photo.note)
                }
                Text(photo.capturedAt.formatted(date: .long, time: .shortened))
                    .font(.brand(.caption))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(photo.caption.isEmpty ? "Foto" : photo.caption)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            image = photo.imageData.flatMap(UIImage.init(data:))
        }
    }
}

/// Horizontal scrollbare Reiter mit Symbol und Titel; der gewählte Reiter wird sichtbar gehalten.
struct ProjectTabBar: View {
    @Binding var selection: ProjectDetailTab

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProjectDetailTab.allCases) { tab in
                        let isSelected = tab == selection
                        Button {
                            withAnimation(.snappy) { selection = tab }
                        } label: {
                            Label(tab.title, systemImage: tab.systemImage)
                                .font(.brand(.subheadline).weight(isSelected ? .semibold : .medium))
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .foregroundStyle(isSelected ? Color.white : Theme.anthrazit)
                                .background {
                                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                        .fill(isSelected ? Theme.gruenSolid : Theme.card)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                        .strokeBorder(isSelected ? Color.clear : Theme.separator.opacity(0.6), lineWidth: 0.5)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(tab)
                        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            .onChange(of: selection) { _, tab in
                withAnimation(.snappy) { proxy.scrollTo(tab, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Projektbereiche")
    }
}
