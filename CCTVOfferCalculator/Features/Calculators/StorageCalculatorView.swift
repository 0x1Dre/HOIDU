import SwiftUI
import CCTVCore

@MainActor
@Observable
final class StorageCalculatorViewModel {
    var input: StorageInput
    var useManualBitrate: Bool
    var manualBitrate: Int

    init(input: StorageInput = StorageInput()) {
        self.input = input
        self.useManualBitrate = input.manualBitrateKbps != nil
        self.manualBitrate = input.manualBitrateKbps ?? 4096
    }

    var effectiveInput: StorageInput {
        var copy = input
        copy.manualBitrateKbps = useManualBitrate ? manualBitrate : nil
        return copy
    }

    var result: Result<StorageResult, StorageCalculatorError> {
        do {
            return .success(try StorageCalculator.calculate(effectiveInput))
        } catch {
            return .failure(error)
        }
    }
}

/// Speicherrechner mit Formel und Annahmen.
struct StorageCalculatorView: View {
    @State private var viewModel: StorageCalculatorViewModel

    private static let diskSizes = [2, 4, 6, 8, 12, 16, 20]
    private static let megapixelOptions: [Double] = [2, 4, 5, 6, 8, 12]

    init(input: StorageInput = StorageInput()) {
        _viewModel = State(initialValue: StorageCalculatorViewModel(input: input))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Section("Kameras und Bild") {
                Stepper(value: $viewModel.input.cameras, in: 1...256) {
                    LabeledContent("Kameras", value: "\(viewModel.input.cameras)")
                }
                Picker("Auflösung", selection: $viewModel.input.megapixels) {
                    ForEach(Self.megapixelOptions, id: \.self) { value in
                        Text("\(Format.number(value, fractionDigits: 0)) MP").tag(value)
                    }
                    if !Self.megapixelOptions.contains(viewModel.input.megapixels) {
                        Text("\(Format.number(viewModel.input.megapixels, fractionDigits: 1)) MP").tag(viewModel.input.megapixels)
                    }
                }
                Stepper(value: $viewModel.input.framesPerSecond, in: 1...60) {
                    LabeledContent("Bildrate", value: "\(viewModel.input.framesPerSecond) fps")
                }
                OptionPicker(title: "Codec", selection: $viewModel.input.codec, segmented: true)
                Toggle("Bitrate manuell eingeben", isOn: $viewModel.useManualBitrate)
                if viewModel.useManualBitrate {
                    Stepper(value: $viewModel.manualBitrate, in: 128...50_000, step: 256) {
                        LabeledContent("Bitrate pro Kamera", value: "\(viewModel.manualBitrate) kbit/s")
                    }
                }
            }

            Section("Aufzeichnung") {
                OptionPicker(title: "Aufzeichnungsart", selection: $viewModel.input.mode, segmented: true)
                if viewModel.input.mode == .ereignis {
                    Stepper(value: $viewModel.input.eventSharePercent, in: 5...100, step: 5) {
                        LabeledContent("Aktivitätsanteil", value: "\(Format.number(viewModel.input.eventSharePercent, fractionDigits: 0)) %")
                    }
                }
                if viewModel.input.mode == .zeitplan {
                    Stepper(value: $viewModel.input.scheduleHoursPerDay, in: 1...24, step: 1) {
                        LabeledContent("Stunden pro Tag", value: Format.number(viewModel.input.scheduleHoursPerDay, fractionDigits: 0))
                    }
                }
                Stepper(value: $viewModel.input.retentionDays, in: 1...365) {
                    LabeledContent("Aufbewahrung", value: "\(viewModel.input.retentionDays) Tage")
                }
                Stepper(value: $viewModel.input.safetyMarginPercent, in: 0...100, step: 5) {
                    LabeledContent("Sicherheitsreserve", value: "\(Format.number(viewModel.input.safetyMarginPercent, fractionDigits: 0)) %")
                }
            }

            Section("Festplatten") {
                Picker("Grösse pro Disk", selection: $viewModel.input.diskSizeTB) {
                    ForEach(Self.diskSizes, id: \.self) { size in
                        Text("\(size) TB").tag(size)
                    }
                }
                Toggle("Zusätzliche Disk für Redundanz (RAID)", isOn: $viewModel.input.redundancyDisk)
            }

            switch viewModel.result {
            case .success(let result):
                StorageResultSection(result: result)
            case .failure(let error):
                Section {
                    Label(error.errorDescription ?? "Ungültige Eingabe", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Speicherrechner")
    }
}

struct StorageResultSection: View {
    let result: StorageResult

    var body: some View {
        Section("Ergebnis") {
            LabeledValueRow(label: "Bitrate pro Kamera", value: "\(Format.number(result.bitratePerCameraKbps, fractionDigits: 0)) kbit/s\(result.bitrateIsManual ? " (manuell)" : "")")
            LabeledValueRow(label: "Speicher pro Tag", value: "\(Format.number(result.dailyTB * 1000, fractionDigits: 1)) GB")
            LabeledValueRow(label: "Speicherbedarf", value: "\(Format.number(result.requiredTB, fractionDigits: 2)) TB")
            LabeledValueRow(label: "Inklusive Reserve", value: "\(Format.number(result.requiredTBWithMargin, fractionDigits: 2)) TB", emphasized: true)
            LabeledValueRow(label: "Empfohlene Festplatten", value: "\(result.recommendedDisks) × \(result.diskSizeTB) TB", emphasized: true)
        }
        Section("Formel") {
            Text(result.formula)
                .font(.callout.monospaced())
                .fixedSize(horizontal: false, vertical: true)
        }
        Section("Annahmen") {
            ForEach(result.assumptions, id: \.self) { assumption in
                Label(assumption, systemImage: "info.circle")
                    .font(.brand(.subheadline))
            }
        }
    }
}

/// Speicherübersicht im Projekt mit Link zum Rechner.
struct StorageSummaryView: View {
    let input: StorageInput
    let result: StorageResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Speicherbedarf", subtitle: "Empfohlene Variante", systemImage: "externaldrive")
            if let result {
                LabeledValueRow(label: "Bitrate pro Kamera", value: "\(Format.number(result.bitratePerCameraKbps, fractionDigits: 0)) kbit/s")
                LabeledValueRow(label: "Speicherbedarf inkl. Reserve", value: "\(Format.number(result.requiredTBWithMargin, fractionDigits: 2)) TB", emphasized: true)
                LabeledValueRow(label: "Festplatten", value: "\(result.recommendedDisks) × \(result.diskSizeTB) TB")
                Text(result.formula)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                ForEach(result.assumptions, id: \.self) { assumption in
                    Label(assumption, systemImage: "info.circle")
                        .font(.brand(.footnote))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Für diese Variante wird kein Rekorder offeriert (z. B. bestehender NVR oder Speicherkarte). Speicherbedarf im Rechner prüfen.")
                    .foregroundStyle(.secondary)
            }
            NavigationLink {
                StorageCalculatorView(input: input)
            } label: {
                Label("Im Speicherrechner anpassen", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.secondaryAction)
        }
        .card()
    }
}
