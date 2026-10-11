import SwiftUI
import UIKit
import CCTVCore

enum Theme {
    static let navy = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.62, blue: 0.92, alpha: 1)
            : UIColor(red: 0.06, green: 0.17, blue: 0.36, alpha: 1)
    })
    static let navySolid = Color(red: 0.06, green: 0.17, blue: 0.36)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtle = Color(uiColor: .tertiarySystemFill)
    static let separator = Color(uiColor: .separator)
    static let success = Color(red: 0.13, green: 0.55, blue: 0.33)

    static let cornerRadius: CGFloat = 16
    static let minimumTouchTarget: CGFloat = 48

    static func color(for severity: WarningSeverity) -> Color {
        switch severity {
        case .info: .blue
        case .warnung: .orange
        case .kritisch: .red
        }
    }

    static func symbol(for severity: WarningSeverity) -> String {
        switch severity {
        case .info: "info.circle.fill"
        case .warnung: "exclamationmark.triangle.fill"
        case .kritisch: "exclamationmark.octagon.fill"
        }
    }

    static func color(for score: Int) -> Color {
        switch FitLevel(score: score) {
        case .sehrGut: success
        case .geeignet: .blue
        case .bedingt: .orange
        case .nichtEmpfohlen: .red
        }
    }

    static func color(for status: ProjectStatus) -> Color {
        switch status {
        case .entwurf: .gray
        case .erfasst: .blue
        case .offeriert: .orange
        case .gewonnen: success
        case .verloren: .red
        case .archiviert: .secondary
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.separator.opacity(0.35), lineWidth: 0.5)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// Grosse, gut treffbare Hauptaktion.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? Theme.navySolid : Color.gray.opacity(0.5))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.navy)
            .frame(minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.subtle)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Beschriftung im Stil der Hauptaktionen für Buttons, die in Formularzeilen
/// `.borderless` sein müssen (sonst löst ein Tipp die ganze Zeile aus).
struct ActionLabel: View {
    let title: String
    let systemImage: String
    var prominent = true

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(prominent ? Color.white : Theme.navy)
            .frame(maxWidth: .infinity, minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prominent ? Theme.navySolid : Theme.subtle)
            )
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondaryAction: SecondaryButtonStyle { SecondaryButtonStyle() }
}
