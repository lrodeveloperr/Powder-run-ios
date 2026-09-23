import SwiftUI

struct ShellRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let featureProvider: any FeatureCanvasProviding
    private let onDeepLink: @MainActor (URL) -> Void
    @State private var model: ShellModel
    @State private var legalConsent: LegalConsentStore

    init(
        featureProvider: any FeatureCanvasProviding,
        onDeepLink: @escaping @MainActor (URL) -> Void = { _ in },
        model: ShellModel = ShellModel(),
        legalConsent: LegalConsentStore = LegalConsentStore()
    ) {
        self.featureProvider = featureProvider
        self.onDeepLink = onDeepLink
        _model = State(initialValue: model)
        _legalConsent = State(initialValue: legalConsent)
    }

    var body: some View {
        Group {
            if let startupMessage = model.startupMessage {
                ContentUnavailableView {
                    Label("startup.error.title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(startupMessage)
                }
            } else if let onboarding = ShellConfiguration.onboarding,
                      legalConsent.requiresPresentation {
                OnboardingView(
                    profile: onboarding,
                    isReconsent: legalConsent.isReconsent,
                    onAccept: legalConsent.acceptCurrentLegalVersion
                )
            } else {
                shell
            }
        }
        .environment(model)
        .environment(model.language)
        .environment(\.locale, model.language.locale)
        .environment(\.layoutDirection, model.language.layoutDirection)
        .sheet(isPresented: $model.settingsPresented) {
            NavigationStack { SettingsView(model: model) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
                .environment(\.layoutDirection, model.language.layoutDirection)
        }
#if DEBUG
        .sheet(isPresented: $model.labPresented) {
            NavigationStack { ShellLabView(onResetOnboarding: legalConsent.resetForTesting) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
                .environment(\.layoutDirection, model.language.layoutDirection)
        }
#endif
        .sheet(isPresented: $model.paywallPresented) {
            NavigationStack { PaywallView(showsDoneButton: true) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
                .environment(\.layoutDirection, model.language.layoutDirection)
        }
        .task {
            await model.start()
            if !requiresOnboarding { await model.prepareAdvertisingIfNeeded() }
        }
        .onChange(of: requiresOnboarding) { _, requiresPresentation in
            if !requiresPresentation { Task { await model.prepareAdvertisingIfNeeded() } }
        }
        .onChange(of: model.access.shouldShowAd) { _, shouldShowAd in
            if shouldShowAd && !requiresOnboarding {
                Task { await model.prepareAdvertisingIfNeeded() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.access.purchases.refreshEntitlements() } }
        }
        .onOpenURL { url in
            guard url.scheme == "powderrun", url.host == "oven" else { return }
            model.selectedDestination = "oven"
            onDeepLink(url)
        }
    }

    private var requiresOnboarding: Bool {
        ShellConfiguration.onboarding != nil && legalConsent.requiresPresentation
    }

    @ViewBuilder
    private var shell: some View {
        if ShellConfiguration.destinations.count == 1, let destination = ShellConfiguration.destinations.first {
            destinationStack(destination)
        } else {
            TabView(selection: $model.selectedDestination) {
                ForEach(ShellConfiguration.destinations) { destination in
                    destinationStack(destination)
                    .tag(destination.id)
                    .tabItem { Label(LocalizedStringKey(destination.titleKey), systemImage: destination.symbol) }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
    }

    private func destinationStack(_ destination: ShellDestination) -> some View {
        NavigationStack {
            FeatureCanvasHost(destination: destination, provider: featureProvider)
                .safeAreaInset(edge: .bottom, spacing: 0) { adBanner }
                .navigationTitle(Text(LocalizedStringKey(destination.titleKey)))
                .shellSettingsToolbar()
        }
    }

    @ViewBuilder
    private var adBanner: some View {
        if model.shouldRenderAd {
            AdaptiveAdBanner(
                adUnitID: ShellConfiguration.advertising.bannerUnitID,
                requestsAds: model.ads.canRequestAds
            )
                .frame(maxWidth: .infinity)
                .background(.bar)
                .accessibilityLabel(Text("advertisement"))
                .accessibilityIdentifier("shell.ad.slot")
        }
    }
}

private extension View {
    func shellSettingsToolbar() -> some View { modifier(ShellSettingsToolbar()) }
}

private struct ShellSettingsToolbar: ViewModifier {
    @Environment(ShellModel.self) private var model

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("settings", systemImage: "gearshape") { model.settingsPresented = true }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("shell.settings")
            }
        }
    }
}
