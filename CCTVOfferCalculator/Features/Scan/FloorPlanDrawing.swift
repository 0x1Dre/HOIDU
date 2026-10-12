import SwiftUI
import UIKit
import CCTVCore

/// Zeichnet einen Grundriss mit nummerierten Kameras und Blickfeldern.
/// Wird in der App (Canvas) und im PDF-Export verwendet, damit beide gleich aussehen.
@MainActor
enum FloorPlanDrawing {
    /// Rechteck, in dem das Bild seitenverhältnistreu in `rect` liegt.
    static func imageRect(for bounds: ScanBounds, in rect: CGRect) -> CGRect {
        let aspect = bounds.width / bounds.depth
        var size = CGSize(width: rect.width, height: rect.width / aspect)
        if size.height > rect.height {
            size = CGSize(width: rect.height * aspect, height: rect.height)
        }
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    static func draw(
        image: UIImage,
        bounds: ScanBounds,
        markers: [DocumentFloorPlanMarker],
        highlighted: Int? = nil,
        in rect: CGRect,
        context cg: CGContext
    ) {
        let imageRect = imageRect(for: bounds, in: rect)
        UIGraphicsPushContext(cg)
        image.draw(in: imageRect)
        UIGraphicsPopContext()

        let metersToPoints = imageRect.width / bounds.width
        func point(_ x: Double, _ z: Double) -> CGPoint {
            let relative = bounds.relative(x: x, z: z)
            return CGPoint(x: imageRect.minX + relative.x * imageRect.width, y: imageRect.minY + relative.y * imageRect.height)
        }

        cg.saveGState()
        cg.clip(to: imageRect)

        // Blickfelder
        for marker in markers {
            let center = point(marker.x, marker.z)
            let radius = CGFloat(marker.rangeMeters) * metersToPoints
            let heading = (marker.yawDegrees - 90) * .pi / 180
            let half = min(marker.fieldOfViewDegrees, 359) / 2 * .pi / 180
            let wedge = CGMutablePath()
            wedge.move(to: center)
            wedge.addArc(center: center, radius: radius, startAngle: heading - half, endAngle: heading + half, clockwise: false)
            wedge.closeSubpath()
            let isHighlighted = highlighted == marker.number
            cg.addPath(wedge)
            cg.setFillColor(OstsichtColor.sonne.withAlphaComponent(isHighlighted ? 0.38 : 0.22).cgColor)
            cg.fillPath()
            cg.addPath(wedge)
            cg.setStrokeColor(OstsichtColor.sonne.withAlphaComponent(0.85).cgColor)
            cg.setLineWidth(1)
            cg.strokePath()
        }

        // Kamerapunkte mit Nummer
        let dotRadius: CGFloat = max(7, min(11, imageRect.width / 60))
        for marker in markers {
            let center = point(marker.x, marker.z)
            let dot = CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
            if highlighted == marker.number {
                cg.setFillColor(OstsichtColor.sonne.cgColor)
                cg.fillEllipse(in: dot.insetBy(dx: -3, dy: -3))
            }
            cg.setFillColor(OstsichtColor.gruen.cgColor)
            cg.fillEllipse(in: dot)
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(1.5)
            cg.strokeEllipse(in: dot)

            let label = NSAttributedString(string: "\(marker.number)", attributes: [
                .font: BrandFont.uiFont(size: dotRadius * 1.1, weight: .semibold),
                .foregroundColor: UIColor.white
            ])
            let size = label.size()
            UIGraphicsPushContext(cg)
            label.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
            UIGraphicsPopContext()
        }
        cg.restoreGState()

        // Rahmen
        cg.setStrokeColor(OstsichtColor.grau.withAlphaComponent(0.4).cgColor)
        cg.setLineWidth(0.5)
        cg.stroke(imageRect)
    }
}

/// Grundriss mit Kameras als SwiftUI-View.
struct FloorPlanView: View {
    let floorPlan: ScanFloorPlan
    let markers: [DocumentFloorPlanMarker]
    var highlighted: Int?

    @State private var image: UIImage?

    var body: some View {
        Canvas { context, size in
            guard let image else { return }
            context.withCGContext { cg in
                FloorPlanDrawing.draw(image: image, bounds: floorPlan.bounds, markers: markers, highlighted: highlighted,
                                      in: CGRect(origin: .zero, size: size), context: cg)
            }
        }
        .aspectRatio(floorPlan.bounds.width / floorPlan.bounds.depth, contentMode: .fit)
        .task(id: floorPlan.imageData.count) {
            image = UIImage(data: floorPlan.imageData)
        }
        .accessibilityElement()
        .accessibilityLabel("Grundriss mit \(markers.count) Kameras")
    }
}

extension ProjectRecord {
    /// Grundriss-Markierungen eines Scans mit fortlaufender Nummer über alle Scans des Projekts.
    func floorPlanMarkers(for scan: SiteScanRecord) -> [DocumentFloorPlanMarker] {
        var number = 0
        for other in scans {
            if other.id == scan.id { break }
            number += other.placements.count
        }
        return scan.placements.enumerated().map { offset, placement in
            let value = number + offset + 1
            return DocumentFloorPlanMarker(number: value, label: displayLabel(for: placement, number: value), placement: placement)
        }
    }
}
