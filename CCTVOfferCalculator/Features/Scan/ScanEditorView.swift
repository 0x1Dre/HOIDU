import SwiftUI
import SceneKit
import simd
import CCTVCore

/// Änderungen an einem Scan, die der Editor speichert.
struct ScanEdits: Equatable {
    var name: String
    var note: String
    var placements: [ScanCameraPlacement]
    var photos: [PhotoRecord]
    var photoPoses: [ScanPhotoPose]
    var areaID: UUID?
}

/// Bearbeitung eines 3D-Scans: Kameras im Modell platzieren, ausrichten und mit Kamerapositionen verknüpfen;
/// Fotos und Überwachungsbereich zuordnen.
struct ScanEditorView: View {
    let project: ProjectRecord
    let scanID: UUID
    /// Speichert die Änderungen (verzögert, damit Schieberegler nicht bei jedem Schritt speichern).
    let onChange: (ScanEdits) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scene: SCNScene?
    @State private var loadError: String?
    @State private var name = ""
    @State private var note = ""
    @State private var placements: [ScanCameraPlacement] = []
    @State private var photos: [PhotoRecord] = []
    @State private var photoPoses: [ScanPhotoPose] = []
    @State private var areaID: UUID?
    @State private var thumbnails: [UUID: UIImage] = [:]
    @State private var viewingPhoto: PhotoRecord?
    @State private var selectedID: UUID?
    @State private var isPlacing = false
    @State private var mode: Mode = .model
    @State private var saveTask: Task<Void, Never>?
    @State private var didLoad = false
    @State private var confirmDelete = false
    @State private var showRename = false

    private enum Mode: String, CaseIterable, Identifiable {
        case model, plan, photos
        var id: String { rawValue }
        var title: String {
            switch self {
            case .model: "3D"
            case .plan: "Grundriss"
            case .photos: "Fotos"
            }
        }
    }

    private var edits: ScanEdits {
        // Aufnahmeorte gelöschter Fotos nicht behalten.
        let ids = Set(photos.map(\.id))
        return ScanEdits(name: name, note: note, placements: placements, photos: photos,
                         photoPoses: photoPoses.filter { ids.contains($0.photoID) }, areaID: areaID)
    }

    private var scan: SiteScanRecord? { project.scans.first { $0.id == scanID } }

    /// Scan mit den aktuell bearbeiteten Platzierungen (für Nummern und Grundriss).
    private var liveScan: SiteScanRecord? {
        guard var scan else { return nil }
        scan.placements = placements
        return scan
    }

    private var markers: [DocumentFloorPlanMarker] {
        guard let liveScan else { return [] }
        return project.floorPlanMarkers(for: liveScan)
    }

    private var numbers: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: zip(placements.map(\.id), markers.map(\.number)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                switch mode {
                case .model: modelView
                case .plan: planView
                case .photos: photosView
                }
            }
            .background(Theme.background)
            .navigationTitle(name.isEmpty ? (scan?.kind.label ?? "3D-Scan") : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        flushSave()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showRename = true
                        } label: {
                            Label("Umbenennen", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Scan löschen", systemImage: "trash")
                        }
                    } label: {
                        Label("Mehr", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: selectedBinding) { item in
                PlacementEditor(
                    placement: binding(for: item.id),
                    number: numbers[item.id] ?? 0,
                    positions: project.allPositions,
                    onDelete: {
                        placements.removeAll { $0.id == item.id }
                        selectedID = nil
                    }
                )
                .presentationDetents([.height(320), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
            }
            .alert("Scan umbenennen", isPresented: $showRename) {
                TextField("Name", text: $name)
                Button("OK") {}
            }
            .confirmationDialog("Scan löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    saveTask?.cancel()
                    onDelete()
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das 3D-Modell und alle darin platzierten Kameras werden entfernt.")
            }
        }
        .task {
            guard !didLoad, let scan else { return }
            didLoad = true
            name = scan.name
            note = scan.note
            placements = scan.placements
            photos = scan.photos
            photoPoses = scan.photoPoses
            areaID = scan.areaID
            thumbnails = Self.makeThumbnails(scan.photos, poses: scan.photoPoses)
            guard let data = scan.modelData else {
                loadError = "Für diesen Scan ist kein 3D-Modell gespeichert (z. B. nach einem Import ohne Fotos)."
                mode = .plan
                return
            }
            do {
                let loaded = try ScanModelFile.scene(from: data)
                scene = loaded
                // Sichtweite für Kameras nachrechnen, die noch keine haben (z. B. aus älteren Versionen).
                if placements.contains(where: { $0.planReach.isEmpty }) {
                    placements = placements.map { $0.planReach.isEmpty ? withReach($0, in: loaded) : $0 }
                }
            } catch {
                loadError = "Das 3D-Modell konnte nicht geladen werden."
                mode = .plan
            }
        }
        .onChange(of: placements) { _, _ in scheduleSave() }
        .onChange(of: name) { _, _ in scheduleSave() }
        .onChange(of: photos) { _, _ in scheduleSave() }
        .onChange(of: areaID) { _, _ in scheduleSave() }
        .onDisappear { flushSave() }
    }

    // MARK: - Ansichten

    @ViewBuilder
    private var modelView: some View {
        if let scene {
            ZStack(alignment: .bottom) {
                ScanSceneView(
                    scene: scene,
                    placements: placements,
                    numbers: numbers,
                    selectedID: selectedID,
                    isPlacing: isPlacing,
                    photoPoses: photoPoses.filter { pose in photos.contains { $0.id == pose.photoID } },
                    photoThumbnails: thumbnails,
                    onPlace: place,
                    onSelect: { selectedID = $0 },
                    onSelectPhoto: { id in viewingPhoto = photos.first { $0.id == id } }
                )
                .ignoresSafeArea(edges: .bottom)
                .sheet(item: $viewingPhoto) { photo in
                    NavigationStack {
                        PhotoViewer(photo: photo)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Fertig") { viewingPhoto = nil }
                                }
                            }
                    }
                }

                VStack(spacing: 8) {
                    if isPlacing {
                        Label("Tippen Sie auf die Wand oder Stelle, an der die Kamera montiert wird.", systemImage: "hand.tap")
                            .font(.brand(.subheadline))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.smallRadius))
                    }
                    Button {
                        isPlacing.toggle()
                        if isPlacing { selectedID = nil }
                    } label: {
                        Label(isPlacing ? "Abbrechen" : "Kamera setzen", systemImage: isPlacing ? "xmark" : "plus.viewfinder")
                            .frame(maxWidth: 320)
                    }
                    .buttonStyle(.primaryAction)
                }
                .padding()
            }
        } else if let loadError {
            ContentUnavailableView("Kein 3D-Modell", systemImage: "cube.transparent", description: Text(loadError))
        } else {
            ProgressView("3D-Modell wird geladen …")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var planView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let floorPlan = scan?.floorPlan {
                    FloorPlanView(floorPlan: floorPlan, markers: markers, highlighted: selectedID.flatMap { numbers[$0] })
                        .card(padding: 8)
                } else {
                    ContentUnavailableView("Kein Grundriss", systemImage: "map", description: Text("Für diesen Scan liegt kein Grundriss vor."))
                }

                if markers.isEmpty {
                    Text("Noch keine Kameras platziert. Wechseln Sie zur 3D-Ansicht und tippen Sie auf «Kamera setzen».")
                        .font(.brand(.subheadline))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(zip(placements, markers)), id: \.0.id) { placement, marker in
                            Button {
                                selectedID = placement.id
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(marker.number)")
                                        .font(.brand(.subheadline).weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Theme.gruenSolid, in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(marker.label).font(.brand(.headline))
                                        Text(summary(placement))
                                            .font(.brand(.caption))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notiz").brandLabel()
                    TextField("z. B. Erdgeschoss, Werkstatt", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit { scheduleSave() }
                }
                .card()
            }
            .padding()
        }
        .onChange(of: note) { _, _ in scheduleSave() }
    }

    // MARK: - Fotos

    private var linkedArea: SiteAreaRecord? {
        areaID.flatMap { id in project.areas.first { $0.id == id } }
    }

    private var photosView: some View {
        Form {
            Section {
                Picker("Überwachungsbereich", selection: $areaID) {
                    Text("Keiner").tag(UUID?.none)
                    ForEach(project.areas) { area in
                        Text(area.name.isEmpty ? "Ohne Namen" : area.name).tag(UUID?.some(area.id))
                    }
                }
            } footer: {
                Text("Verknüpft den Scan mit einem Bereich. Dessen Fotos erscheinen hier, der Bereich steht beim Grundriss in der Offerte.")
            }

            Section {
                PhotoGalleryEditor(photos: $photos, captionSuggestion: name.isEmpty ? "Scan" : name)
            } header: {
                Text("Fotos zum Scan")
            } footer: {
                Text("Aufnahmen vom Scannen sind im 3D-Modell an ihrem Standort zu sehen; antippen öffnet das Foto.")
            }

            if let linkedArea {
                let areaPhotos = linkedArea.allPhotos
                Section("Fotos aus «\(linkedArea.name)»") {
                    if areaPhotos.isEmpty {
                        Text("Keine Fotos im Bereich erfasst.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(areaPhotos) { photo in
                                    Button {
                                        viewingPhoto = photo
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            PhotoThumbnail(photo: photo, size: 110)
                                            Text(photo.caption.isEmpty ? "Foto" : photo.caption)
                                                .font(.brand(.caption))
                                                .lineLimit(1)
                                                .frame(width: 110, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(item: $viewingPhoto) { photo in
            NavigationStack {
                PhotoViewer(photo: photo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { viewingPhoto = nil }
                        }
                    }
            }
        }
    }

    /// Kleine Vorschaubilder für die Fotos im 3D-Modell.
    private static func makeThumbnails(_ photos: [PhotoRecord], poses: [ScanPhotoPose]) -> [UUID: UIImage] {
        let posed = Set(poses.map(\.photoID))
        var result: [UUID: UIImage] = [:]
        for photo in photos where posed.contains(photo.id) {
            if let data = photo.imageData, let image = ImageProcessing.thumbnail(from: data, maxPixel: 256) {
                result[photo.id] = image
            }
        }
        return result
    }

    private func summary(_ placement: ScanCameraPlacement) -> String {
        [
            project.areaName(for: placement),
            "Blick \(placement.directionLabel)",
            "\(Int(placement.fieldOfViewDegrees))°",
            "\(Int(placement.rangeMeters)) m"
        ].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Aktionen

    private var selectedBinding: Binding<SelectedPlacement?> {
        Binding(
            get: { selectedID.flatMap { id in placements.contains { $0.id == id } ? SelectedPlacement(id: id) : nil } },
            set: { selectedID = $0?.id }
        )
    }

    private func binding(for id: UUID) -> Binding<ScanCameraPlacement> {
        Binding(
            get: { placements.first { $0.id == id } ?? ScanCameraPlacement(x: 0, y: 0, z: 0) },
            set: { updated in
                guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
                var updated = updated
                // Sichtweite nur neu berechnen, wenn sich Lage oder Blickfeld geändert hat.
                if ScanVisibility.Key(updated) != ScanVisibility.Key(placements[index]), let scene {
                    updated = withReach(updated, in: scene)
                }
                placements[index] = updated
            }
        )
    }

    private func place(at point: SIMD3<Float>, normal: SIMD3<Float>) {
        var position = point + normal * 0.08
        var yaw = ScanCameraPlacement.yaw(fromNormalX: Double(normal.x), normalZ: Double(normal.z))
        if yaw == nil && normal.y > 0.7 {
            // Tipp auf den Boden: Kamera auf übliche Montagehöhe setzen.
            position.y = point.y + 2.5
        }
        if yaw == nil { yaw = 0 }

        // Nächste noch nicht verknüpfte Kameraposition vorschlagen.
        let linked = Set(placements.compactMap(\.positionID))
        let suggestion = project.allPositions.first { !linked.contains($0.position.id) }?.position.id

        var placement = ScanCameraPlacement(
            positionID: suggestion,
            x: Double(position.x),
            y: Double(position.y),
            z: Double(position.z),
            yawDegrees: yaw ?? 0
        )
        if let scene { placement = withReach(placement, in: scene) }
        placements.append(placement)
        isPlacing = false
        selectedID = placement.id
    }

    private func withReach(_ placement: ScanCameraPlacement, in scene: SCNScene) -> ScanCameraPlacement {
        var placement = placement
        placement.planReach = ScanVisibility.planReach(in: scene.rootNode, for: placement)
        return placement
    }

    private func scheduleSave() {
        guard didLoad else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            onChange(edits)
        }
    }

    private func flushSave() {
        guard didLoad, let saveTask else { return }
        saveTask.cancel()
        self.saveTask = nil
        onChange(edits)
    }
}

private struct SelectedPlacement: Identifiable {
    let id: UUID
}

/// Einstellungen einer platzierten Kamera.
struct PlacementEditor: View {
    @Binding var placement: ScanCameraPlacement
    let number: Int
    let positions: [(area: SiteAreaRecord, position: CameraPositionRecord)]
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kameraposition", selection: $placement.positionID) {
                        Text("Keine Verknüpfung").tag(UUID?.none)
                        ForEach(positions, id: \.position.id) { entry in
                            Text("\(entry.position.label.isEmpty ? "Ohne Namen" : entry.position.label) · \(entry.area.name)")
                                .tag(UUID?.some(entry.position.id))
                        }
                    }
                    if placement.positionID == nil {
                        TextField("Beschriftung", text: $placement.label, prompt: Text("Kamera \(number)"))
                    }
                } footer: {
                    if positions.isEmpty {
                        Text("Im Projekt sind noch keine Kamerapositionen erfasst. Diese legen Sie im Schritt «Überwachungsbereiche» an.")
                    } else {
                        Text("Verknüpfte Kameras erscheinen mit ihrer Position im Grundriss der Offerte.")
                    }
                }

                Section("Ausrichtung") {
                    slider("Blickrichtung", value: $placement.yawDegrees, range: 0...359, step: 1, unit: "°")
                    slider("Neigung nach unten", value: $placement.tiltDegrees, range: 0...90, step: 1, unit: "°")
                }

                Section("Blickfeld") {
                    slider("Öffnungswinkel", value: $placement.fieldOfViewDegrees, range: 20...180, step: 5, unit: "°")
                    slider("Reichweite", value: $placement.rangeMeters, range: 2...40, step: 1, unit: " m")
                }

                Section {
                    Stepper(value: $placement.y, step: 0.1) {
                        LabeledContent("Höhe im Modell", value: Format.number(placement.y, fractionDigits: 1) + " m")
                    }
                } footer: {
                    Text("Verschiebt die Kamera im Modell in 10-cm-Schritten nach oben oder unten.")
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Kamera entfernen", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Kamera \(number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String, fractionDigits: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(Format.number(value.wrappedValue, fractionDigits: fractionDigits) + unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
        }
    }
}
