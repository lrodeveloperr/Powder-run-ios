import Foundation

/// The iOS host must derive `.pro` from a currently verified StoreKit subscription.
/// The ledger never stores purchase status, so a backup cannot grant access.
public enum ShopAccess: Sendable, Equatable { case free, pro }

public enum JobAccessPolicy {
    /// Five first-pass runs demonstrate a shared load and a repeat cycle.
    /// Rework is never counted. Jobs already entered may finish after the quota.
    public static let freeFirstPassRuns = 5

    public static func firstPassRuns(in ledger: ShopLedger) -> Int {
        ledger.links.filter { $0.parentRunID == nil }.count
    }

    public static func freeRunsRemaining(in ledger: ShopLedger) -> Int {
        max(0, freeFirstPassRuns - firstPassRuns(in: ledger))
    }

    public static func canCreateJob(in ledger: ShopLedger, access: ShopAccess) -> Bool {
        access == .pro || freeRunsRemaining(in: ledger) > 0
    }

    /// Called inside the repository's disk lock after mutation, before commit.
    /// Existing jobs, including jobs with pending items, remain completable without Pro.
    public static func validateJobCreation(before: ShopLedger, after: ShopLedger, access: ShopAccess) throws {
        let oldIDs = Set(before.jobs.map(\.id))
        let newJobs = after.jobs.filter { !oldIDs.contains($0.id) }
        guard newJobs.isEmpty || access == .pro || firstPassRuns(in: before) < freeFirstPassRuns else {
            throw RunError.invalid("Five first-pass runs are free. Subscribe before entering another job; existing jobs and rework remain available.")
        }
    }
}
