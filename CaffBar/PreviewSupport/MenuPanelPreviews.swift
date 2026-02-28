#if DEBUG
import SwiftUI

private struct MenuPanelPreviewHost: View {
    @StateObject private var controller: CaffeinateController

    init(makeController: @escaping () -> CaffeinateController) {
        _controller = StateObject(wrappedValue: makeController())
    }

    var body: some View {
        MenuPanelView(controller: controller, onQuit: {})
            .padding()
            .frame(width: 376)
    }
}

private struct DurationStripPreviewHost: View {
    @State private var days = 0
    @State private var hours = 1
    @State private var minutes = 30
    @State private var seconds = 0

    var body: some View {
        DurationStripRow(days: $days, hours: $hours, minutes: $minutes, seconds: $seconds)
            .padding()
            .frame(width: 320)
    }
}

struct MenuPanelPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuPanelPreviewHost(makeController: CaffeinateController.previewInactive)
                .previewDisplayName("Panel Inactive")

            MenuPanelPreviewHost(makeController: CaffeinateController.previewRunning)
                .preferredColorScheme(.light)
                .previewDisplayName("Panel Running")

            MenuPanelPreviewHost(makeController: CaffeinateController.previewRunning)
                .preferredColorScheme(.dark)
                .previewDisplayName("Panel Running Dark")

            MenuPanelPreviewHost(makeController: CaffeinateController.previewAttachValidation)
                .previewDisplayName("Panel Attach Validation")

            MenuPanelPreviewHost(makeController: CaffeinateController.previewAlertState)
                .previewDisplayName("Panel Alert")

            DurationStripPreviewHost()
                .previewDisplayName("Duration Strip")
        }
    }
}
#endif
