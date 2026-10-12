import SwiftUI
import CCTVCore

/// Reiter «3D» im Projekt: Räume und Umgebung scannen, Kameras im Modell platzieren.
struct ProjectScansView: View {
    let record: ProjectRecord
    let onAdd: (SiteScanRecord) -> Void
    let onUpdate: (_ id: UUID, _ name: String, _ note: String, _ placements: [ScanCameraPlacement]) -> Void
    let onDelete: (UUID) -> Void

    @State private var captureKind: ScanKind?
    @State private var pendingOpen: UUID?
    @State private var editing: EditingScan?

    private struct EditingScan: Identifiable { let id: UUID }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "3D-Scans",
                subtitle: record.scans.isEmpty ? "Räume und Umgebung erfassen, Kameras platzieren" : "\(record.scans.count) Scans · \(record.placedCameraCount) Kameras platziert",
                systemImage: "cube.transparent"
            )

            if ScanCapability.anySupported {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(ScanKind.allCases) { kind in
                        Button {
                            captureKind = kind
                        } label: {
                            QuickAction(title: kind == .raum ? "Raum scannen" : "Umgebung scannen",
                                        subtitle: kind.detail,
                                        systemImage: kind.systemImage,
                                        prominent: kind == .raum)
                        }
                        .buttonStyle(.plain)
                        .disabled(!ScanCapability.isSupported(kind))
                    }
                }
            } else {
                Label("3D-Scans benötigen ein iPhone oder iPad mit LiDAR-Sensor (z. B. iPhone Pro ab 12, iPad Pro ab 2020).", systemImage: "info.circle")
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                    .card()
            }

            if record.scans.isEmpty {
                ContentUnavailableView(
                    "Noch keine Scans",
                    systemImage: "cube.transparent",
                    description: Text("Scannen Sie einen Raum oder die Umgebung und setzen Sie danach die geplanten Kameras direkt ins 3D-Modell. Der Grundriss mit den Kameras erscheint in der Offerte.")
                )
                .card()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(record.scans) { scan in
                        Button {
                            editing = EditingScan(id: scan.id)
                        } label: {
                            ScanCard(scan: scan, markers: record.floorPlanMarkers(for: scan))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(scan.id)
                            } label: {
                                Label("Scan löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $captureKind, onDismiss: openPending) { kind in
            ScanCaptureScreen(
                kind: kind,
                onComplete: { scan in
                    var named = scan
                    let count = record.scans.filter { $0.kind == kind }.count
                    named.name = "\(kind.label) \(count + 1)"
                    onAdd(named)
                    pendingOpen = named.id
                    captureKind = nil
                },
                onCancel: { captureKind = nil }
            )
        }
        .fullScreenCover(item: $editing) { item in
            ScanEditorView(
                project: record,
                scanID: item.id,
                onChange: { name, note, placements in onUpdate(item.id, name, note, placements) },
                onDelete: { onDelete(item.id) }
            )
        }
    }

    private func openPending() {
        guard let id = pendingOpen else { return }
        pendingOpen = nil
        editing = EditingScan(id: id)
    }
}

private struct ScanCard: View {
    let scan: SiteScanRecord
    let markers: [DocumentFloorPlanMarker]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let floorPlan = scan.floorPlan {
                FloorPlanView(floorPlan: floorPlan, markers: markers)
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.smallRadius))
            } else {
                Image(systemName: scan.kind.systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.grau)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.smallRadius))
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(scan.displayName).font(.brand(.headline))
                    Text("\(scan.kind.label) · \(Format.date(scan.createdAt))")
                        .font(.brand(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(scan.placements.count)", systemImage: "video")
                    .font(.brand(.subheadline).monospacedDigit())
                    .foregroundStyle(Theme.gruen)
                    .accessibilityLabel("\(scan.placements.count) Kameras")
            }
        }
        .card()
        .contentShape(Rectangle())
        .accessibilityHint("Öffnet das 3D-Modell")
    }
}
