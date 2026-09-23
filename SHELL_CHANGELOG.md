# Shell contract changelog

## Unreleased

- Made in-app locale resolution region/script-aware, mirrored the complete shell when an RTL language is selected independently of the device language, and strengthened the localization gate so machine-generated drafts, English exonyms and blanket cultural-review claims cannot qualify a locale for release.
- Made Settings subscription rows lifecycle-aware: inactive/expired/revoked customers no longer see a success badge or Manage Subscription, checking is neutral, active/recoverable states keep management, and legal button typography can no longer inherit the app tint. Added upstream zero-placeholder, live-localization and Settings-state regression gates.
- Hardened auto-renewable subscription lifecycle handling: verified renewal states, Billing Grace Period, billing retry, cancellation-through-expiry, foreground/expiration refresh, cached effective expiry, and in-app subscription management.
- Prevented unverified subscription-status responses from being misclassified as authoritative expiry, and made paywalls use StoreKit's localized product name as well as price and period.
- Separated screenshot-fixture uploads from production-logic uploads so one workflow input cannot select the wrong entitlement profile.
- Declared the shell's app-only `UserDefaults` access under required-reason API code `CA92.1`; the prior empty privacy-manifest API list contradicted the source.
- Added content-level legal-page parity checks after live Welding Wallet pages loaded successfully but still described the retired advertising and backup-rejection model.
- Added the subscription lifecycle/listing guide from the Welding Gas Wallet lapse audit, including domain-level quota enforcement, stale-form and Delete/Undo bypass prevention, non-destructive over-limit handling, and paid-era backup preservation.
- Added the reusable production wiring checklist from the Welding Gas Wallet audit, including archive/store parity and backup-import integrity gates.
- Added the ads-with-subscription mode so verified subscription access can remove a free-user banner without app-local shell forks.
- Added localized StoreKit failure messages and a terminal product-load retry state.
- Rejected stale stored language selections and added closest-supported locale fallback tests.
- Made TestFlight build numbers timestamp-safe and required unit tests before upload.
- Sized adaptive banners from the SDK response and moved their safe-area reservation inside each destination, preventing the banner from clipping the native tab bar.
- Replaced duplicated placeholder legal bodies with one in-app-browser path to the configured published documents.
- Added release blockers for unchanged generic paywall copy and made the paywall a modal from Settings so it cannot show redundant Back and Done controls.
- Added the ad-enabled shell target to hosted compilation checks.
- Passed the shell model explicitly into Settings and re-injected shell environment values at every root sheet boundary, preventing missing-environment crashes.
- Required native `Label` tab items, documented why custom `Canvas`/`Shape` content disappears from iPhone tab bars, and added focused Settings and tab-icon UI regressions.

## 2.0.0 — 2026-09-02

- Made the default target physically ad-free; added the opt-in `ShellAds` target.
- Prohibited app logo/icon/brand assets on all commerce surfaces and added a source guard.
- Added the official Apple compliance gate and native UI regression matrix.
- Added a 31-locale shared terminology baseline without claiming untranslated product support.
- Added disabled-by-default native backup interfaces and explicit restore-conflict choices.
- Added versioned shell migration infrastructure.

Breaking adoption note: derived ad-supported apps must select `ShellAds`; all other apps use `Shell`. Review `MIGRATIONS.md` before adoption.
