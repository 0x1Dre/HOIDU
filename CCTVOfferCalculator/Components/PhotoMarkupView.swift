import SwiftUI
import UIKit
import CCTVCore

/// Einfache Markierung auf dem Foto: Pfeil für die Blickrichtung, Kreis für den Montagepunkt.
/// Markierungen werden getrennt vom Bild gespeichert und können jederzeit entfernt werden.
struct PhotoMarkupView: View {
    let image: UIImage
    @Binding var markers: [PhotoMarker]

    @State private var tool: PhotoMarkerKind = .pfeil
    @State private var draft: PhotoMarker?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Picker("Werkzeug", selection: $tool) {
                ForEach(PhotoMarkerKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)

            Text(tool == .pfeil
                 ? "Vom Montagepunkt in Blickrichtung ziehen."
                 : "Im Montagepunkt beginnen und für die Grösse nach aussen ziehen.")
                .font(.brand(.subheadline))
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                let container = CGRect(origin: .zero, size: geometry.size)
                let imageRect = MarkerGeometry.aspectFitRect(imageSize: image.size, in: container)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    MarkerOverlay(markers: markers + (draft.map { [$0] } ?? []), imageRect: imageRect)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            draft = marker(from: value.startLocation, to: value.location, in: imageRect)
                        }
                        .onEnded { value in
                            if let marker = marker(from: value.startLocation, to: value.location, in: imageRect) {
                                markers.append(marker)
                            }
                            draft = nil
                        }
                )
                .accessibilityLabel("Foto zum Markieren. Mit dem Finger ziehen, um eine Markierung zu setzen.")
            }
            .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    _ = markers.popLast()
                } label: {
                    Label("Letzte entfernen", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.secondaryAction)
                .disabled(markers.isEmpty)

                Button(role: .destructive) {
                    markers.removeAll()
                } label: {
                    Label("Alle entfernen", systemImage: "trash")
                }
                .buttonStyle(.secondaryAction)
                .disabled(markers.isEmpty)

                Spacer()

                Button("Fertig") { dismiss() }
                    .buttonStyle(.primaryAction)
            }
        }
        .padding()
        .navigationTitle("Markieren")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func marker(from start: CGPoint, to end: CGPoint, in rect: CGRect) -> PhotoMarker? {
        guard rect.width > 0, rect.height > 0, rect.contains(start) else { return nil }
        return PhotoMarker(
            kind: tool,
            startX: Double((start.x - rect.minX) / rect.width),
            startY: Double((start.y - rect.minY) / rect.height),
            endX: Double((end.x - rect.minX) / rect.width),
            endY: Double((end.y - rect.minY) / rect.height)
        )
    }
}
