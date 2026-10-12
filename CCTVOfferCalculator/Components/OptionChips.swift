import SwiftUI
import CCTVCore

/// Fliesslayout, das Elemente zeilenweise umbricht.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Mehrfachauswahl als grosse Auswahlchips.
struct OptionChips<Option: LabeledOption>: View {
    @Binding var selection: Set<Option>
    var options: [Option] = Array(Option.allCases)

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                let isSelected = selection.contains(option)
                Button {
                    if isSelected {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .accessibilityHidden(true)
                        Text(option.label)
                    }
                    .font(.brand(.subheadline).weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(isSelected ? Theme.gruenSolid : Theme.subtle)
                    )
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Einfachauswahl mit Segmenten oder Menü.
struct OptionPicker<Option: LabeledOption>: View {
    let title: String
    @Binding var selection: Option
    var segmented = false

    var body: some View {
        if segmented {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.brand(.subheadline))
                    .foregroundStyle(.secondary)
                Picker(title, selection: $selection) {
                    ForEach(Array(Option.allCases)) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
            }
            .padding(.vertical, 4)
        } else {
            Picker(title, selection: $selection) {
                ForEach(Array(Option.allCases)) { option in
                    Text(option.label).tag(option)
                }
            }
            .frame(minHeight: 44)
        }
    }
}

/// Eingabefeld für CHF-Beträge und Prozentwerte.
struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    var suffix: String = "CHF"
    var fractionDigits = 2

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...fractionDigits)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
                .monospacedDigit()
            Text(suffix)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
