# Powder Coating Run Bench — iOS engine candidate

Swift Package for iOS 16+. No screen design, login, server, shop ERP, oven control, third-party product catalogue, quotation, payments, or QuickBooks integration. This package implements the **Powder Coating Run Bench** flow in `WorksBien-iOS-Operator-Workbench-Build-Candidates-2026-09-23.md`.

**Status: PROVISIONAL ENGINE CANDIDATE.** The research MD expressly requires shop observation and competitor task comparison before a build verdict. This environment has no Swift compiler or Xcode; none of the XCTest cases or the iOS PDF renderer have run here. Do not represent this as `ENGINE LOCKED` or ready for a coating operation until compiled, exercised on iPhone, and reviewed by a qualified shop operator.

The 1,000 customer check is a **deterministic synthetic test definition**, not interviews or usage by 1,000 actual customers. `EngineTests.swift` also defines 10,000 accelerated run lifecycles spread over about 1,000 simulated years. Both await execution on a Mac. Read `customer-stress-report.md` and `code-integrity-report.md` for earlier source reviews, fixes, and remaining gates. Those reviews predate the shop-preset addition and do not verify its new code.

## App icon for the iOS host

`iOSIntegration/Assets.xcassets/AppIcon.appiconset` contains the opaque 1024 × 1024 iOS icon. Copy `AppIcon.appiconset` into the host app's `Assets.xcassets`, then select `AppIcon` for the iOS target in Xcode. The Swift package cannot install an app icon on its own because it has no iOS app target. The square asset has no baked corner mask; iOS applies the corner shape. The browser prototype uses the same artwork in its header and favicon.

## Monetization boundary (decision locked; implementation provisional)

Five **first-pass runs** are free, across multiple jobs. Rework runs never consume the allowance. Once five first-pass runs exist in the ledger, entering a **new job** requires an active Pro subscription; jobs already entered (including their remaining first-pass runs, rework, corrections, reports and handoff) can always be finished. This intentional grandfather rule can allow more than five free runs when work was entered before the quota. Do not place a paywall during an active oven load or withhold historical records or exports after expiry. The one-job gate from v0.1.4 has been removed.

The locked US reference offer is **$2.99 monthly or $24.99 yearly**, auto-renewable in one subscription group. These are App Store Connect targets, not prices hard-coded into the engine; the paywall must display `Product.displayPrice` and the current terms actually returned by StoreKit for each region. There is no local trial-clock flag, no reset when the user restores a backup, and no paid state saved in a ledger, preset or UserDefaults. The package's `PowderRunSubscriptionStore` obtains verified `Transaction.currentEntitlements` for each new transaction; Apple's current-entitlement sequence includes an enabled billing grace period. It uses verified purchases, distinguishes pending and cancelled outcomes, and calls `AppStore.sync()` only for a user-initiated Restore Purchases action. A separate native iOS host and two matching App Store Connect products are required before charging customers.

The browser prototype's purchase and restore actions are simulations, with no Apple purchase. It must match this five-run contract before representing the locked plan to testers. Do not sell or describe Pro as live until the iOS host shows the actual localized price, verifies signed StoreKit transactions, provides restoration, and passes Xcode StoreKit and device sandbox testing. See Apple [subscription rules](https://developer.apple.com/app-store/review/guidelines/#subscriptions), [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), and [sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

## Operator loop

1. Create a job with one or more physical item groups, quantity, substrate, finish, optional due date, and local photos.
2. Configure any required preparation checkpoints; record each against the correct item. Create a run with a **powder product, lot, TDS/procedure source**, booth, operator, and item quantity. A first pass cannot exceed intake. Rework must cite a parent run and cannot exceed its rework quantity. Optionally select a shop-authored preset for a matching part and completed prep checks. Every preset use still requires a new powder lot, actual quantity and booth, operator, and explicit confirmation of the current source.
3. Record coating, then load applied runs from multiple jobs into one named oven load. Oven air readings belong to the batch. **Part metal readings belong to the particular run** and include location and method. Oven air never qualifies a part for cure.
4. Start dwell only with a qualifying part metal reading at that timestamp. End it only after the stated dwell and an end reading plus operator confirmation. A below-target or above-maximum reading resets the active dwell. An exceeded maximum places the run on hold. A clock going backwards is rejected; a clock jump forward still needs the operator's explicit attestation. This thermal oven workflow accepts recipe targets from **120–300 °C**; a stated TDS/procedure source is required, and this floor does not establish that a particular powder will cure.
5. Unload the whole oven batch, inspect each run, then allocate every unit to pass, rework, or scrap with a defect code and reason where applicable. A quality hold prevents release **before handoff**. Corrections preserve the original reading and require a reason/operator; a correction that invalidates cure creates a hold. Rework is a new linked run.
6. Close the job only after each item's intake equals released plus scrapped, with no outstanding rework or unprocessed intake. Record pickup, delivery, or courier handoff.

If a reading is corrected **after handoff** and creates a quality hold, the engine keeps the original handoff and delivered count, records a conspicuous post-handoff quality alert, and lets the operator record follow-up such as customer contact. It cannot automatically contact a customer, recall a part, or treat physically delivered parts as available for rework. Subsequent measurement correction and documented hold review can resolve a mistaken alert. Delivered intake quantity cannot be rewritten; a generic audit addendum can document a discrepancy.

The engine deliberately **does not determine chemical cure or certify quality**. A spot temperature and elapsed time are factual records; the manufacturer's technical data sheet and the shop's qualified process govern the actual procedure. The synthetic 190 °C / 600 s fixture is a demonstration, never a suggested recipe.

## Shop-owned presets

`ShopPreset` stores a shop-authored part identity, substrate, finish, prep checklist, validated recipe, suggested booth and oven, and measurement point/method. A named reviewer records when they checked the source procedure. It cannot store a powder lot, customer, job quantity, actual operator, measurements, inspection or handoff. `ShopLedger.savePreset` creates a revision or requires the next revision number for an edit; `removePreset` leaves historical runs intact. `createRunFromPreset` checks exact item identity/material/finish and item-specific prep checkpoints, then requires a lot, quantity, actual booth, operator and `sourceConfirmed: true` for that run. Existing `createRun` remains available for a manually entered recipe. The created run snapshots the recipe, and a separate ledger event records which preset revision was used. Treat `sourceConfirmed` as an operator attestation, not independent proof that the TDS is correct or current.

The preset array is an additive archive field. Old schema-1 JSON without `presets` decodes as an empty collection; newly encoded archives include it. The original schema version remains 1. The test for this backward-compatible decode is authored but **cannot run without Swift/Xcode** in this environment.

No third-party product list, copied TDS text/images, RAL swatches or manufacturer logos are bundled. Shop staff may enter factual names and their own procedure references. Obtain applicable rights before distributing a branded color library or manufacturer materials. This is an IP-risk design boundary, not a blanket legal clearance for user-supplied content.

The 120 °C guard is a product scope decision for **thermal oven curing**, informed by the [Powder Coating Institute's low-bake discussion](https://www.powdercoating.org/page/Innovations-LowBake). [Interpon describes UV and heat-sensitive substrate systems at lower temperatures](https://www.interpon.com/gb/en/industrial/hss); those need a separately specified cure workflow and are not represented by this engine. An older archive with a lower recipe target will now fail validation on restore; retain the original backup for migration or review on a Mac before deploying this change.

## Storage and exports

- `LedgerRepository` takes a per-file advisory lock across reload, mutation and atomic commit so separate repository instances do not overwrite each other. `snapshot()` now throws and reloads disk. Use a URL in Application Support. On iOS the temporary file receives `completeUnlessOpen` protection before it replaces the live file.
- `LedgerArchive` exports and validates versioned JSON including attached JPEG bytes (5 MB each, up to 20 per item). Restoring validates before replacement. Keep a separate user controlled backup outside the app container; deletion or device loss cannot be reversed from the local store alone.
- `jobsCSV` and `batchCSV` provide factual summaries; spreadsheet formula prefixes are escaped. `PDFReport.job` is available when compiled for iOS and includes the batch, original/corrected readings, counts, and photos.
- A closed job's `released` count means units **already delivered**, even if later investigation puts a run on hold. The jobs CSV and PDF explicitly flag an unresolved post-handoff quality alert. Follow-up events and any hold resolution remain in the audit record.
- Append-only run observations and ledger events remain in the JSON backup. Typed corrections update current job, item, batch and run setup facts while retaining an audit event. A generic event correction is only an addendum and cannot change the authoritative fact. The JSON archive is **not a tamper-evident signature**.

The whole JSON ledger, including base64 photo bytes, is validated and rewritten on each transaction. Twenty 5 MB photos per item can push a ten-item archive above 1 GB before JSON overhead and copies. This is a release blocker for real photo-heavy shops; move photos into bounded separate files and measure storage, low-space recovery and backup/restore on iPhone before deployment.

## Build and test on a Mac

```sh
cd PowderCoatingRunEngine
swift test
swift run powder-run-harness demo /tmp/powder-sample.json
swift run powder-run-harness inspect /tmp/powder-sample.json
swift run powder-run-harness batches-csv /tmp/powder-sample.json
```

Add `Package.swift` to an Xcode iOS project. Configure one auto-renewable subscription group in App Store Connect with distinct monthly and yearly product IDs, then create `PowderRunSubscriptionProducts(monthlyID:yearlyID:)` with those exact IDs and `PowderRunSubscriptionStore(repository:identifiers:)`. Route **every** operator mutation through `store.transact { ledger in ... }`; it checks current verified StoreKit access before calling the repository, which checks new-job creation inside its file lock. Present the `store.products()` results using each `Product.displayPrice` and clear renewal terms; call `store.purchase(product)` from the chosen plan and `store.restorePurchases()` from an explicit Restore Purchases button. Refresh paywall/entitlement presentation on app foreground and `Transaction.updates`; do not cache `.pro` as a durable Boolean. Pass a run's current `revision` to prevent stale edits. The plain harness prints a synthetic multi-job oven load, a job quantity summary and an archive. The iOS app target and paywall screen, camera import, Files/share-sheet routing, notification scheduling, accessibility, and localization remain integration work, not implemented screens.

## Release gates

| Gate | Current result |
| --- | --- |
| iOS package compilation, XCTest, PDF renderer | **Not run:** Swift/Xcode unavailable here |
| On-device interrupted-run and low-storage recovery | **Not run** |
| Real shop multi-job oven load with three operators/shops | **Not run** |
| Competitor task timing and willingness to pay | **Not run** |
| Photo backup/restore volume and long-horizon fuzz/mutation | **Not run** |
| 1,000 synthetic customer cases and 10,000 run lifecycles / 1,000 simulated years | **Authored, not run** |
| Independent customer and code source review | **Completed; see two review reports** |
| Shop preset save/revise/reuse and old JSON decode | **XCTest authored; not run without Swift** |
| Monetization, launch locales and price | **Five-run/free-new-job gate and StoreKit adapter authored, not compiled; $2.99 monthly / $24.99 yearly US reference decision locked. App Store Connect products, native host/paywall and sandbox verification missing** |

See `gate-manifest.json` for requirements and test links. Key domain references: [Powder Coating Institute FAQ](https://www.powdercoating.org/page/FAQ), [PCI glossary](https://www.powdercoating.org/page/Glossaryps), and [Prismatic cure schedule](https://www.prismaticpowders.com/knowledge-base/52/cure-schedule-prismatic-powders-cure-schedules). The source research brief remains the product scope; manufacturer data is the authority for each actual powder.
