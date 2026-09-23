# Powder Run · native iOS integration

This branch derives the app from `lrodeveloperr/Ios-shell` at `fbf8277eef830694f245cd97129a14c042d2d6d0` and vendors the current provisional PowderCoatingRunEngine package under `Packages/`. The production app target is Swift 6/SwiftUI on iOS 18+, with a local ledger and no ads, account, web UI, or runtime service. `ShellAds` remains an unused template target; distribute the `Shell` scheme only.

## Working path

Jobs → intake physical item groups → record prep → create first-pass or linked rework run with actual powder lot and reviewed manufacturer source → confirm coating applied → Oven: select coated runs for a shared load → record actual part-metal readings and qualifying dwell for each run → unload → inspect and allocate pass/rework/scrap → close reconciled job → History: PDF, CSV and explicit backup/restore.

Shop-authored presets may reuse setup only. Each use requires a new quantity, lot, operator, booth and explicit current-source confirmation. A correction retains the original reading. A post-handoff correction that creates a quality alert preserves the recorded handoff and offers documented customer follow-up.

The optional MIT-licensed Live Activity kit renders active oven status on the Lock Screen/Dynamic Island. It links back to the exact batch. It does not infer cure, automate readings or certify a finished run. Its notice is in `ThirdPartyNotices/`.

## Subscription boundary

The shell uses `.usageCapWithSubscription` with `featureScopedGate: true` so it never hides in-progress work or exports. Every shop mutation goes through `PowderRunSubscriptionStore.transact`, which fetches verified StoreKit access and passes it into the repository's locked new-job validation. The only paid gate is creating a **new** job after five first-pass runs. The cap is ledger-derived and not reset by restore. Existing jobs and rework remain editable after expiry. The shell displays both monthly and yearly products from StoreKit, with the App Store's actual localized prices. Proposed IDs:

- `com.goodusestudios.powderrun.pro.monthly`
- `com.goodusestudios.powderrun.pro.yearly`

Create both in one auto-renewable subscription group and confirm their actual IDs before release. US $2.99/month and $24.99/year are reference targets, not hard-coded prices.

## Build and verification

On a Mac with Xcode 16+ and XcodeGen:

1. `xcodegen generate`
2. `bash scripts/validate-shell.sh --release`
3. Build and test scheme `Shell` on an iPhone simulator and iPad; repeat StoreKit monthly/yearly, pending, cancellation, restore, grace, revocation and expiry tests with local StoreKit configuration and sandbox products.
4. Test the Widget extension and actual Lock Screen/Dynamic Island routing on supported devices.

This integration was authored on Linux without `swift`, `xcodebuild`, `xcodegen` or Apple simulator tooling. Local checks succeeded: English catalog parity, commerce-asset gate, plist/YAML parsing, diff whitespace. The shell validation cannot complete here because it calls macOS `plutil` and `PlistBuddy`. No compiler or device-pass claim is made.

## Release blockers

- Replace `support@example.com` and the two `example.com` legal URLs with published, reviewed Powder Run policies. Confirm the bundle ID, signing team and App Store Connect subscription products/metadata.
- Move JPEG bytes out of the whole-ledger JSON and measure storage and backup/restore on real iPhones before photo-heavy use; photo capture has intentionally not been exposed in these screens.
- Review English screen wording with an operator, run the native UI accessibility/compact-iPhone matrix, and localize any additional launch locale before enabling it.
- Run the engine's XCTest suite, native build/UI tests and StoreKit sandbox scenarios on macOS. No GitHub Action or TestFlight upload was triggered by this branch.
