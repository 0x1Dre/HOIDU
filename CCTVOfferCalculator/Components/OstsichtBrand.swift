import SwiftUI
import UIKit

/// Logo und Signet von Ostsicht als Vektorzeichnung.
///
/// Die Geometrie entspricht 1:1 den verbindlichen SVG-Dateien (`ostsicht-signet.svg`,
/// `ostsicht-logo-horizontal.svg`, `ostsicht-logo-vertikal.svg`). Gezeichnet wird mit Core Graphics,
/// damit App und PDF-Export dieselbe Quelle verwenden und das Logo in jeder Grösse scharf bleibt.
///
/// Regeln aus dem Manual: nicht verzerren, nicht drehen, keine Schatten, Farben nicht vertauschen,
/// nicht auf unruhige Fotos setzen. Mindestgrösse am Bildschirm: Logo 140 px breit, Signet 24 px.
@MainActor
enum OstsichtBrand {
    enum Variant {
        /// Farbig auf hellem Grund.
        case standard
        /// Weiss/Orange auf Grün (Fahrzeug, dunkle Flächen).
        case negativ
        /// Einfarbig Anthrazit (Stempel, Gravur).
        case mono
    }

    enum Layout {
        /// Hauptlogo: Signet links, Schriftzug rechts.
        case horizontal
        /// Signet oben, Schriftzug zentriert darunter.
        case vertikal
        /// Signet allein.
        case signet

        /// Seitenverhältnis des SVG-ViewBox.
        var canvasSize: CGSize {
            switch self {
            case .horizontal: CGSize(width: 400, height: 80)
            case .vertikal: CGSize(width: 200, height: 150)
            case .signet: CGSize(width: 120, height: 72)
            }
        }

        var aspectRatio: CGFloat { canvasSize.width / canvasSize.height }
    }

    static let wordmark = "Ostsicht"
    static let tagline = "VIDEOÜBERWACHUNG OSTSCHWEIZ"
    static let claim = "Alles im Blick."

    // MARK: - Zeichnen

    /// Zeichnet das Logo seitenverhältnistreu und zentriert in `rect`.
    static func draw(_ layout: Layout, variant: Variant = .standard, in rect: CGRect, context cg: CGContext) {
        let canvas = layout.canvasSize
        let scale = min(rect.width / canvas.width, rect.height / canvas.height)
        guard scale > 0, scale.isFinite else { return }
        let origin = CGPoint(
            x: rect.midX - canvas.width * scale / 2,
            y: rect.midY - canvas.height * scale / 2
        )

        cg.saveGState()
        cg.translateBy(x: origin.x, y: origin.y)
        cg.scaleBy(x: scale, y: scale)

        switch layout {
        case .signet:
            drawSignet(variant: variant, offset: .zero, context: cg)
        case .horizontal:
            drawSignet(variant: variant, offset: CGPoint(x: 0, y: 4), context: cg)
            drawText(wordmarkString(size: 46, variant: variant), baseline: CGPoint(x: 132, y: 52), targetWidth: 200, centered: false, context: cg)
            drawText(taglineString(size: 12.5, tracking: 2, variant: variant), baseline: CGPoint(x: 134, y: 72), targetWidth: 255, centered: false, context: cg)
        case .vertikal:
            drawSignet(variant: variant, offset: CGPoint(x: 40, y: 4), context: cg)
            drawText(wordmarkString(size: 38, variant: variant), baseline: CGPoint(x: 100, y: 118), targetWidth: nil, centered: true, context: cg)
            drawText(taglineString(size: 10, tracking: 1.5, variant: variant), baseline: CGPoint(x: 100, y: 140), targetWidth: 170, centered: true, context: cg)
        }
        cg.restoreGState()
    }

    /// Signet im Koordinatensystem 120 × 72 (wie `ostsicht-signet.svg`).
    private static func drawSignet(variant: Variant, offset: CGPoint, context cg: CGContext) {
        let gruen = OstsichtColor.gruen.cgColor
        let sonne = OstsichtColor.sonne.cgColor
        let anthrazit = OstsichtColor.anthrazit.cgColor
        let weiss = UIColor.white.cgColor

        let rayColor: CGColor
        let domeColor: CGColor
        let baseColor: CGColor
        let horizonColor: CGColor
        switch variant {
        case .standard:
            rayColor = gruen; domeColor = sonne; baseColor = anthrazit; horizonColor = gruen
        case .negativ:
            rayColor = weiss; domeColor = sonne; baseColor = weiss; horizonColor = weiss
        case .mono:
            rayColor = anthrazit; domeColor = anthrazit; baseColor = anthrazit; horizonColor = anthrazit
        }

        cg.saveGState()
        cg.translateBy(x: offset.x, y: offset.y)

        // Fünf Strahlen
        let rays = CGMutablePath()
        for (from, to) in [((60, 8), (60, 1)), ((36, 18), (31, 12)), ((84, 18), (89, 12)), ((23, 34), (16, 31)), ((97, 34), (104, 31))] {
            rays.move(to: CGPoint(x: from.0, y: from.1))
            rays.addLine(to: CGPoint(x: to.0, y: to.1))
        }
        cg.addPath(rays)
        cg.setStrokeColor(rayColor)
        cg.setLineWidth(3.5)
        cg.setLineCap(.round)
        cg.strokePath()

        // Sonne/Kuppel: Halbkreis über (60, 50), Radius 28
        // (y-Achse zeigt nach unten: von links über oben nach rechts)
        let dome = CGMutablePath()
        dome.addArc(center: CGPoint(x: 60, y: 50), radius: 28, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        dome.closeSubpath()
        cg.addPath(dome)
        cg.setFillColor(domeColor)
        cg.fillPath()

        // Objektiv mit Lichtpunkt
        if variant == .mono {
            fillCircle(center: CGPoint(x: 60, y: 38), radius: 9, color: weiss, context: cg)
            fillCircle(center: CGPoint(x: 60, y: 38), radius: 5, color: anthrazit, context: cg)
            fillCircle(center: CGPoint(x: 60, y: 38), radius: 2, color: weiss, context: cg)
        } else {
            fillCircle(center: CGPoint(x: 60, y: 38), radius: 9, color: anthrazit, context: cg)
            fillCircle(center: CGPoint(x: 60, y: 38), radius: 3.5, color: weiss, context: cg)
        }

        // Sockel
        cg.addPath(CGPath(roundedRect: CGRect(x: 22, y: 50, width: 76, height: 7), cornerWidth: 2, cornerHeight: 2, transform: nil))
        cg.setFillColor(baseColor)
        cg.fillPath()

        // Horizontlinie
        cg.move(to: CGPoint(x: 8, y: 66))
        cg.addLine(to: CGPoint(x: 112, y: 66))
        cg.setStrokeColor(horizonColor)
        cg.setLineWidth(3)
        cg.setLineCap(.butt)
        cg.strokePath()

        cg.restoreGState()
    }

    private static func fillCircle(center: CGPoint, radius: CGFloat, color: CGColor, context cg: CGContext) {
        cg.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        cg.setFillColor(color)
        cg.fillPath()
    }

    // MARK: - Schriftzug

    /// «Ost» in Anthrazit, «sicht» in Grün (negativ: beides weiss).
    private static func wordmarkString(size: CGFloat, variant: Variant) -> NSMutableAttributedString {
        let font = BrandFont.uiFont(size: size, weight: .semibold)
        let ostColor: UIColor
        let sichtColor: UIColor
        switch variant {
        case .standard: ostColor = OstsichtColor.anthrazit; sichtColor = OstsichtColor.gruen
        case .negativ: ostColor = .white; sichtColor = .white
        case .mono: ostColor = OstsichtColor.anthrazit; sichtColor = OstsichtColor.anthrazit
        }
        let string = NSMutableAttributedString(string: "Ost", attributes: [.font: font, .foregroundColor: ostColor, .kern: 0.5])
        string.append(NSAttributedString(string: "sicht", attributes: [.font: font, .foregroundColor: sichtColor, .kern: 0.5]))
        return string
    }

    private static func taglineString(size: CGFloat, tracking: CGFloat, variant: Variant) -> NSMutableAttributedString {
        let color: UIColor = switch variant {
        case .standard: OstsichtColor.grau
        case .negativ: OstsichtColor.gruenHell
        case .mono: OstsichtColor.anthrazit
        }
        return NSMutableAttributedString(string: tagline, attributes: [
            .font: BrandFont.uiFont(size: size, weight: .medium),
            .foregroundColor: color,
            .kern: tracking
        ])
    }

    /// Zeichnet Text auf einer Grundlinie. Mit `targetWidth` wird die Sperrung so angepasst,
    /// dass der Text die Breite aus der SVG-Vorlage (`textLength`) einnimmt.
    private static func drawText(_ string: NSMutableAttributedString, baseline: CGPoint, targetWidth: CGFloat?, centered: Bool, context cg: CGContext) {
        guard let font = string.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else { return }
        if let targetWidth, string.length > 1 {
            let natural = string.size().width
            let currentKern = (string.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat) ?? 0
            let extra = (targetWidth - natural) / CGFloat(string.length - 1)
            string.addAttribute(.kern, value: currentKern + extra, range: NSRange(location: 0, length: string.length - 1))
            string.addAttribute(.kern, value: 0, range: NSRange(location: string.length - 1, length: 1))
        }
        let width = string.size().width
        let x = centered ? baseline.x - width / 2 : baseline.x
        UIGraphicsPushContext(cg)
        string.draw(at: CGPoint(x: x, y: baseline.y - font.ascender))
        UIGraphicsPopContext()
    }
}

// MARK: - SwiftUI

/// Ostsicht-Logo als SwiftUI-View. Die Höhe bestimmt die Grösse, die Breite folgt dem Seitenverhältnis.
struct OstsichtLogo: View {
    var layout: OstsichtBrand.Layout = .horizontal
    var variant: OstsichtBrand.Variant = .standard

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cg in
                OstsichtBrand.draw(layout, variant: variant, in: CGRect(origin: .zero, size: size), context: cg)
            }
        }
        .aspectRatio(layout.aspectRatio, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(layout == .signet ? "Ostsicht" : "Ostsicht – Videoüberwachung Ostschweiz")
        .accessibilityAddTraits(.isImage)
    }
}

/// Grüne Horizontlinie aus dem Signet als Gestaltungselement (z. B. als Abschluss von Kopf- und Fusszeilen).
struct HorizonLine: View {
    var color: Color = Theme.gruenSolid
    var height: CGFloat = 3

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// Markenkopf auf Grün: Logo negativ und Claim. Für das Dashboard.
struct BrandHeader: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OstsichtLogo(layout: .horizontal, variant: .negativ)
                .frame(height: horizontalSizeClass == .compact ? 40 : 52)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(OstsichtBrand.claim)
                .font(.brand(.title2))
                .foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gruenSolid, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
