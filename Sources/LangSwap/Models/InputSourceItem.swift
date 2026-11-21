import Foundation

/// macOSの入力ソース（言語・キーボードレイアウト・IMEモード）を表すモデル
public struct InputSourceItem: Identifiable, Hashable, Codable, Sendable {
    /// 無効（割り当てなし）を表す特別なID
    public static let disabledID = "__DISABLED__"

    /// TISInputSource の一意な識別子 (例: "com.apple.keylayout.US")
    public let id: String
    /// システムから取得したローカライズ名称 (例: "U.S.", "Hiragana", "日本語 - ローマ字入力")
    public let localizedName: String
    /// 入力ソース種別 (TISTypeKeyboardLayout / TISTypeKeyboardInputMode)
    public let sourceType: String
    /// 対応言語コード配列 (例: ["en"], ["ja"], ["de"], ["it"], ["es"])
    public let languages: [String]
    /// 現在macOSで有効化されているかどうか
    public let isEnabled: Bool
    /// ASCII (英数字) 入力に対応しているか
    public let isASCIICapable: Bool

    public init(
        id: String,
        localizedName: String,
        sourceType: String = "",
        languages: [String] = [],
        isEnabled: Bool = true,
        isASCIICapable: Bool = false
    ) {
        self.id = id
        self.localizedName = localizedName
        self.sourceType = sourceType
        self.languages = languages
        self.isEnabled = isEnabled
        self.isASCIICapable = isASCIICapable
    }

    /// 主要な言語コード（例: "en", "ja", "de", "it", "es"）
    public var primaryLanguageCode: String {
        guard let first = languages.first else { return "" }
        return first.lowercased()
    }

    /// Kotoeri・Google日本語入力等の半角英字（ローマ字・英数）入力モードかどうかの判定（全角英数は除外）
    public var isJapaneseRomanOrAlphanumericMode: Bool {
        let lowerID = id.lowercased()
        guard !lowerID.contains("fullwidth") else {
            return false
        }
        return (lowerID.contains("kotoeri") || lowerID.contains("japanese")) &&
               (lowerID.contains("roman") || lowerID.contains("alphanumeric"))
    }

    /// 指定したUI言語に対応した補助言語名（ロケール依存ハードコード回避）
    public func localizedLanguageLabel(for appLang: AppLanguage = .ja) -> String {
        if isJapaneseRomanOrAlphanumericMode {
            return appLang == .ja
                ? "英語"
                : (Locale(identifier: appLang.localeIdentifier).localizedString(forLanguageCode: "en") ?? "English")
        }

        let code = primaryLanguageCode
        if appLang == .ja {
            if id.contains("Kotoeri") || id.contains("Japanese") || code.hasPrefix("ja") {
                return "日本語"
            }
            if id.hasSuffix(".US") || id.hasSuffix(".ABC") {
                return "英語"
            }
            switch code {
            case let c where c.hasPrefix("en"): return "英語"
            case let c where c.hasPrefix("de"): return "ドイツ語"
            case let c where c.hasPrefix("it"): return "イタリア語"
            case let c where c.hasPrefix("es"): return "スペイン語"
            case let c where c.hasPrefix("fr"): return "フランス語"
            case let c where c.hasPrefix("pt"): return "ポルトガル語"
            case let c where c.hasPrefix("ko"): return "韓国語"
            case let c where c.hasPrefix("zh-hans"): return "中国語(簡体字)"
            case let c where c.hasPrefix("zh-hant"): return "中国語(繁体字)"
            case let c where c.hasPrefix("zh"): return "中国語"
            case let c where c.hasPrefix("ru"): return "ロシア語"
            default: break
            }
        }

        let targetCode: String
        if !code.isEmpty {
            targetCode = code
        } else if id.contains("Kotoeri") || id.contains("Japanese") {
            targetCode = "ja"
        } else if id.hasSuffix(".US") || id.hasSuffix(".ABC") {
            targetCode = "en"
        } else {
            return ""
        }

        return Locale(identifier: appLang.localeIdentifier).localizedString(forLanguageCode: targetCode) ?? ""
    }

    /// UI表示用のモノスペース短縮コード（例: EN, JA, DE, IT, ES, OFF）
    public var badgeCode: String {
        if id == Self.disabledID {
            return "OFF"
        }
        if isJapaneseRomanOrAlphanumericMode {
            return "EN"
        }

        let lowerID = id.lowercased()
        let code = primaryLanguageCode

        if lowerID.contains("kotoeri") || lowerID.contains("japanese") || code.hasPrefix("ja") {
            return "JA"
        }
        if lowerID.hasSuffix(".us") || lowerID.contains("usinternational") ||
            lowerID.hasSuffix(".british") || lowerID.hasSuffix(".uk") ||
            lowerID.hasSuffix(".australian") || lowerID.hasSuffix(".canadian") ||
            lowerID.hasSuffix(".abc") || code.hasPrefix("en") {
            return "EN"
        }
        if lowerID.contains("german") || lowerID.contains("swissgerman") || code.hasPrefix("de") {
            return "DE"
        }
        if lowerID.contains("italian") || code.hasPrefix("it") {
            return "IT"
        }
        if lowerID.contains("spanish") || code.hasPrefix("es") {
            return "ES"
        }
        if lowerID.contains("french") || code.hasPrefix("fr") {
            return "FR"
        }
        if lowerID.contains("portuguese") || lowerID.contains("brazilian") || code.hasPrefix("pt") {
            return "PT"
        }
        if lowerID.contains("korean") || code.hasPrefix("ko") {
            return "KO"
        }
        if code.hasPrefix("zh-hant") {
            return "TW"
        }
        if code.hasPrefix("zh") {
            return "ZH"
        }
        if lowerID.contains("russian") || code.hasPrefix("ru") {
            return "RU"
        }
        if !code.isEmpty {
            let prefix = code.split(separator: "-").first.map(String.init) ?? code
            return String(prefix.prefix(2)).uppercased()
        }
        return "IN"
    }

    /// 絵文字を含まない一覧・ドロップダウン表示名
    public func cleanTitle(lang: AppLanguage) -> String {
        if id == Self.disabledID {
            return L10n.t(.disabledOption, lang: lang)
        }
        if lang == .ja {
            let label = localizedLanguageLabel(for: lang)
            if !label.isEmpty && !localizedName.contains(label) {
                return "\(localizedName)（\(label)）"
            }
        }
        return localizedName
    }

    /// 絵文字を含まない短縮表示名
    public func cleanShortName(lang: AppLanguage) -> String {
        if id == Self.disabledID {
            return L10n.t(.disabledShort, lang: lang)
        }
        return localizedName
    }

    /// 英語系の入力ソースかどうかの判定（初期デフォルト設定用）
    public var isEnglishLike: Bool {
        if isJapaneseRomanOrAlphanumericMode {
            return true
        }
        let lowerID = id.lowercased()
        if lowerID == "com.apple.keylayout.abc" || lowerID == "com.apple.keylayout.us" {
            return true
        }
        return primaryLanguageCode.hasPrefix("en") && sourceType.contains("Layout")
    }

    /// 日本語系の入力ソースかどうかの判定（初期デフォルト設定用）
    public var isJapaneseLike: Bool {
        if isJapaneseRomanOrAlphanumericMode {
            return false
        }
        let lowerID = id.lowercased()
        if lowerID.contains("kotoeri") && (lowerID.contains("japanese") || lowerID.contains("hiragana") || lowerID.contains("romaji")) {
            return true
        }
        if lowerID.contains("japanese") {
            return true
        }
        return primaryLanguageCode.hasPrefix("ja")
    }

    /// 無効選択用のプレースホルダー項目（UI表示には必ず cleanTitle(lang:) / cleanShortName(lang:) を使用すること）
    public static let disabledItem = InputSourceItem(
        id: disabledID,
        localizedName: "Disabled",
        sourceType: "",
        languages: [],
        isEnabled: true
    )
}

/// 言語ペアのプリセット設定（例：「英語 ↔ 日本語」「ドイツ語 ↔ 日本語」「スペイン語 ↔ 英語」など）
public struct LanguagePreset: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var leftCommandSourceID: String
    public var rightCommandSourceID: String

    public init(
        id: UUID = UUID(),
        name: String,
        leftCommandSourceID: String,
        rightCommandSourceID: String
    ) {
        self.id = id
        self.name = name
        self.leftCommandSourceID = leftCommandSourceID
        self.rightCommandSourceID = rightCommandSourceID
    }
}
