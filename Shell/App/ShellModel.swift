import Observation

@MainActor
@Observable
final class ShellModel {
    var selectedDestination = ShellConfiguration.destinations.first?.id ?? ""
#if DEBUG
    var contentState = SampleContentState.populated
#endif
    var settingsPresented = false
#if DEBUG
    var labPresented = false
#endif
    var paywallPresented = false
    var startupMessage: String?

    let access: AccessController
    let ads: AdConsentService
    let language: LanguageController
    let backup: BackupCoordinator
    private let migrationManager: ShellMigrationManager

    init(
        access: AccessController = AccessController(),
        ads: AdConsentService = AdConsentService(),
        language: LanguageController = LanguageController(),
        backup: BackupCoordinator = BackupCoordinator(),
        migrationManager: ShellMigrationManager = ShellMigrationManager()
    ) {
        self.access = access
        self.ads = ads
        self.language = language
        self.backup = backup
        self.migrationManager = migrationManager
    }

    /// Reserve the correctly sized slot while consent resolves so the product
    /// canvas and native navigation do not jump when the banner arrives.
    var shouldRenderAd: Bool { access.shouldShowAd }

    func start() async {
        do { try migrationManager.migrateIfNeeded(using: ShellConfiguration.migrations) }
        catch {
            startupMessage = error.localizedDescription
            return
        }
        await access.purchases.start()
    }

    func prepareAdvertisingIfNeeded() async {
        await ads.prepareIfNeeded(advertisingEnabled: access.shouldShowAd)
    }
}
