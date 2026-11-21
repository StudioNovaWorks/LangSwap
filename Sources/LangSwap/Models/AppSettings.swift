import Foundation
import AppKit
import Combine
import ServiceManagement

/// アプリケーション全体の設定を管理・永続化するクラス
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private let defaults: UserDefaults
    private let loginItemStatusProvider: () -> SMAppService.Status

    private enum Keys {
        static let isEnabled = "LangSwap.isEnabled"
        static let leftCommandSourceID = "LangSwap.leftCommandSourceID"
        static let rightCommandSourceID = "LangSwap.rightCommandSourceID"
        static let tapTimeoutMs = "LangSwap.tapTimeoutMs"
        static let showHUDNotification = "LangSwap.showHUDNotification"
        static let presets = "LangSwap.presets"
        static let hasInitializedDefaults = "LangSwap.hasInitializedDefaults"
        static let launchInBackground = "LangSwap.launchInBackground"
        static let appTheme = "LangSwap.appTheme"
        static let appLanguage = "LangSwap.appLanguage"
    }

    /// 機能全体の有効・無効フラグ
    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    /// 左Commandキーに割り当てられた入力ソースID
    @Published public var leftCommandSourceID: String {
        didSet { defaults.set(leftCommandSourceID, forKey: Keys.leftCommandSourceID) }
    }

    /// 右Commandキーに割り当てられた入力ソースID
    @Published public var rightCommandSourceID: String {
        didSet { defaults.set(rightCommandSourceID, forKey: Keys.rightCommandSourceID) }
    }

    /// 単押し（タップ）と判定する最大押下時間（ミリ秒: 150ms 〜 1000ms）
    @Published public var tapTimeoutMs: Int {
        didSet {
            let clamped = min(max(tapTimeoutMs, AppConstants.Timing.minTapTimeoutMs), AppConstants.Timing.maxTapTimeoutMs)
            if tapTimeoutMs != clamped {
                tapTimeoutMs = clamped
            }
            defaults.set(tapTimeoutMs, forKey: Keys.tapTimeoutMs)
        }
    }

    /// 言語切り替え時に画面中央下部にミニHUD通知を表示するか
    @Published public var showHUDNotification: Bool {
        didSet { defaults.set(showHUDNotification, forKey: Keys.showHUDNotification) }
    }

    /// ユーザーが保存した言語組み合わせプリセット一覧
    @Published public var presets: [LanguagePreset] {
        didSet { savePresets() }
    }

    /// ログイン時に自動起動するかどうか (SMAppService連携)
    @Published public var launchAtLogin: Bool = false

    /// システム設定「ログイン項目」でユーザーの承認待ちかどうか
    @Published public private(set) var launchAtLoginNeedsApproval: Bool = false

    /// ログイン項目の登録／解除でエラーが発生したか
    @Published public private(set) var launchAtLoginError: Bool = false

    /// 起動時に設定ウィンドウを開かずバックグラウンド（メニューバー常駐）で起動するか
    @Published public var launchInBackground: Bool {
        didSet { defaults.set(launchInBackground, forKey: Keys.launchInBackground) }
    }

    /// アプリケーションの外観モード（システム / ライト / ダーク）
    @Published public var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
            applyTheme()
        }
    }

    /// UI表示言語（18言語対応）
    @Published public var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    /// 初回デフォルト設定が既に完了しているか
    public var hasInitializedDefaults: Bool {
        defaults.bool(forKey: Keys.hasInitializedDefaults)
    }

    public init(
        defaults: UserDefaults = .standard,
        loginItemStatusProvider: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status }
    ) {
        self.defaults = defaults
        self.loginItemStatusProvider = loginItemStatusProvider

        if defaults.object(forKey: Keys.isEnabled) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        }

        self.leftCommandSourceID = defaults.string(forKey: Keys.leftCommandSourceID) ?? ""
        self.rightCommandSourceID = defaults.string(forKey: Keys.rightCommandSourceID) ?? ""

        let savedTimeout = defaults.integer(forKey: Keys.tapTimeoutMs)
        if savedTimeout >= AppConstants.Timing.minTapTimeoutMs && savedTimeout <= AppConstants.Timing.maxTapTimeoutMs {
            self.tapTimeoutMs = savedTimeout
        } else {
            self.tapTimeoutMs = AppConstants.Timing.defaultTapTimeoutMs
        }

        if defaults.object(forKey: Keys.showHUDNotification) == nil {
            self.showHUDNotification = true
        } else {
            self.showHUDNotification = defaults.bool(forKey: Keys.showHUDNotification)
        }

        var needsPresetCleanupSave = false
        if let data = defaults.data(forKey: Keys.presets),
           let decoded = try? JSONDecoder().decode([LanguagePreset].self, from: data) {
            let deduped = Self.deduplicatedPresets(decoded)
            self.presets = deduped
            needsPresetCleanupSave = (deduped.count != decoded.count)
        } else {
            self.presets = []
        }

        let loginStatus = loginItemStatusProvider()
        self.launchAtLogin = (loginStatus == .enabled)
        self.launchAtLoginNeedsApproval = (loginStatus == .requiresApproval)

        if defaults.object(forKey: Keys.launchInBackground) == nil {
            self.launchInBackground = false
        } else {
            self.launchInBackground = defaults.bool(forKey: Keys.launchInBackground)
        }

        if let rawTheme = defaults.string(forKey: Keys.appTheme),
           let decodedTheme = AppTheme(rawValue: rawTheme) {
            self.appTheme = decodedTheme
        } else {
            self.appTheme = .system
        }

        if let rawLang = defaults.string(forKey: Keys.appLanguage),
           let decodedLang = AppLanguage(rawValue: rawLang) {
            self.appLanguage = decodedLang
        } else {
            self.appLanguage = AppLanguage.detectDefault()
        }

        if needsPresetCleanupSave {
            savePresets()
        }
    }

    /// 単押しタイムアウト秒数 (TimeInterval)
    public var tapTimeoutSeconds: TimeInterval {
        TimeInterval(tapTimeoutMs) / 1000.0
    }

    /// 初回起動時または未設定時に、ユーザーの優先言語とシステムで有効な入力ソースから最適な初期値（例: 左⌘=英語、右⌘=ユーザーの主要非英語言語）を設定する
    /// プリセット登録はユーザーの明示操作に委ねるため、初回から自動生成は行わない。
    public func applySmartDefaultsIfNeeded(
        availableSources: [InputSourceItem],
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        guard !availableSources.isEmpty else { return }

        // 左Commandの初期設定: 英語 (U.S. / ABC 等) を優先選択
        if leftCommandSourceID.isEmpty {
            if let english = availableSources.first(where: { $0.id == "com.apple.keylayout.US" })
                ?? availableSources.first(where: { $0.id == "com.apple.keylayout.ABC" })
                ?? availableSources.first(where: { $0.isEnglishLike && !$0.isJapaneseRomanOrAlphanumericMode })
                ?? availableSources.first(where: { $0.isEnglishLike })
                ?? availableSources.first {
                leftCommandSourceID = english.id
            }
        }

        // 右Commandの初期設定: ユーザーの優先言語に一致する非英語入力ソースを優先選択
        if rightCommandSourceID.isEmpty {
            let candidates = availableSources.filter {
                $0.id != leftCommandSourceID && !$0.isJapaneseRomanOrAlphanumericMode
            }
            var resolvedRight: InputSourceItem?
            for prefLang in preferredLanguages {
                if let match = Self.preferredSource(forPreferredLanguage: prefLang, in: candidates) {
                    resolvedRight = match
                    break
                }
            }
            if let target = resolvedRight
                ?? candidates.first(where: { !$0.isEnglishLike })
                ?? availableSources.first(where: { $0.id != leftCommandSourceID })
                ?? availableSources.first {
                rightCommandSourceID = target.id
            }
        }

        if !defaults.bool(forKey: Keys.hasInitializedDefaults) {
            defaults.set(true, forKey: Keys.hasInitializedDefaults)
        }
    }

    private static func preferredSource(
        forPreferredLanguage rawLang: String,
        in candidates: [InputSourceItem]
    ) -> InputSourceItem? {
        let normalized = rawLang.replacingOccurrences(of: "_", with: "-").lowercased()
        let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
        guard !base.isEmpty, base != "en" else { return nil }

        if base == "ja" {
            return candidates.first(where: { $0.id == "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese" })
                ?? candidates.first(where: { $0.isJapaneseLike })
        }

        if base == "zh" {
            let wantsTraditional = normalized.contains("hant")
                || normalized.contains("-tw")
                || normalized.contains("-hk")
                || normalized.contains("-mo")
            let zhCandidates = candidates.filter { item in
                item.languages.contains {
                    $0.replacingOccurrences(of: "_", with: "-").lowercased().hasPrefix("zh")
                } || item.badgeCode == "ZH" || item.badgeCode == "TW"
            }
            if wantsTraditional {
                return zhCandidates.first(where: { item in
                    let lowerID = item.id.lowercased()
                    return item.languages.contains {
                        $0.replacingOccurrences(of: "_", with: "-").lowercased().hasPrefix("zh-hant")
                    } || item.badgeCode == "TW" || lowerID.contains("tcim") || lowerID.contains("zhuyin") || lowerID.contains("cangjie")
                }) ?? zhCandidates.first
            }
            return zhCandidates.first(where: { item in
                let lowerID = item.id.lowercased()
                return item.languages.contains {
                    $0.replacingOccurrences(of: "_", with: "-").lowercased().hasPrefix("zh-hans")
                } || lowerID.contains("scim") || lowerID.contains("pinyin")
            }) ?? zhCandidates.first
        }

        return candidates.first(where: { item in
            item.languages.contains { langCode in
                let code = langCode.replacingOccurrences(of: "_", with: "-").lowercased()
                return code == base || code.hasPrefix("\(base)-")
            }
        }) ?? candidates.first(where: { $0.badgeCode.lowercased() == base })
    }

    /// 左右のCommandキーに割り当てられた言語を入れ替える
    public func swapLeftAndRightSources() {
        let temp = leftCommandSourceID
        leftCommandSourceID = rightCommandSourceID
        rightCommandSourceID = temp
    }

    /// 現在の左右設定をプリセットとして保存する（同じ左右ペアが既存の場合は重複追加せず先頭へ移動する）
    public func addPreset(name: String, isCustomName: Bool = true) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingIndex = presets.firstIndex(where: {
            $0.leftCommandSourceID == leftCommandSourceID &&
            $0.rightCommandSourceID == rightCommandSourceID
        }) {
            var existing = presets.remove(at: existingIndex)
            if isCustomName && !trimmed.isEmpty {
                existing.name = trimmed
            }
            presets.insert(existing, at: 0)
            return
        }

        guard !trimmed.isEmpty else { return }
        let preset = LanguagePreset(
            name: trimmed,
            leftCommandSourceID: leftCommandSourceID,
            rightCommandSourceID: rightCommandSourceID
        )
        presets.insert(preset, at: 0)
    }

    /// 指定したプリセットを適用する
    public func applyPreset(_ preset: LanguagePreset) {
        leftCommandSourceID = preset.leftCommandSourceID
        rightCommandSourceID = preset.rightCommandSourceID
    }

    /// 指定したプリセットを削除する
    public func removePreset(_ preset: LanguagePreset) {
        presets.removeAll { $0.id == preset.id }
    }

    /// ログイン時自動起動の切り替え
    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            let status = SMAppService.mainApp.status
            launchAtLogin = (status == .enabled)
            launchAtLoginNeedsApproval = (status == .requiresApproval)
            launchAtLoginError = false
        } catch {
            let status = SMAppService.mainApp.status
            launchAtLogin = (status == .enabled)
            launchAtLoginNeedsApproval = (status == .requiresApproval)
            launchAtLoginError = (status != .requiresApproval)
        }
    }

    /// システム設定側のログイン項目状態を再取得して UI と同期する
    public func refreshLaunchAtLoginStatus() {
        let status = loginItemStatusProvider()
        let enabled = (status == .enabled)
        let needsApproval = (status == .requiresApproval)
        if launchAtLogin != enabled {
            launchAtLogin = enabled
        }
        if launchAtLoginNeedsApproval != needsApproval {
            launchAtLoginNeedsApproval = needsApproval
        }
        if (enabled || needsApproval) && launchAtLoginError {
            launchAtLoginError = false
        }
    }

    /// macOSの「システム設定 > 一般 > ログイン項目」画面を開く
    public func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 現在のテーマ設定を通常ウィンドウおよびポップオーバーへ反映する
    /// （ステータスバーウィンドウは macOS メニューバーの明暗へ自動追従させるため nil を維持）
    public func applyTheme() {
        guard let app = NSApp else { return }
        let targetAppearance = appTheme.nsAppearance
        app.appearance = nil
        for window in app.windows {
            let className = NSStringFromClass(type(of: window))
            if className.contains("StatusBar") || window.styleMask.contains(.nonactivatingPanel) {
                window.appearance = nil
                continue
            }
            window.appearance = targetAppearance
            window.contentView?.appearance = nil
        }
    }

    private struct PresetPairKey: Hashable {
        let left: String
        let right: String
    }

    private static func deduplicatedPresets(_ list: [LanguagePreset]) -> [LanguagePreset] {
        var seen = Set<PresetPairKey>()
        var result: [LanguagePreset] = []
        for preset in list {
            let key = PresetPairKey(left: preset.leftCommandSourceID, right: preset.rightCommandSourceID)
            if seen.insert(key).inserted {
                result.append(preset)
            }
        }
        return result
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: Keys.presets)
        }
    }
}
