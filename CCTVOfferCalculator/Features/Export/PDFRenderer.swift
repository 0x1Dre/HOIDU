import UIKit
import CCTVCore

/// Rendert ein `OfferDocument` als mehrseitiges A4-PDF mit UIKit (ohne Drittanbieter).
///
/// Gestaltung nach Ostsicht-Manual: Logo oben links, Barlow (Titel SemiBold, Text Regular),
/// Titel in Anthrazit, Tabellenköpfe in Grün, grüne Horizontlinie im Fuss mit Kontaktdaten.
@MainActor
enum PDFRenderer {
    static let pageSize = CGSize(width: 595.28, height: 841.89)

    static func render(_ document: OfferDocument) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: document.title,
            kCGPDFContextSubject as String: document.subtitle,
            kCGPDFContextCreator as String: "Ostsicht Offerte",
            kCGPDFContextAuthor as String: document.letterhead.first ?? "Ostsicht"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        return renderer.pdfData { context in
            let writer = PDFPageWriter(context: context, document: document)
            writer.drawDocument()
        }
    }
}

@MainActor
private final class PDFPageWriter {
    private let context: UIGraphicsPDFRendererContext
    private let document: OfferDocument
    private let margin: CGFloat = 42
    private var y: CGFloat = 0
    private var pageNumber = 0

    private let gruen = OstsichtColor.gruen
    private let sonne = OstsichtColor.sonne
    private let text = OstsichtColor.anthrazit
    private let muted = OstsichtColor.grau
    private let stripe = OstsichtColor.kalk
    private let rule = UIColor(hex: 0xD9D6CC)
    /// Logo horizontal: 150 pt ≈ 53 mm (Mindestbreite im Druck 35 mm).
    private let logoSize = CGSize(width: 150, height: 30)

    init(context: UIGraphicsPDFRendererContext, document: OfferDocument) {
        self.context = context
        self.document = document
    }

    private var pageWidth: CGFloat { PDFRenderer.pageSize.width }
    private var contentWidth: CGFloat { pageWidth - margin * 2 }
    private var bottomLimit: CGFloat { PDFRenderer.pageSize.height - margin - 28 }

    // MARK: - Ablauf

    func drawDocument() {
        beginPage(isFirst: true)
        drawTitleBlock()
        for section in document.sections {
            drawSection(section)
        }
    }

    private func beginPage(isFirst: Bool = false) {
        context.beginPage()
        pageNumber += 1
        drawFooter()
        if isFirst {
            y = margin
        } else {
            let header = attributed("\(document.title) · \(document.subtitle)", size: 8, color: muted)
            draw(header, at: CGPoint(x: margin, y: margin - 18), width: contentWidth)
            line(at: margin - 4)
            y = margin + 6
        }
    }

    private func ensureSpace(_ height: CGFloat) {
        if y + height > bottomLimit {
            beginPage()
        }
    }

    // MARK: - Kopf und Fuss

    private func drawTitleBlock() {
        let letterheadWidth: CGFloat = 200
        let letterhead = attributed(document.letterhead.joined(separator: "\n"), size: 8.5, color: muted, alignment: .right)
        let letterheadHeight = draw(letterhead, at: CGPoint(x: pageWidth - margin - letterheadWidth, y: y), width: letterheadWidth)

        // Logo oben links; Schutzzone = Höhe der Sonnenkuppel bleibt frei.
        OstsichtBrand.draw(.horizontal, in: CGRect(origin: CGPoint(x: margin, y: y), size: logoSize), context: context.cgContext)
        y += max(letterheadHeight, logoSize.height) + 24

        let title = attributed(document.title, size: 20, weight: .semibold, color: text)
        var titleHeight = draw(title, at: CGPoint(x: margin, y: y), width: contentWidth)
        let subtitle = attributed(document.subtitle, size: 10.5, color: muted)
        titleHeight += draw(subtitle, at: CGPoint(x: margin, y: y + titleHeight + 2), width: contentWidth) + 2
        y += titleHeight + 14

        if let note = document.confidentialityNote {
            let noteText = attributed(note, size: 9.5, weight: .semibold, color: .white)
            let height = measure(noteText, width: contentWidth - 16) + 10
            text.setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentWidth, height: height), cornerRadius: 2).fill()
            draw(noteText, at: CGPoint(x: margin + 8, y: y + 5), width: contentWidth - 16)
            y += height + 12
        }

        let columnWidth = (contentWidth - 20) / 2
        let recipientTitle = attributed("Kunde", size: 8.5, weight: .semibold, color: muted)
        var leftY = y + draw(recipientTitle, at: CGPoint(x: margin, y: y), width: columnWidth) + 2
        let recipient = attributed(document.recipient.joined(separator: "\n"), size: 10.5, color: text)
        leftY += draw(recipient, at: CGPoint(x: margin, y: leftY), width: columnWidth)

        var rightY = y
        for pair in document.meta {
            let label = attributed(pair.label, size: 9, color: muted)
            let value = attributed(pair.value, size: 9, weight: .semibold, color: text, alignment: .right)
            let x = margin + columnWidth + 20
            let h1 = draw(label, at: CGPoint(x: x, y: rightY), width: columnWidth * 0.4)
            let h2 = draw(value, at: CGPoint(x: x + columnWidth * 0.4, y: rightY), width: columnWidth * 0.6)
            rightY += max(h1, h2) + 2
        }
        y = max(leftY, rightY) + 12
        line(at: y)
        y += 14
    }

    private func drawFooter() {
        let footerY = PDFRenderer.pageSize.height - margin + 6
        // Grüne Horizontlinie als Abschluss, darunter die Kontaktdaten.
        line(at: footerY - 7, color: gruen, width: 1.5)
        let footer = attributed(document.footer, size: 7.5, color: muted)
        draw(footer, at: CGPoint(x: margin, y: footerY), width: contentWidth - 60)
        let page = attributed("Seite \(pageNumber)", size: 7.5, color: muted, alignment: .right)
        draw(page, at: CGPoint(x: pageWidth - margin - 60, y: footerY), width: 60)
    }

    // MARK: - Abschnitte und Blöcke

    private func drawSection(_ section: DocumentSection) {
        if section.startsOnNewPage && y > margin + 160 {
            beginPage()
        }
        let title = attributed(section.title, size: 13.5, weight: .semibold, color: text)
        let height = measure(title, width: contentWidth)
        ensureSpace(height + 50)
        draw(title, at: CGPoint(x: margin, y: y), width: contentWidth)
        y += height + 3
        line(at: y, color: gruen, width: 1)
        y += 9
        for block in section.blocks {
            drawBlock(block)
        }
        y += 10
    }

    private func drawBlock(_ block: DocumentBlock) {
        switch block {
        case .paragraph(let value):
            let paragraph = attributed(value, size: 9.5, color: text)
            let height = measure(paragraph, width: contentWidth)
            ensureSpace(height)
            draw(paragraph, at: CGPoint(x: margin, y: y), width: contentWidth)
            y += height + 7
        case .bullets(let items):
            for item in items {
                let bullet = attributed(item, size: 9.5, color: text)
                let height = measure(bullet, width: contentWidth - 14)
                ensureSpace(height)
                draw(attributed("•", size: 9.5, color: gruen), at: CGPoint(x: margin + 2, y: y), width: 10)
                draw(bullet, at: CGPoint(x: margin + 14, y: y), width: contentWidth - 14)
                y += height + 3
            }
            y += 4
        case .keyValues(let pairs):
            drawKeyValues(pairs)
        case .table(let table):
            drawTable(table)
        case .notice(let title, let message, let severity):
            drawNotice(title: title, message: message, severity: severity)
        case .photos(let photos):
            drawPhotos(photos)
        }
    }

    private func drawKeyValues(_ pairs: [KeyValue]) {
        let labelWidth = contentWidth * 0.62
        let valueWidth = contentWidth - labelWidth
        for pair in pairs {
            let weight: UIFont.Weight = pair.emphasized ? .semibold : .regular
            let label = attributed(pair.label, size: pair.emphasized ? 10.5 : 9.5, weight: weight, color: pair.emphasized ? text : muted)
            let value = attributed(pair.value, size: pair.emphasized ? 10.5 : 9.5, weight: pair.emphasized ? .semibold : .medium, color: text, alignment: .right)
            let height = max(measure(label, width: labelWidth), measure(value, width: valueWidth))
            ensureSpace(height + 4)
            if pair.emphasized {
                line(at: y - 1)
                y += 2
            }
            draw(label, at: CGPoint(x: margin, y: y), width: labelWidth)
            draw(value, at: CGPoint(x: margin + labelWidth, y: y), width: valueWidth)
            y += height + 3
        }
        y += 6
    }

    private func drawTable(_ table: DocumentTable) {
        guard !table.columns.isEmpty else { return }
        let totalWeight = table.columns.reduce(0) { $0 + $1.weight }
        let widths = table.columns.map { CGFloat($0.weight / max(totalWeight, 0.01)) * contentWidth }
        let padding: CGFloat = 4

        func cells(_ values: [String], header: Bool) -> [NSAttributedString] {
            table.columns.enumerated().map { index, column in
                let value = index < values.count ? values[index] : ""
                return attributed(
                    value,
                    size: 8.5,
                    weight: header ? .semibold : .regular,
                    color: header ? .white : text,
                    alignment: column.alignment == .trailing ? .right : .left
                )
            }
        }

        func rowHeight(_ row: [NSAttributedString]) -> CGFloat {
            zip(row, widths).map { measure($0, width: $1 - padding * 2) }.max().map { $0 + padding * 2 } ?? 16
        }

        func drawRow(_ row: [NSAttributedString], height: CGFloat, fill: UIColor?) {
            if let fill {
                fill.setFill()
                UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: height))
            }
            var x = margin
            for (cell, width) in zip(row, widths) {
                draw(cell, at: CGPoint(x: x + padding, y: y + padding), width: width - padding * 2)
                x += width
            }
            y += height
        }

        let header = cells(table.columns.map(\.title), header: true)
        let headerHeight = rowHeight(header)
        let firstRowHeight = table.rows.first.map { rowHeight(cells($0, header: false)) } ?? 0
        ensureSpace(headerHeight + firstRowHeight)
        drawRow(header, height: headerHeight, fill: gruen)

        for (index, values) in table.rows.enumerated() {
            let row = cells(values, header: false)
            let height = rowHeight(row)
            if y + height > bottomLimit {
                beginPage()
                drawRow(header, height: headerHeight, fill: gruen)
            }
            drawRow(row, height: height, fill: index.isMultiple(of: 2) ? nil : stripe)
        }
        line(at: y)
        y += 10
    }

    private func drawNotice(title: String, message: String, severity: WarningSeverity) {
        // Orange nur als Fläche/Balken, nie als Textfarbe.
        let color: UIColor = switch severity {
        case .info: gruen
        case .warnung: sonne
        case .kritisch: .systemRed
        }
        let titleText = attributed(title, size: 9.5, weight: .semibold, color: text)
        let body = attributed(message, size: 9, color: text)
        let innerWidth = contentWidth - 16
        let height = measure(titleText, width: innerWidth) + measure(body, width: innerWidth) + 12
        ensureSpace(height)
        color.withAlphaComponent(0.08).setFill()
        UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: height))
        color.setFill()
        UIRectFill(CGRect(x: margin, y: y, width: 3, height: height))
        let titleHeight = draw(titleText, at: CGPoint(x: margin + 10, y: y + 5), width: innerWidth)
        draw(body, at: CGPoint(x: margin + 10, y: y + 6 + titleHeight), width: innerWidth)
        y += height + 6
    }

    private func drawPhotos(_ photos: [DocumentPhoto]) {
        let spacing: CGFloat = 14
        let columnWidth = (contentWidth - spacing) / 2
        let boxHeight: CGFloat = 190
        var index = 0
        while index < photos.count {
            let row = Array(photos[index..<min(index + 2, photos.count)])
            let captions = row.map { photo -> (NSAttributedString, NSAttributedString) in
                (attributed(photo.title, size: 9, weight: .semibold, color: text),
                 attributed(photo.details.joined(separator: "\n"), size: 8, color: muted))
            }
            let captionHeight = captions.map { measure($0.0, width: columnWidth) + measure($0.1, width: columnWidth) }.max() ?? 0
            let rowHeight = boxHeight + 6 + captionHeight
            ensureSpace(rowHeight)

            for (offset, photo) in row.enumerated() {
                let x = margin + CGFloat(offset) * (columnWidth + spacing)
                let box = CGRect(x: x, y: y, width: columnWidth, height: boxHeight)
                stripe.setFill()
                UIRectFill(box)
                if let image = UIImage(data: photo.imageData) {
                    let imageRect = MarkerGeometry.aspectFitRect(imageSize: image.size, in: box)
                    image.draw(in: imageRect)
                    drawMarkers(photo.markers, in: imageRect)
                }
                let titleHeight = draw(captions[offset].0, at: CGPoint(x: x, y: y + boxHeight + 4), width: columnWidth)
                draw(captions[offset].1, at: CGPoint(x: x, y: y + boxHeight + 5 + titleHeight), width: columnWidth)
            }
            y += rowHeight + 12
            index += 2
        }
    }

    private func drawMarkers(_ markers: [PhotoMarker], in rect: CGRect) {
        guard !markers.isEmpty else { return }
        let cg = context.cgContext
        let width = MarkerGeometry.lineWidth(in: rect)
        cg.saveGState()
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        for marker in markers {
            let path = MarkerGeometry.path(for: marker, in: rect)
            cg.addPath(path)
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(width + 1.5)
            cg.strokePath()
            cg.addPath(path)
            cg.setStrokeColor(UIColor.systemRed.cgColor)
            cg.setLineWidth(width)
            cg.strokePath()
        }
        cg.restoreGState()
    }

    // MARK: - Text

    private func attributed(
        _ string: String,
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.5
        return NSAttributedString(string: string, attributes: [
            .font: BrandFont.uiFont(size: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
    }

    private func measure(_ string: NSAttributedString, width: CGFloat) -> CGFloat {
        guard string.length > 0, width > 0 else { return 0 }
        let rect = string.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    @discardableResult
    private func draw(_ string: NSAttributedString, at origin: CGPoint, width: CGFloat) -> CGFloat {
        let height = measure(string, width: width)
        guard height > 0 else { return 0 }
        string.draw(
            with: CGRect(x: origin.x, y: origin.y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return height
    }

    private func line(at yPosition: CGFloat, color: UIColor? = nil, width: CGFloat = 0.5) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: yPosition))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: yPosition))
        (color ?? rule).setStroke()
        path.lineWidth = width
        path.stroke()
    }
}
