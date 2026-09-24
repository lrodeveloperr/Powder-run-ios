#!/usr/bin/env bash
set -euo pipefail

mode="${1:---template}"
case "$mode" in
  --template|--release|--release-ads) ;;
  *) echo "Usage: $0 [--template|--release|--release-ads]" >&2; exit 64 ;;
esac

fail() { echo "VALIDATION FAILED: $*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "Missing $1"; }
require_text() { grep -Fq "$2" "$1" || fail "$1 must contain: $2"; }
reject_text() { ! grep -Fq "$2" "$1" || fail "$1 contains forbidden text: $2"; }

[[ -x scripts/validate-shell.sh ]] || fail "scripts/validate-shell.sh must retain its executable bit"

for path in project.yml AGENTS.md docs/APPLE_STORE_COMPLIANCE.md docs/DERIVED_APP_RELEASE_WIRING.md docs/UI_REGRESSION_MATRIX.md SHELL_CHANGELOG.md MIGRATIONS.md Shell/App/ShellConfiguration.swift Shell/App/ShellContract.swift Shell/App/FeatureCanvasBoundary.swift Shell/Services/AppLocalization.swift Shell/Services/PurchaseService.swift Shell/Services/AccessController.swift Shell/Services/NativeBackup.swift Shell/Services/AdConsentService.swift Shell/Resources/Info.plist Shell/Resources/Info-Ads.plist Shell/Resources/PrivacyInfo.xcprivacy Shell/Resources/LocalizationBaseline.swift Shell/Resources/gooduse-common-localization-v1.json Shell/Resources/Assets.xcassets/AppIcon.appiconset/PowderRun-1024.png scripts/check-commerce-branding.sh; do
  require_file "$path"
done

if rg -n 'import (Flutter|React|ReactNative)|FlutterViewController|RCTRootView' Shell; then
  fail "Cross-platform runtime detected; this shell must remain native Swift/SwiftUI"
fi

bash scripts/check-commerce-branding.sh
python3 scripts/validate-localizations.py

# The default product is physically ad-free. Advertising symbols are compiled
# only for ShellAds, which alone links Google Mobile Ads.
reject_text Shell/Resources/Info.plist 'GADApplicationIdentifier'
reject_text Shell/Resources/Info.plist 'SKAdNetworkIdentifier'
require_text project.yml 'ShellAds:'
require_text project.yml 'SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) ADS_ENABLED"'
require_text project.yml 'package: GoogleMobileAds'
require_text Shell/Services/AdConsentService.swift '#if ADS_ENABLED'
require_text Shell/Services/AdaptiveAdBanner.swift '#if ADS_ENABLED'

for mode_name in free ads adsWithRemovePurchase adsWithSubscription oneTimeUnlock subscription usageCapWithOneTimeUnlock usageCapWithSubscription; do
  require_text Shell/App/ShellConfiguration.swift "case $mode_name"
done
for seam in 'Transaction.updates' 'Transaction.currentEntitlements' 'AppStore.sync()' 'revocationDate' 'expirationDate'; do
  require_text Shell/Services/PurchaseService.swift "$seam"
done
require_text Shell/Services/AdConsentService.swift 'ConsentForm.loadAndPresentIfRequired'
require_text Shell/App/ShellRootView.swift '.safeAreaInset(edge: .bottom, spacing: 0) { adBanner }'
require_text Shell/Services/AdaptiveAdBanner.swift '.frame(height: adSize.size.height)'
require_text Shell/Features/PaywallView.swift 'paywall.retryProduct'
require_text Shell/Services/LanguageController.swift 'supported.contains(stored)'
require_text Shell/Services/LanguageController.swift 'SupportedLocaleResolver.isRightToLeft'
require_text Shell/App/ShellRootView.swift '.environment(\.layoutDirection, model.language.layoutDirection)'
require_text docs/LOCALIZATION_RELEASE_CHECKLIST.md 'Automated translation, if used to create a draft, is never treated as approval.'
require_text Shell/Services/NativeBackup.swift 'current free/paid limits'
require_text .github/workflows/powder-run-testflight.yml 'date -u +%y%m%d%H%M'
require_text .github/workflows/powder-run-testflight.yml 'Run unit tests before upload'
require_text .github/workflows/powder-run-testflight.yml 'ENABLE_TESTABILITY=YES'
require_text .github/workflows/powder-run-testflight.yml 'UPLOAD POWDER RUN'
reject_text .github/workflows/powder-run-testflight.yml 'SCREENSHOT_BUILD'
reject_text Shell/Features/SettingsView.swift 'NavigationLink { PaywallView() }'
require_text Shell/Features/OnboardingView.swift 'Toggle(isOn: $accepted)'
require_text Shell/Services/LegalConsentStore.swift 'acceptedLegalVersion'
require_text Shell/App/ShellConfiguration.swift 'static let onboarding: OnboardingProfile?'
require_text Shell/App/ShellRootView.swift 'if let onboarding = ShellConfiguration.onboarding'
require_text Shell/App/ShellRootView.swift 'private var requiresOnboarding: Bool'
require_text Shell/Services/UsageLedger.swift 'KeychainUsageStore'
require_text Shell/Services/UsageLedger.swift 'revised.insert(id)'
require_text Shell/Services/UsageLedger.swift 'id.utf8.count <= 128'
require_text Shell/App/FeatureCanvasBoundary.swift 'switch model.access.decision'
require_text Shell/App/ShellRootView.swift '.tabItem { Label('
require_text Shell/App/ShellRootView.swift 'SettingsView(model: model)'
require_text Shell/Features/ShellLabView.swift '#if DEBUG'
require_text Shell/Features/SettingsView.swift '#if DEBUG'
require_text Shell/Features/SettingsView.swift 'SubscriptionSettingsPresentation.resolve'
require_text Shell/Features/SettingsView.swift 'shell.settings.subscription.manage'
require_text Shell/Features/SettingsView.swift '.buttonStyle(.plain)'
require_text Shell/App/ShellModel.swift '#if DEBUG'
require_text Shell/App/ShellContract.swift 'currentVersion = "2.0.0"'
require_text Shell/App/ShellConfiguration.swift 'BackupConfiguration(enabled: false)'

plutil -lint Shell/Resources/Info.plist >/dev/null
plutil -lint Shell/Resources/Info-Ads.plist >/dev/null
plutil -lint Shell/Resources/PrivacyInfo.xcprivacy >/dev/null

for info_plist in Shell/Resources/Info.plist Shell/Resources/Info-Ads.plist; do
  export_flag="$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$info_plist" 2>/dev/null || true)"
  [[ "$export_flag" == "false" ]] || fail "$info_plist must declare ITSAppUsesNonExemptEncryption=false unless the derived app adds non-exempt encryption"
done

ruby <<'RUBY'
require "json"
def keys(path)
  File.readlines(path).filter_map { |line| line[/^\s*"([^"]+)"\s*=/, 1] }.sort
end
base = keys("Shell/Resources/en.lproj/Localizable.strings")
Dir["Shell/Resources/*.lproj/Localizable.strings"].each do |path|
  abort "Localization key mismatch in #{path}" unless keys(path) == base
end
abort "Duplicate English localization keys" unless base.length == base.uniq.length

common = JSON.parse(File.read("Shell/Resources/gooduse-common-localization-v1.json"))
abort "Shared localization baseline must contain exactly 31 locales" unless common.fetch("locales").length == 31
common.fetch("entries").each do |key, entry|
  abort "Shared localization width mismatch for #{key}" unless entry.fetch("translations").length == 31
end
RUBY

if command -v sips >/dev/null 2>&1; then
  dimensions="$(sips -g pixelWidth -g pixelHeight Shell/Resources/Assets.xcassets/AppIcon.appiconset/PowderRun-1024.png 2>/dev/null)"
  grep -Fq 'pixelWidth: 1024' <<<"$dimensions" || fail "App icon width must be 1024"
  grep -Fq 'pixelHeight: 1024' <<<"$dimensions" || fail "App icon height must be 1024"
fi

if [[ "$mode" == "--release" || "$mode" == "--release-ads" ]]; then
  reject_text Shell/App/ShellConfiguration.swift 'appName = "Shell"'
  reject_text Shell/App/ShellConfiguration.swift 'support@example.com'
  reject_text Shell/App/ShellConfiguration.swift 'https://example.com/'
  reject_text Shell/App/ShellConfiguration.swift 'shell.pro.'
  reject_text Shell/Resources/Info.plist '<string>Shell</string>'
  reject_text project.yml 'com.goodusestudios.shelllab'
  reject_text project.yml 'PRODUCT_NAME: Shell'
  reject_text Shell/Resources/en.lproj/Localizable.strings 'REPLACE_WITH_REVIEWED_'
  reject_text Shell/Resources/es.lproj/Localizable.strings 'REPLACE_WITH_REVIEWED_'
  reject_text Shell/Resources/en.lproj/Localizable.strings 'Make the useful thing unlimited.'
  reject_text Shell/Resources/en.lproj/Localizable.strings 'Unlimited core actions'
  reject_text Shell/Resources/es.lproj/Localizable.strings 'Usa la función sin límites.'
  reject_text Shell/Resources/es.lproj/Localizable.strings 'Acciones principales ilimitadas'
  reject_text Shell/App/ShellApp.swift 'PlaceholderFeatureCanvasProvider()'
  grep -Fq 'privacyURL: URL(string: "https://' Shell/App/ShellConfiguration.swift || fail "Privacy URL must use HTTPS"
  grep -Fq 'termsURL: URL(string: "https://' Shell/App/ShellConfiguration.swift || fail "Terms URL must use HTTPS"
fi

selected_mode="$(sed -n 's/.*mode: \.\([A-Za-z]*\).*/\1/p' Shell/App/ShellConfiguration.swift | head -1)"
if [[ "$mode" == "--release-ads" ]]; then
  [[ "$selected_mode" == "ads" || "$selected_mode" == "adsWithRemovePurchase" || "$selected_mode" == "adsWithSubscription" ]] || fail "--release-ads requires an advertising monetization mode"
  reject_text Shell/App/ShellConfiguration.swift 'ca-app-pub-3940256099942544/'
  reject_text Shell/Resources/Info-Ads.plist 'ca-app-pub-3940256099942544~'
  if grep -A1 -F '<key>NSPrivacyCollectedDataTypes</key>' Shell/Resources/PrivacyInfo.xcprivacy | grep -Fq '<array/>'; then
    fail "Advertising release must declare reviewed collected-data types"
  fi
elif [[ "$mode" == "--release" ]]; then
  [[ "$selected_mode" != "ads" && "$selected_mode" != "adsWithRemovePurchase" && "$selected_mode" != "adsWithSubscription" ]] || fail "Advertising mode must use --release-ads and the ShellAds target"
fi

echo "iOS shell validation passed ($mode)."
