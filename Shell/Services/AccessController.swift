import Foundation
import Observation

enum AccessDecision: Equatable, Sendable {
    case allowed
    case checkingEntitlement
    case purchaseRequired
    case usageLimitReached
}

@MainActor
@Observable
final class AccessController {
    let configuration: MonetizationConfiguration
    let purchases: PurchaseService
    let usage: UsageLedger

    init(
        configuration: MonetizationConfiguration = ShellConfiguration.monetization,
        purchases: PurchaseService? = nil,
        usage: UsageLedger? = nil
    ) {
        self.configuration = configuration
        self.purchases = purchases ?? PurchaseService(configuration: configuration)
        self.usage = usage ?? UsageLedger(limit: configuration.freeSuccessfulActions)
    }

    var decision: AccessDecision {
        // A domain-scoped limit must not hide existing jobs, records or exports.
        // The feature repository validates new-job creation inside its file lock.
        return Self.resolveDecision(
            mode: configuration.mode,
            isEntitled: purchases.isEntitled,
            isChecking: purchases.isChecking,
            hasFreeActionRemaining: usage.hasFreeActionRemaining,
            featureScopedGate: configuration.featureScopedGate
        )
    }

    static func resolveDecision(
        mode: MonetizationMode,
        isEntitled: Bool,
        isChecking: Bool,
        hasFreeActionRemaining: Bool,
        featureScopedGate: Bool = false
    ) -> AccessDecision {
        if featureScopedGate && (mode == .usageCapWithSubscription || mode == .usageCapWithOneTimeUnlock) {
            return .allowed
        }
        return switch mode {
        case .free, .ads, .adsWithRemovePurchase, .adsWithSubscription:
            .allowed
        case .oneTimeUnlock, .subscription:
            if isEntitled { .allowed }
            else if isChecking { .checkingEntitlement }
            else { .purchaseRequired }
        case .usageCapWithOneTimeUnlock, .usageCapWithSubscription:
            if isEntitled || hasFreeActionRemaining { .allowed }
            else if isChecking { .checkingEntitlement }
            else { .usageLimitReached }
        }
    }

    var remainingFreeActions: Int? {
        switch configuration.mode {
        case .usageCapWithOneTimeUnlock, .usageCapWithSubscription:
            usage.remaining
        default:
            nil
        }
    }

    var shouldShowAd: Bool {
        Self.resolveAdVisibility(
            mode: configuration.mode,
            isEntitled: purchases.isEntitled,
            isChecking: purchases.isChecking
        )
    }

    static func resolveAdVisibility(mode: MonetizationMode, isEntitled: Bool, isChecking: Bool) -> Bool {
        switch mode {
        case .ads:
            true
        case .adsWithRemovePurchase, .adsWithSubscription:
            !isChecking && !isEntitled
        default:
            false
        }
    }

    @discardableResult
    func recordSuccessfulAction(id: String) -> UsageRecordingResult {
        switch configuration.mode {
        case .usageCapWithOneTimeUnlock, .usageCapWithSubscription:
            guard !purchases.isEntitled else { return .notMetered }
            return usage.recordSuccessfulAction(id: id)
        default:
            return .notMetered
        }
    }
}
