# Powder Run for iOS

Native SwiftUI shop board and provisional [powder-coating run engine](Packages/PowderCoatingRunEngine/) for batch-oven production. The app keeps its ledger on device and uses StoreKit subscriptions after five first-pass runs. Existing jobs, rework, history and exports remain usable without a subscription.

Read [the integration guide](POWDER_RUN_INTEGRATION.md) for the operator flow, subscription rules, Mac build instructions and release blockers. [AGENTS.md](AGENTS.md) documents the inherited shell architecture. This app derives from [lrodeveloperr/Ios-shell](https://github.com/lrodeveloperr/Ios-shell) at `fbf8277eef830694f245cd97129a14c042d2d6d0`.

This is source code for review and native build testing. It has not yet been compiled on a Mac. Policy links, support contact, App Store Connect products and signing still need their production values. The manually dispatched iOS workflow builds and tests the provisional code; it does not upload to TestFlight.
