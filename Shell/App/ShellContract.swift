import Foundation

enum ShellContract {
    /// Increment MAJOR when a derived app must supply a migration or change its
    /// feature-provider/configuration contract.
    static let currentVersion = "2.0.0"
    static let storedVersionKey = "shell.contract.version"
}

struct ShellMigration: Sendable {
    let fromVersion: String
    let toVersion: String
    let apply: @MainActor @Sendable () throws -> Void
}

enum ShellMigrationError: LocalizedError {
    case missingStep(from: String, to: String)
    case cycle(version: String)

    var errorDescription: String? {
        switch self {
        case let .missingStep(from, to): "No shell migration exists from \(from) to \(to)."
        case let .cycle(version): "Shell migration cycle detected at \(version)."
        }
    }
}

@MainActor
final class ShellMigrationManager {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func migrateIfNeeded(using steps: [ShellMigration]) throws {
        guard let installed = defaults.string(forKey: ShellContract.storedVersionKey) else {
            defaults.set(ShellContract.currentVersion, forKey: ShellContract.storedVersionKey)
            return
        }
        guard installed != ShellContract.currentVersion else { return }

        var cursor = installed
        var visited = Set<String>()
        while cursor != ShellContract.currentVersion {
            guard visited.insert(cursor).inserted else { throw ShellMigrationError.cycle(version: cursor) }
            guard let step = steps.first(where: { $0.fromVersion == cursor }) else {
                throw ShellMigrationError.missingStep(from: cursor, to: ShellContract.currentVersion)
            }
            try step.apply()
            cursor = step.toVersion
            defaults.set(cursor, forKey: ShellContract.storedVersionKey)
        }
    }
}
