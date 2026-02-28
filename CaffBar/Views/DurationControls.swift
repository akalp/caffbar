import SwiftUI

struct MonospacedModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.monospacedDigit()
        } else {
            content
        }
    }
}

struct DurationStripRow: View {
    @Binding var days: Int
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            DurationUnitEditor(label: "Days", shortLabel: "D", value: $days, range: 0...30)
            DurationUnitEditor(label: "Hours", shortLabel: "H", value: $hours, range: 0...23)
            DurationUnitEditor(label: "Minutes", shortLabel: "M", value: $minutes, range: 0...59)
            DurationUnitEditor(label: "Seconds", shortLabel: "S", value: $seconds, range: 0...59)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DurationUnitEditor: View {
    let label: String
    let shortLabel: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shortLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)

            HStack(spacing: 4) {
                Stepper("", value: $value, in: range)
                    .labelsHidden()
                    .controlSize(.mini)
                    .fixedSize()
                    .accessibilityLabel(Text(label))

                Text("\(value)")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 20, alignment: .trailing)
                    .accessibilityLabel(Text("\(label) \(value)"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.015))
        }
    }
}
