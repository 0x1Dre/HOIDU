import SwiftUI
import SwiftData
import PDFKit
import CCTVCore

/// Export eines Projekts: Kunden-PDF, internes PDF, CSV und JSON.
struct ExportPanel: View {
    let project: Project
    let record: ProjectRecord
    let analysis: OfferAnalysis

    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var exported: ExportedFile?
    @State private var alert: AlertMessage?
    @State private var isWorking = false

    private var repository: ProjectRepository { ProjectRepository(context: modelContext) }

    var body: some View {
        @Bindable var bindableSettings = settings
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Offerte als PDF", subtitle: "Teilen, drucken, per Mail senden oder in «Dateien» sichern", systemImage: "doc.richtext")
                Toggle("Fotos im Kunden-PDF anzeigen", isOn: $bindableSettings.includePhotosInCustomerPDF)
                    .frame(minHeight: 44)
                Text("Einzelne Fotos lassen sich beim Foto über «Im Kunden-PDF anzeigen» ausschliessen. Das interne PDF enthält immer alle Fotos.")
                    .font(.brand(.footnote))
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { pdfButtons }
                    VStack(spacing: 12) { pdfButtons }
                }
                if !analysis.isCalculable {
                    Label("Ohne berechnete Varianten enthält das PDF nur Ausgangslage und Hinweise.", systemImage: "info.circle")
                        .font(.brand(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Daten exportieren", systemImage: "square.and.arrow.up.on.square")
                Toggle("Fotos in JSON einbetten (Base64)", isOn: $bindableSettings.includePhotosInJSON)
                    .frame(minHeight: 44)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { dataButtons }
                    VStack(spacing: 12) { dataButtons }
                }
                Text("CSV: Semikolon-getrennt, UTF-8, für Excel und Buchhaltung. JSON: vollständiges Projekt zum Import auf einem anderen Gerät.")
                    .font(.brand(.footnote))
                    .foregroundStyle(.secondary)
            }
            .card()

            if !project.offers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Offertversionen", systemImage: "clock.arrow.circlepath")
                    ForEach(project.offers.sorted { $0.createdAt > $1.createdAt }) { offer in
                        OfferHistoryRow(offer: offer) {
                            try? repository.commit()
                        }
                        Divider()
                    }
                    Text("Eine neue Offertnummer wird vergeben, sobald das Projekt nach der letzten Offerte geändert wurde.")
                        .font(.brand(.footnote))
                        .foregroundStyle(.secondary)
                }
                .card()
            }
        }
        .overlay {
            if isWorking {
                ProgressView("Export wird erstellt …")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
        .sheet(item: $exported) { file in
            ExportPreviewSheet(file: file)
        }
        .messageAlert($alert)
    }

    @ViewBuilder
    private var pdfButtons: some View {
        Button {
            exportPDF(.customer)
        } label: {
            Label("Kunden-PDF", systemImage: "person.crop.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primaryAction)
        Button {
            exportPDF(.internal)
        } label: {
            Label("Internes PDF", systemImage: "lock.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondaryAction)
    }

    @ViewBuilder
    private var dataButtons: some View {
        Button {
            exportCSV(includeInternal: false)
        } label: {
            Label("CSV Kunde", systemImage: "tablecells")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondaryAction)
        .disabled(!analysis.isCalculable)
        if settings.internalMode {
            Button {
                exportCSV(includeInternal: true)
            } label: {
                Label("CSV intern", systemImage: "tablecells.badge.ellipsis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaryAction)
            .disabled(!analysis.isCalculable)
        }
        Button {
            exportJSON()
        } label: {
            Label("Projekt (JSON)", systemImage: "curlybraces")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondaryAction)
    }

    // MARK: - Aktionen

    private func exportPDF(_ audience: DocumentAudience) {
        isWorking = true
        defer { isWorking = false }
        do {
            let offer = try repository.offer(for: project, analysis: analysis, settings: settings)
            let document = OfferDocumentBuilder.build(
                project: record,
                analysis: analysis,
                company: settings.company,
                options: DocumentOptions(
                    audience: audience,
                    offerNumber: offer.number,
                    offerDate: offer.createdAt,
                    includePhotosInCustomerPDF: settings.includePhotosInCustomerPDF,
                    appVersion: AppInfo.version
                )
            )
            let data = PDFRenderer.render(document)
            let suffix = audience == .customer ? "Offerte_\(offer.number)" : "Intern_\(offer.number)"
            let url = try ExportService.write(data, fileName: ProjectExchange.suggestedFileName(for: record, suffix: suffix, fileExtension: "pdf"))
            exported = ExportedFile(
                url: url,
                kind: .pdf,
                title: audience.label,
                detail: "Offerte \(offer.number) · \(document.photoCount) Fotos · \(ExportService.byteCount(of: url))"
            )
        } catch {
            alert = AlertMessage(title: "PDF konnte nicht erstellt werden", text: error.localizedDescription)
        }
    }

    private func exportCSV(includeInternal: Bool) {
        do {
            let csv = CSVExporter.lineItems(project: record, variants: analysis.variants, includeInternal: includeInternal)
            let url = try ExportService.write(Data(csv.utf8), fileName: ProjectExchange.suggestedFileName(for: record, suffix: includeInternal ? "Positionen_intern" : "Positionen", fileExtension: "csv"))
            exported = ExportedFile(url: url, kind: .csv, title: includeInternal ? "CSV intern" : "CSV Kunde",
                                    detail: "\(analysis.variants.reduce(0) { $0 + $1.lineItems.count }) Positionen · \(ExportService.byteCount(of: url))")
        } catch {
            alert = AlertMessage(title: "CSV konnte nicht erstellt werden", text: error.localizedDescription)
        }
    }

    private func exportJSON() {
        do {
            let data = try ProjectExchange.export(record, appVersion: AppInfo.version, includePhotos: settings.includePhotosInJSON)
            let url = try ExportService.write(data, fileName: ProjectExchange.suggestedFileName(for: record, suffix: "Projekt", fileExtension: "json"))
            exported = ExportedFile(url: url, kind: .json, title: "Projektdatei",
                                    detail: "\(settings.includePhotosInJSON ? "\(record.photoCount) Fotos eingebettet" : "ohne Fotos") · \(ExportService.byteCount(of: url))")
        } catch {
            alert = AlertMessage(title: "Export fehlgeschlagen", text: error.localizedDescription)
        }
    }
}

struct OfferHistoryRow: View {
    let offer: Offer
    let onChange: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.number).font(.brand(.headline).monospacedDigit())
                Text("\(Format.date(offer.createdAt)) · gültig bis \(Format.date(offer.validUntil)) · \(offer.recommendedTier.label)")
                    .font(.brand(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.chf(offer.recommendedTotal))
                .monospacedDigit()
            Menu {
                ForEach(OfferStatus.allCases) { status in
                    Button(status.label) {
                        offer.status = status
                        onChange()
                    }
                }
            } label: {
                Text(offer.status.label)
                    .font(.brand(.caption).weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(Theme.subtle, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            }
        }
        .frame(minHeight: 44)
    }
}

struct ExportPreviewSheet: View {
    let file: ExportedFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if file.kind == .pdf {
                    PDFKitView(url: file.url)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: file.kind.symbol)
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.gruen)
                        Text(file.url.lastPathComponent)
                            .font(.brand(.headline))
                            .multilineTextAlignment(.center)
                        Text(file.detail)
                            .foregroundStyle(.secondary)
                        ShareLink(item: file.url) {
                            Label("Teilen oder sichern", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.primaryAction)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(file.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: file.url) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if file.kind == .pdf {
                    Text(file.detail)
                        .font(.brand(.footnote))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
