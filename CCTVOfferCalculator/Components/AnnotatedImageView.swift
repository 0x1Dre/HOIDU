import SwiftUI
import UIKit
import CCTVCore

/// Zeigt ein Foto mit seinen Markierungen (Pfeil/Kreis) als Overlay an.
struct AnnotatedImageView: View {
    let image: UIImage
    let markers: [PhotoMarker]

    var body: some View {
        GeometryReader { geometry in
            let container = CGRect(origin: .zero, size: geometry.size)
            let imageRect = MarkerGeometry.aspectFitRect(imageSize: image.size, in: container)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                MarkerOverlay(markers: markers, imageRect: imageRect)
            }
        }
        .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(markers.isEmpty ? "Foto" : "Foto mit \(markers.count) Markierungen")
    }
}

struct MarkerOverlay: View {
    let markers: [PhotoMarker]
    let imageRect: CGRect

    var body: some View {
        let markers = markers
        let rect = imageRect
        Canvas { context, _ in
            let width = MarkerGeometry.lineWidth(in: rect)
            for marker in markers {
                let path = Path(MarkerGeometry.path(for: marker, in: rect))
                context.stroke(path, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: width + 2, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Lädt ein Vorschaubild asynchron aus den JPEG-Daten.
struct PhotoThumbnail: View {
    let photo: PhotoRecord
    var size: CGFloat = 120

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.subtle)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: photo.imageData == nil ? "photo.badge.exclamationmark" : "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            if !photo.markers.isEmpty {
                Image(systemName: "pencil.tip.crop.circle.fill")
                    .foregroundStyle(.white, .red)
                    .font(.title3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .task(id: photo.id) {
            if let data = photo.imageData {
                image = ImageProcessing.thumbnail(from: data)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(photo.caption.isEmpty ? "Foto ohne Beschriftung" : "Foto: \(photo.caption)")
    }
}
