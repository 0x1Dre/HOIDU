import SwiftUI
import CCTVCore

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

extension View {
    func messageAlert(_ message: Binding<AlertMessage?>) -> some View {
        alert(
            message.wrappedValue?.title ?? "",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } }),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { value in
            Text(value.text)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.gruen)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.brand(.title3).weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.brand(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.gruen

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.brand(.title2))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(.brand(.title).weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct PrivacyNoticeCard: View {
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.brand(.title3))
                .foregroundStyle(Theme.gruen)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Datenschutz – Verantwortung des Kunden")
                    .font(.brand(.headline))
                Text(PrivacyText.responsibilityNotice)
                    .font(compact ? .brand(.footnote) : .brand(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct WarningRow: View {
    let warning: ProjectWarning

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Theme.symbol(for: warning.severity))
                .foregroundStyle(Theme.color(for: warning.severity))
                .font(.brand(.title3))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title)
                    .font(.brand(.subheadline).weight(.semibold))
                Text(warning.message)
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(warning.category.label) · \(warning.severity.label)")
                    .font(.brand(.caption))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(warning.severity.label): \(warning.title). \(warning.message)")
    }
}

struct ValidationBanner: View {
    let issues: [ValidationIssue]

    var body: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Bitte prüfen", systemImage: "exclamationmark.circle.fill")
                    .font(.brand(.headline))
                    .foregroundStyle(.red)
                ForEach(issues) { issue in
                    Text("• " + issue.message)
                        .font(.brand(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }
}

struct FieldError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.brand(.footnote))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        Text(status.label)
            .font(.brand(.caption).weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.color(for: status).opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            .foregroundStyle(Theme.color(for: status))
            .accessibilityLabel("Status: \(status.label)")
    }
}

struct ScoreBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.brand(.headline).monospacedDigit())
            .frame(minWidth: 44, minHeight: 32)
            .background(Theme.color(for: score).opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            .foregroundStyle(Theme.color(for: score))
            .accessibilityLabel("Bewertung \(score) von 100")
    }
}

struct LabeledValueRow: View {
    let label: String
    let value: String
    var emphasized = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(emphasized ? .semibold : .regular)
                .multilineTextAlignment(.trailing)
        }
        .font(emphasized ? .brand(.headline) : .brand(.subheadline))
        .accessibilityElement(children: .combine)
    }
}
