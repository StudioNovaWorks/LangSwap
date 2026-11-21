import AppKit
import Foundation

/// アプリケーションの外観モード
public enum AppTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    /// AppKit 側の外観指定（`.system` の場合は `nil` にしてシステム設定を継承する）
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// UI表示言語（18言語対応・非対応ロケールは英語にフォールバック）
public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case en
    case ja
    case zh_CN
    case zh_TW
    case ko
    case fr
    case it
    case de
    case es
    case pt
    case ar
    case hi
    case th
    case id
    case vi
    case tr
    case uk
    case ru

    public var id: String { rawValue }

    /// 言語自体のネイティブ表記
    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .ja: return "日本語"
        case .zh_CN: return "简体中文"
        case .zh_TW: return "繁體中文"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .pt: return "Português"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        case .th: return "ไทย"
        case .id: return "Bahasa Indonesia"
        case .vi: return "Tiếng Việt"
        case .tr: return "Türkçe"
        case .uk: return "Українська"
        case .ru: return "Русский"
        }
    }

    /// モノスペースバッジ用の短縮コード
    public var shortBadge: String {
        switch self {
        case .en: return "EN"
        case .ja: return "JA"
        case .zh_CN: return "ZH"
        case .zh_TW: return "TW"
        case .ko: return "KO"
        case .fr: return "FR"
        case .it: return "IT"
        case .de: return "DE"
        case .es: return "ES"
        case .pt: return "PT"
        case .ar: return "AR"
        case .hi: return "HI"
        case .th: return "TH"
        case .id: return "ID"
        case .vi: return "VI"
        case .tr: return "TR"
        case .uk: return "UK"
        case .ru: return "RU"
        }
    }

    /// Foundation Locale 用の識別子
    public var localeIdentifier: String {
        switch self {
        case .en: return "en_US"
        case .ja: return "ja_JP"
        case .zh_CN: return "zh_Hans_CN"
        case .zh_TW: return "zh_Hant_TW"
        case .ko: return "ko_KR"
        case .fr: return "fr_FR"
        case .it: return "it_IT"
        case .de: return "de_DE"
        case .es: return "es_ES"
        case .pt: return "pt_BR"
        case .ar: return "ar"
        case .hi: return "hi_IN"
        case .th: return "th_TH"
        case .id: return "id_ID"
        case .vi: return "vi_VN"
        case .tr: return "tr_TR"
        case .uk: return "uk_UA"
        case .ru: return "ru_RU"
        }
    }

    /// RTL言語（アラビア語）かどうか
    public var isRTL: Bool {
        self == .ar
    }

    /// 端末の優先言語から初期UI言語を判定する（18言語に一致しない場合は英語へフォールバック）
    public static func detectDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let rawFirst = preferredLanguages.first, !rawFirst.isEmpty else {
            return .en
        }

        let normalized = rawFirst.replacingOccurrences(of: "-", with: "_").lowercased()

        // 中国語はスクリプト/地域コードで簡体字・繁体字を判別
        if normalized.hasPrefix("zh") {
            if normalized.contains("hant") || normalized.contains("_tw") || normalized.contains("_hk") || normalized.contains("_mo") {
                return .zh_TW
            }
            return .zh_CN
        }

        let baseCode = normalized.split(separator: "_").first.map(String.init) ?? normalized
        if let matched = AppLanguage.allCases.first(where: { $0.rawValue.lowercased() == baseCode }) {
            return matched
        }

        return .en
    }
}

/// UIローカライズキー
public enum L10nKey: CaseIterable, Sendable {
    // Tabs
    case tabMapping
    case tabPresets
    case tabBehavior
    case tabGuide

    // Status & Permissions
    case statusActive
    case statusPaused
    case permSectionTitle
    case permGranted
    case permRequired
    case permBannerTitle
    case permBannerBody
    case permBannerUpdateHint
    case btnOpenSystemSettings
    case btnViewPermissionSettings
    case btnRecheck
    case btnRelaunch

    // Mapping tab
    case leftCommand
    case rightCommand
    case swapKeys
    case presetsHeader
    case saveCurrentPair

    // Presets & Languages tab
    case presetSectionTitle
    case btnApply
    case badgeActive
    case inputSourcesSectionTitle
    case searchLanguagePlaceholder
    case btnRefresh
    case btnSystemKeyboard
    case badgeEnabled
    case badgeUnavailable
    case btnEnable
    case deletePresetTooltip
    case deleteMenuAction
    case presetEmptyHint
    case deleteInputSourceTooltip
    case deleteInputSourceProtectedTooltip

    // Behavior tab
    case startupSectionTitle
    case launchAtLogin
    case launchAtLoginApprovalHint
    case launchAtLoginErrorHint
    case btnOpenLoginItems
    case launchInBackground
    case launchInBackgroundDesc
    case appearanceSectionTitle
    case themeLabel
    case themeSystem
    case themeLight
    case themeDark
    case uiLanguageLabel
    case showHudLabel
    case detectionSectionTitle
    case tapTimeoutLabel
    case tapTimeoutDesc

    // Guide & Info tab
    case guideOverviewTitle
    case guideOverviewDesc
    case privacyPolicyBtn
    case guideStepsTitle
    case guideStep1
    case guideStep2
    case guideStep3
    case guideStep4
    case guideTroubleshootTitle
    case troubleshootQ1
    case troubleshootA1
    case troubleshootQ2
    case troubleshootA2
    case troubleshootQ3
    case troubleshootA3
    case troubleshootQ4
    case troubleshootA4
    case troubleshootQ5
    case troubleshootA5
    case troubleshootQ6
    case troubleshootA6
    case supportTitle
    case supportDesc
    case donateBtn
    case creditDevelopedBy

    // Menu Bar, HUD, App Menu & Tooltips
    case openSettings
    case quitApp
    case disabledOption
    case disabledShort
    case leftTapLabel
    case rightTapLabel
    case languageTooltip
    case themeTooltip
    case infoTooltip
    case kofiTooltip
    case menuSettings
    case menuQuit
    case menuEdit
    case menuWindow
    case menuUndo
    case menuRedo
    case menuCut
    case menuCopy
    case menuPaste
    case menuSelectAll
    case menuClose
    case menuMinimize
    case statusTooltipActive
    case statusTooltipPaused
    case statusTooltipPermRequired
}

/// 18言語対応のローカライズ辞書
public enum L10n {
    public static let kofiURLString = "https://ko-fi.com/E1E81S63Z8"
    public static let privacyPolicyURLString = "https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html"

    public static func privacyPolicyURL(lang: AppLanguage) -> URL? {
        URL(string: "\(privacyPolicyURLString)?lang=\(lang.rawValue)")
    }

    public static func t(_ key: L10nKey, lang: AppLanguage) -> String {
        if let value = translations[lang]?[key] {
            return value
        }
        return translations[.en]?[key] ?? ""
    }

    /// すべてのキーと18言語の網羅性を検証するためのヘルパー
    public static func hasCompleteCoverage() -> Bool {
        for lang in AppLanguage.allCases {
            guard let dict = translations[lang] else { return false }
            for key in L10nKey.allCases where (dict[key] ?? "").isEmpty {
                return false
            }
        }
        return true
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = {
        var merged: [AppLanguage: [L10nKey: String]] = [:]
        for (lang, dict) in LocalizationTables.core {
            merged[lang] = dict
        }
        for (lang, dict) in LocalizationTables.europe {
            merged[lang] = dict
        }
        for (lang, dict) in LocalizationTables.asiaME {
            merged[lang] = dict
        }
        return merged
    }()
}

enum LocalizationTables {}
