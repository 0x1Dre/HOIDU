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
                        .foregroundStyle(Theme.navy)
                        .accessibilityHidden(true)
                    Text(line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
            }
        }
        .card()
    }
}

struct ScoreCardView: View {
    let score: ManufacturerScore
    var isRecommended = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.manufacturer.label)
                        .font(.title3.weight(.semibold))
                    Text(score.fit.label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.color(for: score.score))
                }
                Spacer()
                ScoreBadge(score: score.score)
            }
            ProgressView(value: Double(score.score), total: 100)
                .tint(Theme.color(for: score.score))
                .accessibilityHidden(true)
            Text(score.rationale)
                .font(.subheadline)
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
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isRecommended {
                Label("Empfohlen", systemImage: "star.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.navy)
            }
        }
        .card()
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
                        .font(.footnote)
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.footnote)
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
                    .font(.title3.weight(.bold))
                if isRecommended {
                    Text("Empfohlen")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.navySolid, in: Capsule())
                        .foregroundStyle(.white)
                }
                Spacer()
                ScoreBadge(score: variant.score.score)
            }
            Text("\(variant.manufacturer.label)\(variant.isManualSelection ? " (manuell gewählt)" : "") · \(variant.selection.cameraCount) Kameras")
                .font(.subheadline)
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
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(isRecommended ? Theme.navy : .clear, lineWidth: 2)
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
                    .font(.subheadline)
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
                            Text(row.manufacturer.label).font(.headline)
                            Text(row.score.fit.label).font(.caption).foregroundStyle(.secondary)
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
            .font(.subheadline.weight(.semibold))
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
            .fontWeight(isChosen ? .bold : .regular)
            .foregroundStyle(isChosen ? Theme.navy : Color.primary)
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
                            Text(estimate.basis).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !variant.selection.notes.isEmpty || !variant.selection.warnings.isEmpty {
                Section("Hinweise zur Variante") {
                    ForEach(variant.selection.notes, id: \.self) { note in
                        Label(note, systemImage: "info.circle").font(.subheadline)
                    }
                    ForEach(variant.selection.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
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
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .leading)
                Text(item.description)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(Format.chf(item.totalSell))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            HStack {
                Text(item.quantityText + " × " + Format.chf(item.unitSellPrice))
                if internalMode {
                    Text("· EK \(Format.chf(item.unitPurchasePrice)) · Marge \(Format.percent(item.marginPercent))")
                }
            }
            .font(.caption.monospacedDigit())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wartung und Support", subtitle: "Monatliche Pauschale exkl. MWST", systemImage: "wrench.and.screwdriver")
            Picker("Wartungspaket", selection: $selection.package) {
                Text("Keine Wartung").tag(MaintenancePackage?.none)
                ForEach(MaintenancePackage.allCases) { package in
                    Text(package.label).tag(MaintenancePackage?.some(package))
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            Toggle("Jährlicher Check vor Ort (Option bei Basic/Business)", isOn: $selection.includeOnSiteCheck)
                .frame(minHeight: 44)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(quotes, id: \.package) { quote in
                    MaintenanceQuoteCard(quote: quote, isSelected: selection.package == quote.package)
                        .onTapGesture { selection.package = quote.package }
                }
            }
        }
        .card()
    }
}

struct MaintenanceQuoteCard: View {
    let quote: MaintenanceQuote
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(quote.package.label).font(.headline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.navy)
                        .accessibilityLabel("gewählt")
                }
            }
            Text(Format.chf(quote.monthlyNet) + " / Monat")
                .font(.title3.weight(.bold).monospacedDigit())
            Text("\(Format.chf(quote.yearlyNet)) pro Jahr · inkl. MWST \(Format.chf(quote.yearlyInclVAT))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Reaktionszeit: \(quote.responseTime)")
                .font(.caption)
            Divider()
            ForEach(quote.services, id: \.self) { service in
                Label(service, systemImage: "checkmark")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isSelected ? Theme.navySolid.opacity(0.08) : Theme.subtle.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? Theme.navy : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
