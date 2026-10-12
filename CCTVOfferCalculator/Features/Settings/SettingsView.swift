import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CCTVCore

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var backupFile: ExportedFile?
    @State private var isRestoring = false
    @State private var confirmDefaults = false
    @State private var alert: AlertMessage?

    private var repository: ProjectRepository { ProjectRepository(context: modelContext) }

    var body: some View {
        @Bindable var bindableStore = store
        Form {
            Section {
                TextField("Firmenname", text: $bindableStore.settings.company.name)
                TextField("Strasse und Nummer", text: $bindableStore.settings.company.street)
                HStack {
                    TextField("PLZ", text: $bindableStore.settings.company.postalCode)
                        .keyboardType(.numberPad)
                        .frame(width: 90)
                    Divider()
                    TextField("Ort", text: $bindableStore.settings.company.city)
                }
                TextField("Telefon", text: $bindableStore.settings.company.phone)
                    .keyboardType(.phonePad)
                TextField("E-Mail", text: $bindableStore.settings.company.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Website", text: $bindableStore.settings.company.website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                TextField("MWST-Nummer (CHE-123.456.789 MWST)", text: $bindableStore.settings.company.vatNumber)
                TextField("Schlusstext der Offerte", text: $bindableStore.settings.company.offerFooter, axis: .vertical)
                    .lineLimit(2...4)
                if !store.settings.company.email.isEmpty && !ProjectValidator.isValidEmail(store.settings.company.email) {
                    FieldError(message: "Die E-Mail-Adresse ist ungültig.")
                }
            } header: {
                Text("Firma")
            } footer: {
                Text("Erscheint im Kopf jeder Offerte.")
            }

            Section {
                DecimalField(title: "Stundensatz Verkauf", value: $bindableStore.settings.calculation.hourlyRate)
                DecimalField(title: "Interner Kostensatz", value: $bindableStore.settings.calculation.internalHourlyCost)
                DecimalField(title: "Anfahrtspauschale", value: $bindableStore.settings.calculation.travelFlatFee)
                DecimalField(title: "Anfahrt interne Kosten", value: $bindableStore.settings.calculation.travelInternalCost)
                DecimalField(title: "MWST-Satz", value: $bindableStore.settings.calculation.vatPercent, suffix: "%", fractionDigits: 1)
                if store.settings.calculation.vatPercent != CalculationSettings.swissVATPercent {
                    Text("Abweichend vom Schweizer Normalsatz \(Format.percent(CalculationSettings.swissVATPercent)).")
                        .font(.brand(.footnote))
                        .foregroundStyle(Theme.sonneText)
                }
                Stepper(value: $bindableStore.settings.calculation.offerValidityDays, in: 7...180) {
                    LabeledContent("Gültigkeit der Offerte", value: "\(store.settings.calculation.offerValidityDays) Tage")
                }
            } header: {
                Text("Arbeit und Preise")
            } footer: {
                Text("Interne Kosten dienen nur zur Berechnung von Marge und Deckungsbeitrag.")
            }

            Section("Annahmen Kalkulation") {
                Stepper(value: $bindableStore.settings.calculation.cableMetersPerCamera, in: 5...100, step: 5) {
                    LabeledContent("Kabel pro Kamera", value: "\(store.settings.calculation.cableMetersPerCamera) m")
                }
                Picker("Standard-Festplatte", selection: $bindableStore.settings.calculation.defaultDiskSizeTB) {
                    ForEach([4, 8, 12, 16], id: \.self) { Text("\($0) TB").tag($0) }
                }
                Stepper(value: $bindableStore.settings.calculation.storageSafetyMarginPercent, in: 0...100, step: 5) {
                    LabeledContent("Speicherreserve", value: "\(store.settings.calculation.storageSafetyMarginPercent) %")
                }
                Stepper(value: $bindableStore.settings.calculation.eventRecordingSharePercent, in: 5...100, step: 5) {
                    LabeledContent("Aktivitätsanteil Ereignisaufnahme", value: "\(store.settings.calculation.eventRecordingSharePercent) %")
                }
                Button("Kalkulationswerte zurücksetzen", role: .destructive) {
                    confirmDefaults = true
                }
            }

            Section {
                ForEach(MaintenancePackage.allCases) { package in
                    NavigationLink {
                        MaintenancePackageEditor(package: package)
                    } label: {
                        let config = store.settings.calculation.maintenanceConfig(for: package)
                        LabeledContent(package.label, value: "ab \(Format.chf(config.monthlyBaseFee)) / Monat")
                    }
                }
            } header: {
                Text("Wartungspakete")
            }

            Section {
                Toggle("Interner Modus (Einkauf und Margen anzeigen)", isOn: $bindableStore.internalMode)
                Toggle("Fotos im Kunden-PDF", isOn: $bindableStore.includePhotosInCustomerPDF)
                Toggle("Fotos im JSON-Export einbetten", isOn: $bindableStore.includePhotosInJSON)
            } header: {
                Text("Ansicht und Export")
            }

            Section {
                Button {
                    createBackup()
                } label: {
                    Label("Vollständiges Backup erstellen", systemImage: "externaldrive.badge.icloud")
                }
                Button {
                    isRestoring = true
                } label: {
                    Label("Backup einspielen", systemImage: "arrow.down.doc")
                }
                Button {
                    PersistenceController.insertDemoProjects(context: modelContext)
                    try? modelContext.save()
                    alert = AlertMessage(title: "Demo-Projekte hinzugefügt", text: "Drei Beispielprojekte stehen unter «Projekte» bereit.")
                } label: {
                    Label("Demo-Projekte hinzufügen", systemImage: "sparkles.rectangle.stack")
                }
            } header: {
                Text("Datensicherung")
            } footer: {
                Text("Das Backup enthält alle Projekte inklusive Fotos, alle Preislisten und Einstellungen als JSON-Datei. Es wird zusätzlich in «Dateien › Auf meinem iPad › Ostsicht › Backups» abgelegt.")
            }

            Section("Datenschutz und Offline-Betrieb") {
                Label("Die App benötigt kein Internet und sendet keine Daten.", systemImage: "wifi.slash")
                Label("Projekte, Fotos und Preislisten bleiben lokal im geschützten App-Speicher.", systemImage: "lock.iphone")
                Label("Daten verlassen das Gerät nur über «Teilen» oder «Exportieren».", systemImage: "square.and.arrow.up")
                Label("Kamerazugriff nur für Fotos der Montagepositionen.", systemImage: "camera")
            }
            .font(.brand(.subheadline))

            Section("Über") {
                LabeledContent("Version", value: AppInfo.version)
                LabeledContent("MWST Schweiz", value: Format.percent(CalculationSettings.swissVATPercent))
                Text("Beispielpreise und Herstellerprofile sind Richtwerte ohne Gewähr.")
                    .font(.brand(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        .sheet(item: $backupFile) { file in
            ExportPreviewSheet(file: file)
        }
        .fileImporter(isPresented: $isRestoring, allowedContentTypes: [.json]) { result in
            restore(result)
        }
        .confirmationDialog("Kalkulationswerte zurücksetzen?", isPresented: $confirmDefaults, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) { store.resetCalculationDefaults() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Stundensätze, MWST, Annahmen und Wartungspakete werden auf die Standardwerte gesetzt. Firmenangaben bleiben erhalten.")
        }
        .messageAlert($alert)
    }

    private func createBackup() {
        do {
            let data = try repository.backup(settings: store.settings, appVersion: AppInfo.version)
            let url = try ExportService.write(data, fileName: "Ostsicht-Backup-\(ExportService.timestamp()).json", permanent: true)
            backupFile = ExportedFile(url: url, kind: .json, title: "Backup", detail: "Alle Projekte, Preislisten und Einstellungen · \(ExportService.byteCount(of: url))")
        } catch {
            alert = AlertMessage(title: "Backup fehlgeschlagen", text: error.localizedDescription)
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let summary = try repository.restore(from: try Data(contentsOf: url), settings: store)
            var text = "\(summary.importedProjects) Projekte übernommen, \(summary.priceLists) Preislisten ersetzt."
            if summary.skippedProjects > 0 {
                text += " \(summary.skippedProjects) bereits vorhandene Projekte wurden übersprungen."
            }
            alert = AlertMessage(title: "Backup eingespielt", text: text)
        } catch {
            alert = AlertMessage(title: "Backup konnte nicht eingespielt werden", text: error.localizedDescription)
        }
    }
}

struct MaintenancePackageEditor: View {
    let package: MaintenancePackage
    @Environment(SettingsStore.self) private var store

    private var index: Int? {
        store.settings.calculation.maintenancePackages.firstIndex { $0.package == package }
    }

    var body: some View {
        @Bindable var bindableStore = store
        Form {
            if let index {
                Section("Preise pro Monat (exkl. MWST)") {
                    DecimalField(title: "Grundgebühr", value: $bindableStore.settings.calculation.maintenancePackages[index].monthlyBaseFee)
                    DecimalField(title: "Pro Kamera", value: $bindableStore.settings.calculation.maintenancePackages[index].pricePerCamera)
                    DecimalField(title: "Pro NVR/VMS", value: $bindableStore.settings.calculation.maintenancePackages[index].pricePerRecorder)
                }
                Section("Leistungsumfang") {
                    Stepper(value: $bindableStore.settings.calculation.maintenancePackages[index].includedRemoteMinutes, in: 0...600, step: 15) {
                        LabeledContent("Fernsupport inklusive", value: "\(store.settings.calculation.maintenancePackages[index].includedRemoteMinutes) Min.")
                    }
                    Toggle("Jährlicher Vor-Ort-Service inklusive", isOn: $bindableStore.settings.calculation.maintenancePackages[index].onSiteCheckIncluded)
                    if !store.settings.calculation.maintenancePackages[index].onSiteCheckIncluded {
                        DecimalField(title: "Vor-Ort-Check pro Jahr (Option)", value: $bindableStore.settings.calculation.maintenancePackages[index].yearlyOnSiteCheckPrice)
                    }
                    TextField("Reaktionszeit", text: $bindableStore.settings.calculation.maintenancePackages[index].responseTime)
                }
                Section {
                    TextEditor(text: Binding(
                        get: { store.settings.calculation.maintenancePackages[index].services.joined(separator: "\n") },
                        set: { store.settings.calculation.maintenancePackages[index].services = $0.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
                    ))
                    .frame(minHeight: 160)
                } header: {
                    Text("Leistungen")
                } footer: {
                    Text("Eine Leistung pro Zeile. Erscheint in der Offerte.")
                }
            } else {
                ContentUnavailableView("Paket nicht gefunden", systemImage: "questionmark.circle")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Wartung \(package.label)")
    }
}
