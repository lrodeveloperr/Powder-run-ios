import StoreKit
import SwiftUI

struct SettingsView: View {
    let model: ShellModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showPaywall = false
    @State private var legalDocument: LegalDocument?
    @State private var showingManageSubscriptions = false

    var body: some View {
        List {
            if model.access.configuration.includesPurchase, shouldShowUpgrade {
                Section {
                    Button { showPaywall = true } label: {
                        SettingsLabel("upgrade", subtitle: "upgrade.subtitle", symbol: "sparkles")
                    }
                    .accessibilityIdentifier("shell.settings.upgrade")
                }
            }

            if model.access.configuration.includesSubscription, let subscriptionPresentation {
                Section {
                    SettingsLabel(
                        "subscription.status",
                        verbatimSubtitle: subscriptionStatus,
                        symbol: subscriptionPresentation.symbol
                    )
                    if subscriptionPresentation.showsManagement {
                        Button { showingManageSubscriptions = true } label: {
                            SettingsLabel("subscription.manage", subtitle: "subscription.manage.subtitle", symbol: "person.crop.circle.badge.checkmark")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("shell.settings.subscription.manage")
                    }
                }
            }

            if model.backup.isEnabled {
                Section {
                    NavigationLink { BackupSettingsView() } label: {
                        SettingsLabel("backup", subtitle: model.backup.provider.providerName, symbol: "externaldrive")
                    }
                }
            }

            Section {
                NavigationLink { LanguageView() } label: {
                    SettingsLabel("language", subtitle: languageSubtitle, symbol: "globe")
                }
                Link(destination: URL(string: "mailto:\(ShellConfiguration.supportEmail)")!) {
                    SettingsLabel("support", subtitle: ShellConfiguration.supportEmail, symbol: "questionmark.circle")
                }
                if model.access.configuration.includesAdvertising && model.ads.isPrivacyOptionsRequired {
                    Button {
                        Task { await model.ads.presentPrivacyOptions() }
                    } label: {
                        SettingsLabel("privacyOptions", subtitle: "privacyOptions.subtitle", symbol: "hand.raised.square")
                    }
                }
                if model.access.configuration.includesAdvertising && model.ads.message != nil {
                    Button {
                        Task { await model.prepareAdvertisingIfNeeded() }
                    } label: {
                        SettingsLabel("privacyRetry", subtitle: "privacyRetry.subtitle", symbol: "arrow.clockwise")
                    }
                }
            }

            Section("legal") {
                Button { legalDocument = .privacy } label: {
                    SettingsLabel("privacyPolicy", symbol: "hand.raised")
                }
                .buttonStyle(.plain)
                Button { legalDocument = .terms } label: {
                    SettingsLabel("termsOfUse", symbol: "doc.text")
                }
                .buttonStyle(.plain)
            }

#if DEBUG
            Section("development") {
                Button {
                    dismiss()
                    Task { @MainActor in model.labPresented = true }
                } label: {
                    SettingsLabel("shellLab", subtitle: "shellLab.subtitle", symbol: "testtube.2")
                }
            }
#endif

            Section {
                Text("settings.footer").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("done") { dismiss() } } }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView(showsDoneButton: true) }
                .environment(model)
                .environment(model.language)
                .environment(\.locale, model.language.locale)
        }
        .sheet(item: $legalDocument) { document in
            LegalView(document: document)
                .ignoresSafeArea()
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
    }

    private var languageSubtitle: String {
        ShellConfiguration.supportedLanguages.first { $0.id == model.language.selection }?.displayName ?? "Follow system"
    }

    private var shouldShowUpgrade: Bool {
        guard !model.access.isEntitled else { return false }
        switch model.access.purchases.subscriptionCondition {
        case .checking, .billingRetry, .subscribed, .gracePeriod, .offlineCached:
            return false
        case .notApplicable, .expired, .revoked:
            return true
        }
    }

    private var subscriptionPresentation: SubscriptionSettingsPresentation? {
        SubscriptionSettingsPresentation.resolve(model.access.purchases.subscriptionCondition)
    }

    private var subscriptionStatus: String {
        switch model.access.purchases.subscriptionCondition {
        case .notApplicable, .expired, .revoked:
            return AppLocalization.string("subscription.inactive", locale: locale)
        case .checking:
            return AppLocalization.string("access.checking", locale: locale)
        case let .subscribed(willAutoRenew, expiration):
            return AppLocalization.string(willAutoRenew ? "subscription.renews %@" : "subscription.ends %@", locale: locale, subscriptionDate(expiration))
        case let .gracePeriod(expiration):
            return AppLocalization.string("subscription.grace %@", locale: locale, subscriptionDate(expiration))
        case .billingRetry:
            return AppLocalization.string("subscription.billingRetry", locale: locale)
        case let .offlineCached(expiration):
            return AppLocalization.string("subscription.offline %@", locale: locale, subscriptionDate(expiration))
        }
    }

    private func subscriptionDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(locale).day().month(.abbreviated).year())
    }
}

struct SubscriptionSettingsPresentation: Equatable {
    let showsManagement: Bool
    let symbol: String

    static func resolve(_ condition: SubscriptionCondition) -> Self? {
        switch condition {
        case .notApplicable, .expired, .revoked:
            return nil
        case .checking:
            return Self(showsManagement: false, symbol: "hourglass")
        case .subscribed:
            return Self(showsManagement: true, symbol: "checkmark.seal.fill")
        case .gracePeriod, .billingRetry:
            return Self(showsManagement: true, symbol: "exclamationmark.triangle.fill")
        case .offlineCached:
            return Self(showsManagement: true, symbol: "checkmark.seal")
        }
    }
}

private struct SettingsLabel: View {
    let titleKey: LocalizedStringKey
    let subtitle: String?
    let verbatimSubtitle: String?
    let symbol: String

    init(_ titleKey: LocalizedStringKey, subtitle: String? = nil, verbatimSubtitle: String? = nil, symbol: String) {
        self.titleKey = titleKey
        self.subtitle = subtitle
        self.verbatimSubtitle = verbatimSubtitle
        self.symbol = symbol
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey).foregroundStyle(Color.primary)
                if let subtitle { Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(Color.secondary) }
                if let verbatimSubtitle { Text(verbatimSubtitle).font(.caption).foregroundStyle(Color.secondary) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
        }
    }
}

private struct LanguageView: View {
    @Environment(LanguageController.self) private var language

    var body: some View {
        @Bindable var language = language
        Form {
            Picker("language", selection: $language.selection) {
                ForEach(ShellConfiguration.supportedLanguages) { option in
                    Text(option.displayName).tag(option.id)
                }
            }
            .pickerStyle(.inline)
            Text("language.help").font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("language")
    }
}
