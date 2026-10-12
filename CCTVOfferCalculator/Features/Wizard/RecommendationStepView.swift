import SwiftUI
import SwiftData
import CCTVCore

struct RecommendationStepView: View {
    @Bindable var viewModel: WizardViewModel
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    private var discount: Binding<Double> {
        Binding(
            get: { viewModel.draft.discountPercent.asDouble },
            set: { viewModel.draft.discountPercent = Decimal(string: String(format: "%.1f", $0)) ?? 0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ValidationBanner(issues: viewModel.issues.filter { $0.step == .empfehlung })

                if let analysis = viewModel.analysis {
                    if analysis.isCalculable {
                        content(analysis)
                    } else {
                        ContentUnavailableView(
                            "Keine Kalkulation möglich",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Bitte im Schritt «Überwachungsbereiche» mindestens einen Bereich mit Kameras erfassen und prüfen, ob die Preislisten aktive Kameras enthalten.")
                        )
                        WarningsCard(warnings: analysis.warnings)
                    }
                } else {
                    ProgressView("Empfehlung wird berechnet …")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                PrivacyNoticeCard()
            }
            .padding()
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .onChange(of: viewModel.draft.discountPercent) { _, _ in recalculate() }
        .onChange(of: viewModel.draft.maintenance) { _, _ in recalculate() }
    }

    @ViewBuilder
    private func content(_ analysis: OfferAnalysis) -> some View {
        TechnicalRecommendationCard(lines: analysis.technicalRecommendation)

        SectionHeader(title: "Angebotsvarianten", subtitle: "Automatisch gewählt nach Bewertung und Variante", systemImage: "square.stack.3d.up")
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(analysis.variants) { variant in
                VariantSummaryCard(variant: variant, isRecommended: variant.tier == analysis.recommendedTier, internalMode: settings.internalMode)
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rabatt")
                Spacer()
                Text(Format.percent(viewModel.draft.discountPercent))
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            Slider(value: discount, in: 0...30, step: 0.5) {
                Text("Rabatt")
            } minimumValueLabel: {
                Text("0 %")
            } maximumValueLabel: {
                Text("30 %")
            }
            .accessibilityValue(Format.percent(viewModel.draft.discountPercent))
        }
        .card()

        MaintenanceOptionsView(quotes: analysis.maintenanceQuotes, selection: $viewModel.draft.maintenance)

        SectionHeader(title: "Herstellerbewertung", subtitle: "0–100 Punkte anhand der erfassten Anforderungen", systemImage: "chart.bar")
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(analysis.scores) { score in
                ScoreCardView(score: score, isRecommended: analysis.recommendedVariant?.manufacturer == score.manufacturer)
            }
        }

        SectionHeader(title: "Vergleich nach Hersteller", subtitle: "Einmalkosten inkl. MWST je Variante", systemImage: "tablecells")
        ComparisonTableView(analysis: analysis, internalMode: settings.internalMode)

        WarningsCard(warnings: analysis.warnings)
    }

    private func recalculate() {
        viewModel.refreshAnalysis(catalog: ProjectRepository(context: modelContext).catalog(), settings: settings.calculation)
    }
}
