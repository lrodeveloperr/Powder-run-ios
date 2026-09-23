#if canImport(StoreKit)
import Foundation
import StoreKit

/// Configure these IDs in an auto-renewable subscription group in App Store Connect.
/// The host owns the IDs; the package never hard-codes storefront prices.
public struct PowderRunSubscriptionProducts: Sendable {
    public let monthlyID: String
    public let yearlyID: String

    public init(monthlyID: String, yearlyID: String) throws {
        guard !monthlyID.isEmpty, !yearlyID.isEmpty, monthlyID != yearlyID else {
            throw RunError.invalid("Configure distinct monthly and yearly subscription product IDs.")
        }
        self.monthlyID = monthlyID
        self.yearlyID = yearlyID
    }
}

public enum PowderRunPurchaseOutcome: Sendable { case active, pending, cancelled }

/// This is the iOS/macOS StoreKit boundary. Never persist the returned access in
/// the ledger or pass `.pro` based on the paywall's own UI state.
public actor PowderRunSubscriptionStore {
    private let repository: LedgerRepository
    private let identifiers: PowderRunSubscriptionProducts

    public init(repository: LedgerRepository, identifiers: PowderRunSubscriptionProducts) {
        self.repository = repository
        self.identifiers = identifiers
    }

    /// Product.displayPrice is localized by the App Store; show it verbatim.
    public func products() async throws -> [Product] {
        let found = try await Product.products(for: [identifiers.monthlyID, identifiers.yearlyID])
        guard found.count == 2, found.allSatisfy({ $0.type == .autoRenewable }) else {
            throw RunError.invalid("The monthly and yearly subscriptions are unavailable. Check App Store Connect configuration.")
        }
        return [identifiers.monthlyID, identifiers.yearlyID].compactMap { identifier in
            found.first(where: { $0.id == identifier })
        }
    }

    /// StoreKit excludes expired subscriptions and includes an enabled billing
    /// grace period in currentEntitlements. Check again on every transaction so
    /// an expired, refunded or revoked subscription cannot authorize new work.
    public func currentAccess() async -> ShopAccess {
        let acceptedIDs: Set<String> = [identifiers.monthlyID, identifiers.yearlyID]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  acceptedIDs.contains(transaction.productID),
                  transaction.productType == .autoRenewable,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }
            return .pro
        }
        return .free
    }

    /// Use this entry point for all mutations in the iOS host. The repository
    /// validates the free boundary within its disk lock before committing.
    public func transact<T: Sendable>(
        _ mutate: @Sendable (inout ShopLedger) throws -> T
    ) async throws -> T {
        let access = await currentAccess()
        return try await repository.transact(access: access, mutate)
    }

    public func purchase(_ product: Product) async throws -> PowderRunPurchaseOutcome {
        guard product.id == identifiers.monthlyID || product.id == identifiers.yearlyID,
              product.type == .autoRenewable else {
            throw RunError.invalid("Select one of this app's subscriptions.")
        }
        switch try await product.purchase() {
        case .success(let result):
            guard case .verified(let transaction) = result,
                  transaction.productID == product.id else {
                throw RunError.invalid("The App Store could not verify this purchase.")
            }
            await transaction.finish()
            // The signed purchase can arrive before currentEntitlements refreshes.
            // Keep new work gated until StoreKit confirms ongoing access.
            return await currentAccess() == .pro ? .active : .pending
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw RunError.invalid("The App Store returned an unrecognized purchase state.")
        }
    }

    /// Invoke only from an explicit Restore Purchases action; sync may prompt.
    public func restorePurchases() async throws -> ShopAccess {
        try await AppStore.sync()
        return await currentAccess()
    }
}
#endif
