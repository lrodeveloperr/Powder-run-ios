# Auto-renewable subscription lifecycle guide

Use this guide for every derived app that sells an auto-renewable subscription. It records the failures found while hardening Welding Gas Wallet and the reusable fixes adopted upstream.

## StoreKit state contract

| Verified state | Paid access | Product response |
|---|---:|---|
| `subscribed`, auto-renew on | Yes | Show renewal date and Manage Subscription |
| `subscribed`, auto-renew off | Yes, until paid expiration | Show the paid-through date; do not downgrade on cancellation |
| `inGracePeriod` | Yes, until verified grace expiration | Keep access and offer billing management |
| `inBillingRetryPeriod` | No after grace | Preserve data, show billing recovery, and do not sell a duplicate subscription |
| `expired` | No | Apply the documented free/lapsed policy |
| `revoked` or refunded | No immediately | Clear cached entitlement and apply the lapsed policy |
| Offline verified snapshot | Yes only until its effective verified expiration | Never extend access because the device is offline |

Settings must be derived from that verified condition, not merely from the fact that the app sells a subscription:

| Condition | Status row | Icon | Manage Subscription |
|---|---|---|---|
| Checking | Localized checking copy | Neutral hourglass | Hidden |
| No purchase / expired / revoked | Hidden; show the app's upgrade entry point when appropriate | None | Hidden |
| Subscribed, auto-renew on or off | Renewal or paid-through date | Success seal | Shown |
| Billing Grace Period | Grace-period date and payment warning | Warning | Shown |
| Billing retry after grace | Payment-recovery message | Warning | Shown |
| Valid offline snapshot | Verified-until date | Neutral verified seal | Shown |

Never show a success checkmark beside an inactive state, and never offer Apple's management sheet to a customer for whom the app has no current or recoverable subscription context. That combination looks like placeholder UI and can produce a blank or irrelevant system sheet in testing.

Use verified `Product.SubscriptionInfo.Status` and verified transaction and renewal information. A transaction's original `expirationDate` alone is insufficient because Billing Grace Period has its own effective expiration.

Refresh on launch, verified `Transaction.updates`, purchase, restore, foreground activation, and a scheduled task at the effective expiration. A UI that was opened while paid must re-read entitlement when its mutation commits.

## Failure patterns and upstream fixes

| Failure | Root cause | Required fix |
|---|---|---|
| Paid access survives while the app remains open past expiry | No expiration timer or foreground refresh | Schedule a refresh at effective expiry and refresh when the scene becomes active |
| Grace-period subscriber is locked out | Code rejects the original transaction expiration without reading renewal state | Treat verified `inGracePeriod` as entitled until `gracePeriodExpirationDate` |
| Cancel immediately removes paid access | Auto-renew preference is confused with current entitlement | `willAutoRenew == false` changes messaging only; access continues through paid expiration |
| Billing-retry customer sees another purchase button | Recovery state is treated as a new customer | Show Manage Subscription/billing recovery instead of a duplicate purchase action |
| Unverified status is treated as a verified expiry | A nonempty status response is called authoritative even though every entry failed verification | Only an empty response or at least one relevant verified status may replace the verified cache |
| A form opened before expiry commits a paid mutation afterward | Entitlement was captured when the screen opened | Resolve entitlement again inside the domain operation at commit time |
| Add, duplicate, import, undo, migration, deep link, or background work bypasses a limit | Buttons are treated as the security boundary | Put quota and record-access checks in the repository/store used by every mutation |
| A lapsed user retains unlimited operational value | Existing over-limit records remain editable | Preserve all records, but restrict paid mutations according to a deterministic, documented lapsed policy |
| Expiry deletes or silently archives records | Quota enforcement mutates customer data | Never delete or change lifecycle automatically; use visible read-only state and allow data-reducing actions |
| A valid backup is rejected only because it contains paid-era data | Restore equates possession with entitlement | Restore valid data atomically, discard entitlement, then apply the current locked/read-only policy where the product can represent it safely |
| Delete, add, then Undo creates an extra free record | Undo bypasses the same active-record policy | Reconcile access after Undo; restored excess data may return read-only but never as an extra free managed slot |
| Every Settings user sees Manage Subscription | UI is gated by product configuration instead of verified customer state | Hide it for absent, expired and revoked states; expose it for active, grace, billing-retry and valid offline-cached states |

For a record-count freemium product, define what counts toward the quota and what happens after lapse before implementation. A fair default is:

- keep all records visible and exportable;
- let the customer select the free allowance once;
- make excess active records read-only;
- allow delete, return, archive, backup, export, restore, purchase management, and resubscription;
- require a managed record to leave the counted state before assigning its slot to another record; and
- unlock everything immediately after verified recovery or resubscription.

If a product cannot safely represent over-limit data read-only, fail the import atomically before changing device data. Never partially restore.

## App Store Connect and listing gate

Apple's current subscription guidance requires ongoing value and clear purchase terms. Before finalizing the listing:

- Use one subscription group for one service unless customers genuinely need simultaneous subscriptions. A single monthly product needs one group and one level.
- Configure the exact product identifier, one-month duration, availability, tax category, and intended starting price in App Store Connect.
- Use StoreKit's localized `displayName`, `displayPrice`, and subscription period in the app. Do not hard-code a currency or claim a manual exchange-rate conversion.
- Make the full renewal price the most prominent pricing element. State the subscription name, duration, and exact service unlocked.
- Keep Restore Purchases, Privacy Policy, Terms of Use, subscription status, and Manage Subscription easy to find.
- Localize the subscription group display name and the subscription display name/description for every storefront language claimed by the app.
- Supply the subscription review screenshot and notes showing where the paywall is reached, the free limit, what Pro unlocks, and how Review can restore/test it.
- Submit the first subscription and subscription group with the app version and add the product for review.
- If Billing Grace Period is enabled, test `inGracePeriod`, billing retry, recovery, cancellation, expiry, refund/revocation, offline launch, foreground refresh, and expiration while a mutation form is open.
- Keep the app description, screenshots, paywall, legal documents, review notes, and App Store Connect product at the same price and entitlement contract.

## Default product-page gate

- Make the name memorable and descriptive without keyword stuffing (30-character limit). Use the subtitle for one concrete outcome, not a generic superlative (30-character limit).
- Treat screenshots 1–3 as the search-results story when there is no app preview. Lead with the core job and outcome, then use each later screenshot for one distinct benefit. Show real app UI and localize the screenshot set for every claimed listing language.
- Upload one to ten screenshots with no alpha channel. Prefer the highest-resolution required device class so App Store Connect can scale it; provide the required 13-inch set whenever the binary supports iPad.
- Start the description with the clearest differentiator, then a short feature list in the audience's own terminology. Do not put a fixed subscription price in the description because storefront prices vary.
- Use the 170-character promotional text for timely marketing, not keyword ranking. Keep the 100-character keyword field relevant, comma-separated and free of duplicate/plural/category/app terms, competitor names and unauthorized trademarks.
- Ensure the privacy label covers the app and every embedded third-party SDK, and keep the required public privacy-policy URL current. Localize privacy URLs where matching documents exist; otherwise disclose the document language accurately.
- Give App Review exact navigation steps to the free limit, paywall, Restore Purchases, Manage Subscription and any state that needs setup. Include complete contact information and never submit broken links, placeholders or unfinished metadata.
- After release, use Product Page Optimization for controlled screenshot/icon/preview experiments rather than changing several conversion variables at once.

Primary references:

- [Apple auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Manage subscription pricing](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/)
- [App Review Guidelines 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions)
- [Creating your product page](https://developer.apple.com/app-store/product-page/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Preparing for App Review](https://developer.apple.com/distribute/app-review/)
