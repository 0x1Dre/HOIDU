import SwiftUI
import CCTVCore

struct RecordingStepView: View {
    @Bindable var viewModel: WizardViewModel

    /// 0 steht für «frei wählbar».
    private var retentionSelection: Binding<Int> {
        Binding(
            get: {
                let days = viewModel.draft.recording.retentionDays
                return RecordingRecord.retentionPresets.contains(days) ? days : 0
            },
            set: { value in
                if value == 0 {
                    if RecordingRecord.retentionPresets.contains(viewModel.draft.recording.retentionDays) {
                        viewModel.draft.recording.retentionDays = 21
                    }
                } else {
                    viewModel.draft.recording.retentionDays = value
                }
            }
        )
    }

    var body: some View {
        Form {
            if !viewModel.issues(for: .aufzeichnung).isEmpty {
                Section {
                    ValidationBanner(issues: viewModel.issues(for: .aufzeichnung))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section("Aufzeichnung") {
                OptionPicker(title: "Aufzeichnungsart", selection: $viewModel.draft.recording.mode, segmented: true)
                if viewModel.draft.recording.mode == .zeitplan {
                    Stepper(value: $viewModel.draft.recording.scheduleHoursPerDay, in: 1...24) {
                        LabeledContent("Aufnahme pro Tag", value: "\(viewModel.draft.recording.scheduleHoursPerDay) h")
                    }
                    .frame(minHeight: 44)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aufbewahrung in Tagen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Aufbewahrung", selection: retentionSelection) {
                        ForEach(RecordingRecord.retentionPresets, id: \.self) { days in
                            Text("\(days)").tag(days)
                        }
                        Text("Frei").tag(0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
                if retentionSelection.wrappedValue == 0 {
                    Stepper(value: $viewModel.draft.recording.retentionDays, in: 1...365) {
                        LabeledContent("Aufbewahrung", value: "\(viewModel.draft.recording.retentionDays) Tage")
                    }
                    .frame(minHeight: 44)
                }
                FieldError(message: viewModel.message(for: "retention"))
                Stepper(value: $viewModel.draft.recording.framesPerSecond, in: 1...30) {
                    LabeledContent("Bildrate", value: "\(viewModel.draft.recording.framesPerSecond) fps")
                }
                .frame(minHeight: 44)
                OptionPicker(title: "Codec", selection: $viewModel.draft.recording.codec, segmented: true)
            }

            Section("Benutzer und Zugriff") {
                Stepper(value: $viewModel.draft.recording.userCount, in: 1...100) {
                    LabeledContent("Anzahl Benutzer", value: "\(viewModel.draft.recording.userCount)")
                }
                .frame(minHeight: 44)
                OptionChips(selection: $viewModel.draft.recording.access)
                FieldError(message: viewModel.message(for: "access"))
            }

            Section("Funktionen") {
                OptionChips(selection: $viewModel.draft.recording.features)
            }

            Section {
                OptionPicker(title: "Systemstufe", selection: $viewModel.draft.recording.tier, segmented: true)
            } header: {
                Text("Systemstufe")
            } footer: {
                Text("Bestimmt die empfohlene Variante. «Offen» empfiehlt die Standardvariante.")
            }

            Section("Integration und Sicherheit") {
                Toggle("Mehrere Standorte", isOn: $viewModel.draft.recording.multiSite)
                    .frame(minHeight: 44)
                Toggle("Erhöhte Cybersecurity- oder Compliance-Anforderungen", isOn: $viewModel.draft.recording.highCybersecurity)
                    .frame(minHeight: 44)
                Toggle("Integration in Drittsysteme (VMS, ONVIF, Zutritt, Alarm)", isOn: $viewModel.draft.recording.thirdPartyIntegration)
                    .frame(minHeight: 44)
            }
        }
        .formStyle(.grouped)
    }
}
