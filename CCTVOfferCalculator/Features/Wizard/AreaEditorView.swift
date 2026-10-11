import SwiftUI
import CCTVCore

/// Erfassung eines Überwachungsbereichs inklusive Kamerapositionen und Fotos.
struct AreaEditorView: View {
    let isNew: Bool
    let onSave: (SiteAreaRecord) -> Void

    @State private var area: SiteAreaRecord
    @State private var nameError: String?
    @State private var path: [PositionSelection] = []
    @State private var quantityNotice: String?
    @Environment(\.dismiss) private var dismiss

    struct PositionSelection: Identifiable, Hashable {
        let id: UUID
    }

    private static let megapixelOptions = [0, 2, 4, 5, 8, 12]

    init(area: SiteAreaRecord, isNew: Bool, onSave: @escaping (SiteAreaRecord) -> Void) {
        _area = State(initialValue: area)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section("Bereich") {
                    TextField("Name, z. B. Einfahrt Nord", text: $area.name)
                        .frame(minHeight: 44)
                    FieldError(message: nameError)
                    OptionPicker(title: "Lage", selection: $area.location, segmented: true)
                }

                Section("Zweck") {
                    OptionChips(selection: $area.purposes)
                    if area.purposes.isEmpty {
                        FieldError(message: "Bitte mindestens einen Zweck wählen.")
                    }
                }

                Section {
                    OptionPicker(title: "Erkennungsziel", selection: $area.detectionTarget)
                    LabeledContent("Richtwert") {
                        Text("\(area.detectionTarget.pixelDensityHint), mind. \(area.detectionTarget.minimumMegapixels) MP")
                            .multilineTextAlignment(.trailing)
                    }
                    OptionPicker(title: "Nachtsicht", selection: $area.nightVision, segmented: true)
                    OptionPicker(title: "Audio", selection: $area.audio, segmented: true)
                    if area.audio != .nein {
                        Label("Audio ist datenschutzrechtlich heikel. Der Kunde muss die Zulässigkeit klären.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Erkennung")
                }

                Section("Kameras") {
                    Stepper(value: $area.camera.quantity, in: 1...ProjectValidator.maximumCamerasPerArea) {
                        LabeledContent("Gewünschte Kameraanzahl", value: "\(area.camera.quantity)")
                    }
                    .frame(minHeight: 44)
                    OptionPicker(title: "Bauform", selection: $area.camera.formFactor)
                    Picker("Auflösung", selection: $area.camera.preferredMegapixels) {
                        ForEach(Self.megapixelOptions, id: \.self) { value in
                            Text(value == 0 ? "Automatisch (\(area.detectionTarget.minimumMegapixels) MP)" : "\(value) MP").tag(value)
                        }
                    }
                    .frame(minHeight: 44)
                    Stepper(value: $area.camera.distanceMeters, in: 1...150) {
                        LabeledContent("Distanz zum Objekt", value: "\(area.camera.distanceMeters) m")
                    }
                    .frame(minHeight: 44)
                }

                Section {
                    if area.positions.isEmpty {
                        Text("Legen Sie für jede Kamera eine Position an und fotografieren Sie den geplanten Montagepunkt.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(area.positions) { position in
                        NavigationLink(value: PositionSelection(id: position.id)) {
                            PositionRow(position: position)
                        }
                    }
                    .onDelete { area.positions.remove(atOffsets: $0) }

                    Button {
                        addPosition()
                    } label: {
                        ActionLabel(title: "Kameraposition hinzufügen", systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.borderless)
                    if let quantityNotice {
                        Text(quantityNotice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Kamerapositionen (\(area.positions.count) von \(area.camera.quantity))")
                } footer: {
                    Text("Pro Position mehrere Fotos mit Beschriftung, Montagehöhe und Blickrichtung. Zum Löschen nach links wischen.")
                }

                Section {
                    PhotoGalleryEditor(photos: $area.photos, captionSuggestion: area.name.isEmpty ? "Übersicht" : "Übersicht \(area.name)")
                } header: {
                    Text("Übersichtsfotos des Bereichs")
                }

                Section("Notiz") {
                    TextField("Besonderheiten, Hindernisse, Montageuntergrund", text: $area.notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .formStyle(.grouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "Neuer Bereich" : (area.name.isEmpty ? "Bereich" : area.name))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PositionSelection.self) { selection in
                CameraPositionEditorView(positions: $area.positions, positionID: selection.id)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Hinzufügen" : "Übernehmen") { commit() }
                        .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(!area.allPhotos.isEmpty || !area.name.isEmpty)
        }
    }

    private func addPosition() {
        let position = CameraPositionRecord(label: area.nextPositionLabel)
        area.positions.append(position)
        if area.positions.count > area.camera.quantity {
            area.camera.quantity = area.positions.count
            quantityNotice = "Kameraanzahl automatisch auf \(area.camera.quantity) erhöht."
        }
        path.append(PositionSelection(id: position.id))
    }

    private func commit() {
        let trimmed = area.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            nameError = "Bitte einen Namen für den Bereich erfassen."
            return
        }
        area.name = trimmed
        onSave(area)
        dismiss()
    }
}

struct PositionRow: View {
    let position: CameraPositionRecord

    var body: some View {
        HStack(spacing: 12) {
            if let first = position.photos.first {
                PhotoThumbnail(photo: first, size: 56)
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(position.label.isEmpty ? "Ohne Beschriftung" : position.label)
                    .font(.headline)
                let details = position.detailLines.joined(separator: " · ")
                if !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(position.photos.count == 1 ? "1 Foto" : "\(position.photos.count) Fotos")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
