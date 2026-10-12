import SwiftUI
import SwiftData
import CCTVCore

struct PriceListsView: View {
    @Query(sort: \PriceList.name) private var priceLists: [PriceList]
    @Environment(\.modelContext) private var modelContext
    @State private var confirmReset = false
    @State private var alert: AlertMessage?

    var body: some View {
        List {
            Section {
                Label("Alle Preise sind Beispielwerte in CHF exkl. MWST. Vor der ersten Offerte mit den aktuellen Distributorpreisen abgleichen.", systemImage: "info.circle")
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
            }
            ForEach(Manufacturer.allCases) { manufacturer in
                let lists = priceLists.filter { $0.manufacturer == manufacturer }
                if !lists.isEmpty {
                    Section(manufacturer.label) {
                        ForEach(lists) { list in
                            NavigationLink {
                                PriceListDetailView(priceList: list)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name).font(.brand(.headline))
                                    Text("\(list.products.count) Produkte · gültig ab \(Format.date(list.validFrom))\(list.isExampleData ? " · Beispieldaten" : "")")
                                        .font(.brand(.subheadline))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if priceLists.isEmpty {
                ContentUnavailableView {
                    Label("Keine Preislisten", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Laden Sie die mitgelieferten Beispielpreislisten, um Offerten zu berechnen.")
                } actions: {
                    Button("Beispielpreislisten laden") { resetExamples() }
                        .buttonStyle(.primaryAction)
                }
            }
        }
        .navigationTitle("Preislisten")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Beispielpreise zurücksetzen", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Beispielpreise zurücksetzen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) { resetExamples() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle als Beispieldaten markierten Preislisten werden durch die mitgelieferten Werte ersetzt. Eigene Anpassungen in diesen Listen gehen verloren.")
        }
        .messageAlert($alert)
    }

    private func resetExamples() {
        do {
            try PersistenceController.resetExamplePriceLists(context: modelContext)
        } catch {
            alert = AlertMessage(title: "Zurücksetzen fehlgeschlagen", text: error.localizedDescription)
        }
    }
}

struct PriceListDetailView: View {
    @Bindable var priceList: PriceList
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @State private var editing: ProductEditing?
    @State private var searchText = ""
    @State private var showMarginSheet = false
    @State private var alert: AlertMessage?

    struct ProductEditing: Identifiable {
        let record: ProductRecord
        let isNew: Bool
        var id: UUID { record.id }
    }

    private var products: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return priceList.products
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.articleNumber.localizedCaseInsensitiveContains(query) }
            .sorted { $0.sortKey < $1.sortKey }
    }

    var body: some View {
        List {
            Section {
                TextField("Name der Preisliste", text: $priceList.name)
                DatePicker("Gültig ab", selection: $priceList.validFrom, displayedComponents: .date)
                if !priceList.note.isEmpty {
                    Text(priceList.note).font(.brand(.footnote)).foregroundStyle(.secondary)
                }
            }
            ForEach(ProductCategory.allCases) { category in
                let items = products.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.label) {
                        ForEach(items) { product in
                            Button {
                                editing = ProductEditing(record: product.record, isNew: false)
                            } label: {
                                ProductRow(product: product.record)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    modelContext.delete(product)
                                    save()
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Produkt oder Artikelnummer")
        .navigationTitle(priceList.manufacturer.label)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showMarginSheet = true
                } label: {
                    Label("Marge anwenden", systemImage: "percent")
                }
                Button {
                    let record = ProductRecord(manufacturer: priceList.manufacturer, category: .kamera, name: "", purchasePrice: 0, sellPrice: 0)
                    editing = ProductEditing(record: record, isNew: true)
                } label: {
                    Label("Produkt hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { item in
            ProductEditorView(product: item.record, isNew: item.isNew) { updated in
                apply(updated)
            }
        }
        .sheet(isPresented: $showMarginSheet) {
            MarginSheet(productCount: priceList.products.count) { margin in
                applyMargin(margin)
            }
            .presentationDetents([.medium])
        }
        .onDisappear { save() }
        .messageAlert($alert)
    }

    private func apply(_ record: ProductRecord) {
        if let existing = priceList.products.first(where: { $0.id == record.id }) {
            existing.apply(record)
        } else {
            let product = Product(id: record.id)
            modelContext.insert(product)
            product.apply(record)
            priceList.products.append(product)
        }
        save()
    }

    private func applyMargin(_ margin: Decimal) {
        for product in priceList.products where product.purchaseRappen > 0 {
            var record = product.record
            record.sellPrice = PricingCalculator.sellPrice(purchase: record.purchasePrice, targetMarginPercent: margin)
            product.apply(record)
        }
        save()
        alert = AlertMessage(title: "Verkaufspreise angepasst", text: "Für alle Produkte mit Einkaufspreis wurde eine Marge von \(Format.percent(margin)) auf den Verkaufspreis angewendet (gerundet auf 5 Rappen).")
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            alert = AlertMessage(title: "Speichern fehlgeschlagen", text: error.localizedDescription)
        }
    }
}

struct ProductRow: View {
    let product: ProductRecord

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.brand(.subheadline).weight(.semibold))
                    .foregroundStyle(product.isActive ? .primary : .secondary)
                Text([product.articleNumber, product.tier.label, product.role.label].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.brand(.caption))
                    .foregroundStyle(.secondary)
                if !product.isActive {
                    Text("Inaktiv – wird nicht kalkuliert").font(.brand(.caption)).foregroundStyle(Theme.sonneText)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("VK \(Format.chf(product.sellPrice))")
                    .font(.brand(.subheadline).monospacedDigit().weight(.semibold))
                Text("EK \(Format.chf(product.purchasePrice)) · \(Format.percent(product.marginPercent))")
                    .font(.brand(.caption).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("pro \(product.unit.label)")
                    .font(.brand(.caption2))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct MarginSheet: View {
    let productCount: Int
    let onApply: (Decimal) -> Void
    @State private var margin: Double = 30
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $margin, in: 0...80, step: 1) {
                        LabeledContent("Zielmarge auf Verkaufspreis", value: "\(Int(margin)) %")
                    }
                    .frame(minHeight: 44)
                    Text("Verkaufspreis = Einkaufspreis ÷ (1 − Marge). Betrifft \(productCount) Produkte dieser Preisliste.")
                        .font(.brand(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Marge anwenden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anwenden") {
                        onApply(Decimal(Int(margin)))
                        dismiss()
                    }
                }
            }
        }
    }
}
