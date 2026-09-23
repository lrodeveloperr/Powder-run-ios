import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public enum LedgerArchive {
    public static func encode(_ ledger: ShopLedger) throws -> Data {
        try ledger.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(ledger)
    }

    public static func decode(_ data: Data) throws -> ShopLedger {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let ledger = try decoder.decode(ShopLedger.self, from: data)
        try ledger.validate()
        return ledger
    }

    public static func jobsCSV(_ ledger: ShopLedger) throws -> String {
        try ledger.validate()
        var rows = ["job_reference,item_identity,substrate,finish,intake,released,rework_pending,scrapped,not_processed,closed_at,post_handoff_quality_alert"]
        for job in ledger.jobs {
            for item in job.items {
                let s = try ledger.summary(jobID: job.id, itemID: item.id)
                rows.append([job.reference, item.identity, item.substrate, item.finish,
                             String(s.intake), String(s.released), String(s.reworkPending),
                             String(s.scrapped), String(s.notProcessed),
                             job.closedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                             job.closedAt != nil && ledger.links.contains(where: { link in
                                 link.jobID == job.id && link.itemID == item.id &&
                                 ledger.runs.contains(where: { $0.id == link.runID && $0.qualityHold })
                             }) ? "YES" : "NO"]
                    .map(csvField).joined(separator: ","))
            }
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    public static func batchCSV(_ ledger: ShopLedger) throws -> String {
        try ledger.validate()
        var rows = ["batch,oven,run_id,job,part,original_job,original_part,powder_code,powder_lot,quantity,part_temp_start,part_temp_end,dwell_seconds,inspection_at,inspection_operator,inspection_note,pass,rework,scrap,defect_code,defect_reason,hold,handoff_at,post_handoff_alert"]
        for batch in ledger.batches {
            for runID in batch.runIDs {
                guard let run = ledger.runs.first(where: { $0.id == runID }),
                      let link = ledger.links.first(where: { $0.runID == runID }) else { continue }
                let startReading = run.dwellStartedAt.flatMap { time in
                    run.observations.indices.first(where: { run.observations[$0].kind == .partMetal && run.observations[$0].recordedAt == time })
                }.map { String(describing: run.effectiveCelsius(at: $0)) } ?? ""
                let endReading = run.dwellEndedAt.flatMap { time in
                    run.observations.indices.last(where: { run.observations[$0].kind == .partMetal && run.observations[$0].recordedAt == time })
                }.map { String(describing: run.effectiveCelsius(at: $0)) } ?? ""
                let job = ledger.jobs.first(where: { $0.id == link.jobID })
                let item = job?.items.first(where: { $0.id == link.itemID })
                rows.append([batch.loadIdentity, batch.equipment, runID.uuidString,
                             job?.reference ?? run.jobReference, item?.identity ?? run.partDescription,
                             run.jobReference, run.partDescription, run.recipe.productCode,
                             link.powderLot, String(run.quantity), startReading, endReading,
                             run.dwellStartedAt.flatMap { start in run.dwellEndedAt.map { String(Int($0.timeIntervalSince(start))) } } ?? "",
                             run.inspection.map { ISO8601DateFormatter().string(from: $0.checkedAt) } ?? "",
                             run.inspection?.operatorName ?? "", run.inspection?.note ?? "",
                             String(run.disposition?.passed ?? 0), String(run.disposition?.rework ?? 0),
                             String(run.disposition?.scrapped ?? 0), run.disposition?.defectCode?.rawValue ?? "",
                             run.disposition?.reason ?? "", run.qualityHold ? "YES" : "NO",
                             job?.closedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                             job?.closedAt != nil && run.qualityHold ? "YES" : "NO"]
                    .map(csvField).joined(separator: ","))
            }
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    private static func csvField(_ value: String) -> String {
        // Quoting every cell prevents formula execution when opened in spreadsheets.
        let leading = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = "=+-@".contains(leading.first ?? " ") ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// An iOS host app can put this URL in Application Support, exclude it from iCloud if desired,
/// and share explicit backup bytes with Files. Never decode in place over the live store.
public struct LedgerFileStore {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> ShopLedger {
        guard FileManager.default.fileExists(atPath: url.path) else { return ShopLedger() }
        return try LedgerArchive.decode(Data(contentsOf: url))
    }

    public func save(_ ledger: ShopLedger) throws {
        let data = try LedgerArchive.encode(ledger)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen],
                                              ofItemAtPath: temporary.path)
        #endif
        // No throwing operation follows the rename: a failed protection operation cannot
        // make disk look committed while the repository still holds the prior snapshot.
        guard rename(temporary.path, url.path) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    /// The lock spans reload, mutation, validation and commit across repository instances.
    public func withExclusiveLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let descriptor = open(url.path + ".lock", O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { _ = close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try body()
    }

    /// Explicit restore replaces the store only after all links and counts validate.
    public func restore(_ backup: Data) throws -> ShopLedger {
        let candidate = try LedgerArchive.decode(backup)
        try save(candidate)
        return candidate
    }
}

/// Serialize writes from multiple iOS scenes; commit memory only after atomic disk save succeeds.
public actor LedgerRepository {
    private let store: LedgerFileStore
    private var ledger: ShopLedger

    public init(url: URL) throws {
        let disk = LedgerFileStore(url: url)
        store = disk
        ledger = try disk.load()
    }

    public func snapshot() throws -> ShopLedger {
        try store.withExclusiveLock {
            try ensureStorePresent()
            let current = try store.load()
            ledger = current
            return current
        }
    }

    public func transact<T: Sendable>(access: ShopAccess = .free,
                                      _ mutate: @Sendable (inout ShopLedger) throws -> T) throws -> T {
        try store.withExclusiveLock {
            try ensureStorePresent()
            let previous = try store.load()
            var candidate = previous
            let result = try mutate(&candidate)
            try JobAccessPolicy.validateJobCreation(before: previous, after: candidate, access: access)
            try store.save(candidate)
            ledger = candidate
            return result
        }
    }

    public func backup() throws -> Data { try LedgerArchive.encode(snapshot()) }

    public func restore(_ data: Data) throws {
        try store.withExclusiveLock {
            let candidate = try store.restore(data)
            ledger = candidate
        }
    }

    private func ensureStorePresent() throws {
        guard FileManager.default.fileExists(atPath: store.url.path) ||
                (ledger.jobs.isEmpty && ledger.runs.isEmpty && ledger.events.isEmpty) else {
            throw RunError.invalid("Local ledger disappeared; restore a backup before continuing.")
        }
    }
}
