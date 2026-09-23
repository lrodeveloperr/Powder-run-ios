import Foundation
import Observation
import Security

enum UsageRecordingResult: Equatable, Sendable {
    case recorded(remaining: Int)
    case duplicate(remaining: Int)
    case limitReached
    case invalidIdentifier
    case persistenceFailed
    case notMetered
}

protocol UsagePersisting: Sendable {
    func load() -> Set<String>
    func save(_ actionIDs: Set<String>) throws
}

struct KeychainUsageStore: UsagePersisting {
    let service: String
    let account = "successful-actions-v1"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.goodusestudios.shell") {
        self.service = service
    }

    func load() -> Set<String> {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(values)
    }

    func save(_ actionIDs: Set<String>) throws {
        let data = try JSONEncoder().encode(actionIDs.sorted())
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else { throw UsageStoreError.status(insertStatus) }
        } else if status != errSecSuccess {
            throw UsageStoreError.status(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

struct UserDefaultsUsageStore: UsagePersisting, @unchecked Sendable {
    let defaults: UserDefaults
    let key: String

    func load() -> Set<String> { Set(defaults.stringArray(forKey: key) ?? []) }
    func save(_ actionIDs: Set<String>) throws { defaults.set(actionIDs.sorted(), forKey: key) }
}

@MainActor
@Observable
final class UsageLedger {
    private let store: any UsagePersisting
    private let limit: Int
    private(set) var successfulActionIDs: Set<String>
    private(set) var persistenceHealthy: Bool

    init(limit: Int, store: any UsagePersisting = KeychainUsageStore()) {
        self.limit = max(0, limit)
        self.store = store
        let loaded = store.load()
        successfulActionIDs = loaded
        do {
            try store.save(loaded)
            persistenceHealthy = true
        } catch {
            persistenceHealthy = false
        }
    }

    var successfulActionCount: Int { successfulActionIDs.count }
    var remaining: Int { max(0, limit - successfulActionCount) }
    var hasFreeActionRemaining: Bool { persistenceHealthy && remaining > 0 }

    /// Call only after the product action has completed successfully. A stable,
    /// product-owned UUID makes retries idempotent and prevents double charging.
    @discardableResult
    func recordSuccessfulAction(id rawID: String) -> UsageRecordingResult {
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.utf8.count <= 128 else { return .invalidIdentifier }
        if successfulActionIDs.contains(id) { return .duplicate(remaining: remaining) }
        guard hasFreeActionRemaining else { return .limitReached }

        var revised = successfulActionIDs
        revised.insert(id)
        do {
            try store.save(revised)
            successfulActionIDs = revised
            return .recorded(remaining: remaining)
        } catch {
            persistenceHealthy = false
            return .persistenceFailed
        }
    }
}

private enum UsageStoreError: Error {
    case status(OSStatus)
}
