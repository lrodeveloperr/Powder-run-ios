import Foundation
import Security

struct EntitlementSnapshot: Codable, Equatable, Sendable {
    let entitledProductIDs: Set<String>
    let subscriptionExpiryByProductID: [String: Date]
    let verifiedAt: Date

    func isEntitled(to productIDs: Set<String>, at date: Date) -> Bool {
        for id in entitledProductIDs where productIDs.contains(id) {
            if let expiry = subscriptionExpiryByProductID[id] {
                if expiry > date { return true }
            } else {
                return true
            }
        }
        return false
    }

    func earliestExpiration(for productIDs: Set<String>) -> Date? {
        entitledProductIDs
            .intersection(productIDs)
            .compactMap { subscriptionExpiryByProductID[$0] }
            .min()
    }
}

protocol EntitlementCaching: Sendable {
    func load() -> EntitlementSnapshot?
    func save(_ snapshot: EntitlementSnapshot) throws
    func clear() throws
}

struct KeychainEntitlementCache: EntitlementCaching {
    let service: String
    let account = "verified-entitlements-v1"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.goodusestudios.shell") {
        self.service = service
    }

    func load() -> EntitlementSnapshot? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(EntitlementSnapshot.self, from: data)
    }

    func save(_ snapshot: EntitlementSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else { throw KeychainError.status(insertStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

private enum KeychainError: Error {
    case status(OSStatus)
}
