import SwiftUI
import CCTVCore

struct TechnicalRecommendationCard: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Technische Empfehlung", systemImage: "lightbulb")
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.gruen)
                        .accessibilityHidden(true)
                    Text(line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.brand(.subheadline))
            }
        }
        .card()
    }
}

struct ScoreCardView: View {
    let score: ManufacturerScore
    var isRecommended = false
    /// Mit Projekt wird die Karte antippbar und zeigt die ausführliche Erklärung.
    var project: ProjectRecord?

    @State private var showDetail = false

    var body: some View {
        if let project {
            Button {
                showDetail = true
            } label: {
                card(detailHint: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Zeigt Begründung und Abgleich mit den Anforderungen")
            .sheet(isPresented: $showDetail) {
                ManufacturerDetailView(score: score, project: project, isRecommended: isRecommended)
            }
        } else {
            card(detailHint: false)
        }
    }

    /// Anzahl Wünsche, die dieser Hersteller nicht umsetzen kann.
    private var impossibleCount: Int {
        guard let project else { return 0 }
        return RequirementMatcher.checks(for: score.manufacturer, project: project).filter { $0.status == .nichtMoeglich }.count
    }

    private func card(detailHint: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.manufacturer.label)
                        .font(.brand(.title3).weight(.semibold))
                    Text(score.fit.label)
                        .font(.brand(.subheadline))
                        .foregroundStyle(Theme.color(for: score.score))
                }
                Spacer()
                ScoreBadge(score: score.score)
            }
            ProgressView(value: Double(score.score), total: 100)
                .tint(Theme.color(for: score.score))
                .accessibilityHidden(true)
            Text(score.rationale)
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !score.pros.isEmpty {
                FactorList(items: Array(score.pros.prefix(3)), systemImage: "plus.circle.fill", tint: Theme.success)
            }
            if !score.cons.isEmpty {
                FactorList(items: Array(score.cons.prefix(3)), systemImage: "minus.circle.fill", tint: .red)
            }
            ForEach(score.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.brand(.footnote))
                    .foregroundStyle(Theme.sonneText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isRecommended {
                Label("Empfohlen", systemImage: "star.fill")
                    .font(.brand(.footnote).weight(.semibold))
                    .foregroundStyle(Theme.gruen)
            }
            if detailHint {
                HStack {
                    if impossibleCount > 0 {
                        Label(impossibleCount == 1 ? "1 Wunsch nicht umsetzbar" : "\(impossibleCount) Wünsche nicht umsetzbar",
                              systemImage: "xmark.octagon.fill")
                            .foregroundStyle(Theme.error)
                    }
                    Spacer()
                    Text("Details")
                    Image(systemName: "chevron.right")
                }
                .font(.brand(.footnote).weight(.semibold))
                .foregroundStyle(Theme.gruen)
            }
        }
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct FactorList: View {
    let items: [String]
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .font(.brand(.footnote))
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.brand(.footnote))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct VariantSummaryCard: View {
    let variant: OfferVariant
    let isRecommended: Bool
    let internalMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(variant.tier.label)
                    .font(.brand(.title3).weight(.semibold))
                if isRecommended {
                    Text("Empfohlen")
                        .font(.brand(.caption).weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.gruenSolid, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                        .foregroundStyle(.white)
                }
                Spacer()
                ScoreBadge(score: variant.score.score)
            }
            Text("\(variant.manufacturer.label)\(variant.isManualSelection ? " (manuell gewählt)" : "") · \(variant.selection.cameraCount) Kameras")
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)
            Divider()
            LabeledValueRow(label: "Einmalig exkl. MWST", value: Format.chf(variant.totals.netAfterDiscount))
            LabeledValueRow(label: "Einmalig inkl. MWST", value: Format.chf(variant.totals.totalInclVAT), emphasized: true)
            if let maintenance = variant.maintenance {
                LabeledValueRow(label: "Wartung \(maintenance.package.label) / Monat", value: Format.chf(maintenance.monthlyNet))
            }
            if internalMode {
                Divider()
                LabeledValueRow(label: "Deckungsbeitrag", value: "\(Format.chf(variant.totals.contributionMargin)) (\(Format.percent(variant.totals.contributionMarginPercent)))")
                LabeledValueRow(label: "Marge Material", value: Format.percent(variant.totals.materialMarginPercent))
            }
            if !variant.selection.warnings.isEmpty {
                Label("\(variant.selection.warnings.count) Kompromisse – Details in den Positionen", systemImage: "exclamationmark.triangle")
                    .font(.brand(.footnote))
                    .foregroundStyle(Theme.sonneText)
            }
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(isRecommended ? Theme.gruen : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
    }
}

struct WarningsCard: View {
    let warnings: [ProjectWarning]
    var title = "Hinweise und Warnungen"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, systemImage: "exclamationmark.bubble")
            if warnings.isEmpty {
                Label("Keine Warnungen für dieses Projekt.", systemImage: "checkmark.circle")
                    .foregroundStyle(Theme.success)
                    .font(.brand(.subheadline))
            } else {
                ForEach(warnings) { warning in
                    WarningRow(warning: warning)
                    if warning.id != warnings.last?.id { Divider() }
                }
            }
        }
        .card()
    }
}

/// Herstellervergleich: Bewertung und Einmalkosten je Variante.
struct ComparisonTableView: View {
    let analysis: OfferAnalysis
    let internalMode: Bool

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    header("Hersteller")
                    header("Bewertung")
                    ForEach(OfferTier.allCases) { tier in
                        header(tier.label).gridColumnAlignment(.trailing)
                    }
                    header("Wartung/Monat").gridColumnAlignment(.trailing)
                    if internalMode { header("DB % Std.").gridColumnAlignment(.trailing) }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(analysis.comparison) { row in
                    GridRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.manufacturer.label).font(.brand(.headline))
                            Text(row.score.fit.label).font(.brand(.caption)).foregroundStyle(.secondary)
                        }
                        ScoreBadge(score: row.score.score)
                        ForEach(OfferTier.allCases) { tier in
                            ComparisonCellText(
                                tier: tier,
                                total: row.cell(tier)?.totalInclVAT,
                                isChosen: analysis.variant(tier)?.manufacturer == row.manufacturer
                            )
                        }
                        Text(row.maintenanceMonthly.map(Format.chf) ?? "–")
                            .monospacedDigit()
                        if internalMode {
                            Text(row.cell(.standard)?.contributionMarginPercent.map { Format.percent($0) } ?? "–")
                                .monospacedDigit()
                        }
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
            }
            .padding()
        }
        .card(padding: 0)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.brand(.subheadline).weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

struct ComparisonCellText: View {
    let tier: OfferTier
    let total: Decimal?
    let isChosen: Bool

    var body: some View {
        let text = total.map { Format.chf($0) } ?? "–"
        let spoken = total.map { Format.chf($0) } ?? "nicht verfügbar"
        Text(text)
            .monospacedDigit()
            .fontWeight(isChosen ? .semibold : .regular)
            .foregroundStyle(isChosen ? Theme.gruen : Color.primary)
            .accessibilityLabel(isChosen ? "\(tier.label): \(spoken), gewählte Variante" : "\(tier.label): \(spoken)")
    }
}

/// Positionen einer Variante, im internen Modus mit Einkauf und Marge.
struct VariantDetailView: View {
    let variant: OfferVariant
    let internalMode: Bool

    var body: some View {
        List {
            Section {
                LabeledContent("Hersteller", value: variant.manufacturer.label)
                LabeledContent("Bewertung", value: "\(variant.score.score)/100 – \(variant.score.fit.label)")
                LabeledContent("Kameras", value: "\(variant.selection.cameraCount)")
                if let storage = variant.selection.storage {
                    LabeledContent("Speicher", value: "\(Format.number(storage.requiredTBWithMargin, fractionDigits: 1)) TB · \(storage.recommendedDisks) × \(storage.diskSizeTB) TB")
                }
            }

            Section("Material") {
                ForEach(variant.materialItems) { item in
                    LineItemRow(item: item, internalMode: internalMode)
                }
            }

            Section("Arbeit") {
                ForEach(variant.laborItems) { item in
                    LineItemRow(item: item, internalMode: internalMode)
                }
            }

            Section("Total") {
                let t = variant.totals
                LabeledValueRow(label: "Material netto", value: Format.chf(t.materialNet))
                LabeledValueRow(label: "Arbeit netto (\(Format.hours(t.laborHours)))", value: Format.chf(t.laborNet))
                LabeledValueRow(label: "Zwischentotal", value: Format.chf(t.subtotal))
                if t.discountAmount > 0 {
                    LabeledValueRow(label: "Rabatt \(Format.percent(t.discountPercent))", value: "– " + Format.chf(t.discountAmount))
                }
                LabeledValueRow(label: "Total exkl. MWST", value: Format.chf(t.netAfterDiscount))
                LabeledValueRow(label: "MWST \(Format.percent(t.vatPercent))", value: Format.chf(t.vatAmount))
                if t.roundingDifference != 0 {
                    LabeledValueRow(label: "Rundungsdifferenz", value: Format.chf(t.roundingDifference))
                }
                LabeledValueRow(label: "Total inkl. MWST", value: Format.chf(t.totalInclVAT), emphasized: true)
            }

            if internalMode {
                Section("Intern") {
                    let t = variant.totals
                    LabeledValueRow(label: "Materialkosten (Einkauf)", value: Format.chf(t.materialCost))
                    LabeledValueRow(label: "Marge Material", value: "\(Format.chf(t.materialMargin)) (\(Format.percent(t.materialMarginPercent)))")
                    LabeledValueRow(label: "Arbeitskosten intern", value: Format.chf(t.laborCost))
                    LabeledValueRow(label: "Deckungsbeitrag", value: "\(Format.chf(t.contributionMargin)) (\(Format.percent(t.contributionMarginPercent)))", emphasized: true)
                }
                Section("Arbeitsschätzung") {
                    ForEach(variant.labor, id: \.kind) { estimate in
                        VStack(alignment: .leading, spacing: 2) {
                            LabeledValueRow(label: estimate.kind.label, value: Format.hours(estimate.hours))
                            Text(estimate.basis).font(.brand(.caption)).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !variant.selection.notes.isEmpty || !variant.selection.warnings.isEmpty {
                Section("Hinweise zur Variante") {
                    ForEach(variant.selection.notes, id: \.self) { note in
                        Label(note, systemImage: "info.circle").font(.brand(.subheadline))
                    }
                    ForEach(variant.selection.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.brand(.subheadline))
                            .foregroundStyle(Theme.sonneText)
                    }
                }
            }
        }
        .navigationTitle("Variante \(variant.tier.label) – \(variant.manufacturer.label)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LineItemRow: View {
    let item: OfferLineItem
    let internalMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(item.position).")
                    .font(.brand(.subheadline).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                Text(item.description)
                    .font(.brand(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(Format.chf(item.totalSell))
                    .font(.brand(.subheadline).monospacedDigit().weight(.semibold))
            }
            HStack {
                Text(item.quantityText + " × " + Format.chf(item.unitSellPrice))
                if internalMode {
                    Text("· EK \(Format.chf(item.unitPurchasePrice)) · Marge \(Format.percent(item.marginPercent))")
                }
            }
            .font(.brand(.caption).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.leading, 30)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct MaintenanceOptionsView: View {
    let quotes: [MaintenanceQuote]
    @Binding var selection: MaintenanceSelection

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var scrolledID: String?

    /// Karten-ID: "keine" für ohne Wartung, sonst das Paket.
    private static let noneID = "keine"

    private var selectedID: String { selection.package?.rawValue ?? Self.noneID }
    private var cardIDs: [String] { [Self.noneID] + quotes.map(\.package.rawValue) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wartung und Support", subtitle: "Monatliche Pauschale exkl. MWST", systemImage: "wrench.and.screwdriver")

            // Wischbares Karussell: auf dem iPhone eine Karte pro Seite, auf dem iPad drei.
            ScrollView(.horizontal, showsIndicators: false) {
                // Normale HStack (nicht lazy), damit die Höhe der höchsten Karte gemessen wird;
                // mit fixedSize werden alle Karten gleich hoch.
                HStack(alignment: .top, spacing: 12) {
                    NoMaintenanceCard(isSelected: selection.package == nil)
                        .containerRelativeFrame(.horizontal, count: columns, spacing: 12)
                        .onTapGesture { select(nil) }
                        .id(Self.noneID)
                    ForEach(quotes, id: \.package) { quote in
                        MaintenanceQuoteCard(quote: quote, isSelected: selection.package == quote.package)
                            .containerRelativeFrame(.horizontal, count: columns, spacing: 12)
                            .onTapGesture { select(quote.package) }
                            .id(quote.package.rawValue)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledID, anchor: .leading)
            .scrollClipDisabled()
            .onAppear { scrolledID = selectedID }
            .onChange(of: scrolledID) { _, id in
                // iPhone: die sichtbare Karte gilt als ausgewählt.
                guard columns == 1, let id, id != selectedID else { return }
                withAnimation(.snappy) {
                    apply(id == Self.noneID ? nil : MaintenancePackage(rawValue: id))
                }
            }

            if columns == 1 {
                PageDots(ids: cardIDs, current: scrolledID ?? selectedID) { id in
                    withAnimation(.snappy) { scrolledID = id }
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Jährlicher Vor-Ort-Check", isOn: onSiteBinding)
                    .frame(minHeight: 44)
                    .disabled(selection.package == .premium || selection.package == nil)
                Text(onSiteNote)
                    .font(.brand(.caption))
                    .foregroundStyle(.secondary)
            }
            .card()
        }
    }

    private var columns: Int { horizontalSizeClass == .compact ? 1 : 3 }

    /// Bei Premium ist der Check inbegriffen und wird als eingeschaltet angezeigt.
    private var onSiteBinding: Binding<Bool> {
        Binding(
            get: { selection.package == .premium || selection.includeOnSiteCheck },
            set: { selection.includeOnSiteCheck = $0 }
        )
    }

    private var onSiteNote: String {
        switch selection.package {
        case .premium: "Im Premium-Paket inbegriffen."
        case .business: "Bei Business empfohlen und vorausgewählt; der Anteil ist im Monatspreis enthalten."
        case .basic: "Option bei Basic; der Anteil wird zum Monatspreis addiert."
        case nil: "Nur mit Wartungspaket möglich."
        }
    }

    private func select(_ package: MaintenancePackage?) {
        withAnimation(.snappy) {
            apply(package)
            scrolledID = package?.rawValue ?? Self.noneID
        }
    }

    /// Paket übernehmen. Business und Premium: Vor-Ort-Check einschalten; ohne Wartung ausschalten.
    private func apply(_ package: MaintenancePackage?) {
        selection.package = package
        switch package {
        case .business, .premium: selection.includeOnSiteCheck = true
        case nil: selection.includeOnSiteCheck = false
        case .basic: break
        }
    }
}

/// Karte «Keine Wartung» im Karussell.
private struct NoMaintenanceCard: View {
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keine Wartung").font(.brand(.headline))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.gruen)
                        .accessibilityLabel("gewählt")
                }
            }
            Text(Format.chf(0) + " / Monat")
                .font(.brand(.title3).weight(.semibold).monospacedDigit())
            Text("Ohne Wartungsvertrag. Einsätze werden nach Aufwand verrechnet.")
                .font(.brand(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? Theme.gruenSolid.opacity(0.08) : Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .strokeBorder(isSelected ? Theme.gruen : Theme.separator.opacity(0.4), lineWidth: isSelected ? 2 : 0.5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Seitenpunkte unter einem Karussell.
struct PageDots: View {
    let ids: [String]
    let current: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ids, id: \.self) { id in
                Circle()
                    .fill(id == current ? Theme.gruenSolid : Theme.grau.opacity(0.35))
                    .frame(width: 8, height: 8)
                    .padding(6)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(id) }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MaintenanceQuoteCard: View {
    let quote: MaintenanceQuote
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(quote.package.label).font(.brand(.headline))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.gruen)
                        .accessibilityLabel("gewählt")
                }
            }
            Text(Format.chf(quote.monthlyNet) + " / Monat")
                .font(.brand(.title3).weight(.semibold).monospacedDigit())
            Text("\(Format.chf(quote.yearlyNet)) pro Jahr · inkl. MWST \(Format.chf(quote.yearlyInclVAT))")
                .font(.brand(.caption))
                .foregroundStyle(.secondary)
            Text("Reaktionszeit: \(quote.responseTime)")
                .font(.brand(.caption))
            Divider()
            ForEach(quote.services, id: \.self) { service in
                Label(service, systemImage: "checkmark")
                    .font(.brand(.caption))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? Theme.gruenSolid.opacity(0.08) : Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .strokeBorder(isSelected ? Theme.gruen : Theme.separator.opacity(0.4), lineWidth: isSelected ? 2 : 0.5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
