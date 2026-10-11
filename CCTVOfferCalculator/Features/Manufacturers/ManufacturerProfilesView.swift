import SwiftUI
import SwiftData
import CCTVCore

struct ManufacturerProfilesView: View {
    @Query private var products: [Product]

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Neutrale Kurzprofile als Beratungshilfe. Die Bewertung im Projekt berücksichtigt diese Schwerpunkte automatisch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(ManufacturerProfiles.all) { profile in
                        ManufacturerProfileCard(
                            profile: profile,
                            productCount: products.filter { $0.manufacturerRaw == profile.manufacturer.rawValue && $0.isActive }.count
                        )
                    }
                }
            }
            .padding()
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("Herstellerprofile")
    }
}

struct ManufacturerProfileCard: View {
    let profile: ManufacturerProfile
    let productCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(profile.manufacturer.label)
                    .font(.title2.weight(.bold))
                Spacer()
                Text(profile.segment)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.subtle, in: Capsule())
            }
            Text(profile.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LabeledContent("Typische Grösse", value: profile.typicalSize)
                .font(.subheadline)
            LabeledContent("Ökosystem", value: profile.ecosystem)
                .font(.subheadline)
            LabeledContent("Aktive Produkte", value: "\(productCount)")
                .font(.subheadline)
            group("Stärken", profile.strengths, "plus.circle.fill", Theme.success)
            group("Einschränkungen", profile.limitations, "minus.circle.fill", .red)
            group("Bevorzugt, wenn", profile.preferredWhen, "hand.thumbsup.fill", Theme.navy)
            group("Eher nicht, wenn", profile.avoidWhen, "hand.thumbsdown.fill", .orange)
        }
        .card()
    }

    private func group(_ title: String, _ items: [String], _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            FactorList(items: items, systemImage: symbol, tint: tint)
        }
    }
}
