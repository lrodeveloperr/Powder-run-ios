# Powder Run production TestFlight

The manual `.github/workflows/powder-run-testflight.yml` workflow builds the production `Shell` target, checks the app and widget bundle IDs, exports a cloud-signed IPA and uploads it to App Store Connect. Its dispatch confirmation must exactly equal `UPLOAD POWDER RUN`. It has no screenshot fixture mode; `.github/workflows/ios.yml` builds and tests. The upload workflow skips the repeated test suites only while app source matches commit `4c02d5cda8519634eb6b24d95fd8b7a70a418d43`, which passed the full hosted iOS suite. Run the iOS suite again before uploading any later source change.

## Required account setup

In the Apple Developer account, register `com.goodusestudios.powderrun` and its Live Activity widget extension `com.goodusestudios.powderrun.widgets`. Both identifiers and the App Store Connect app record are already registered. The workflow uses Xcode automatic signing and an App Store Connect API key to manage provisioning and cloud signing; no `.p12` certificate or manually created provisioning profile is required. The API key must have the permissions needed to manage signing and upload the app. The workflow does not create subscription products or enter the listing. Review subscription prices in the actual storefront; none are hard-coded.

Set these **repository variables** for `lrodeveloperr/Powder-run-ios`:

| Variable | Value |
|---|---|
| `APPLE_TEAM_ID` | Actual ten-character Apple Developer team ID |

Set these **repository secrets** for the same repository:

| Secret | Value |
|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | App Store Connect API key ID, issuer and downloaded PEM `.p8` contents with app upload and automatic signing permissions |

Do not copy credentials into the repo. Inspect the first workflow run for build/signing failures. An upload is only a TestFlight processing request; verify the processed build and assign it to the `Lateef Internal Testing` group in App Store Connect. The group has one internal tester and automatic distribution is disabled. The source and listing are not yet backed by a signed build, live StoreKit products, or Apple tester delivery.
