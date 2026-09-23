import Foundation
import Observation
import PowderCoatingRunEngine

/// The ledger is the single source of shop truth. No editable state is cached
/// in a view and no UI flag authorizes a new job.
@MainActor
@Observable
final class ShopBoardModel {
    private(set) var ledger = ShopLedger()
    private(set) var access: ShopAccess = .free
    private(set) var busy = false
    var errorMessage: String?
    var backupURL: URL?
    var jobsCSVURL: URL?
    var batchCSVURL: URL?
    var reportURLs: [UUID: URL] = [:]
    var deepLinkedBatchID: UUID?

    @ObservationIgnored private var repository: LedgerRepository?
    @ObservationIgnored private var subscriptionStore: PowderRunSubscriptionStore?
    @ObservationIgnored private let activityService = PowderRunActivityService()

    var freeRunsRemaining: Int { JobAccessPolicy.freeRunsRemaining(in: ledger) }
    var mayEnterNewJob: Bool { JobAccessPolicy.canCreateJob(in: ledger, access: access) }

    func start() async {
        if repository == nil {
            do {
                let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask, appropriateFor: nil, create: true)
                let repo = try LedgerRepository(url: support.appendingPathComponent("powder-run-ledger.json"))
                let ids = try PowderRunSubscriptionProducts(
                    monthlyID: ShellConfiguration.monetization.subscriptionProductID,
                    yearlyID: ShellConfiguration.monetization.yearlySubscriptionProductID
                )
                repository = repo
                subscriptionStore = PowderRunSubscriptionStore(repository: repo, identifiers: ids)
            } catch {
                errorMessage = message(for: error)
                return
            }
        }
        await refresh()
    }

    func refresh() async {
        guard let repository, let subscriptionStore else { return }
        do {
            ledger = try await repository.snapshot()
            access = await subscriptionStore.currentAccess()
            await activityService.sync(with: ledger)
        } catch { errorMessage = message(for: error) }
    }

    @discardableResult
    func perform(_ change: @escaping @Sendable (inout ShopLedger) throws -> Void) async -> Bool {
        guard let subscriptionStore, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            // Entitlement is freshly verified inside transact; the repository
            // checks new-job creation while holding its cross-instance lock.
            try await subscriptionStore.transact(change)
            await refresh()
            return true
        } catch {
            errorMessage = message(for: error)
            await refresh()
            return false
        }
    }

    func export() async {
        guard let repository else { return }
        busy = true
        defer { busy = false }
        do {
            let snapshot = try await repository.snapshot()
            let backup = try await repository.backup()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PowderRunExports", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let json = directory.appendingPathComponent("powder-run-backup.json")
            let jobs = directory.appendingPathComponent("powder-run-jobs.csv")
            let batches = directory.appendingPathComponent("powder-run-batches.csv")
            try backup.write(to: json, options: .atomic)
            try LedgerArchive.jobsCSV(snapshot).write(to: jobs, atomically: true, encoding: .utf8)
            try LedgerArchive.batchCSV(snapshot).write(to: batches, atomically: true, encoding: .utf8)
            backupURL = json; jobsCSVURL = jobs; batchCSVURL = batches
        } catch { errorMessage = message(for: error) }
    }

    func prepareReport(jobID: UUID) async {
        guard let repository else { return }
        do {
            let ledger = try await repository.snapshot()
            let data = try PDFReport.job(ledger, jobID: jobID)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PowderRunExports", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("job-\(jobID.uuidString).pdf")
            try data.write(to: url, options: .atomic)
            reportURLs[jobID] = url
        } catch { errorMessage = message(for: error) }
    }

    func restore(from url: URL) async {
        guard let repository else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        busy = true
        defer { busy = false }
        do {
            let data = try Data(contentsOf: url)
            try await repository.restore(data)
            backupURL = nil; jobsCSVURL = nil; batchCSVURL = nil
            reportURLs = [:]
            await refresh()
        } catch { errorMessage = message(for: error) }
    }

    private func message(for error: Error) -> String {
        if let runError = error as? RunError { return runError.description }
        return error.localizedDescription
    }
}
