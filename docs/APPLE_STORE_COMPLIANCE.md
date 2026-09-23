# Apple App Store compliance gate

Reviewed against Apple’s official material on **2026-09-02**. Apple’s App Review Guidelines showed “Last Updated: June 8, 2026” when reviewed. Policy changes and app-specific behavior mean a template can reduce risk but cannot guarantee acceptance. Before every submission, a human or reviewing agent must open the current sources below, assess every row, and record **PASS**, **N/A with reason**, or **BLOCKED**.

## Official sources

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [In-app purchase design guidance](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Set up win-back offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-win-back-offers/)

## Mandatory shell checks

- [ ] Native SwiftUI experience is complete, stable, responsive and useful; no crashes, broken links, placeholders, demo copy or inaccessible features.
- [ ] App identity, screenshots, previews, description, privacy answers, age rating, category and review notes match the binary and current business model.
- [ ] Every App Store locale contains text for that locale; stale or cross-locale promotional text, description, keywords and review notes block submission.
- [ ] App Review can reach every feature. Provide a demo account, sample data, QR code, hardware instructions or fully featured demo mode when applicable.
- [ ] Privacy Policy and Terms of Use links use HTTPS, open before purchase and onboarding acceptance, and match actual data handling.
- [ ] Privacy manifest, Required Reason APIs, SDK manifests/signatures and App Store privacy answers match the final archive—not the template plan.
- [ ] Export compliance is code-grounded. Both app Info.plists declare `ITSAppUsesNonExemptEncryption=false` only while the derived app uses no proprietary or non-exempt encryption; reassess and change this before release if app-specific code adds it.
- [ ] The app asks only for permissions needed at that moment, explains them clearly and remains useful when optional permission is declined.
- [ ] No private API, downloaded executable code, misleading capability, hidden feature, placeholder or dormant switch ships.
- [ ] Accessibility, Dynamic Type, VoiceOver, contrast, 44-point hit targets, RTL, compact iPhone and iPad layouts were manually checked using `UI_REGRESSION_MATRIX.md`.

## Purchases and subscriptions

- [ ] Digital features/content use StoreKit In-App Purchase unless a current guideline exception applies and is documented.
- [ ] Before confirmation, the commerce surface clearly states the exact benefit, StoreKit-fetched localized price and billing period. Do not hard-code a storefront price.
- [ ] Auto-renewal is disclosed; privacy and Terms of Use are visible; subscription grouping prevents accidental duplicate subscriptions.
- [ ] Restore is visible for restorable purchases. Pending, cancelled, unverified, expired, refunded or revoked transactions never unlock access.
- [ ] Product-loading failure ends in a localized retry state and never leaves a permanent loading indicator.
- [ ] Cancellation retains access through paid expiration; grace, billing retry, recovery, expiry and revocation follow `docs/SUBSCRIPTION_LIFECYCLE_GUIDE.md`.
- [ ] Subscription status and Apple's Manage Subscription surface are available in Settings; billing retry does not present a duplicate purchase.
- [ ] Full StoreKit-localized renewal price is the most prominent price; subscription name, duration and unlocked service are explicit.
- [ ] Subscription group and product metadata are localized for every claimed listing language; review screenshot and navigation notes match the submitted binary.
- [ ] Purchase success is verified through StoreKit; `Transaction.updates` and current entitlements keep access current.
- [ ] Free trial, introductory, promotional, offer-code and win-back claims appear only when StoreKit confirms eligibility and terms.
- [ ] Recurring payment has defensible ongoing value. One-time value is not misleadingly sold as a subscription.
- [ ] App description and screenshots identify paid features when required by Guideline 2.3.2.
- [ ] Product display name, description, review screenshot and localization in App Store Connect are accurate and appropriate for all audiences.
- [ ] Review notes describe the current free limit, ads/consent behavior, subscription type and reviewer path; remove claims inherited from an older one-time or ad-free model.
- [ ] If promoting an IAP or win-back offer, its promotional image is **not the app icon and not an app screenshot**, per Apple’s win-back guidance.
- [ ] House rule: in-app paywall, purchase, restore, subscription and win-back surfaces contain no app logo, AppIcon, custom brand mark or app-name hero. Run `scripts/check-commerce-branding.sh`. This is intentionally stricter than Apple’s published in-app UI rule and prevents recurrence of the prior rejection pattern.
- [ ] Standard Apple EULA link appears in the description when used, or the custom EULA is configured in App Store Connect.

## Advertising profile

- [ ] Non-ad apps archive the default `Shell` target. Confirm the archive has no GoogleMobileAds/UMP framework and its Info.plist has no GAD or SKAdNetwork metadata.
- [ ] Ad-supported apps deliberately archive `ShellAds`, replace demo IDs, configure UMP/privacy choices, and reconcile SDK behavior with privacy disclosures.
- [ ] Ads are identifiable, age-appropriate, non-deceptive and do not block core use or manipulate taps. Any dismiss control is visible and usable.
- [ ] Google's demo ad IDs appear only in an explicitly internal TestFlight archive that is never submitted for App Review; storefront archives use reviewed publisher-owned IDs.
- [ ] The app is not predominantly an advertisement and does not artificially increase impressions or clicks.

## Full App Review Guidelines applicability sweep

The shell cannot decide product content. Review every numbered section in the current official guidelines, including subsections, and attach evidence or an N/A reason:

| Guideline family | Required product-level decision |
|---|---|
| 1 Safety | Objectionable content; user-generated/creator content moderation; children; physical harm; developer information |
| 2 Performance | Completeness; beta/demo behavior; accurate metadata; hardware compatibility; software requirements |
| 3 Business | Payments; subscriptions; other purchase methods; advertising; enterprise/person-to-person/service-specific models |
| 4 Design | Copycats; minimum functionality; spam; extensions; Apple sites/services; alternate icons; Sign in with Apple |
| 5 Legal | Privacy; data use/sharing; permissions; regulated fields; intellectual property; gambling; VPN/MDM; developer conduct |

Do not mark a family N/A as a whole. Review its current subsections. Examples that commonly become applicable only after product code is added include accounts and account deletion, social login, health/medical claims, financial services, location, background activity, UGC moderation, kids, contests, crypto, VPN, MDM, government sources and third-party trademarks.

## Submission evidence record

- App/version/build:
- Shell contract version:
- Review date and guideline “Last Updated” date:
- Monetization mode and App Store product IDs:
- Archive target (`Shell` or `ShellAds`):
- Data collected/tracked and SDK inventory:
- Legal document versions/URLs:
- Review access/sample data supplied:
- App-specific guideline exceptions or N/A reasons:
- Reviewer and final result:
