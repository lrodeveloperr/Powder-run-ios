import SwiftUI

enum ShellConfiguration {
    static let appName = "Powder Run"
    static let tint = Color(red: 0.08, green: 0.49, blue: 0.51)
    static let supportEmail = "info@worksbienstudios.com"

    static let legal = LegalConfiguration(
        version: "1",
        privacyURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/powder-run/privacy/")!,
        termsURL: URL(string: "https://lrodeveloperr.github.io/privacy-policy/powder-run/terms/")!
    )

    /// Set to nil when the product does not have a genuine onboarding need.
    /// Published legal links alone do not require a blocking acceptance screen.
    static let onboarding: OnboardingProfile? = nil

    static let monetization = MonetizationConfiguration(
        mode: .usageCapWithSubscription,
        freeSuccessfulActions: 5,
        lifetimeProductID: "com.goodusestudios.powderrun.pro.lifetime.unused",
        subscriptionProductID: "com.goodusestudios.powderrun.pro.monthly",
        yearlySubscriptionProductID: "com.goodusestudios.powderrun.pro.yearly",
        // The ledger gates only new jobs after five first-pass runs. Existing
        // work must remain visible and mutable after the subscription lapses.
        featureScopedGate: true
    )

    static let advertising = AdvertisingConfiguration(
        bannerUnitID: "ca-app-pub-3940256099942544/2435281174"
    )

    /// Cloud is absent by default. A derived app must enable this and inject an
    /// app-owned provider only after privacy, entitlements and conflict UX review.
    static let backup = BackupConfiguration(enabled: false)

    /// New installs record the current contract. Derived apps add an explicit,
    /// ordered step here before adopting a breaking shell contract.
    static let migrations: [ShellMigration] = []

    static let destinations: [ShellDestination] = [
        .init(id: "jobs", titleKey: "powder.jobs", symbol: "list.bullet"),
        .init(id: "oven", titleKey: "powder.oven", symbol: "flame"),
        .init(id: "history", titleKey: "powder.history", symbol: "clock.arrow.circlepath"),
    ]

    /// Only locales with complete app text belong here. The 31-locale shared
    /// terminology baseline is tracked separately in LocalizationBaseline.swift.
    static let supportedLanguages: [AppLanguage] = [
        .init(id: "system", displayName: "Follow system"),
        .init(id: "en", displayName: "English"),
    ]
}

struct LegalConfiguration: Sendable {
    let version: String
    let privacyURL: URL
    let termsURL: URL
}

enum OnboardingProfile: Equatable, Sendable {
    case legalOnly
    case singleScreen
    case guidedTour
}

struct AdvertisingConfiguration: Sendable {
    let bannerUnitID: String
}

struct BackupConfiguration: Sendable {
    let enabled: Bool
}

struct MonetizationConfiguration: Sendable {
    let mode: MonetizationMode
    let freeSuccessfulActions: Int
    let lifetimeProductID: String
    let subscriptionProductID: String
    var yearlySubscriptionProductID: String = ""
    var featureScopedGate: Bool = false

    var subscriptionProductIDs: Set<String> {
        [subscriptionProductID, yearlySubscriptionProductID].filter { !$0.isEmpty }.reduce(into: Set<String>()) { $0.insert($1) }
    }

    var productIDs: Set<String> {
        switch mode {
        case .adsWithRemovePurchase, .oneTimeUnlock, .usageCapWithOneTimeUnlock:
            [lifetimeProductID]
        case .adsWithSubscription, .subscription, .usageCapWithSubscription:
            subscriptionProductIDs
        case .free, .ads:
            []
        }
    }

    var includesAdvertising: Bool { mode == .ads || mode == .adsWithRemovePurchase || mode == .adsWithSubscription }
    var includesPurchase: Bool { !productIDs.isEmpty }
    var includesSubscription: Bool { mode == .adsWithSubscription || mode == .subscription || mode == .usageCapWithSubscription }
}

struct ShellDestination: Hashable, Identifiable, Sendable {
    let id: String
    let titleKey: String
    let symbol: String

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AppLanguage: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
}

enum MonetizationMode: String, CaseIterable, Identifiable, Sendable {
    case free
    case ads
    case adsWithRemovePurchase
    case adsWithSubscription
    case oneTimeUnlock
    case subscription
    case usageCapWithOneTimeUnlock
    case usageCapWithSubscription

    var id: Self { self }
    var title: String {
        switch self {
        case .free: "Free"
        case .ads: "Ads"
        case .adsWithRemovePurchase: "Ads + remove purchase"
        case .adsWithSubscription: "Ads + subscription"
        case .oneTimeUnlock: "One-time unlock"
        case .subscription: "Subscription"
        case .usageCapWithOneTimeUnlock: "Usage cap + one-time unlock"
        case .usageCapWithSubscription: "Usage cap + subscription"
        }
    }
}

enum SampleContentState: String, CaseIterable, Identifiable, Sendable {
    case populated, empty, loading, error
    var id: Self { self }
    var title: String { rawValue.capitalized }
}
