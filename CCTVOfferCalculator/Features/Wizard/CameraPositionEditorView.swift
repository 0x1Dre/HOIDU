import SwiftUI
import CCTVCore

/// Montageposition einer Kamera: Beschriftung, Montagehöhe, Blickrichtung, Notiz und Fotos.
/// Zugriff über die ID, damit das Löschen der Position aus dieser Ansicht sicher ist.
struct CameraPositionEditorView: View {
    @Binding var positions: [CameraPositionRecord]
    let positionID: UUID

    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    private var position: CameraPositionRecord? {
        positions.first { $0.id == positionID }
    }

    private func update(_ change: (inout CameraPositionRecord) -> Void) {
        guard let index = positions.firstIndex(where: { $0.id == positionID }) else { return }
        change(&positions[index])
    }

    private var label: Binding<String> {
        Binding(get: { position?.label ?? "" }, set: { value in update { $0.label = value } })
    }

    private var mountingHeight: Binding<String> {
        Binding(get: { position?.mountingHeight ?? "" }, set: { value in update { $0.mountingHeight = value } })
    }

    private var viewDirection: Binding<String> {
        Binding(get: { position?.viewDirection ?? "" }, set: { value in update { $0.viewDirection = value } })
    }

    private var note: Binding<String> {
        Binding(get: { position?.note ?? "" }, set: { value in update { $0.note = value } })
    }

    private var photos: Binding<[PhotoRecord]> {
        Binding(
            get: { position?.photos ?? [] },
            set: { value in update { $0.photos = value } }
        )
    }

    var body: some View {
        Group {
            if let position {
                Form {
                    Section("Position") {
                        TextField("Beschriftung, z. B. Kamera 1 – Nordfassade", text: label)
                            .frame(minHeight: 44)
                        if position.label.trimmingCharacters(in: .whitespaces).isEmpty {
                            FieldError(message: "Bitte eine Beschriftung erfassen.")
                        }
                        TextField("Montagehöhe, z. B. 2.8 m unter Vordach", text: mountingHeight)
                            .frame(minHeight: 44)
                        TextField("Blickrichtung, z. B. Richtung Einfahrt (Nord)", text: viewDirection)
                            .frame(minHeight: 44)
                        TextField("Notiz, z. B. Kabelweg, Untergrund, Steckdose", text: note, axis: .vertical)
                            .lineLimit(2...6)
                    }

                    Section {
                        PhotoGalleryEditor(photos: photos, captionSuggestion: position.label)
                    } header: {
                        Text("Fotos der Position")
                    } footer: {
                        Text("Fotos werden verkleinert und nur lokal gespeichert. Mit «Markieren» lassen sich Montagepunkt und Blickrichtung einzeichnen.")
                    }

                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Position löschen", systemImage: "trash")
                        }
                        .frame(minHeight: 44)
                    }
                }
                .formStyle(.grouped)
                .scrollDismissesKeyboard(.interactively)
            } else {
                ContentUnavailableView("Position gelöscht", systemImage: "trash", description: Text("Diese Kameraposition ist nicht mehr vorhanden."))
            }
        }
        .navigationTitle(position?.label.isEmpty == false ? position!.label : "Kameraposition")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Position löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                dismiss()
                positions.removeAll { $0.id == positionID }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Position und alle zugehörigen Fotos werden entfernt.")
        }
    }
}
