import Foundation

/// Baut den Inhalt der Kunden- und der internen Offerte. Das Kunden-PDF enthält
/// ausschliesslich Verkaufspreise – keine Einkaufspreise, Margen oder Deckungsbeiträge.
public enum OfferDocumentBuilder {
    public static func build(
        project: ProjectRecord,
        analysis: OfferAnalysis,
        company: CompanyProfile,
        options: DocumentOptions
    ) -> OfferDocument {
        let isInternal = options.audience == .internal
        let settings = analysis.settings
        let validUntil = Calendar.current.date(byAdding: .day, value: settings.offerValidityDays, to: options.offerDate) ?? options.offerDate

        var recipient = [project.customer.company, project.customer.contactPerson]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if recipient.isEmpty { recipient = [project.customer.displayName] }
        if !project.siteAddressLine.isEmpty { recipient.append("Objekt: \(project.siteAddressLine)") }

        let meta = [
            KeyValue("Offerte Nr.", options.offerNumber),
            KeyValue("Datum", Format.date(options.offerDate)),
            KeyValue("Gültig bis", Format.date(validUntil)),
            KeyValue("Projekt", project.displayTitle),
            KeyValue("Objektart", project.objectType.label),
            KeyValue("Begehung", Format.date(project.surveyDate))
        ]

        var sections: [DocumentSection] = []
        sections.append(situationSection(project))
        sections.append(DocumentSection(title: "Technische Empfehlung", blocks: [.bullets(analysis.technicalRecommendation)]))
        sections.append(overviewSection(analysis, isInternal: isInternal))
        sections.append(comparisonSection(analysis, isInternal: isInternal))
        for variant in analysis.variants {
            sections.append(variantSection(variant, recommended: variant.tier == analysis.recommendedTier, isInternal: isInternal))
        }
        sections.append(maintenanceSection(project, analysis))
        if let positions = positionsSection(project, audience: options.audience, includeCustomerPhotos: options.includePhotosInCustomerPDF) {
            sections.append(positions)
        }
        if let hints = hintsSection(analysis, isInternal: isInternal) {
            sections.append(hints)
        }
        sections.append(privacySection(analysis))
        if isInternal {
            sections.append(assumptionsSection(analysis))
        }
        sections.append(conditionsSection(settings, validUntil: validUntil, company: company))

        return OfferDocument(
            audience: options.audience,
            title: isInternal ? "Interne Kalkulation Videoüberwachung" : "Offerte Videoüberwachung",
            subtitle: "\(project.displayTitle) · \(project.customer.displayName)",
            confidentialityNote: isInternal ? "INTERN – enthält Einkaufspreise und Margen. Nicht an Kunden weitergeben." : nil,
            letterhead: company.letterheadLines,
            recipient: recipient,
            meta: meta,
            sections: sections,
            footer: [company.name, "Offerte \(options.offerNumber)", "Erstellt mit CCTV Offer Calculator CH \(options.appVersion)"]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        )
    }

    // MARK: - Abschnitte

    static func situationSection(_ project: ProjectRecord) -> DocumentSection {
        var blocks: [DocumentBlock] = []
        let infra = project.infrastructure
        let rec = project.recording
        blocks.append(.paragraph("Objekt: \(project.objectType.label)\(project.siteAddressLine.isEmpty ? "" : ", \(project.siteAddressLine)"). Erfasst wurden \(project.areas.count) Überwachungsbereiche mit insgesamt \(project.totalCameras) Kameras."))
        blocks.append(.table(DocumentTable(
            columns: [
                DocumentColumn("Bereich", weight: 2.2),
                DocumentColumn("Lage", weight: 0.8),
                DocumentColumn("Zweck", weight: 2.4),
                DocumentColumn("Erkennungsziel", weight: 1.4),
                DocumentColumn("Nachtsicht", weight: 1.3),
                DocumentColumn("Kameras", weight: 0.9, alignment: .trailing)
            ],
            rows: project.areas.map { area in
                [area.name, area.location.label, area.purposes.labels, area.detectionTarget.label, area.nightVision.label, String(area.camera.quantity)]
            }
        )))
        blocks.append(.keyValues([
            KeyValue("Verkabelung", infra.cabling.label),
            KeyValue("Strom / Internet", "\(infra.power.label) / \(infra.internet.label)"),
            KeyValue("Verbindung", infra.connection.label),
            KeyValue("Montagezugang", infra.mountingAccess.label),
            KeyValue("Aufzeichnung", "\(rec.mode.label), \(rec.retentionDays) Tage"),
            KeyValue("Zugriff", rec.access.labels),
            KeyValue("Funktionen", rec.features.isEmpty ? "–" : rec.features.labels)
        ]))
        let notes = project.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            blocks.append(.paragraph("Bemerkungen: \(notes)"))
        }
        return DocumentSection(title: "Ausgangslage", blocks: blocks)
    }

    static func overviewSection(_ analysis: OfferAnalysis, isInternal: Bool) -> DocumentSection {
        var columns = [
            DocumentColumn("Variante", weight: 1.2),
            DocumentColumn("Hersteller", weight: 1.2),
            DocumentColumn("Kameras", weight: 0.8, alignment: .trailing),
            DocumentColumn("Einmalig exkl. MWST", weight: 1.5, alignment: .trailing),
            DocumentColumn("Einmalig inkl. MWST", weight: 1.5, alignment: .trailing),
            DocumentColumn("Wartung/Monat", weight: 1.3, alignment: .trailing)
        ]
        if isInternal { columns.append(DocumentColumn("DB %", weight: 0.8, alignment: .trailing)) }
        let rows = analysis.variants.map { variant -> [String] in
            var row = [
                variant.tier.label + (variant.tier == analysis.recommendedTier ? " (empfohlen)" : ""),
                variant.manufacturer.label,
                String(variant.selection.cameraCount),
                Format.chf(variant.totals.netAfterDiscount),
                Format.chf(variant.totals.totalInclVAT),
                variant.maintenance.map { Format.chf($0.monthlyNet) } ?? "–"
            ]
            if isInternal { row.append(Format.percent(variant.totals.contributionMarginPercent)) }
            return row
        }
        var blocks: [DocumentBlock] = [.table(DocumentTable(columns: columns, rows: rows))]
        if analysis.variants.isEmpty {
            blocks = [.paragraph("Für dieses Projekt konnten noch keine Varianten berechnet werden.")]
        }
        return DocumentSection(title: "Angebotsvarianten im Überblick", blocks: blocks)
    }

    static func comparisonSection(_ analysis: OfferAnalysis, isInternal: Bool) -> DocumentSection {
        var columns = [
            DocumentColumn("Hersteller", weight: 1.2),
            DocumentColumn("Eignung", weight: 1.0, alignment: .trailing),
            DocumentColumn("Budget", weight: 1.4, alignment: .trailing),
            DocumentColumn("Standard", weight: 1.4, alignment: .trailing),
            DocumentColumn("Premium", weight: 1.4, alignment: .trailing)
        ]
        if isInternal { columns.append(DocumentColumn("DB % Std.", weight: 0.9, alignment: .trailing)) }
        let rows = analysis.comparison.map { row -> [String] in
            var cells = [row.manufacturer.label, "\(row.score.score)/100"]
            for tier in OfferTier.allCases {
                cells.append(row.cell(tier)?.totalInclVAT.map(Format.chf) ?? "nicht verfügbar")
            }
            if isInternal {
                cells.append(row.cell(.standard)?.contributionMarginPercent.map { Format.percent($0) } ?? "–")
            }
            return cells
        }
        var blocks: [DocumentBlock] = [
            .paragraph("Bewertung der Hersteller anhand der erfassten Anforderungen (0–100 Punkte). Beträge inkl. MWST."),
            .table(DocumentTable(columns: columns, rows: rows))
        ]
        blocks.append(.bullets(analysis.scores.map { "\($0.manufacturer.label) – \($0.fit.label): \($0.rationale)" }))
        if isInternal {
            for score in analysis.scores where !score.warnings.isEmpty {
                blocks.append(.notice(title: "Warnungen \(score.manufacturer.label)", text: score.warnings.joined(separator: " "), severity: .warnung))
            }
        }
        return DocumentSection(title: "Herstellervergleich", blocks: blocks)
    }

    static func variantSection(_ variant: OfferVariant, recommended: Bool, isInternal: Bool) -> DocumentSection {
        var blocks: [DocumentBlock] = []
        let columns: [DocumentColumn]
        let rows: [[String]]
        if isInternal {
            columns = [
                DocumentColumn("Pos.", weight: 0.5),
                DocumentColumn("Beschreibung", weight: 3.6),
                DocumentColumn("Menge", weight: 0.9, alignment: .trailing),
                DocumentColumn("EK Einzel", weight: 1.1, alignment: .trailing),
                DocumentColumn("VK Einzel", weight: 1.1, alignment: .trailing),
                DocumentColumn("VK Total", weight: 1.2, alignment: .trailing),
                DocumentColumn("Marge", weight: 0.8, alignment: .trailing)
            ]
            rows = variant.lineItems.map {
                [String($0.position), $0.description, quantityText($0), Format.number($0.unitPurchasePrice, fractionDigits: 2),
                 Format.number($0.unitSellPrice, fractionDigits: 2), Format.number($0.totalSell, fractionDigits: 2), Format.percent($0.marginPercent)]
            }
        } else {
            columns = [
                DocumentColumn("Pos.", weight: 0.5),
                DocumentColumn("Beschreibung", weight: 4.4),
                DocumentColumn("Menge", weight: 1.0, alignment: .trailing),
                DocumentColumn("Preis CHF", weight: 1.2, alignment: .trailing),
                DocumentColumn("Total CHF", weight: 1.3, alignment: .trailing)
            ]
            rows = variant.lineItems.map {
                [String($0.position), $0.description, quantityText($0), Format.number($0.unitSellPrice, fractionDigits: 2), Format.number($0.totalSell, fractionDigits: 2)]
            }
        }
        blocks.append(.paragraph("Hersteller: \(variant.manufacturer.label) · Eignung: \(variant.score.fit.label) (\(variant.score.score)/100)\(variant.isManualSelection ? " · manuell gewählt" : "")"))
        blocks.append(.table(DocumentTable(columns: columns, rows: rows)))

        let t = variant.totals
        var totals = [
            KeyValue("Material netto", Format.chf(t.materialNet)),
            KeyValue("Arbeit netto (\(Format.hours(t.laborHours)) inkl. Anfahrt)", Format.chf(t.laborNet)),
            KeyValue("Zwischentotal", Format.chf(t.subtotal))
        ]
        if t.discountAmount > 0 {
            totals.append(KeyValue("Rabatt \(Format.percent(t.discountPercent))", "– " + Format.chf(t.discountAmount)))
        }
        totals += [
            KeyValue("Total exkl. MWST", Format.chf(t.netAfterDiscount)),
            KeyValue("MWST \(Format.percent(t.vatPercent))", Format.chf(t.vatAmount))
        ]
        if t.roundingDifference != 0 {
            totals.append(KeyValue("Rundungsdifferenz", Format.chf(t.roundingDifference)))
        }
        totals.append(KeyValue("Total inkl. MWST", Format.chf(t.totalInclVAT), emphasized: true))
        if isInternal {
            totals += [
                KeyValue("Materialkosten (Einkauf)", Format.chf(t.materialCost)),
                KeyValue("Marge Material", "\(Format.chf(t.materialMargin)) (\(Format.percent(t.materialMarginPercent)))"),
                KeyValue("Arbeitskosten intern", Format.chf(t.laborCost)),
                KeyValue("Deckungsbeitrag", "\(Format.chf(t.contributionMargin)) (\(Format.percent(t.contributionMarginPercent)))", emphasized: true)
            ]
        }
        blocks.append(.keyValues(totals))

        if !variant.selection.notes.isEmpty {
            blocks.append(.bullets(variant.selection.notes))
        }
        if isInternal && !variant.selection.warnings.isEmpty {
            blocks.append(.notice(title: "Kompromisse in dieser Variante", text: variant.selection.warnings.joined(separator: " "), severity: .warnung))
        }
        return DocumentSection(
            title: "Variante \(variant.tier.label) – \(variant.manufacturer.label)\(recommended ? " (empfohlen)" : "")",
            blocks: blocks,
            startsOnNewPage: true
        )
    }

    static func maintenanceSection(_ project: ProjectRecord, _ analysis: OfferAnalysis) -> DocumentSection {
        let selected = project.maintenance.package
        let rows = analysis.maintenanceQuotes.map { quote in
            [
                quote.package.label + (quote.package == selected ? " (gewählt)" : ""),
                quote.services.joined(separator: "; "),
                quote.responseTime,
                Format.chf(quote.monthlyNet),
                Format.chf(quote.yearlyNet)
            ]
        }
        return DocumentSection(title: "Wartung und Support", blocks: [
            .table(DocumentTable(
                columns: [
                    DocumentColumn("Paket", weight: 1.1),
                    DocumentColumn("Leistungen", weight: 4.2),
                    DocumentColumn("Reaktionszeit", weight: 1.4),
                    DocumentColumn("pro Monat", weight: 1.1, alignment: .trailing),
                    DocumentColumn("pro Jahr", weight: 1.2, alignment: .trailing)
                ],
                rows: rows
            )),
            .paragraph("Wartungspreise exkl. MWST, Laufzeit 12 Monate, danach jährlich verlängerbar. Grundlage: Anzahl Kameras und Rekorder der empfohlenen Variante.")
        ])
    }

    static func positionsSection(_ project: ProjectRecord, audience: DocumentAudience, includeCustomerPhotos: Bool) -> DocumentSection? {
        let hasPositions = project.areas.contains { !$0.positions.isEmpty }
        let showPhotos = audience == .internal || includeCustomerPhotos
        var blocks: [DocumentBlock] = []

        if hasPositions {
            blocks.append(.table(DocumentTable(
                columns: [
                    DocumentColumn("Bereich", weight: 1.6),
                    DocumentColumn("Position", weight: 2.2),
                    DocumentColumn("Montagehöhe", weight: 1.1),
                    DocumentColumn("Blickrichtung", weight: 2.0),
                    DocumentColumn("Notiz", weight: 2.2)
                ],
                rows: project.areas.flatMap { area in
                    area.positions.map { [area.name, $0.label, $0.mountingHeight, $0.viewDirection, $0.note] }
                }
            )))
        }

        if showPhotos {
            for area in project.areas {
                var photos: [DocumentPhoto] = []
                let areaPhotos = area.photos.map { (photo: $0, position: Optional<CameraPositionRecord>.none) }
                let positionPhotos = area.positions.flatMap { position in position.photos.map { (photo: $0, position: Optional(position)) } }
                for entry in areaPhotos + positionPhotos {
                    guard let data = entry.photo.imageData, !data.isEmpty else { continue }
                    if audience == .customer && !entry.photo.includeInCustomerPDF { continue }
                    let caption = entry.photo.caption.trimmingCharacters(in: .whitespaces)
                    let title = caption.isEmpty ? (entry.position?.label ?? area.name) : caption
                    var details: [String] = []
                    if let position = entry.position {
                        if caption.isEmpty == false { details.append(position.label) }
                        details += position.detailLines
                    } else {
                        details.append("Bereich \(area.name)")
                    }
                    if !entry.photo.note.isEmpty { details.append(entry.photo.note) }
                    photos.append(DocumentPhoto(id: entry.photo.id, title: title, details: details, imageData: data, markers: entry.photo.markers))
                }
                if !photos.isEmpty {
                    blocks.append(.paragraph("Fotos Bereich «\(area.name)»"))
                    blocks.append(.photos(photos))
                }
            }
        }

        guard !blocks.isEmpty else { return nil }
        return DocumentSection(title: showPhotos ? "Kamerapositionen und Fotos" : "Kamerapositionen", blocks: blocks, startsOnNewPage: true)
    }

    static func hintsSection(_ analysis: OfferAnalysis, isInternal: Bool) -> DocumentSection? {
        let relevant = analysis.warnings.filter { $0.category != .datenschutz && (isInternal || $0.severity >= .info) }
        guard !relevant.isEmpty else { return nil }
        return DocumentSection(title: "Projekthinweise", blocks: relevant.map {
            .notice(title: "\($0.severity.label): \($0.title)", text: $0.message, severity: $0.severity)
        })
    }

    static func privacySection(_ analysis: OfferAnalysis) -> DocumentSection {
        var blocks: [DocumentBlock] = [.bullets(PrivacyText.documentSection)]
        for warning in analysis.warnings where warning.category == .datenschutz {
            blocks.append(.notice(title: warning.title, text: warning.message, severity: warning.severity))
        }
        blocks.append(.paragraph(PrivacyText.responsibilityNotice))
        return DocumentSection(title: "Datenschutz", blocks: blocks)
    }

    static func assumptionsSection(_ analysis: OfferAnalysis) -> DocumentSection {
        let s = analysis.settings
        var blocks: [DocumentBlock] = [
            .keyValues([
                KeyValue("Stundensatz Verkauf", Format.chf(s.hourlyRate)),
                KeyValue("Interner Kostensatz", Format.chf(s.internalHourlyCost)),
                KeyValue("Anfahrtspauschale (Verkauf / intern)", "\(Format.chf(s.travelFlatFee)) / \(Format.chf(s.travelInternalCost))"),
                KeyValue("MWST", Format.percent(s.vatPercent)),
                KeyValue("Kabel pro Kamera", "\(s.cableMetersPerCamera) m"),
                KeyValue("Speicherreserve", "\(s.storageSafetyMarginPercent) %"),
                KeyValue("Ereignisanteil", "\(s.eventRecordingSharePercent) %")
            ])
        ]
        if let variant = analysis.recommendedVariant {
            blocks.append(.table(DocumentTable(
                columns: [DocumentColumn("Arbeit", weight: 2), DocumentColumn("Stunden", weight: 0.8, alignment: .trailing), DocumentColumn("Grundlage", weight: 4)],
                rows: variant.labor.map { [$0.kind.label, Format.hours($0.hours), $0.basis] }
            )))
            if let storage = variant.selection.storage {
                blocks.append(.paragraph(storage.formula))
                blocks.append(.bullets(storage.assumptions + [
                    "Ergebnis: \(Format.number(storage.requiredTBWithMargin, fractionDigits: 2)) TB, \(storage.recommendedDisks) × \(storage.diskSizeTB) TB"
                ]))
            }
        }
        return DocumentSection(title: "Annahmen und Berechnungsgrundlagen", blocks: blocks, startsOnNewPage: true)
    }

    static func conditionsSection(_ settings: CalculationSettings, validUntil: Date, company: CompanyProfile) -> DocumentSection {
        var bullets = [
            "Alle Preise in CHF. MWST \(Format.percent(settings.vatPercent)) separat ausgewiesen.",
            "Diese Offerte ist gültig bis \(Format.date(validUntil)).",
            "Arbeitsaufwand geschätzt aufgrund der Begehung; Mehraufwand durch nicht erkennbare bauliche Gegebenheiten wird nach Aufwand verrechnet.",
            "Nicht enthalten: 230-V-Elektroinstallationen, Bau- und Grabarbeiten, Bewilligungsgebühren, Internetanschluss.",
            "Lieferfristen gemäss Verfügbarkeit beim Lieferanten."
        ]
        if !company.offerFooter.isEmpty { bullets.append(company.offerFooter) }
        return DocumentSection(title: "Bedingungen", blocks: [.bullets(bullets)])
    }

    static func quantityText(_ item: OfferLineItem) -> String {
        item.quantityText
    }
}
