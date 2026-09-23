import Foundation
import Observation

struct BackupRecord: Identifiable, Hashable, Sendable {
    let id: String
    let createdAt: Date
    let byteCount: Int64
}

enum BackupConflictResolution: String, Sendable {
    case keepDevice
    case replaceDevice
}

/// App-owned implementations may use the user's iCloud container. The shell
/// does not assume a schema, request an entitlement, or turn cloud on.
protocol NativeBackupProviding: Sendable {
    var providerName: String { get }
    func listBackups() async throws -> [BackupRecord]
    func createBackup() async throws
    /// Decode into temporary state, validate schema and references, enforce all
    /// current free/paid limits, then commit atomically. Never trust backup data.
    func restoreBackup(id: String, resolution: BackupConflictResolution) async throws
}

struct DisabledNativeBackupProvider: NativeBackupProviding {
    let providerName = "Disabled"
    func listBackups() async throws -> [BackupRecord] { [] }
    func createBackup() async throws {}
    func restoreBackup(id: String, resolution: BackupConflictResolution) async throws {}
}

@MainActor
@Observable
final class BackupCoordinator {
    let configuration: BackupConfiguration
    let provider: any NativeBackupProviding
    private(set) var records: [BackupRecord] = []
    private(set) var isWorking = false
    var message: String?

    init(
        configuration: BackupConfiguration = ShellConfiguration.backup,
        provider: any NativeBackupProviding = DisabledNativeBackupProvider()
    ) {
        self.configuration = configuration
        self.provider = provider
    }

    var isEnabled: Bool { configuration.enabled }

    func refresh() async {
        guard isEnabled else { return }
        isWorking = true
        defer { isWorking = false }
        do { records = try await provider.listBackups() }
        catch { message = error.localizedDescription }
    }

    func create() async {
        guard isEnabled else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await provider.createBackup()
            records = try await provider.listBackups()
        } catch { message = error.localizedDescription }
    }

    func restore(_ record: BackupRecord, resolution: BackupConflictResolution) async {
        guard isEnabled else { return }
        isWorking = true
        defer { isWorking = false }
        do { try await provider.restoreBackup(id: record.id, resolution: resolution) }
        catch { message = error.localizedDescription }
    }
}
