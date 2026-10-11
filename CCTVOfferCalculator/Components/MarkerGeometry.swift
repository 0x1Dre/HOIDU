import CoreGraphics
import Foundation
import CCTVCore

/// Gemeinsame Geometrie für Markierungen in der App und im PDF.
enum MarkerGeometry {
    static func point(_ x: Double, _ y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat(x) * rect.width, y: rect.minY + CGFloat(y) * rect.height)
    }

    static func lineWidth(in rect: CGRect) -> CGFloat {
        max(2, rect.width * 0.008)
    }

    static func path(for marker: PhotoMarker, in rect: CGRect) -> CGPath {
        let start = point(marker.startX, marker.startY, in: rect)
        let end = point(marker.endX, marker.endY, in: rect)
        let path = CGMutablePath()
        switch marker.kind {
        case .pfeil:
            path.move(to: start)
            path.addLine(to: end)
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLength = max(12, rect.width * 0.045)
            let spread = CGFloat.pi / 7
            for direction in [-1.0, 1.0] {
                let headAngle = angle + .pi + CGFloat(direction) * spread
                path.move(to: end)
                path.addLine(to: CGPoint(x: end.x + cos(headAngle) * headLength, y: end.y + sin(headAngle) * headLength))
            }
        case .kreis:
            let radius = max(8, hypot(end.x - start.x, end.y - start.y))
            path.addEllipse(in: CGRect(x: start.x - radius, y: start.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    /// Rechteck, in dem ein Bild mit `scaledToFit` innerhalb eines Containers dargestellt wird.
    static func aspectFitRect(imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: container.midX - size.width / 2,
            y: container.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
