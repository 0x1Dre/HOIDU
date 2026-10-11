import SwiftUI
import PhotosUI
import UIKit
import CCTVCore

/// Fotoliste eines Bereichs oder einer Kameraposition mit Aufnahme, Mediathek, Beschriftung,
/// Markierung, Neuaufnahme und Löschen. Wird innerhalb eines Form-Abschnitts verwendet.
struct PhotoGalleryEditor: View {
    @Binding var photos: [PhotoRecord]
    /// Vorschlag für die Beschriftung neuer Fotos, z. B. «Kamera 1 – Nordfassade».
    let captionSuggestion: String

    @State private var cameraTrigger = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importError: String?
    @State private var editing: PhotoSelection?

    struct PhotoSelection: Identifiable {
        let id: UUID
    }

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if photos.isEmpty {
                Text("Noch keine Fotos. Fotografieren Sie die geplante Montageposition direkt vor Ort.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(photos) { photo in
                        Button {
                            editing = PhotoSelection(id: photo.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                PhotoThumbnail(photo: photo, size: 110)
                                Text(photo.caption.isEmpty ? "Ohne Beschriftung" : photo.caption)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                    .frame(width: 110, alignment: .leading)
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityHint("Öffnet Beschriftung, Markierung und Löschen")
                        .contextMenu {
                            Button(role: .destructive) {
                                photos.removeAll { $0.id == photo.id }
                            } label: {
                                Label("Foto löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    cameraTrigger = true
                } label: {
                    ActionLabel(title: "Foto aufnehmen", systemImage: "camera.fill", prominent: true)
                }
                .buttonStyle(.borderless)
                .accessibilityHint(CameraAccess.isCameraAvailable ? "Öffnet die Kamera" : "Keine Kamera verfügbar, bitte Mediathek verwenden")

                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    ActionLabel(title: "Mediathek", systemImage: "photo.on.rectangle", prominent: false)
                }
                .buttonStyle(.borderless)
            }

            if !CameraAccess.isCameraAvailable {
                Label("Auf diesem Gerät ist keine Kamera verfügbar. Fotos können aus der Mediathek gewählt werden.", systemImage: "camera.badge.ellipsis")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isImporting {
                ProgressView("Fotos werden übernommen …")
            }
            if let importError {
                Text(importError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .cameraCapture(trigger: $cameraTrigger) { data in
            appendPhoto(data)
        }
        .sheet(item: $editing) { selection in
            NavigationStack {
                PhotoDetailEditor(photos: $photos, photoID: selection.id)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { editing = nil }
                        }
                    }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importItems(items) }
        }
    }

    private func nextCaption() -> String {
        let base = captionSuggestion.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return "" }
        return photos.isEmpty ? base : "\(base) (\(photos.count + 1))"
    }

    private func appendPhoto(_ data: Data) {
        photos.append(PhotoRecord(caption: nextCaption(), capturedAt: Date(), imageData: data))
    }

    @MainActor
    private func importItems(_ items: [PhotosPickerItem]) async {
        isImporting = true
        importError = nil
        var failed = 0
        for item in items {
            do {
                if let raw = try await item.loadTransferable(type: Data.self),
                   let prepared = ImageProcessing.preparedJPEG(from: raw) {
                    appendPhoto(prepared)
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }
        if failed > 0 {
            importError = failed == 1
                ? "Ein Foto konnte nicht geladen werden. Bitte erneut versuchen oder ein anderes Format wählen."
                : "\(failed) Fotos konnten nicht geladen werden. Bitte erneut versuchen."
        }
        pickerItems = []
        isImporting = false
    }
}

/// Bearbeitung eines einzelnen Fotos. Greift über die ID auf das Foto zu, damit
/// Löschen und Ersetzen sicher sind, auch während die Ansicht geöffnet ist.
struct PhotoDetailEditor: View {
    @Binding var photos: [PhotoRecord]
    let photoID: UUID

    @State private var image: UIImage?
    @State private var retakeTrigger = false
    @State private var replaceItem: PhotosPickerItem?
    @State private var confirmDelete = false
    @State private var showMarkup = false
    @Environment(\.dismiss) private var dismiss

    private var photo: PhotoRecord? {
        photos.first { $0.id == photoID }
    }

    private func update(_ change: (inout PhotoRecord) -> Void) {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else { return }
        change(&photos[index])
    }

    private func text(_ keyPath: WritableKeyPath<PhotoRecord, String>) -> Binding<String> {
        Binding(
            get: { photo?[keyPath: keyPath] ?? "" },
            set: { value in update { $0[keyPath: keyPath] = value } }
        )
    }

    private var markersBinding: Binding<[PhotoMarker]> {
        Binding(
            get: { photo?.markers ?? [] },
            set: { value in update { $0.markers = value } }
        )
    }

    var body: some View {
        Group {
            if let photo {
                Form {
                    Section {
                        if let image {
                            AnnotatedImageView(image: image, markers: photo.markers)
                                .frame(maxHeight: 420)
                                .frame(maxWidth: .infinity)
                        } else {
                            ContentUnavailableView("Bild nicht verfügbar", systemImage: "photo.badge.exclamationmark",
                                                   description: Text("Die Bilddaten fehlen, z. B. nach einem Import ohne Fotos. Bitte neu aufnehmen."))
                        }
                        Button {
                            showMarkup = true
                        } label: {
                            Label(photo.markers.isEmpty ? "Markierung hinzufügen" : "Markierungen bearbeiten (\(photo.markers.count))",
                                  systemImage: "pencil.tip.crop.circle")
                        }
                        .disabled(image == nil)
                        .frame(minHeight: 44)
                    }

                    Section("Beschriftung") {
                        TextField("z. B. Kamera 1 – Nordfassade", text: text(\.caption))
                            .frame(minHeight: 44)
                        TextField("Notiz zum Foto", text: text(\.note), axis: .vertical)
                            .lineLimit(2...5)
                        Toggle("Im Kunden-PDF anzeigen", isOn: Binding(
                            get: { photo.includeInCustomerPDF },
                            set: { value in update { $0.includeInCustomerPDF = value } }
                        ))
                        .frame(minHeight: 44)
                        LabeledContent("Aufgenommen", value: photo.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        if let data = photo.imageData {
                            LabeledContent("Dateigrösse", value: ImageProcessing.byteCountText(data.count))
                        }
                    }

                    Section("Foto ersetzen") {
                        Button {
                            retakeTrigger = true
                        } label: {
                            Label("Neu aufnehmen", systemImage: "camera.rotate")
                        }
                        .frame(minHeight: 44)
                        PhotosPicker(selection: $replaceItem, matching: .images) {
                            Label("Aus Mediathek ersetzen", systemImage: "photo.on.rectangle")
                        }
                        .frame(minHeight: 44)
                    }

                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Foto löschen", systemImage: "trash")
                        }
                        .frame(minHeight: 44)
                    }
                }
            } else {
                ContentUnavailableView("Foto gelöscht", systemImage: "trash", description: Text("Dieses Foto ist nicht mehr vorhanden."))
            }
        }
        .navigationTitle(photo?.caption.isEmpty == false ? photo!.caption : "Foto")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: photo?.imageData?.count) {
            image = photo?.imageData.flatMap(UIImage.init(data:))
        }
        .cameraCapture(trigger: $retakeTrigger) { data in
            replaceImage(with: data)
        }
        .onChange(of: replaceItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let prepared = ImageProcessing.preparedJPEG(from: raw) {
                    replaceImage(with: prepared)
                }
                replaceItem = nil
            }
        }
        .navigationDestination(isPresented: $showMarkup) {
            if let image {
                PhotoMarkupView(image: image, markers: markersBinding)
            }
        }
        .confirmationDialog("Foto löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                photos.removeAll { $0.id == photoID }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Foto und seine Markierungen werden aus dem Projekt entfernt.")
        }
    }

    private func replaceImage(with data: Data) {
        update {
            $0.imageData = data
            $0.capturedAt = Date()
            // Markierungen beziehen sich auf das alte Bild.
            $0.markers = []
        }
        image = UIImage(data: data)
    }
}
