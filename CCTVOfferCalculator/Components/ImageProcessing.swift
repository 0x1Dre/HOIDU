import UIKit

/// Verkleinert und komprimiert Fotos vor dem Speichern. Die Ausrichtung wird dabei
/// normalisiert, damit Markierungen und PDF-Ausgabe übereinstimmen.
enum ImageProcessing {
    static let maximumDimension: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.72

    static func preparedJPEG(from image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maximumDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    static func preparedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return preparedJPEG(from: image)
    }

    static func thumbnail(from data: Data, maxPixel: CGFloat = 360) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxPixel / max(size.width, size.height))
        return image.preparingThumbnail(of: CGSize(width: size.width * scale, height: size.height * scale)) ?? image
    }

    static func byteCountText(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}
