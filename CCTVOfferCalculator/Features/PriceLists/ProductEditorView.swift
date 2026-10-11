import SwiftUI
import CCTVCore

struct ProductEditorView: View {
    let isNew: Bool
    let onSave: (ProductRecord) -> Void

    @State private var product: ProductRecord
    @State private var errors: [String] = []
    @Environment(\.dismiss) private var dismiss

    init(product: ProductRecord, isNew: Bool, onSave: @escaping (ProductRecord) -> Void) {
        _product = State(initialValue: product)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                        }
                    }
                }

                Section("Produkt") {
                    TextField("Bezeichnung", text: $product.name)
                        .frame(minHeight: 44)
                    TextField("Artikelnummer", text: $product.articleNumber)
                        .textInputAutocapitalization(.characters)
                        .frame(minHeight: 44)
                    OptionPicker(title: "Kategorie", selection: Binding(
                        get: { product.category },
                        set: { value in
                            product.category = value
                            product.role = ComponentRole.defaultRole(for: value)
                        }
                    ))
                    OptionPicker(title: "Verwendung in Kalkulation", selection: $product.role)
                    OptionPicker(title: "Einheit", selection: $product.unit)
                    OptionPicker(title: "Produktlinie", selection: $product.tier, segmented: true)
                    Toggle("Aktiv (in Kalkulation verwenden)", isOn: $product.isActive)
                        .frame(minHeight: 44)
                }

                Section {
                    DecimalField(title: "Einkaufspreis", value: $product.purchasePrice)
                    DecimalField(title: "Verkaufspreis", value: $product.sellPrice)
                    LabeledValueRow(label: "Marge", value: "\(Format.chf(product.marginAmount)) (\(Format.percent(product.marginPercent)))")
                } header: {
                    Text("Preise in CHF exkl. MWST")
                } footer: {
                    Text("Einkaufspreise und Margen erscheinen nur im internen PDF, nie in der Kundenofferte.")
                }

                if product.category == .kamera {
                    Section("Kameramerkmale") {
                        Stepper(value: $product.specs.megapixels, in: 1...48) {
                            LabeledContent("Auflösung", value: "\(product.specs.megapixels) MP")
                        }
                        OptionPicker(title: "Bauform", selection: $product.specs.formFactor)
                        OptionPicker(title: "Nachtsicht", selection: $product.specs.nightVision, segmented: true)
                        OptionPicker(title: "Audio", selection: $product.specs.audio, segmented: true)
                        Toggle("Aussentauglich", isOn: $product.specs.isOutdoor)
                        Toggle("PoE", isOn: $product.specs.supportsPoE)
                        Toggle("WLAN", isOn: $product.specs.supportsWiFi)
                        Toggle("Akku/Solar", isOn: $product.specs.isBattery)
                        Toggle("PTZ (schwenk-/neigbar)", isOn: $product.specs.isPTZ)
                        Toggle("Personen-/Fahrzeugerkennung", isOn: $product.specs.hasAnalytics)
                        Toggle("Kennzeichenerkennung", isOn: $product.specs.hasLPR)
                    }
                }
                if product.category == .nvr {
                    Section("Rekorder") {
                        Stepper(value: $product.specs.channels, in: 1...256) {
                            LabeledContent("Kanäle", value: "\(product.specs.channels)")
                        }
                        Stepper(value: $product.specs.poePorts, in: 0...64) {
                            LabeledContent("PoE-Ports", value: "\(product.specs.poePorts)")
                        }
                        Stepper(value: $product.specs.driveBays, in: 0...16) {
                            LabeledContent("Festplattenschächte", value: "\(product.specs.driveBays)")
                        }
                    }
                }
                if product.category == .poeSwitch {
                    Section("Switch") {
                        Stepper(value: $product.specs.channels, in: 1...64) {
                            LabeledContent("Ports", value: "\(product.specs.channels)")
                        }
                    }
                }
                if product.category == .festplatte {
                    Section("Festplatte") {
                        Stepper(value: $product.specs.capacityTB, in: 1...30) {
                            LabeledContent("Kapazität", value: "\(product.specs.capacityTB) TB")
                        }
                    }
                }
                if product.category == .usv {
                    Section("USV") {
                        Stepper(value: $product.specs.powerVA, in: 300...5000, step: 50) {
                            LabeledContent("Leistung", value: "\(product.specs.powerVA) VA")
                        }
                    }
                }

                Section("Notiz") {
                    TextField("Interne Notiz", text: $product.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Neues Produkt" : "Produkt bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { commit() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func commit() {
        var problems: [String] = []
        if product.name.trimmingCharacters(in: .whitespaces).isEmpty {
            problems.append("Bitte eine Bezeichnung erfassen.")
        }
        if product.purchasePrice < 0 || product.sellPrice < 0 {
            problems.append("Preise dürfen nicht negativ sein.")
        }
        if product.sellPrice < product.purchasePrice {
            problems.append("Der Verkaufspreis liegt unter dem Einkaufspreis.")
        }
        if product.category == .nvr && product.specs.channels < 1 {
            problems.append("Ein Rekorder braucht mindestens einen Kanal.")
        }
        errors = problems
        guard problems.isEmpty else { return }
        product.name = product.name.trimmingCharacters(in: .whitespaces)
        onSave(product)
        dismiss()
    }
}
