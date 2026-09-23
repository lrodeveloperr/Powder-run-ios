# Shell migration protocol

The compiled shell contract is `ShellContract.currentVersion`. A derived app records the installed contract in `UserDefaults` and must supply ordered `ShellMigration` steps for any breaking upgrade.

## Adopt 2.0.0

1. Choose `Shell` for no advertising or `ShellAds` for an app whose reviewed monetization mode includes ads.
2. Keep GAD/SKAdNetwork metadata only in `Info-Ads.plist`; never copy it into `Info.plist`.
3. Remove every app logo, icon, named brand image and app-name hero from commerce surfaces. Run `scripts/check-commerce-branding.sh` when execution is authorized.
4. Leave `backup.enabled` false unless the app adds a reviewed `NativeBackupProviding` implementation, iCloud entitlement, privacy disclosure, serialization version and rollback-safe conflict behavior.
5. Advertise a locale only after all shell, product, legal and store text is translated and reviewed. `LocalizationBaseline` is terminology scope, not proof of completion.
6. Add a migration closure before changing persistent product schema. Each step must be idempotent, preserve a recoverable copy when practical, and update the stored contract version only after success.

Example:

```swift
static let migrations: [ShellMigration] = [
    ShellMigration(fromVersion: "2.0.0", toVersion: "3.0.0") {
        try ProductStore.migrateToVersion3()
    }
]
```

Never silently skip a missing step or erase user data to resolve a migration failure.
