import SwiftUI
import ARKit
#if canImport(RoomPlan)
import RoomPlan
#endif
import CCTVCore

/// Welche Scan-Arten dieses Gerät unterstützt (beide benötigen einen LiDAR-Sensor).
enum ScanCapability {
    @MainActor
    static func isSupported(_ kind: ScanKind) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        switch kind {
        case .raum:
            #if canImport(RoomPlan)
            return RoomCaptureSession.isSupported
            #else
            return false
            #endif
        case .umgebung:
            return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        }
        #endif
    }

    @MainActor
    static var anySupported: Bool {
        ScanKind.allCases.contains { isSupported($0) }
    }
}

/// Vollbild-Erfassung für die gewählte Scan-Art.
struct ScanCaptureScreen: View {
    let kind: ScanKind
    let onComplete: (SiteScanRecord) -> Void
    let onCancel: () -> Void

    var body: some View {
        Group {
            if ScanCapability.isSupported(kind) {
                switch kind {
                case .raum: roomScreen
                case .umgebung: meshScreen
                }
            } else {
                unsupported
            }
        }
        .statusBarHidden()
    }

    private var roomScreen: AnyView {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        return AnyView(RoomScanScreen(onComplete: onComplete, onCancel: onCancel))
        #else
        return AnyView(unsupported)
        #endif
    }

    private var meshScreen: AnyView {
        #if !targetEnvironment(simulator)
        return AnyView(MeshScanScreen(onComplete: onComplete, onCancel: onCancel))
        #else
        return AnyView(unsupported)
        #endif
    }

    private var unsupported: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "3D-Scan nicht verfügbar",
                systemImage: "cube.transparent",
                description: Text(ScanError.unsupported.localizedDescription)
            )
            Button("Schliessen", action: onCancel)
                .buttonStyle(.secondaryAction)
        }
        .padding()
    }
}
