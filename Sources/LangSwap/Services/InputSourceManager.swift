import Foundation
import Carbon
import AppKit

/// macOSの入力ソース（言語・キーボードレイアウト・IME）の取得・監視・切り替えを担うマネージャ
@MainActor
public final class InputSourceManager: ObservableObject {
    public static let shared = InputSourceManager()

    /// 現在macOSで有効化されており、選択可能な入力ソースの一覧
    @Published public private(set) var enabledSources: [InputSourceItem] = []

    /// macOSにインストールされているすべてのキーボード入力ソース（追加画面用）
    @Published public private(set) var installableSources: [InputSourceItem] = []

    /// 現在アクティブな入力ソース
    @Published public private(set) var currentSource: InputSourceItem?

    /// 直近の切り替えイベント通知用コールバック (切り替えられた側, 切り替え先のInputSourceItem)
    public var onInputSourceSwitched: ((CommandKeySide, InputSourceItem) -> Void)?

    private var notificationObservers: [NSObjectProtocol] = []
    private var retryWorkItem: DispatchWorkItem?
    private var selectGeneration: UInt64 = 0
    private var metadataCache: [String: InputSourceItem] = [:]

    private init() {
        refreshInputSources()
        setupNotifications()
    }

    /// 終了時にリトライ予約および分散通知オブザーバを解放する
    public func shutdown() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        for observer in notificationObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    /// システムの入力ソース一覧および現在の入力ソースを再取得する
    public func refreshInputSources() {
        metadataCache.removeAll()
        self.enabledSources = fetchInputSources(includeAllInstalled: false)
        self.currentSource = fetchCurrentInputSource()
        if !self.installableSources.isEmpty {
            self.installableSources = fetchInputSources(includeAllInstalled: true)
        }
        AppSettings.shared.applySmartDefaultsIfNeeded(availableSources: self.enabledSources)
    }

    /// システムにインストールされている全言語一覧を読み込む（言語追加画面表示時用）
    public func loadInstallableSources() {
        self.enabledSources = fetchInputSources(includeAllInstalled: false)
        self.installableSources = fetchInputSources(includeAllInstalled: true)
    }

    /// 指定したIDの入力ソースを安全に削除（無効化）可能かどうかを判定する純粋ロジック
    public static func canDisable(sourceID: String, in enabledSources: [InputSourceItem]) -> Bool {
        guard enabledSources.count > 1,
              let target = enabledSources.first(where: { $0.id == sourceID }) else {
            return false
        }
        if target.isASCIICapable {
            return enabledSources.filter(\.isASCIICapable).count > 1
        }
        return true
    }

    /// 現在有効なシステム入力ソースのうち、指定したIDを安全に削除（無効化）可能か
    public func canDisableInputSource(withID sourceID: String) -> Bool {
        Self.canDisable(sourceID: sourceID, in: enabledSources)
    }

    /// 指定したIDの入力ソースへ切り替える
    /// - Parameters:
    ///   - sourceID: 切り替え先の `InputSourceItem.id`
    ///   - side: トリガーとなったCommandキー（左 or 右）
    /// - Returns: 切り替えに成功した場合はその `InputSourceItem`
    @discardableResult
    public func selectInputSource(withID sourceID: String, triggeredBy side: CommandKeySide? = nil) -> InputSourceItem? {
        guard !sourceID.isEmpty, sourceID != InputSourceItem.disabledID else {
            return nil
        }

        retryWorkItem?.cancel()
        retryWorkItem = nil
        selectGeneration &+= 1
        let generation = selectGeneration

        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: sourceID,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString
        ]

        if let unmanagedList = TISCreateInputSourceList(filter as CFDictionary, false),
           let sources = unmanagedList.takeRetainedValue() as? [TISInputSource],
           let targetSource = sources.first {
            let sourceType = getStringProperty(from: targetSource, key: kTISPropertyInputSourceType) ?? ""
            guard isActuallyEnabled(targetSource, sourceType: sourceType, parentStatus: parentMethodBundleStatus()) else {
                return nil
            }
            return performSelect(targetSource, expectedID: sourceID, triggeredBy: side, generation: generation)
        }

        return nil
    }

    /// インストール済みの入力ソースをmacOS上で有効化する
    @discardableResult
    public func enableInputSource(withID sourceID: String) -> Bool {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: sourceID,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first else {
            return false
        }

        var enabledPreviouslyDisabledParent = false
        var enabledParentSource: TISInputSource?
        var targetBundleID: String?

        // InputMode は親の InputMethodModeEnabled を先に有効化しないとシステム設定上に現れず孤立状態になる
        if getStringProperty(from: source, key: kTISPropertyInputSourceType) == (kTISTypeKeyboardInputMode as String),
           let bundleID = getStringProperty(from: source, key: kTISPropertyBundleID) {
            targetBundleID = bundleID
            let parentFilter: [CFString: Any] = [
                kTISPropertyBundleID: bundleID,
                kTISPropertyInputSourceType: kTISTypeKeyboardInputMethodModeEnabled as CFString
            ]
            if let parentList = TISCreateInputSourceList(parentFilter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource],
               let parentSource = parentList.first,
               getBoolProperty(from: parentSource, key: kTISPropertyInputSourceIsEnabled) != true {
                let parentStatus = TISEnableInputSource(parentSource)
                guard parentStatus == noErr else {
                    return false
                }
                enabledPreviouslyDisabledParent = true
                enabledParentSource = parentSource
            }
        }

        let status = TISEnableInputSource(source)
        if status == noErr && enabledPreviouslyDisabledParent, let bundleID = targetBundleID {
            // 無効状態だった親IMEを有効化した際に既定で有効化されている未選択兄弟モードを明示的に無効化する
            let siblingFilter: [CFString: Any] = [
                kTISPropertyBundleID: bundleID,
                kTISPropertyInputSourceType: kTISTypeKeyboardInputMode as CFString
            ]
            let siblingModes = (TISCreateInputSourceList(siblingFilter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
            for sibling in siblingModes {
                guard let siblingID = getStringProperty(from: sibling, key: kTISPropertyInputSourceID),
                      siblingID != sourceID,
                      getBoolProperty(from: sibling, key: kTISPropertyInputSourceIsEnabled) == true else {
                    continue
                }
                _ = TISDisableInputSource(sibling)
            }
        } else if status != noErr && enabledPreviouslyDisabledParent, let parentSource = enabledParentSource {
            _ = TISDisableInputSource(parentSource)
        }

        refreshInputSources()
        loadInstallableSources()
        return status == noErr
    }

    /// 有効な入力ソースをmacOSから安全に削除（無効化）する（最後の1件／最後のASCIIソース保護付き）
    @discardableResult
    public func disableInputSource(withID sourceID: String) -> Bool {
        guard canDisableInputSource(withID: sourceID) else {
            return false
        }

        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: sourceID,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first else {
            return false
        }

        // 現在選択中の入力ソースを削除する場合は、先に安全な別の有効ソースへ切り替える
        if fetchCurrentInputSource()?.id == sourceID,
           let fallback = enabledSources.first(where: { $0.id != sourceID && $0.isASCIICapable })
               ?? enabledSources.first(where: { $0.id != sourceID }) {
            selectInputSource(withID: fallback.id, triggeredBy: nil)
        }

        let sourceType = getStringProperty(from: source, key: kTISPropertyInputSourceType) ?? ""
        let succeeded: Bool

        if sourceType == (kTISTypeKeyboardInputMode as String),
           let bundleID = getStringProperty(from: source, key: kTISPropertyBundleID) {
            let siblingFilter: [CFString: Any] = [
                kTISPropertyBundleID: bundleID,
                kTISPropertyInputSourceType: kTISTypeKeyboardInputMode as CFString
            ]
            let enabledIDs = Set(enabledSources.map(\.id))
            let siblingModes = (TISCreateInputSourceList(siblingFilter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
            let hasOtherActiveSibling = siblingModes.contains { mode in
                guard let modeID = getStringProperty(from: mode, key: kTISPropertyInputSourceID) else { return false }
                return modeID != sourceID && enabledIDs.contains(modeID)
            }

            if !hasOtherActiveSibling {
                let preChildStatus = TISDisableInputSource(source)
                let parentFilter: [CFString: Any] = [
                    kTISPropertyBundleID: bundleID,
                    kTISPropertyInputSourceType: kTISTypeKeyboardInputMethodModeEnabled as CFString
                ]
                if let parentList = TISCreateInputSourceList(parentFilter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource],
                   let parentSource = parentList.first {
                    let parentStatus = TISDisableInputSource(parentSource)
                    if preChildStatus != noErr {
                        let _ = TISDisableInputSource(source)
                    }
                    succeeded = (parentStatus == noErr)
                } else {
                    succeeded = (preChildStatus == noErr)
                }
            } else {
                let childStatus = TISDisableInputSource(source)
                succeeded = (childStatus == noErr)
            }
        } else {
            let status = TISDisableInputSource(source)
            succeeded = (status == noErr)
        }

        if succeeded {
            if AppSettings.shared.leftCommandSourceID == sourceID {
                AppSettings.shared.leftCommandSourceID = InputSourceItem.disabledID
            }
            if AppSettings.shared.rightCommandSourceID == sourceID {
                AppSettings.shared.rightCommandSourceID = InputSourceItem.disabledID
            }
        }

        refreshInputSources()
        loadInstallableSources()
        return succeeded
    }

    /// IDから対応する `InputSourceItem` を取得する
    public func item(forID sourceID: String) -> InputSourceItem? {
        if sourceID == InputSourceItem.disabledID {
            return .disabledItem
        }
        if let found = enabledSources.first(where: { $0.id == sourceID })
            ?? installableSources.first(where: { $0.id == sourceID })
            ?? metadataCache[sourceID] {
            return found
        }
        guard !sourceID.isEmpty else { return nil }

        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: sourceID,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource],
              let rawSource = list.first,
              let resolved = makeInputSourceItem(from: rawSource) else {
            return nil
        }

        let unavailableItem = InputSourceItem(
            id: resolved.id,
            localizedName: resolved.localizedName,
            sourceType: resolved.sourceType,
            languages: resolved.languages,
            isEnabled: false,
            isASCIICapable: resolved.isASCIICapable
        )
        metadataCache[sourceID] = unavailableItem
        return unavailableItem
    }

    /// macOSの「システム設定 > キーボード > 入力ソース」画面を開く
    public func openSystemKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Helpers

    private func performSelect(
        _ targetSource: TISInputSource,
        expectedID sourceID: String,
        triggeredBy side: CommandKeySide?,
        generation: UInt64
    ) -> InputSourceItem? {
        let status = TISSelectInputSource(targetSource)
        guard status == noErr else {
            return nil
        }

        let resolvedItem = enabledSources.first(where: { $0.id == sourceID })
            ?? makeInputSourceItem(from: targetSource)

        // CJKV InputMode 等は単発の TISSelectInputSource 後に即座に反映されない場合があるため実状態を検証する
        if let actual = fetchCurrentInputSource(), actual.id == sourceID {
            self.currentSource = resolvedItem ?? actual
            if let side = side, let item = self.currentSource {
                onInputSourceSwitched?(side, item)
            }
            return self.currentSource
        }

        let retry = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self, self.selectGeneration == generation else { return }
                let retryFilter: [CFString: Any] = [
                    kTISPropertyInputSourceID: sourceID,
                    kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString
                ]
                if let retryList = TISCreateInputSourceList(retryFilter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
                   let retryTarget = retryList.first {
                    _ = TISSelectInputSource(retryTarget)
                }
                let confirmed = self.fetchCurrentInputSource()
                self.currentSource = confirmed
                if let side = side, let item = confirmed, item.id == sourceID {
                    self.onInputSourceSwitched?(side, item)
                } else if let side = side, let fallback = resolvedItem, confirmed == nil {
                    self.currentSource = fallback
                    self.onInputSourceSwitched?(side, fallback)
                }
            }
        }
        retryWorkItem = retry
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Timing.cjkvRetryDelaySeconds,
            execute: retry
        )
        return resolvedItem
    }

    private func fetchCurrentInputSource() -> InputSourceItem? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return makeInputSourceItem(from: current)
    }

    /// 各IMEバンドル親 (TISTypeKeyboardInputMethodModeEnabled) の存在および有効状態を取得する
    private func parentMethodBundleStatus() -> (known: Set<String>, enabled: Set<String>) {
        let parentFilter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString,
            kTISPropertyInputSourceType: kTISTypeKeyboardInputMethodModeEnabled as CFString
        ]
        guard let list = TISCreateInputSourceList(parentFilter as CFDictionary, true)?.takeRetainedValue() as? [TISInputSource] else {
            return ([], [])
        }
        var known = Set<String>()
        var enabled = Set<String>()
        for parent in list {
            if let bundleID = getStringProperty(from: parent, key: kTISPropertyBundleID) {
                known.insert(bundleID)
                if getBoolProperty(from: parent, key: kTISPropertyInputSourceIsEnabled) == true {
                    enabled.insert(bundleID)
                }
            }
        }
        return (known, enabled)
    }

    /// 親IME状態も含めて入力ソースが真に有効化されているかを判定する
    private func isActuallyEnabled(
        _ source: TISInputSource,
        sourceType: String,
        parentStatus: (known: Set<String>, enabled: Set<String>)
    ) -> Bool {
        guard getBoolProperty(from: source, key: kTISPropertyInputSourceIsEnabled) == true else {
            return false
        }
        if sourceType == (kTISTypeKeyboardInputMode as String),
           let bundleID = getStringProperty(from: source, key: kTISPropertyBundleID),
           parentStatus.known.contains(bundleID) {
            return parentStatus.enabled.contains(bundleID)
        }
        return true
    }

    private func fetchInputSources(includeAllInstalled: Bool) -> [InputSourceItem] {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as CFString,
            kTISPropertyInputSourceIsSelectCapable: true
        ]

        guard let unmanagedList = TISCreateInputSourceList(filter as CFDictionary, includeAllInstalled),
              let rawSources = unmanagedList.takeRetainedValue() as? [TISInputSource] else {
            return []
        }

        // HIToolbox は includeAllInstalled: true 呼び出し後に同一プロセス内の includeAllInstalled: false 結果へも
        // 未有効IME配下の既定InputModeを混ぜて返すため、親IME有効状態との照合で必ず除外する
        let parentStatus = parentMethodBundleStatus()

        var seenIDs = Set<String>()
        var result: [InputSourceItem] = []

        for source in rawSources {
            guard let item = makeInputSourceItem(from: source, parentStatus: parentStatus) else {
                continue
            }
            // パレット系（絵文字・記号ビューア等）や親コンテナのみのものは除外し、キーボード入力可能なものだけを対象にする
            guard item.sourceType == (kTISTypeKeyboardLayout as String) ||
                  item.sourceType == (kTISTypeKeyboardInputMode as String) ||
                  item.sourceType == (kTISTypeKeyboardInputMethodWithoutModes as String) else {
                continue
            }
            if !includeAllInstalled && !item.isEnabled {
                continue
            }
            if !seenIDs.contains(item.id) {
                seenIDs.insert(item.id)
                result.append(item)
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled {
                return lhs.isEnabled && !rhs.isEnabled
            }
            return lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
        }
    }

    private func makeInputSourceItem(
        from source: TISInputSource,
        parentStatus: (known: Set<String>, enabled: Set<String>)? = nil
    ) -> InputSourceItem? {
        guard let id = getStringProperty(from: source, key: kTISPropertyInputSourceID),
              let localizedName = getStringProperty(from: source, key: kTISPropertyLocalizedName) else {
            return nil
        }
        let sourceType = getStringProperty(from: source, key: kTISPropertyInputSourceType) ?? ""
        let languages = getStringArrayProperty(from: source, key: kTISPropertyInputSourceLanguages)
        let isASCIICapable = getBoolProperty(from: source, key: kTISPropertyInputSourceIsASCIICapable) ?? false
        let isEnabled: Bool
        if let parentStatus = parentStatus {
            isEnabled = isActuallyEnabled(source, sourceType: sourceType, parentStatus: parentStatus)
        } else {
            isEnabled = getBoolProperty(from: source, key: kTISPropertyInputSourceIsEnabled) ?? true
        }

        return InputSourceItem(
            id: id,
            localizedName: localizedName,
            sourceType: sourceType,
            languages: languages,
            isEnabled: isEnabled,
            isASCIICapable: isASCIICapable
        )
    }

    private func getStringProperty(from source: TISInputSource, key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        let cfValue = Unmanaged<CFTypeRef>.fromOpaque(ptr).takeUnretainedValue()
        guard CFGetTypeID(cfValue) == CFStringGetTypeID(),
              let str = cfValue as? String else {
            return nil
        }
        return str
    }

    private func getStringArrayProperty(from source: TISInputSource, key: CFString) -> [String] {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return [] }
        let cfValue = Unmanaged<CFTypeRef>.fromOpaque(ptr).takeUnretainedValue()
        guard CFGetTypeID(cfValue) == CFArrayGetTypeID(),
              let array = cfValue as? [String] else {
            return []
        }
        return array
    }

    private func getBoolProperty(from source: TISInputSource, key: CFString) -> Bool? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        let cfValue = Unmanaged<CFTypeRef>.fromOpaque(ptr).takeUnretainedValue()
        guard CFGetTypeID(cfValue) == CFBooleanGetTypeID(),
              let boolVal = cfValue as? Bool else {
            return nil
        }
        return boolVal
    }

    private func setupNotifications() {
        let dnc = DistributedNotificationCenter.default()

        let enabledChangedObserver = dnc.addObserver(
            forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshInputSources()
            }
        }

        let selectedChangedObserver = dnc.addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.currentSource = self?.fetchCurrentInputSource()
            }
        }

        notificationObservers = [enabledChangedObserver, selectedChangedObserver]
    }
}
