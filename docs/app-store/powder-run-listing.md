# Powder Run — App Store listing and review pack

**Decision: BLOCKED for submission; published legal pages are ready. Updated 24 September 2026.** This is the English launch copy for the native `Shell` target, bundle `com.goodusestudios.powderrun`, version `1.0` build `1`, iOS 18+, iPhone and iPad. Availability territories and seller identity must be confirmed in App Store Connect. No App Store record or final signed build was inspected. Copy is ready to enter, but build-dependent disclosures require verification before submission.

## Facts behind the copy

| Claim | Current source | Status |
|---|---|---|
| Local shop board, job/intake, prep, shared oven load, measured part-metal dwell, inspection/rework and reports | `Shell/Features/PowderBoard/`; engine `ShopLedger.swift`, `RunEngine.swift` | Source-confirmed; not device-tested |
| Five first-pass runs free; after that a subscription gates *new job creation*; existing jobs, rework and history usable | `AccessPolicy.swift`, `ShopBoardModel.swift`, `ShellConfiguration.swift` | Source-confirmed; StoreKit sandbox untested |
| Monthly and yearly Pro via verified StoreKit | `ShellConfiguration.swift`, `PurchaseService.swift` | Product IDs proposed, App Store Connect unverified |
| No app account, no app server, no ad framework linked to production `Shell`; local ledger and user-initiated share | `project.yml`, `ShopBoardModel.swift`, privacy manifest | Source-confirmed; final archive/SDK audit pending |
| Optional local Live Activity with load identifier and equipment, no remote push | `PowderRunActivityService.swift` | Source-confirmed; device behavior untested |
| English UI, iPhone+iPad | `ShellConfiguration.swift`, `project.yml` | Source-confirmed; device matrix untested |

## App Store Connect fields — English (US) draft

| Field | Proposed value |
|---|---|
| Name | **Powder Run: Coating Log** |
| Subtitle | **Batch Oven & Cure Records** |
| Primary category | **Business** (shop production records) |
| Secondary category | **Productivity** (job and process tracking; verify availability in Connect) |
| Promotional text | Leave blank at launch |
| Keywords | `pretreatment,part metal,rework,inspection,job tracker,traceability,shop floor,quality control` |
| Copyright | `2026 WorksBien Studios Inc.` — confirm actual rights holder and Apple seller |
| Privacy Policy URL | https://lrodeveloperr.github.io/privacy-policy/powder-run/privacy/ |
| Support URL | https://lrodeveloperr.github.io/privacy-policy/powder-run/support/ |
| Marketing URL | Omit initially; use a dedicated product page only when live |
| Terms of Use | https://lrodeveloperr.github.io/privacy-policy/powder-run/terms/; use Apple's standard EULA unless a custom EULA is deliberately configured |
| What's New | Omit for first release |

**Description — plain text draft with published legal links:**

Powder Run gives powder-coating shops a clear record of each job from intake to handoff.

Track item groups and preparation checks, set up first-pass or rework runs, and place coated runs in a shared oven load. Record actual part-metal temperatures and dwell against the reviewed powder instructions. Then inspect, allocate accepted, rework or scrapped quantities, and close the job with its numbers reconciled.

• Keep batch-oven runs and their reading history together.
• Use your own setup presets while confirming each new powder lot and recipe source.
• Export a job PDF, job and oven-run CSV files, or a full JSON backup.
• See an optional oven Live Activity; return to the app to enter readings and make decisions.

Five first-pass runs are free. Powder Run Pro is a monthly or yearly auto-renewable subscription that lets you create new jobs after the free limit. Jobs already entered, rework, history and exports remain accessible without an active subscription. The total price and renewal period for your region appear before purchase in the App Store flow.

Powder Run stores shop records on your device. Sharing or backing up a file is your choice. It is a recordkeeping aid, not a temperature sensor or an automatic certification of cure. Follow the current powder manufacturer's instructions and your shop's safety procedures.

Privacy Policy: https://lrodeveloperr.github.io/privacy-policy/powder-run/privacy/
Terms of Use: https://lrodeveloperr.github.io/privacy-policy/powder-run/terms/

**Subscription metadata (draft):** one group, one entitlement tier. Monthly display name `Powder Run Pro Monthly`; description `Create new jobs after five free first-pass runs; existing jobs and rework remain available.` Yearly display name `Powder Run Pro Yearly`; same description. IDs: `com.goodusestudios.powderrun.pro.monthly` and `com.goodusestudios.powderrun.pro.yearly`. Verify the exact duration, tier, prices, subscription group and localized metadata in App Store Connect before use. Do not create public promotional IAP artwork from the AppIcon or screenshots.

## Three authentic screenshots per device family

Capture a working native build with fictional customer and lot data, no placeholder/legal URLs in view. Use the same shop story in all images. On iPhone, capture a supported 6.9-inch portrait master, for example **1320 × 2868 px**; on iPad, a 13-inch portrait master, for example **2064 × 2752 px**. Reconfirm [Apple's current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) and check text/crop in App Store Connect. Do not enlarge a web mockup or fake a device screen.

| # | Caption | Actual screen and honest state |
|---|---|---|
| 1 | **Know what every job needs next** | Jobs board with several fictional jobs and one unmistakable next step; free-tier records |
| 2 | **Record prep and oven readings** | Oven run with actual example part-metal reading and dwell step; manually recorded, no false “cured” claim |
| 3 | **Close the run with a clear record** | Finished job inspection/reconciliation or History with a prepared PDF/CSV share; avoid displaying a PDF unless captured in the app |

If Pro or creation past the five-run limit is shown, identify the paid boundary clearly on the page. Three English screenshots each for iPhone and iPad is the launch plan; there are no image assets yet. English is the only in-app locale. Additional translated store locales should state that accurately.

## ASO choices

The name carries the primary phrase “Coating Log”; the subtitle identifies the oven/cure job; keywords cover prep, measured part-metal readings, powder lot, rework, inspection and shop jobs without using another company's brand. These are relevance hypotheses based on this workflow, not measured search volume. Business is a better first category than a general calculator category for this job-to-handoff tool. After launch, measure search impressions, page conversion and first-run activation before changing one field at a time.

## App Store Connect answers to verify

| Question | Draft answer | Evidence still needed |
|---|---|---|
| App Privacy | Likely “No, we do not collect data from this app”; shop data stays on-device, optional exports are user-directed, and Apple processes StoreKit purchases | Inspect signed binary, Live Activity library, SDKs, any future diagnostics and actual support flows before submitting the answer; distinguish Apple's optional device backups |
| Tracking/ads | No tracking or ads in the production `Shell` scheme | Archive inspection; never submit the unused `ShellAds` scheme |
| Accounts/hardware | No account or connected equipment required; manual part-metal readings | Native walkthrough |
| Age rating | Answer questionnaire for a shop productivity tool; do not assert a numerical rating before Connect | App Store Connect questionnaire |
| Content rights | Original Powder Run icon, shop-entered presets, licensed Live Activity kit | Audit final asset and MIT notice inclusion |
| Encryption/export compliance | `ITSAppUsesNonExemptEncryption = false` in source | Reconfirm the final build and App Store Connect export questions |
| Availability | Undecided | Select territories and resolve their applicable obligations |
| Data deletion | No in-app account; local data controlled by user, exported/device-backup copies separate | Verify iOS deletion behavior and support procedure |

**Notes for App Review (draft):** No login, backend, powder-coating equipment or temperature sensor is required. Open Jobs and create a fictional customer job, item and prep record; make a first-pass run and enter the powder lot and manufacturer-source values. In Oven, add coated runs to a batch and record manually observed part-metal readings at the qualifying dwell points; then unload, inspect and allocate accepted/rework/scrap quantities. In History, share a job PDF, CSV or JSON backup. The Lock Screen Live Activity, if permitted, displays a local reminder and opens the associated batch; it does not establish cure. Five first-pass runs are free; create new jobs after the limit using a verified monthly or yearly StoreKit subscription. Existing jobs, rework, history, exports and Restore Purchases remain available. The paywall is accessible from Settings or the new-job gate. No demo account is needed. **Complete reviewer name, verified email and phone, exact product status, tested device/OS and any required sandbox steps before submission.**

## Guideline disposition and release gates

Reviewed 23 September 2026 against the [live App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [metadata fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [App Privacy help](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), and [subscription guidance](https://developer.apple.com/app-store/subscriptions/). The five families all matter: Safety (physical shop process), Performance (build/metadata), Business (subscriptions), Design (native utility), Legal (privacy and rights).

| Rule | Disposition | Reason / owner |
|---|---|---|
| 1.4, 1.5, 1.6 | Blocked | Run safety UI, live developer contact and final data/security behavior need device review — product owner |
| 2.1, 2.3, 2.4 | Blocked | Build, screenshot authenticity and iPhone/iPad compatibility untested — iOS owner |
| 3.1.1, 3.1.2 | Blocked | Both StoreKit products, continuing value, purchase/renewal disclosure and state transitions untested — commerce owner |
| 4.1, 4.2 | Blocked | Original asset rights, fully working native functionality and template customization need archive review — iOS owner |
| 5.1.1, 5.2 | Blocked | Compare published policy and privacy answers with final binary/SDKs and confirm content rights — privacy owner |

Other guideline subsections must be re-reviewed against the final build and the selected markets; this matrix is the draft's applicable core, not a claim that all sections passed. Release also needs a verified seller/copyright owner, subscription products and signing, three real screenshots for each device family, testable reviewer contact, a Mac build and test pass, archive privacy checks, and a regional availability decision. The production source points to live privacy and terms pages; the support page and contact are published. App Store Connect access and signed archive checks remain unverified.
