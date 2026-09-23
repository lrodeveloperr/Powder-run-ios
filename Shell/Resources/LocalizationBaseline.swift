import Foundation

/// Shared terminology target for future derived apps. This is not a claim that
/// product-specific copy has been translated. A locale may be exposed in
/// `supportedLanguages` only after its complete app catalog passes review.
enum LocalizationBaseline {
    static let localeIdentifiers: Set<String> = [
        "en", "es", "pt", "fr", "de", "it", "nl", "pl", "tr", "ro",
        "cs", "uk", "ru", "ar", "zh", "ja", "ko", "hi", "ur", "bn",
        "vi", "id", "th", "fil", "ms", "fi", "sv", "da", "nb", "el", "he",
    ]

    static let sharedKeys: Set<String> = [
        "common.back", "common.continue", "common.language", "common.selected",
        "common.tapToSelect", "common.all", "common.notes", "common.notifications",
        "common.settings", "common.support", "common.analytics", "common.exports",
        "common.accessibility", "common.privacyPolicy", "common.termsOfUse",
        "common.safetyNotice", "common.localDataBackups", "common.thirdPartyNotices",
    ]
}
