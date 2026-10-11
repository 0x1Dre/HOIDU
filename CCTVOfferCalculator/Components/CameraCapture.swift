import SwiftUI
import UIKit
import AVFoundation

/// Gründe, weshalb die Kamera nicht verwendet werden kann.
enum CameraAccessIssue: String, Identifiable {
    case unavailable
    case denied
    case restricted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unavailable: "Keine Kamera verfügbar"
        case .denied: "Kein Zugriff auf die Kamera"
        case .restricted: "Kamera eingeschränkt"
        }
    }

    var message: String {
        switch self {
        case .unavailable:
            "Auf diesem Gerät steht keine Kamera zur Verfügung (zum Beispiel im Simulator). Bitte ein Foto aus der Mediathek wählen."
        case .denied:
            "Die App darf die Kamera nicht verwenden. Erlauben Sie den Zugriff unter Einstellungen › CCTV Offerte › Kamera. Fotos aus der Mediathek können weiterhin gewählt werden."
        case .restricted:
            "Der Kamerazugriff ist durch eine Geräteeinschränkung (z. B. Bildschirmzeit oder MDM) gesperrt. Bitte ein Foto aus der Mediathek wählen."
        }
    }

    var canOpenSettings: Bool { self == .denied }
}

enum CameraAccess {
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Prüft Verfügbarkeit und Berechtigung; fragt beim ersten Mal nach der Berechtigung.
    @MainActor
    static func requestAccess() async -> CameraAccessIssue? {
        guard isCameraAvailable else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return nil
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? nil : .denied
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
}

/// Wrapper um `UIImagePickerController` für die Aufnahme eines Fotos.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onFinish: onFinish)
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onFinish: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onFinish: @escaping () -> Void) {
            self.onImage = onImage
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            onFinish()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish()
        }
    }
}

/// Startet die Kameraaufnahme inklusive Berechtigungsprüfung und deutscher Fehlermeldungen.
struct CameraCaptureModifier: ViewModifier {
    @Binding var trigger: Bool
    let onCapture: (Data) -> Void

    @State private var isPresentingCamera = false
    @State private var issue: CameraAccessIssue?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, requested in
                guard requested else { return }
                trigger = false
                Task { @MainActor in
                    if let problem = await CameraAccess.requestAccess() {
                        issue = problem
                    } else {
                        isPresentingCamera = true
                    }
                }
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraPicker(
                    onImage: { image in
                        if let data = ImageProcessing.preparedJPEG(from: image) {
                            onCapture(data)
                        }
                    },
                    onFinish: { isPresentingCamera = false }
                )
                .ignoresSafeArea()
            }
            .alert(
                issue?.title ?? "",
                isPresented: Binding(get: { issue != nil }, set: { if !$0 { issue = nil } }),
                presenting: issue
            ) { problem in
                if problem.canOpenSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Einstellungen öffnen") { openURL(url) }
                }
                Button("OK", role: .cancel) {}
            } message: { problem in
                Text(problem.message)
            }
    }
}

extension View {
    func cameraCapture(trigger: Binding<Bool>, onCapture: @escaping (Data) -> Void) -> some View {
        modifier(CameraCaptureModifier(trigger: trigger, onCapture: onCapture))
    }
}
