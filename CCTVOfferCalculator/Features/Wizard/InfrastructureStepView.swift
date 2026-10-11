import SwiftUI
import CCTVCore

struct InfrastructureStepView: View {
    @Bindable var viewModel: WizardViewModel

    private var privacyWarnings: [ProjectWarning] {
        ProjectWarningService.warnings(for: viewModel.draft).filter { $0.category == .datenschutz }
    }

    var body: some View {
        Form {
            Section("Netzwerk und Strom") {
                OptionPicker(title: "Netzwerkverkabelung vorhanden", selection: $viewModel.draft.infrastructure.cabling, segmented: true)
                OptionPicker(title: "Strom am Montageort", selection: $viewModel.draft.infrastructure.power, segmented: true)
                OptionPicker(title: "Internetanschluss", selection: $viewModel.draft.infrastructure.internet, segmented: true)
                OptionPicker(title: "Verbindung der Kameras", selection: $viewModel.draft.infrastructure.connection, segmented: true)
            }

            Section("Montage und Umgebung") {
                OptionPicker(title: "Montagezugang", selection: $viewModel.draft.infrastructure.mountingAccess, segmented: true)
                OptionPicker(title: "Beleuchtung", selection: $viewModel.draft.infrastructure.lighting)
            }

            Section {
                OptionChips(selection: $viewModel.draft.infrastructure.existing)
                TextField("Vorhandene Kameras / Hersteller", text: $viewModel.draft.infrastructure.existingCameras, axis: .vertical)
                    .lineLimit(1...4)
                    .frame(minHeight: 44)
            } header: {
                Text("Bestehende Infrastruktur")
            } footer: {
                Text("Vorhandene Komponenten werden in der Kalkulation nicht neu offeriert.")
            }

            Section {
                Toggle("Datenschutzprüfung erforderlich", isOn: $viewModel.draft.infrastructure.privacyReviewRequired)
                    .frame(minHeight: 44)
                Toggle("Öffentlicher Bereich betroffen", isOn: $viewModel.draft.infrastructure.publicAreaAffected)
                    .frame(minHeight: 44)
                Toggle("Nachbargrundstück betroffen", isOn: $viewModel.draft.infrastructure.neighborPropertyAffected)
                    .frame(minHeight: 44)
                Toggle("Mitarbeitende betroffen", isOn: $viewModel.draft.infrastructure.employeesAffected)
                    .frame(minHeight: 44)
                ForEach(privacyWarnings) { warning in
                    WarningRow(warning: warning)
                }
            } header: {
                Text("Datenschutz")
            } footer: {
                Text(PrivacyText.responsibilityNotice)
            }
        }
        .formStyle(.grouped)
    }
}
