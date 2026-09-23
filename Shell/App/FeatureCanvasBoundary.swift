import SwiftUI

/// The only boundary a derived app replaces. Product modules receive shell
/// access services without owning navigation, billing, ads, legal, or settings.
@MainActor
protocol FeatureCanvasProviding {
    func makeCanvas(for destination: ShellDestination, context: FeatureCanvasContext) -> AnyView
}

struct FeatureCanvasContext {
    let remainingFreeActions: () -> Int?
    let recordSuccessfulAction: (_ stableActionID: String) -> UsageRecordingResult
    let requestUpgrade: () -> Void
}

struct PlaceholderFeatureCanvasProvider: FeatureCanvasProviding {
    func makeCanvas(for destination: ShellDestination, context: FeatureCanvasContext) -> AnyView {
        AnyView(FeatureView(destination: destination, context: context))
    }
}

struct FeatureCanvasHost: View {
    let destination: ShellDestination
    let provider: any FeatureCanvasProviding
    @Environment(ShellModel.self) private var model

    @ViewBuilder
    var body: some View {
        switch model.access.decision {
        case .allowed:
            provider.makeCanvas(
                for: destination,
                context: FeatureCanvasContext(
                    remainingFreeActions: { model.access.remainingFreeActions },
                    recordSuccessfulAction: { model.access.recordSuccessfulAction(id: $0) },
                    requestUpgrade: { model.paywallPresented = true }
                )
            )
        case .checkingEntitlement:
            ProgressView("access.checking")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(Text("access.checking"))
        case .purchaseRequired:
            LockedFeatureView(
                titleKey: "access.purchase.title",
                messageKey: "access.purchase.message",
                onUpgrade: { model.paywallPresented = true }
            )
        case .usageLimitReached:
            LockedFeatureView(
                titleKey: "access.limit.title",
                messageKey: "access.limit.message",
                onUpgrade: { model.paywallPresented = true }
            )
        }
    }
}

private struct LockedFeatureView: View {
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey
    let onUpgrade: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(titleKey, systemImage: "lock.fill")
        } description: {
            Text(messageKey)
        } actions: {
            Button("upgrade", action: onUpgrade)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
