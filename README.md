# Powder Run for iOS

Native SwiftUI shop board and provisional [powder-coating run engine](Packages/PowderCoatingRunEngine/) for batch-oven production. The app keeps its ledger on device and uses StoreKit subscriptions after five first-pass runs. Existing jobs, rework, history and exports remain usable without a subscription.

Read [the integration guide](POWDER_RUN_INTEGRATION.md) for the operator flow, subscription rules, Mac build instructions and release blockers. [AGENTS.md](AGENTS.md) documents the inherited shell architecture. This app derives from [lrodeveloperr/Ios-shell](https://github.com/lrodeveloperr/Ios-shell) at `fbf8277eef830694f245cd97129a14c042d2d6d0`.

The [App Store listing draft](docs/app-store/powder-run-listing.md), [validation report](docs/app-store/validation-report.md), and draft [privacy policy](docs/policies/powder-run-privacy.md), [terms](docs/policies/powder-run-terms.md) and [support page](docs/policies/powder-run-support.md) are prepared for review. Publish and wire legal URLs only after the final binary and contact details are confirmed.

This is source code for review and native build testing. It has not yet been compiled on a Mac. The privacy, terms and support pages are published and wired to the app. App Store Connect products and signing still require verification. The manually dispatched iOS workflow builds and tests source without uploading; the separate production TestFlight workflow is guarded by the exact confirmation phrase `UPLOAD POWDER RUN` and requires app and widget distribution signing profiles.
