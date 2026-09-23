import Foundation
import Observation

@MainActor
@Observable
final class LegalConsentStore {
    private enum Key {
        static let onboardingComplete = "shell.onboarding.complete"
        static let acceptedLegalVersion = "shell.legal.acceptedVersion"
        static let acceptedLegalDate = "shell.legal.acceptedDate"
    }

    private let defaults: UserDefaults
    private let requiredVersion: String

    private(set) var onboardingComplete: Bool
    private(set) var acceptedLegalVersion: String?

    init(defaults: UserDefaults = .standard, requiredVersion: String = ShellConfiguration.legal.version) {
        self.defaults = defaults
        self.requiredVersion = requiredVersion
        onboardingComplete = defaults.bool(forKey: Key.onboardingComplete)
        acceptedLegalVersion = defaults.string(forKey: Key.acceptedLegalVersion)
    }

    var requiresPresentation: Bool {
        !onboardingComplete || acceptedLegalVersion != requiredVersion
    }

    var isReconsent: Bool {
        onboardingComplete && acceptedLegalVersion != requiredVersion
    }

    func acceptCurrentLegalVersion() {
        defaults.set(requiredVersion, forKey: Key.acceptedLegalVersion)
        defaults.set(Date(), forKey: Key.acceptedLegalDate)
        defaults.set(true, forKey: Key.onboardingComplete)
        acceptedLegalVersion = requiredVersion
        onboardingComplete = true
    }

    func resetForTesting() {
        defaults.removeObject(forKey: Key.onboardingComplete)
        defaults.removeObject(forKey: Key.acceptedLegalVersion)
        defaults.removeObject(forKey: Key.acceptedLegalDate)
        onboardingComplete = false
        acceptedLegalVersion = nil
    }
}
