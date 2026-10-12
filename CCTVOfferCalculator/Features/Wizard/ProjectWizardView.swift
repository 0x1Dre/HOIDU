import SwiftUI
import SwiftData
import CCTVCore

/// Geführte Projekterfassung in fünf Schritten.
struct ProjectWizardView: View {
    @Bindable var viewModel: WizardViewModel
    let onSave: (ProjectRecord) -> Void
    var onDiscard: (() -> Void)?

    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var confirmDiscard = false

    var body: some View {
        VStack(spacing: 0) {
            WizardProgressHeader(viewModel: viewModel)
            Divider()
            Group {
                switch viewModel.step {
                case .kunde: CustomerStepView(viewModel: viewModel)
                case .bereiche: AreasStepView(viewModel: viewModel)
                case .infrastruktur: InfrastructureStepView(viewModel: viewModel)
                case .aufzeichnung: RecordingStepView(viewModel: viewModel)
                case .empfehlung: RecommendationStepView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            bottomBar
        }
        .background(Theme.background)
        .navigationTitle(viewModel.mode == .create ? "Neues Projekt" : "Projekt bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onDiscard {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.mode == .create ? "Verwerfen" : "Abbrechen", role: .destructive) {
                        if viewModel.hasContent { confirmDiscard = true } else { onDiscard() }
                    }
                }
            }
        }
        .confirmationDialog(
            viewModel.mode == .create ? "Entwurf verwerfen?" : "Änderungen verwerfen?",
            isPresented: $confirmDiscard,
            titleVisibility: .visible
        ) {
            Button("Verwerfen", role: .destructive) { onDiscard?() }
            Button("Weiter bearbeiten", role: .cancel) {}
        } message: {
            Text("Alle nicht gespeicherten Angaben und Fotos gehen verloren.")
        }
        .onChange(of: viewModel.step) { _, step in
            if step == .empfehlung { recalculate() }
        }
        .onAppear {
            if viewModel.step == .empfehlung { recalculate() }
        }
    }

    private func recalculate() {
        viewModel.refreshAnalysis(catalog: ProjectRepository(context: modelContext).catalog(), settings: settings.calculation)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if viewModel.step != .kunde {
                Button {
                    viewModel.back()
                } label: {
                    Label("Zurück", systemImage: "chevron.left")
                }
                .buttonStyle(.secondaryAction)
            }
            Spacer()
            Text("\(viewModel.step.rawValue)/\(WizardStep.allCases.count)")
                .font(.brand(.subheadline).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel("Schritt \(viewModel.step.rawValue) von \(WizardStep.allCases.count)")
            Spacer()
            if viewModel.isLastStep {
                Button {
                    if let record = viewModel.finalizedRecord() {
                        onSave(record)
                    }
                } label: {
                    Label("Speichern", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.primaryAction)
            } else {
                Button {
                    viewModel.next()
                } label: {
                    Label("Weiter", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.primaryAction)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

struct WizardProgressHeader: View {
    @Bindable var viewModel: WizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: viewModel.progress)
                .tint(Theme.gruen)
                .accessibilityLabel("Fortschritt")
                .accessibilityValue("Schritt \(viewModel.step.rawValue) von \(WizardStep.allCases.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WizardStep.allCases) { step in
                        let isCurrent = step == viewModel.step
                        let hasIssues = !viewModel.stepIssues(step).isEmpty
                        Button {
                            viewModel.jump(to: step)
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(step.rawValue)")
                                    .font(.brand(.caption).weight(.semibold))
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(isCurrent ? Color.white : Theme.gruenSolid.opacity(0.15)))
                                    .foregroundStyle(isCurrent ? Theme.gruenSolid : Theme.gruen)
                                Text(step.title)
                                    .font(.brand(.subheadline).weight(isCurrent ? .semibold : .regular))
                                if hasIssues {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(isCurrent ? .white : .red)
                                        .accessibilityLabel("enthält Fehler")
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(isCurrent ? Theme.gruenSolid : Theme.subtle))
                            .foregroundStyle(isCurrent ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canJump(to: step))
                        .opacity(viewModel.canJump(to: step) ? 1 : 0.45)
                        .accessibilityLabel("Schritt \(step.rawValue): \(step.title)")
                        .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Theme.card)
    }
}

/// Bereich «Neues Projekt»: hostet den Assistenten und speichert das Ergebnis.
struct NewProjectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var saveError: String?

    var body: some View {
        ProjectWizardView(
            viewModel: router.newProjectWizard,
            onSave: { save($0) },
            onDiscard: { router.resetNewProject() }
        )
        .safeAreaInset(edge: .top) {
            if router.newProjectWizard.wasRestored {
                HStack {
                    Label("Entwurf wiederhergestellt", systemImage: "arrow.counterclockwise.circle")
                        .font(.brand(.subheadline))
                    Spacer()
                    Button("Ausblenden") { router.newProjectWizard.wasRestored = false }
                        .font(.brand(.subheadline))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Theme.gruen.opacity(0.12))
            }
        }
        .alert("Speichern fehlgeschlagen", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func save(_ record: ProjectRecord) {
        do {
            let project = try ProjectRepository(context: modelContext).save(record)
            router.resetNewProject()
            router.openProject(project.id)
        } catch {
            saveError = error.localizedDescription
        }
    }
}
