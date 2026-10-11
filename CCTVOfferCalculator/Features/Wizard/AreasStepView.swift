import SwiftUI
import CCTVCore

struct AreasStepView: View {
    @Bindable var viewModel: WizardViewModel
    @State private var editing: AreaEditing?

    struct AreaEditing: Identifiable {
        let area: SiteAreaRecord
        let isNew: Bool
        var id: UUID { area.id }
    }

    struct AreaTemplate: Identifiable {
        let name: String
        let location: AreaLocation
        let target: DetectionTarget
        let purposes: Set<AreaPurpose>
        var id: String { name }
    }

    private static let templates: [AreaTemplate] = [
        AreaTemplate(name: "Hauseingang", location: .aussen, target: .gesicht, purposes: [.abschreckung, .zufahrtZutritt]),
        AreaTemplate(name: "Einfahrt / Parkplatz", location: .aussen, target: .fahrzeug, purposes: [.zufahrtZutritt, .einbruchVandalismus]),
        AreaTemplate(name: "Garten / Umgebung", location: .aussen, target: .person, purposes: [.einbruchVandalismus]),
        AreaTemplate(name: "Verkaufsraum", location: .innen, target: .person, purposes: [.diebstahlpraevention]),
        AreaTemplate(name: "Kasse", location: .innen, target: .kasseVorgang, purposes: [.diebstahlpraevention]),
        AreaTemplate(name: "Lager", location: .innen, target: .person, purposes: [.diebstahlpraevention, .einbruchVandalismus]),
        AreaTemplate(name: "Anlieferung / Rampe", location: .aussen, target: .fahrzeug, purposes: [.prozesskontrolle, .zufahrtZutritt])
    ]

    var body: some View {
        Form {
            if !viewModel.issues(for: .bereiche).isEmpty {
                Section {
                    ValidationBanner(issues: viewModel.issues(for: .bereiche))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                if viewModel.draft.areas.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Bereiche",
                        systemImage: "video.badge.plus",
                        description: Text("Erfassen Sie jeden Bereich, der überwacht werden soll – zum Beispiel Eingang, Parkplatz oder Lager. Pro Bereich können Sie Kamerapositionen fotografieren.")
                    )
                } else {
                    ForEach(viewModel.draft.areas) { area in
                        Button {
                            editing = AreaEditing(area: area, isNew: false)
                        } label: {
                            AreaRow(area: area)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if let index = viewModel.draft.areas.firstIndex(where: { $0.id == area.id }) {
                                    viewModel.deleteAreas(at: IndexSet(integer: index))
                                }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            Button {
                                viewModel.duplicateArea(area)
                            } label: {
                                Label("Duplizieren", systemImage: "plus.square.on.square")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { viewModel.moveAreas(from: $0, to: $1) }
                }
            } header: {
                Text("Überwachungsbereiche")
            } footer: {
                if !viewModel.draft.areas.isEmpty {
                    Text("Total \(viewModel.draft.totalCameras) Kameras in \(viewModel.draft.areas.count) Bereichen · \(viewModel.draft.photoCount) Fotos. Zum Löschen nach links wischen.")
                }
            }

            Section {
                Button {
                    editing = AreaEditing(area: SiteAreaRecord(), isNew: true)
                } label: {
                    ActionLabel(title: "Bereich hinzufügen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Menu {
                    ForEach(Self.templates) { template in
                        Button(template.name) {
                            editing = AreaEditing(
                                area: SiteAreaRecord(name: template.name, location: template.location, purposes: template.purposes,
                                                     detectionTarget: template.target),
                                isNew: true
                            )
                        }
                    }
                } label: {
                    ActionLabel(title: "Aus Vorlage hinzufügen", systemImage: "square.grid.2x2", prominent: false)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { item in
            AreaEditorView(area: item.area, isNew: item.isNew) { updated in
                viewModel.upsertArea(updated)
            }
        }
    }
}

struct AreaRow: View {
    let area: SiteAreaRecord

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: area.location == .aussen ? "sun.max" : "house")
                .font(.title2)
                .foregroundStyle(Theme.navy)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(area.name.isEmpty ? "Ohne Namen" : area.name)
                    .font(.headline)
                Text("\(area.location.label) · \(area.detectionTarget.label) · Nachtsicht: \(area.nightVision.label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !area.purposes.isEmpty {
                    Text(area.purposes.labels)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label("\(area.camera.quantity) Kameras", systemImage: "video")
                    Label("\(area.positions.count) Positionen", systemImage: "mappin.and.ellipse")
                    Label("\(area.allPhotos.count) Fotos", systemImage: "photo")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Bereich bearbeiten")
    }
}
