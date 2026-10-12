import SwiftUI
import UIKit
import CCTVCore

/// Gestaltung nach dem Ostsicht-Manual (CI/CD).
///
/// Farben: Grün trägt die Marke, Orange (Sonne) ist das Licht und wird sparsam eingesetzt.
/// Faustregel pro Fläche: 60 % Weiss/Kalk, 30 % Grün und Anthrazit, höchstens 10 % Orange.
/// Orange ist nie Textfarbe – für orangen Text gibt es `sonneText`. Auf Orange steht Anthrazit, nie Weiss.
enum Theme {
    // MARK: Markenfarben (fix, für Flächen)

    /// Ostsicht Grün #1B7A44 – Hauptfarbe. Weisse Schrift darauf ist gut lesbar.
    static let gruenSolid = Color(uiColor: OstsichtColor.gruen)
    /// Sonnen-Orange #F29A1F – nur für Flächen und Akzente, nie für Text.
    static let sonne = Color(uiColor: OstsichtColor.sonne)
    /// Anthrazit #22272B
    static let anthrazitSolid = Color(uiColor: OstsichtColor.anthrazit)
    /// Grau #5F6368
    static let grauSolid = Color(uiColor: OstsichtColor.grau)
    /// Kalk #F4F2EC
    static let kalk = Color(uiColor: OstsichtColor.kalk)

    // MARK: Dynamische Farben (Text, Symbole, Tint – hell und dunkel lesbar)

    /// Grün für Text, Symbole und Tint. Im Dunkelmodus aufgehellt.
    static let gruen = Color(uiColor: OstsichtColor.gruenText)
    /// Oranger Text («sonne-text»). Hell #9C5600, dunkel #F5B04D.
    static let sonneText = Color(uiColor: OstsichtColor.sonneText)
    /// Anthrazit für Text und Symbole, im Dunkelmodus hell.
    static let anthrazit = Color(uiColor: OstsichtColor.anthrazitText)
    /// Grau für Nebentext.
    static let grau = Color(uiColor: OstsichtColor.grauText)

    // MARK: Flächen

    static let background = Color(uiColor: OstsichtColor.background)
    static let card = Color(uiColor: OstsichtColor.card)
    static let subtle = Color(uiColor: .tertiarySystemFill)
    static let separator = Color(uiColor: .separator)
    static let success = gruen
    static let error = Color(uiColor: .systemRed)

    // MARK: Form

    /// Ecken eher kantig (2–8 px), passend zur technischen Schrift.
    static let cornerRadius: CGFloat = 8
    static let controlRadius: CGFloat = 6
    static let smallRadius: CGFloat = 4
    static let minimumTouchTarget: CGFloat = 48

    static func color(for severity: WarningSeverity) -> Color {
        switch severity {
        case .info: gruen
        case .warnung: sonneText
        case .kritisch: error
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
        case .sehrGut: gruen
        case .geeignet: anthrazit
        case .bedingt: sonneText
        case .nichtEmpfohlen: error
        }
    }

    static func color(for status: ProjectStatus) -> Color {
        switch status {
        case .entwurf: grau
        case .erfasst: anthrazit
        case .offeriert: sonneText
        case .gewonnen: gruen
        case .verloren: error
        case .archiviert: .secondary
        }
    }
}

/// Markenfarben als `UIColor`, auch für den PDF-Export.
enum OstsichtColor {
    static var gruen: UIColor { UIColor(hex: 0x1B7A44) }
    static var sonne: UIColor { UIColor(hex: 0xF29A1F) }
    static var anthrazit: UIColor { UIColor(hex: 0x22272B) }
    static var grau: UIColor { UIColor(hex: 0x5F6368) }
    static var kalk: UIColor { UIColor(hex: 0xF4F2EC) }
    /// Helle Zusatzzeile auf Grün (aus dem Negativ-Logo).
    static var gruenHell: UIColor { UIColor(hex: 0xE3F1E8) }
    /// Oranger Text auf Weiss/Kalk (Kontrast ≥ 4.5:1).
    static var sonneTextFix: UIColor { UIColor(hex: 0x9C5600) }

    static var gruenText: UIColor { UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x5BBF86) : gruen } }
    static var sonneText: UIColor { UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xF5B04D) : sonneTextFix } }
    static var anthrazitText: UIColor { UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xE8E9EA) : anthrazit } }
    static var grauText: UIColor { UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xA3A7AC) : grau } }
    static var background: UIColor { UIColor { $0.userInterfaceStyle == .dark ? .systemGroupedBackground : kalk } }
    static var card: UIColor { UIColor { $0.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white } }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Schrift (Barlow)

/// Hausschrift Barlow: Titel SemiBold (600), Fliesstext Regular (400), Labels Medium (500).
/// Kein Bold und kein Kursiv – Hervorhebungen in SemiBold.
enum BrandFont {
    static let family = "Barlow"
    static let regular = "Barlow-Regular"
    static let medium = "Barlow-Medium"
    static let semibold = "Barlow-SemiBold"

    /// `UIFont` in Barlow; fällt auf die Systemschrift zurück, falls die Datei fehlt.
    static func uiFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let name: String
        switch weight {
        case .medium: name = medium
        case .semibold, .bold, .heavy, .black: name = semibold
        default: name = regular
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    /// Mit Dynamic Type skalierte Barlow-Schrift für UIKit (Navigationsleiste, Tab-Leiste).
    static func scaledUIFont(_ style: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFontMetrics(forTextStyle: style).scaledFont(for: uiFont(size: size, weight: weight))
    }

    static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }

    /// Wendet Barlow auf Navigations- und Tab-Leisten an. Einmal beim App-Start aufrufen.
    @MainActor
    static func applyAppearance() {
        let navigation = UINavigationBar.appearance()
        navigation.largeTitleTextAttributes = [
            .font: scaledUIFont(.largeTitle, size: 34, weight: .semibold),
            .foregroundColor: OstsichtColor.anthrazitText
        ]
        navigation.titleTextAttributes = [
            .font: scaledUIFont(.headline, size: 17, weight: .semibold),
            .foregroundColor: OstsichtColor.anthrazitText
        ]
        let tabFont = uiFont(size: 11, weight: .medium)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: uiFont(size: 14, weight: .medium)], for: .normal)
    }
}

extension Font {
    /// Barlow im passenden Schnitt für den Textstil, skaliert mit Dynamic Type.
    /// Titel und Headline in SemiBold, alles andere Regular.
    static func brand(_ style: Font.TextStyle) -> Font {
        let base = Font.custom(BrandFont.family, size: BrandFont.size(for: style), relativeTo: style)
        switch style {
        case .largeTitle, .title, .title2, .title3, .headline:
            return base.weight(.semibold)
        default:
            return base
        }
    }

    /// Label-Stil: Barlow Medium in Grossbuchstaben mit Sperrung (mit `.brandLabel()` kombinieren).
    static func brandLabel(_ style: Font.TextStyle = .caption) -> Font {
        Font.custom(BrandFont.family, size: BrandFont.size(for: style), relativeTo: style).weight(.medium)
    }
}

extension View {
    /// Labels und Zusatzzeilen: Barlow Medium, Grossbuchstaben, etwas Sperrung.
    func brandLabel(_ style: Font.TextStyle = .caption) -> some View {
        font(.brandLabel(style))
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - Karten und Buttons

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

/// Grosse, gut treffbare Hauptaktion: Grün mit weisser Schrift.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brand(.headline))
            .foregroundStyle(.white)
            .frame(minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(isEnabled ? Theme.gruenSolid : Theme.grauSolid.opacity(0.5))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brand(.headline))
            .foregroundStyle(Theme.gruen)
            .frame(minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .strokeBorder(Theme.gruen, lineWidth: 1.5)
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
            .font(.brand(.headline))
            .foregroundStyle(prominent ? Color.white : Theme.gruen)
            .frame(maxWidth: .infinity, minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 12)
            .background {
                if prominent {
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                        .fill(Theme.gruenSolid)
                } else {
                    RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                        .strokeBorder(Theme.gruen, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondaryAction: SecondaryButtonStyle { SecondaryButtonStyle() }
}
