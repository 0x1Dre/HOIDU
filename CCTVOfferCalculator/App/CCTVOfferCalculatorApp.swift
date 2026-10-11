import SwiftUI
import SwiftData

@main
struct CCTVOfferCalculatorApp: App {
    private let persistence: PersistenceController.Result
    @State private var settings = SettingsStore()
    @State private var router = AppRouter()

    init() {
        persistence = PersistenceController.makeContainer()
        ExportService.removeTemporaryExports()
    }

    var body: some Scene {
        WindowGroup {
            RootView(storageError: persistence.errorMessage)
                .environment(settings)
                .environment(router)
                .tint(Theme.navy)
        }
        .modelContainer(persistence.container)
    }
}

enum AppInfo {
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
