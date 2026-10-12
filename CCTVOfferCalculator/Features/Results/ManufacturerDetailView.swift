import SwiftUI
import CCTVCore

/// Erklärung einer Herstellerbewertung: Abgleich mit den erfassten Wünschen,
/// Zusammensetzung der Punkte, Hinweise und Herstellerprofil.
struct ManufacturerDetailView: View {
    let score: ManufacturerScore
    let project: ProjectRecord
    var isRecommended = false

    @Environment(\.dismiss) private var dismiss

    private var checks: [RequirementCheck] {
        RequirementMatcher.checks(for: score.manufacturer, project: project)
            .sorted { $0.status == $1.status ? false : $0.status < $1.status }
    }

    private var impossible: [RequirementCheck] { checks.filter { $0.status == .nichtMoeglich } }
    private var limited: [RequirementCheck] { checks.filter { $0.status == .teilweise } }
    private var profile: ManufacturerProfile? { ManufacturerProfiles.all.first { $0.manufacturer == score.manufacturer } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summary
                    requirements
                    points
                    if !score.warnings.isEmpty { warnings }
                    if let profile { profileSection(profile) }
                }
                .padding()
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle(score.manufacturer.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Abschnitte

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(score.manufacturer.label).font(.brand(.title2))
                Text(score.fit.label)
                    .font(.brand(.headline))
                    .foregroundStyle(Theme.color(for: score.score))
                if isRecommended {
                    Label("Empfohlen für dieses Projekt", systemImage: "star.fill")
                        .font(.brand(.footnote).weight(.semibold))
                        .foregroundStyle(Theme.gruen)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(score.score)")
                    .font(.brand(.largeTitle).monospacedDigit())
                    .foregroundStyle(Theme.color(for: score.score))
                Text("von 100").font(.brand(.caption)).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bewertung \(score.score) von 100")
        }
        .card()
    }

    @ViewBuilder
    private var summary: some View {
        if !impossible.isEmpty {
            notice(
                title: impossible.count == 1 ? "1 Wunsch ist nicht umsetzbar" : "\(impossible.count) Wünsche sind nicht umsetzbar",
                text: impossible.map { "\($0.title): \($0.wish)" }.joined(separator: " · "),
                systemImage: "xmark.octagon.fill",
                tint: Theme.error
            )
        } else if !limited.isEmpty {
            notice(
                title: limited.count == 1 ? "1 Wunsch mit Einschränkungen" : "\(limited.count) Wünsche mit Einschränkungen",
                text: "Alle Wünsche sind umsetzbar, einzelne aber nur teilweise. Details unten.",
                systemImage: "exclamationmark.triangle.fill",
                tint: Theme.sonneText
            )
        } else if !checks.isEmpty {
            notice(title: "Alle Wünsche erfüllt", text: "\(score.manufacturer.label) deckt alle erfassten Anforderungen ab.",
                   systemImage: "checkmark.seal.fill", tint: Theme.gruen)
        }
    }

    private var requirements: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Ihre Anforderungen", subtitle: "Abgleich mit den Angaben im Projekt", systemImage: "checklist")
                .padding(.bottom, 8)
            ForEach(checks) { check in
                RequirementRow(check: check)
                if check.id != checks.last?.id { Divider() }
            }
        }
        .card()
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "So entsteht die Bewertung", subtitle: "Start bei \(ManufacturerScoring.baseScore) Punkten, dann Zu- und Abschläge", systemImage: "function")
            pointRow("Ausgangswert", ManufacturerScoring.baseScore, signed: false)
            ForEach(Array(score.factors.enumerated()), id: \.offset) { _, factor in
                pointRow(factor.reason, factor.points, signed: true)
            }
            Divider()
            let raw = ManufacturerScoring.baseScore + score.factors.reduce(0) { $0 + $1.points }
            pointRow("Ergebnis", score.score, signed: false, emphasized: true)
            if raw != score.score {
                Text("Rechnerisch \(raw) Punkte, begrenzt auf 0–100.")
                    .font(.brand(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Hinweise", systemImage: "exclamationmark.bubble")
            ForEach(score.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.brand(.subheadline))
                    .foregroundStyle(Theme.sonneText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func profileSection(_ profile: ManufacturerProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Herstellerprofil", subtitle: profile.tagline, systemImage: "building.2")
            LabeledValueRow(label: "Segment", value: profile.segment)
            LabeledValueRow(label: "Typische Grösse", value: profile.typicalSize)
            FactorList(items: profile.strengths, systemImage: "plus.circle.fill", tint: Theme.success)
            FactorList(items: profile.limitations, systemImage: "minus.circle.fill", tint: Theme.error)
        }
        .card()
    }

    // MARK: - Bausteine

    private func notice(title: String, text: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.brand(.title2))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.brand(.headline))
                Text(text)
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func pointRow(_ label: String, _ value: Int, signed: Bool, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.brand(emphasized ? .headline : .subheadline))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(signed ? (value > 0 ? "+\(value)" : "\(value)") : "\(value)")
                .font(.brand(emphasized ? .headline : .subheadline).monospacedDigit())
                .foregroundStyle(signed ? (value > 0 ? Theme.gruen : Theme.error) : Theme.anthrazit)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Eine Anforderung mit Status, Begründung und Alternative.
struct RequirementRow: View {
    let check: RequirementCheck

    private var symbol: String {
        switch check.status {
        case .erfuellt: "checkmark.circle.fill"
        case .teilweise: "exclamationmark.circle.fill"
        case .nichtMoeglich: "xmark.circle.fill"
        }
    }

    private var tint: Color {
        switch check.status {
        case .erfuellt: Theme.gruen
        case .teilweise: Theme.sonneText
        case .nichtMoeglich: Theme.error
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.brand(.title3))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(check.title).font(.brand(.headline))
                    Spacer(minLength: 8)
                    Text(check.status.label)
                        .font(.brand(.caption).weight(.semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .fixedSize()
                }
                Text("Gewünscht: \(check.wish)")
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                Text(check.explanation)
                    .font(.brand(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                if let alternative = check.alternative, check.status != .erfuellt {
                    Label(alternative, systemImage: "arrow.turn.down.right")
                        .font(.brand(.footnote))
                        .foregroundStyle(Theme.gruen)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.title), gewünscht \(check.wish): \(check.status.label). \(check.explanation)")
    }
}
