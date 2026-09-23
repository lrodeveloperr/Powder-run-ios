import ActivityKit
import LiveActivityKit
import SwiftUI
import WidgetKit

@main
struct PowderRunWidgets: WidgetBundle {
    var body: some Widget { PowderOvenActivityWidget() }
}

private struct PowderOvenActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PowderRunActivityAttributes.self) { context in
            LiveActivityLockScreenCard(model: context.state.model, theme: .porcelain)
                .widgetURL(deepLink(context.attributes.batchID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityExpandedIslandView(model: context.state.model, theme: .porcelain)
                }
            } compactLeading: {
                LiveActivityCompactLeadingView(model: context.state.model)
            } compactTrailing: {
                LiveActivityCompactTrailingView(model: context.state.model)
            } minimal: {
                LiveActivityMinimalView(model: context.state.model)
            }
            .widgetURL(deepLink(context.attributes.batchID))
        }
    }

    private func deepLink(_ batchID: String) -> URL? {
        URL(string: "powderrun://oven/\(batchID)")
    }
}
