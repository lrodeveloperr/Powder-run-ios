# Powder Run production TestFlight

The manual `.github/workflows/powder-run-testflight.yml` workflow builds the production `Shell` target, runs the engine Swift package tests and native unit tests, checks the app and widget bundle IDs, exports a signed IPA and uploads it to App Store Connect. Its dispatch confirmation must exactly equal `UPLOAD POWDER RUN`. It has no screenshot fixture mode; `.github/workflows/ios.yml` only builds and tests.

## Required account setup

In the Apple Developer account, register `com.goodusestudios.powderrun` and the Live Activity widget extension `com.goodusestudios.powderrun.widgets`. Create an Apple Distribution certificate and two active App Store distribution provisioning profiles that include the matching identifiers. The workflow checks each profile's name, App ID, distribution entitlement and team before export. In App Store Connect, create or verify the iOS app, its seller, primary English locale, Business category, subscription group and monthly/yearly subscription products. The workflow can create the app record from the API key if absent, but it does not create subscription products or enter the listing. Review subscription prices in the actual storefront; none are hard-coded.

Set these **repository variables** for `lrodeveloperr/Powder-run-ios`:

| Variable | Value |
|---|---|
| `APPLE_TEAM_ID` | Actual ten-character Apple Developer team ID |
| `POWDER_RUN_APP_PROFILE_NAME` | Exact active App Store profile name for the app |
| `POWDER_RUN_WIDGET_PROFILE_NAME` | Exact active App Store profile name for the widget extension |

Set these **repository secrets** for the same repository:

| Secret | Value |
|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | App Store Connect API key ID, issuer and PEM `.p8` contents with suitable app and certificate/profile permissions |
| `IOS_DISTRIBUTION_CERTIFICATE_P12` | Base64 encoded Apple Distribution `.p12` |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password for that `.p12` |

Do not copy credentials into the repo. Inspect the first workflow run for build/signing failures. An upload is only a TestFlight processing request; verify the processed build and add the intended Apple account to an internal tester group in App Store Connect. The user's TestFlight invitation address has not been verified. The source and listing are not yet backed by a signed build, live StoreKit products, or Apple tester delivery.
