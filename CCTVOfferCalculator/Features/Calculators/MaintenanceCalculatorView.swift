import SwiftUI
import CCTVCore

/// Eigenständiger Wartungsrechner auf Basis der Paketeinstellungen.
struct MaintenanceCalculatorView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var cameras = 8
    @State private var recorders = 1
    @State private var onSiteCheck = false

    private var quotes: [MaintenanceQuote] {
        MaintenanceCalculator.quotes(settings: settings.calculation, cameras: cameras, recorders: recorders, includeOnSiteCheck: onSiteCheck)
    }

    var body: some View {
        Form {
            Section("Anlage") {
                Stepper(value: $cameras, in: 1...256) {
                    LabeledContent("Kameras", value: "\(cameras)")
                }
                .frame(minHeight: 44)
                Stepper(value: $recorders, in: 0...20) {
                    LabeledContent("NVR / VMS", value: "\(recorders)")
                }
                .frame(minHeight: 44)
                Toggle("Jährlicher Check vor Ort (Option)", isOn: $onSiteCheck)
                    .frame(minHeight: 44)
            }

            ForEach(quotes, id: \.package) { quote in
                Section(quote.package.label) {
                    LabeledValueRow(label: "Grundgebühr", value: Format.chf(quote.monthlyBaseFee))
                    LabeledValueRow(label: "Kameras (\(quote.cameras) × \(Format.chf(settings.calculation.maintenanceConfig(for: quote.package).pricePerCamera)))", value: Format.chf(quote.monthlyCameraFee))
                    LabeledValueRow(label: "NVR/VMS (\(quote.recorders) × \(Format.chf(settings.calculation.maintenanceConfig(for: quote.package).pricePerRecorder)))", value: Format.chf(quote.monthlyRecorderFee))
                    if quote.monthlyOnSiteShare > 0 {
                        LabeledValueRow(label: "Vor-Ort-Check (anteilig)", value: Format.chf(quote.monthlyOnSiteShare))
                    }
                    LabeledValueRow(label: "Total pro Monat", value: Format.chf(quote.monthlyNet), emphasized: true)
                    LabeledValueRow(label: "Total pro Jahr", value: Format.chf(quote.yearlyNet))
                    LabeledValueRow(label: "Jahr inkl. MWST \(Format.percent(quote.vatPercent))", value: Format.chf(quote.yearlyInclVAT))
                    LabeledContent("Reaktionszeit", value: quote.responseTime)
                    LabeledContent("Fernsupport inklusive", value: quote.includedRemoteMinutes > 0 ? "\(quote.includedRemoteMinutes) Min./Monat" : "nach Aufwand")
                    DisclosureGroup("Leistungen") {
                        ForEach(quote.services, id: \.self) { service in
                            Label(service, systemImage: "checkmark").font(.brand(.subheadline))
                        }
                    }
                }
            }

            Section {
                Text("Preise exkl. MWST. Die Ansätze lassen sich unter Einstellungen › Wartungspakete anpassen.")
                    .font(.brand(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Wartungsrechner")
    }
}
