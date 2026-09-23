# Powder Run listing validation — 23 September 2026

**Status: DRAFT_READY for offline copy; not approved for App Store submission.** The App Store listing skill validator (`mode: draft`) reports **74/74 declared compliance checks (100%)**, **75/75 declared launch listing checks (100%)**, and **0 draft-stage machine blockers** for `listing-manifest.json`. These scores check the completeness and format of the *declared draft*, not the factual truth of an unbuilt app or a release. Five areas are deferred by the validator: final build, privacy/legal pages, App Store Connect, applicable guideline review and reviewer access.

| Field | Measured length | Apple limit checked 23 September 2026 |
|---|---:|---:|
| English name | 23 characters | 30 characters |
| English subtitle | 25 characters | 30 characters |
| English keyword field | 93 UTF-8 bytes | 100 bytes |
| English description | 1,341 characters in the manifest | 4,000 characters |
| Promotional text | Blank | Optional; 170 characters if used |

The draft avoids hard-coded prices and competitor names. Three real native screenshots each for iPhone and iPad are specified but **not created**. Current candidate master sizes: iPhone 1320×2868 and iPad 2064×2752 pixels. Recheck Apple's requirements and device crop before upload.

**Remaining release blocks:** publish reviewed Powder Run privacy, terms and support pages; replace the in-app `example.com` and `support@example.com` placeholders; confirm legal operator and App Store seller; configure and test both subscription products with localized total prices and review screenshots; confirm availability territories and age questionnaire; compile/test the native app and engine on macOS; inspect signed archive/SDKs and App Privacy answers; capture authentic screenshots; provide real review contact information. The production scheme is `Shell`, not `ShellAds`. A JPEG-heavy ledger storage issue is documented in `POWDER_RUN_INTEGRATION.md` before photo-heavy use.

**Primary sources reviewed:** [Apple metadata fields](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), [subscriptions](https://developer.apple.com/app-store/subscriptions/). Refresh these against the actual submission date.
