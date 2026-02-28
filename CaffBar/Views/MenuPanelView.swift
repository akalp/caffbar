import SwiftUI
import AppKit

struct MenuPanelView: View {
    private enum UI {
        static let panelWidth: CGFloat = 344
        static let panelPadding: CGFloat = 10
        static let sectionSpacing: CGFloat = 8
        static let cardCorner: CGFloat = 10
        static let insetCorner: CGFloat = 8
    }

    @ObservedObject var controller: CaffeinateController
    let onQuit: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: UI.sectionSpacing) {
            headerCard
            presetsCard
            durationCard
            modeCard
            advancedCard
            footerRow
        }
        .padding(UI.panelPadding)
        .frame(width: UI.panelWidth)
        .background(panelBackground)
        .controlSize(.small)
        .alert(item: $controller.alertItem, content: alert(for:))
    }

    private var headerCard: some View {
        cardContainer {
            HStack(spacing: 10) {
                Circle()
                    .fill(controller.isRunning ? Color.green : Color.secondary.opacity(0.75))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.isRunning ? "Active" : "Inactive")
                        .font(.headline)

                    if controller.isRunning {
                        HStack(spacing: 5) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(controller.remainingText)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    } else {
                        Text("ready to start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: controller.isRunning ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(controller.isRunning ? .primary : .secondary)
                    .frame(width: 26, height: 26)
            }
        }
    }

    private var presetsCard: some View {
        sectionCard(title: "Presets", systemImage: "timer") {
            HStack(spacing: 6) {
                Button("15m", action: startPreset15m)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.small)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)

                Button("1h", action: startPreset1h)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.small)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)

                Button("3h", action: startPreset3h)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.small)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)

                Button("8h", action: startPreset8h)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.small)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)

                Button("∞", action: startPresetInfinity)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.small)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(Text(CaffBarPreset.infinity.title))

                Spacer(minLength: 0)
            }
        }
    }

    private var durationCard: some View {
        sectionCard(title: "Duration", systemImage: "hourglass", trailingText: durationSummaryText, trailingMonospaced: true) {
            VStack(alignment: .leading, spacing: 7) {
                if controller.attachToPID {
                    microBanner(text: "Duration disabled while attached to a process.", systemImage: "link")
                }

                insetSurface {
                    DurationStripRow(
                        days: controller.durationBinding(\.days, range: 0...30),
                        hours: controller.durationBinding(\.hours, range: 0...23),
                        minutes: controller.durationBinding(\.minutes, range: 0...59),
                        seconds: controller.durationBinding(\.seconds, range: 0...59)
                    )
                    .disabled(controller.attachToPID)
                    .opacity(controller.attachToPID ? 0.5 : 1)
                }

                HStack(spacing: 6) {
                    Image(systemName: "infinity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(controller.attachToPID ? "Use Start Session after setting a PID." : "Set all to 0 for infinity. Use Start Session below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var modeCard: some View {
        sectionCard(title: "Mode", systemImage: "moon.zzz", trailingText: modeSummaryText) {
            VStack(alignment: .leading, spacing: 8) {
                insetSurface {
                    VStack(alignment: .leading, spacing: 4) {
                        modeOptionRow("Keep display awake", flag: "-d", isOn: $controller.keepDisplayAwake)
                        modeOptionRow("Keep idle awake", flag: "-i", isOn: $controller.keepIdleAwake)
                        modeOptionRow("Keep system awake", flag: "-s", isOn: $controller.keepSystemAwake)
                        modeOptionRow("Declare user active", flag: "-u", isOn: $controller.declareUserActive)
                        modeOptionRow("Prevent disk sleep", flag: "-m", isOn: $controller.preventDiskSleep)
                    }
                }

                Text("Mode controls what macOS is prevented from sleeping.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var advancedCard: some View {
        sectionCard(title: "Advanced", systemImage: "slider.horizontal.3") {
            Button(action: toggleAdvancedOptions) {
                HStack(spacing: 8) {
                    Image(systemName: controller.isAdvancedExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Show advanced options")
                        .font(.subheadline)
                    Spacer()
                    stateChip(text: advancedSummaryText)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if controller.isAdvancedExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    insetSurface {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Attach to process (-w)", isOn: $controller.attachToPID)

                            HStack(spacing: 8) {
                                Text("PID")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .leading)
                                Spacer()
                                TextField("12345", text: pidInputBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    .disabled(!controller.attachToPID)
                            }
                            .opacity(controller.attachToPID ? 1 : 0.55)
                        }
                    }

                    Text("Keeps awake until that process exits.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let inlineError = controller.inlineErrorMessage {
                        microBanner(text: inlineError, systemImage: "exclamationmark.triangle.fill", tint: .red, backgroundTint: .red)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Button(action: controller.startFooterPrimary) {
                HStack(spacing: 10) {
                    Image(systemName: primaryActionSymbol)
                        .font(.headline.weight(.bold))
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(primaryActionTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(primaryActionSubtitle)
                            .font(.caption)
                            .foregroundStyle(primaryActionSubtitleColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(primaryActionFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(primaryActionBorderColor, lineWidth: 0.9)
                        }
                }
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .help(primaryActionHelpText)

            Button(action: onQuit) {
                VStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.subheadline.weight(.semibold))
                    Text("Quit")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(quitActionForegroundColor)
                .frame(width: 62)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(quitActionFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(borderColor, lineWidth: 0.8)
                        }
                }
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Quit CaffBar")
                .keyboardShortcut("q")
        }
        .padding(.top, 4)
        .controlSize(.regular)
    }

    private var advancedSummaryText: String {
        controller.attachToPID ? "PID" : "Off"
    }

    private var primaryActionTitle: String {
        controller.isRunning ? "Stop Session" : "Start Session"
    }

    private var primaryActionSubtitle: String {
        if controller.isRunning {
            return "Release sleep assertions now"
        }

        if controller.attachToPID {
            return "Keep awake until the linked process exits"
        }

        return durationSummaryText == "∞" ? "Run until you stop it" : "Run for \(durationSummaryText)"
    }

    private var primaryActionSymbol: String {
        controller.isRunning ? "stop.fill" : "play.fill"
    }

    private var primaryActionHelpText: String {
        controller.isRunning ? "Stop the current caffeinate session" : "Start a new caffeinate session"
    }

    private var modeSummaryText: String {
        let enabledCount = [
            controller.keepDisplayAwake,
            controller.keepIdleAwake,
            controller.keepSystemAwake,
            controller.declareUserActive,
            controller.preventDiskSleep
        ].filter { $0 }.count
        return "\(enabledCount) on"
    }

    private var durationSummaryText: String {
        let total = controller.durationComponents.totalSeconds
        if total == 0 { return "∞" }

        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    private var pidInputBinding: Binding<String> {
        Binding(
            get: { controller.attachPIDText },
            set: { newValue in
                controller.attachPIDText = newValue.filter(\.isNumber)
            }
        )
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        systemImage: String,
        trailingText: String? = nil,
        trailingMonospaced: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    if let trailingText {
                        stateChip(text: trailingText, monospaced: trailingMonospaced)
                    }
                }

                content()
            }
        }
    }

    @ViewBuilder
    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: UI.cardCorner, style: .continuous)
                .fill(cardFillStyle)
                .overlay {
                    RoundedRectangle(cornerRadius: UI.cardCorner, style: .continuous)
                        .stroke(borderColor, lineWidth: 0.8)
                }
        }
    }

    @ViewBuilder
    private func insetSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: UI.insetCorner, style: .continuous)
                .fill(insetFillStyle)
        }
    }

    private func stateChip(text: String, monospaced: Bool = false) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .modifier(MonospacedModifier(enabled: monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(insetFillStyle)
            }
    }

    private func modeOptionRow(_ title: String, flag: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                stateChip(text: flag, monospaced: true)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(toggleRowFillColor)
        }
    }

    private func microBanner(text: String, systemImage: String, tint: Color = .secondary, backgroundTint: Color = .secondary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(microBannerFillColor(backgroundTint))
        }
    }

    private var cardFillStyle: AnyShapeStyle {
        AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.90 : 0.96))
    }

    private var insetFillStyle: AnyShapeStyle {
        AnyShapeStyle(Color(nsColor: .textBackgroundColor).opacity(colorScheme == .dark ? 0.82 : 0.96))
    }

    private var primaryActionFill: AnyShapeStyle {
        let baseColor = controller.isRunning
            ? Color(nsColor: .systemOrange)
            : Color(nsColor: .controlAccentColor)
        let startOpacity = colorScheme == .dark ? 0.98 : 1.0
        let endOpacity = colorScheme == .dark ? 0.82 : 0.86
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    baseColor.opacity(startOpacity),
                    baseColor.opacity(endOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var primaryActionBorderColor: Color {
        let baseColor = controller.isRunning
            ? Color(nsColor: .systemOrange)
            : Color(nsColor: .controlAccentColor)
        return baseColor.opacity(colorScheme == .dark ? 0.88 : 0.62)
    }

    private var primaryActionSubtitleColor: Color {
        Color.white.opacity(0.78)
    }

    private var quitActionFill: AnyShapeStyle {
        AnyShapeStyle(Color(nsColor: .textBackgroundColor).opacity(colorScheme == .dark ? 0.72 : 0.92))
    }

    private var quitActionForegroundColor: Color {
        Color(nsColor: .secondaryLabelColor)
    }

    private var borderColor: Color {
        Color(nsColor: .separatorColor).opacity(colorScheme == .dark ? 0.75 : 0.55)
    }

    private var toggleRowFillColor: Color {
        Color(nsColor: .quaternaryLabelColor).opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    private func microBannerFillColor(_ tint: Color) -> AnyShapeStyle {
        AnyShapeStyle(tint.opacity(colorScheme == .dark ? 0.20 : 0.12))
    }

    private var panelBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Rectangle()
                .fill(.thinMaterial)
        }
    }

    private func alert(for item: MenuAlertItem) -> Alert {
        Alert(
            title: Text(item.title),
            message: Text(item.message),
            dismissButton: .default(Text("OK"), action: controller.dismissAlert)
        )
    }

    private func startPreset15m() { controller.startPreset(.minutes15) }
    private func startPreset1h() { controller.startPreset(.hour1) }
    private func startPreset3h() { controller.startPreset(.hours3) }
    private func startPreset8h() { controller.startPreset(.night8) }
    private func startPresetInfinity() { controller.startPreset(.infinity) }
    private func toggleAdvancedOptions() { controller.isAdvancedExpanded.toggle() }

    var debugPIDBinding: Binding<String> {
        pidInputBinding
    }

    func debugTriggerPreset(_ preset: CaffBarPreset) {
        switch preset {
        case .minutes15: startPreset15m()
        case .hour1: startPreset1h()
        case .hours3: startPreset3h()
        case .night8: startPreset8h()
        case .infinity: startPresetInfinity()
        }
    }

    func debugTriggerQuit() {
        onQuit()
    }
}
