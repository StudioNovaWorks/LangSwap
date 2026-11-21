# 静的コードレビュー報告書 — LangSwap (旧称 LangChanger) for Mac US Keyboard

本レポートは、開発初期の静的コードレビュー結果（`v1.1.0` 開発時点）および修正実績と、正式名称 **LangSwap (`v1.0.0`)** としてのリリース前最終コードレビュー結果をまとめたドキュメントです。

---

## 0.1 リリース前最終レビュー・公開対応サマリー（`LangSwap v1.0.0` / 2026-11-21 対応済み）

UI 刷新（コンパクト 2 ペイン `720 × 590`・18 言語化・`AppIcon.icns` 統合・外観切替の AppKit 統一）および `LangSwap` (`v1.0.0`) リネーム後に最終レビューを実施し、以下をすべて反映・検証済みです。

| ID | 区分 | 概要 | 対応内容・修正ファイル |
| --- | --- | --- | --- |
| **P1-1** | Warning | `launchAtLogin`（`SMAppService.mainApp.status`）の起動後 OS 側変更との非同期 | `AppSettings.refreshLaunchAtLoginStatus()` を追加し、`didBecomeActiveNotification` および `openSettingsWindow` 時に自動再同期（`AppSettings.swift`, `LangChangerApp.swift`） |
| **P1-2** | Info | プリセット名入力フォーム廃止後のプリセット表示名と UI 言語切替時の表記追従 | `InputSourcePickerHelper.presetDisplayName(for:manager:lang:)` で現在の UI 言語に基づき動的構築（未検出時は保存名フォールバック）（`SettingsSharedComponents.swift`, `PresetsLanguagesTabView.swift`, `MenuBarView.swift`, `KeyMappingTabView.swift`） |
| **P1-3** | Info | UI 簡素化で未使用となった `L10nKey` 4 件・`AppTheme.colorScheme` の整理 | `permAllowBtn`, `monitoringFallback`, `presetPlaceholder`, `btnSave`（全 18 言語 72 エントリ）および `AppTheme.colorScheme` を削除（`AppLocalization.swift`, `Localizations/*.swift`） |
| **REL-1** | Release | `Info.plist` 公開メタデータ整備 & バージョン `1.0.0` (`Build 1`) 化 | `CFBundleShortVersionString = 1.0.0`, `CFBundleVersion = 1`, `CFBundleDevelopmentRegion = en`, `LSApplicationCategoryType = public.app-category.utilities` を設定（`Info.plist`, `AppConstants.swift`, `GuideTabView.swift`） |
| **REL-2** | Release | Universal Binary (`arm64` + `x86_64`) ビルド・シンボル整理・厳格検証対応 | `build_app.sh` を Universal Binary ビルド＋`lipo -info` 確認＋`strip -x`＋`codesign --verify --deep --strict` 対応へ刷新 |
| **REL-3** | Release | 配布用 DMG パッケージャ作成 & Gatekeeper 初回起動手順整備 | `scripts/package_dmg.sh` を新設し、`LangSwap.app` ＋ `/Applications` シンボリックリンク構成の `dist/LangSwap-v1.0.0.dmg` を生成。`README.md` / `docs/ARCHITECTURE.md` を完全同期 |
| **HOTFIX-1** | Critical | `.listenOnly` タップが入力監視 (`kTCCServiceListenEvent`) ブロック時に他アプリ監視のみ無言失敗する現象 | `setupCGEventTap()` を `.defaultTap` 優先（`CGPreflightListenEventAccess()` 真の時のみ `.listenOnly` フォールバック）へ暫定変更し、UI・メニューバーと連動（※その後 **POLISH-1** にて最小権限方針として `.listenOnly` + 事前 `CGPreflightListenEventAccess()` ガードへ一本化） |
| **HOTFIX-2** | Bug | `CFBundleDevelopmentRegion = en` 変更後に Carbon TIS 名が英語 (`Hiragana`) になる問題 | `Info.plist` に `CFBundleLocalizations`（18 言語コード）を追加し、「ひらがな（日本語）」等への OS ネイティブローカライズを復元（`Info.plist`） |
| **HOTFIX-3** | UI | 設定ウインドウ最下部の ~28pt 白帯（`NSHostingController` による `.fullSizeContentView` 領域拡張とサイズ固定のズレ） | `hostingController.sizingOptions = []` ＋ `window.setContentSize(720 × 590)` と `SettingsView` の全方向 `.frame(maxWidth: .infinity, maxHeight: .infinity)` + `.ignoresSafeArea(.all, edges: .top)` により下部余白を解消（`LangChangerApp.swift`, `SettingsView.swift`） |
| **POLISH-1** | Security | 最小権限原則に基づく権限の「入力監視 (`kTCCServiceListenEvent`) のみ」統一 | `AXIsProcessTrustedWithOptions` / `.defaultTap` / `ApplicationServices` を撤廃し、`CGPreflightListenEventAccess()` 事前ガード付きの `.listenOnly` タップへ統一。全 18 言語の文言も入力監視ベース・平易な表現へ刷新（`Package.swift`, `AccessibilityService.swift`, `CommandKeyEventMonitor.swift`, `Localizations/*.swift`） |
| **POLISH-2** | UI/UX | ライトモード時のメニューバーアイコン黒潰れ、ロケール初回デフォルト、ヘッダー配置およびガイド充実 | `NSApp.appearance` / `NSStatusBarWindow` をシステム自動追従のまま維持しつつ白線 `command` アイコンへ変更。`Locale.preferredLanguages` 連動の初回キー割り当て（初期プリセット空）、ヘッダー「起動中」トグル右寄せ固定、動作設定の常時権限設定ボタン追加、使い方タブ順刷新＋「よくあるトラブル」4 項目追加（`LangChangerApp.swift`, `AppSettings.swift`, `SettingsView.swift`, `BehaviorTabView.swift`, `GuideTabView.swift`, `AppLocalization.swift`, `Localizations/*.swift`） |
| **DOC-1** | Docs | GitHub Pages 用プライバシーポリシー新設＆ドキュメント最新化 | 18 言語・ライト/ダーク対応の [docs/LangSwap_PrivacyPolicy.html](LangSwap_PrivacyPolicy.html) を新設し、`README.md` / `docs/ARCHITECTURE.md` / `docs/CODE_REVIEW.md` を最新実装・構成と完全同期 |
| **POLISH-3** | UI/UX | 「使い方」タブ概要（Apple Silicon 表記＋プライバシーポリシーリンク）および「基本的な使い方（4項目）」「よくあるトラブル（6項目）」改訂 | 起動前事象・他社製品名の排除、日本語文言調整、Apple Silicon Mac 明記、プライバシーポリシー URL（`?lang=` 連動）を概要カード下部に統合、全 18 言語（97 キー）を更新（`AppLocalization.swift`, `GuideTabView.swift`, `Localizations/*.swift`, `SelfTestRunner.swift`） |
| **DMG-1** | Packaging | スプリット・シグネチャー Retina DMG 背景＆Finder レイアウト自動化・ボリュームアイコン統合 | [scripts/generate_dmg_background.swift](../scripts/generate_dmg_background.swift)（12° 斜め分割・A-1 ベクター矢印・12.5pt 均等サイズ日英ガイド「Applications へドラッグ / から起動」の `600×400pt` `@1x/@2x` TIFF）と [scripts/package_dmg.sh](../scripts/package_dmg.sh)（HFS+ ステージング・Finder `osascript` レイアウト・`.VolumeIcon.icns` / `SetFile -a C`）を実装 |
| **REL-1** | Release | GitHub Releases 初回公開前レビュー（`#1`〜`#12`）一括反映 | `.gitignore`・MIT [LICENSE](../LICENSE) 追加、DMG アイコン Y 座標 (`114`)・`.openSettings`「…」削除、`MenuBarView` `⌘,` / `⌘Q` 表記削除＆プリセットスクロール、単一インスタンス起動・PID 待機型安全再起動・イベント監視統合デバウンス・世代ガード・ログイン項目承認/エラーヒント・RTL ヘッダー余白修正・HUD 再計測、`Sources/LangSwap` & `InputMonitoringService` リネーム、Swift 6 `-warn-concurrency` 警告ゼロ達成、`build_app.sh` Apple Silicon (`arm64`) 既定化、プライバシーポリシー全 18 言語外部リンク記述更新（全 100 キー・セルフテスト 44 項目同期） |
| **TIS-1** | Bugfix | Carbon TIS 入力ソース追加済み表示の乖離・親 IME 未有効化バグ修正 | `InputSourceManager.swift` にて全インストール済み一覧 (`includeAllInstalled: true`) の `isEnabled` 判定を実有効一覧 (`includeAllInstalled: false`) との照合に修正し、未有効 IME 配下 `InputMode` の誤「追加済み」表示を解消。また `enableInputSource` で親 `kTISTypeKeyboardInputMethodModeEnabled` を先行有効化し、`SelfTestRunner` / `CommandKeyLogicTests` へ照合一致テストを追加（45 項目） |
| **TIS-2** | Bugfix | HIToolbox インプロセスキャッシュ汚染による「言語設定」タブ開覧後の再汚染バグ修正 | `TISCreateInputSourceList(..., true)` を 1 度呼ぶと同一プロセス内の以降の小呼び出し (`false`) でも未有効 IME 配下モードが混入する macOS HIToolbox 仕様への対策として、`parentMethodBundleStatus()`（親 `TISTypeKeyboardInputMethodModeEnabled` 有効集合）を全取得・切替経路で直接照合するよう改修。汚染後再取得テストを含む 46 項目のセルフテストおよび XCTest を追加 |
| **TIS-3** | Feature | 「言語設定」タブへ macOS 入力ソースの安全削除（ゴミ箱アイコン）機能を追加（案A） | `InputSourceManager.disableInputSource(withID:)` および保護ガード `canDisable(sourceID:in:)` を実装し、最後の 1 件・唯一の `isASCIICapable` 入力ソース保護、アクティブソース退避、他に有効モードがない親 `TISTypeKeyboardInputMethodModeEnabled` 連動無効化、左右 Command 割り当てクリーンアップに対応。[PresetsLanguagesTabView.swift](../Sources/LangSwap/Views/Settings/PresetsLanguagesTabView.swift) へゴミ箱ボタン・全 18 言語ツールチップ（計 102 キー）を追加し、`SelfTestRunner` / `CommandKeyLogicTests` を 47 項目へ拡張 |
| **REL-2** | Release | 外部 2 モデル最終監査の全 15 指摘（Review 1 `#1`〜`#5` / Review 2 `#1`〜`#10`）を漏れなく反映 | **低レイヤー・監視**: `handleEnvironmentChange()` の世代番号 (`monitoringRestartGeneration`) 重複回避と停止状態復帰（R1-#1）、`left/right/otherMouseUp` 監視追加によるドラッグ＆ドロップ抑止（R1-#2）、`.tapDisabledBy*` の非同期 MainQueue 復旧＆5秒3回超過時 `NSEvent` フォールバック降格（R2-#8）、`InputMonitoringService.isTrusted` 変化時のみ `@Published` 更新（R2-#7）。**TIS・入力ソース**: 無効親 IME 初回有効化時の未選択兄弟 `InputMode` 連動無効化＆削除時 `parentStatus == noErr` 検証（R2-#1）、`item(forID:)` のターゲット取得＋`metadataCache` 補完および UI 全体の `.badgeUnavailable`（「未追加」）警告表示（R2-#4）、`FullWidthRoman` の半角 EN 除外（R2-#10）。**UI/UX・18 言語**: ポップオーバー `NSHostingController.sizingOptions = [.preferredContentSize]` 化（R1-#3）、日本語 `.themeSystem` 短縮（`"システム"`）＆ `BehaviorTabView` セグメント幅緩和・`MenuBarView` 2 行バナー・`KeyMappingTabView` 柔軟ラベル幅（R2-#2）、`compactKeyPreviewBar` LTR 固定（R2-#3）、`disabledItem` 英語フォールバック化（R1-#4）、`es` *tú* / `"Desact."`・`ar` RTL 方向・`pt_BR`・`vi` 表記統一（R2-#9）、多重起動時 `DistributedNotificationCenter` で設定ウインドウ再表示（R2-#10）。**ビルド・テスト・スクリプト**: `Developer ID Application:` SHA-1 限定＆`--timestamp` 署名（R2-#5）、`--no-finder-layout` と `osascript` エラーガイド追加（R1-#5）、`--universal` 既存バイナリアーキ検証＆`$PROJECT_ROOT/Info.plist` mtime 比較（R2-#6, R2-#10）、`AppSettings` `loginItemStatusProvider` DI 対応（R2-#10）。全 18 言語 103 キー・セルフテスト 56 項目へ拡充 |

> **最新検証実績**: Debug・DMG マウント版（`arm64`）にてセルフテスト **56 passed, 0 failed**（`FullWidthRoman`・未追加ソース補助表示・決定論的ログイン項目・キャッシュ汚染耐性・入力ソース安全削除保護含む）、Swift 6 `-warn-concurrency` **警告ゼロ**、全 18 言語 AppKit 幅計測（見切れ 0 件）、`lipo -info` (`arm64`)、`codesign --verify --deep --strict`、`hdiutil verify` (`VALID`)、DMG `.DS_Store`・`.background/dmg_background.tiff`（mtime 不変保持）・`.VolumeIcon.icns` (`GetFileInfo -ac = 1`) すべて合格。

---

## 0. 初回レビュー修正対応完了サマリー（2026-11-21 対応済み）

指摘事項 **全16件（Critical 3件 / Warning 8件 / Info・Refactor 5件）すべてについて修正を実装し、セルフテスト全32項目合格・Releaseビルド完了を確認済みです。**

| ID | 重要度 | 概要 | 対応ステータス | 主な修正ファイル |
| --- | --- | --- | --- | --- |
| **C-1** | Critical | `CFMachPortInvalidate` / `CFRunLoopSourceInvalidate`、`private init()`、`deinit`、安全なメインディスパッチ | ✅ 修正完了 | `CommandKeyEventMonitor.swift` |
| **C-2** | Critical | 実行中の権限剥奪フォールバック降格、スリープ復帰／画面ロック解除追従、タップ再有効化確認 | ✅ 修正完了 | `CommandKeyEventMonitor.swift`, `AccessibilityService.swift` |
| **C-3** | Critical | CJKV `InputMode` の切り替え後実状態検証＆20msリトライ、`TISEnableInputSource` 成否確認 | ✅ 修正完了 | `InputSourceManager.swift` |
| **W-1** | Warning | `Fn / Globe` (`.maskSecondaryFn` / `.function`) 除外判定追加、マウスドラッグ監視追加 | ✅ 修正完了 | `CommandKeyTapDetector.swift`, `CommandKeyEventMonitor.swift` |
| **W-2** | Warning | `NSEvent` フォールバックの同期メインスレッド処理化（順序逆転防止） | ✅ 修正完了 | `CommandKeyEventMonitor.swift` |
| **W-3** | Warning | 権限許可済み時の30秒省電力ポーリング（`tolerance` 付き）＋スリープ復帰時再確認 | ✅ 修正完了 | `AccessibilityService.swift` |
| **W-4** | Warning | Kotoeri / Google 日本語入力の `Roman` / `Alphanumeric` モードを `EN` として正しく分類 | ✅ 修正完了 | `InputSourceItem.swift` |
| **W-5** | Warning | `HUDViewModel` 再利用＋ `displayGeneration` 世代トークンによるフェード競合解消 | ✅ 修正完了 | `HUDNotificationWindow.swift` |
| **W-6** | Warning | `CFGetTypeID` 型検証追加、`InputSourceManager` / `AccessibilityService` の `deinit` 解放 | ✅ 修正完了 | `InputSourceManager.swift`, `AccessibilityService.swift` |
| **W-7** | Warning | `LazyVStack` で50件上限撤廃、初回プリセット名・ロケールの言語非依存化、`InputSourcePickerHelper` | ✅ 修正完了 | `PresetsLanguagesTabView.swift`, `AppSettings.swift`, `InputSourceItem.swift`, `SettingsSharedComponents.swift`, `MenuBarView.swift` |
| **W-8** | Warning | `.app` バンドル／非バンドル実行両対応の `relaunchApplication()` | ✅ 修正完了 | `LangChangerApp.swift` |
| **R-1** | Info/Refactor | `SettingsView`（8ファイル）および `AppLocalization`（4ファイル）のモジュール分割 | ✅ 修正完了 | `Views/Settings/*`, `Models/Localizations/*` |
| **R-2** | Info/Refactor | 未使用シンボル（`excludedBundleIDs` 等）削除、`NSMenu` / `toolTip` の18言語動的ローカライズ | ✅ 修正完了 | `AppSettings.swift`, `InputSourceItem.swift`, `CommandKeyTapDetector.swift`, `LangChangerApp.swift`, `AppLocalization.swift` |
| **R-3** | Info/Refactor | キーコード・タイミング・レイアウト値の `AppConstants` 集約 | ✅ 修正完了 | `Models/AppConstants.swift` |
| **R-4** | Info/Refactor | プレビューハイライトおよび切り替え遅延の `DispatchWorkItem` キャンセル管理 | ✅ 修正完了 | `SettingsModels.swift`, `CommandKeyEventMonitor.swift` |
| **R-5** | Info/Refactor | 証明書署名時の Hardened Runtime (`--options runtime`) 対応、境界値・`Fn`・`Roman` テスト拡充 | ✅ 修正完了 | `build_app.sh`, `SelfTestRunner.swift`, `CommandKeyLogicTests.swift` |

---

## 1. レビューサマリー・観点別チェック結果（初回監査時点）

| 重要度 | 件数 | 主な対象領域 |
| --- | ---: | --- |
| **[Critical]** | 3件 | `CGEventTap` ライフサイクル管理、権限剥奪／スリープ復帰時の復旧、CJKV IME 切り替え信頼性 |
| **[Warning]** | 8件 | 修飾キー漏れ（Fn/Globe）、`NSEvent` イベント順序逆転、タイマー省電力、Kotoeri英字モード誤判定、HUD競合、CF型安全性、50件表示制限、再起動パス |
| **[Info / Refactor]** | 5件 | Massive View / 巨大ファイルの分割、未使用コード・未ローカライズ箇所整理、マジックナンバー定数化、遅延タスクキャンセル、配布署名／テスト統合 |

### 観点別の現状評価

| 重点レビュー観点 | 現状の評価 | 主な検出ID |
| --- | --- | --- |
| **1. イベント監視の堅牢性・エッジケース** | タイムアウト自動再有効化（`tapDisabledByTimeout`）や `⌘+Shift` / 左右同時押し / マウスクリック抑止は実装済みだが、解放処理・スリープ復帰・Fnキー・権限剥奪検知に抜けがある | C-1, C-2, W-1, W-2 |
| **2. スレッド安全性とmacOS APIの制約** | Carbon TIS API・SwiftUI状態更新は `@MainActor` に集約され、`TISCreateInputSourceList` 等も `.takeRetainedValue()` で適切に所有権回収されている。一方、`CFGetTypeID` 検証や `TISSelectInputSource` 固有バグ対策が不足 | C-1, C-3, W-6 |
| **3. 権限・セキュリティ・エラーハンドリング** | `.listenOnly` タップ採用・ハードコードされたシークレットなし・`isRestorable = false` は良好。ただし実行中の権限剥奪へのフォールバック降格と、常時2秒タイマーの負荷改善が必要 | C-2, W-3, R-5 |
| **4. 汎用性（任意言語対応）** | TIS動的列挙により欧州言語等にも対応済みだが、`badgeCode` / `localizedLanguageLabel` がKotoeri/Google日本語入力の英字モード（Roman）を日本語と誤判定する | C-3, W-4, W-7 |
| **5. コード品質・リファクタリング** | `SettingsView.swift` (1,203行) と `AppLocalization.swift` (1,586行) の肥大化、未使用プロパティ（`excludedBundleIDs` UI未接続等）の整理余地あり | W-5, W-8, R-1〜R-4 |

### 現状の優れた設計ポイント
- `InputSourceManager`・`AccessibilityService`・`CommandKeyEventMonitor` が一貫して `@MainActor` に隔離されており、Swift Concurrency 環境下で Carbon HIToolbox API がバックグラウンドスレッドから呼ばれるリスクが抑制されている。
- `TISCreateInputSourceList` / `TISCopyCurrentKeyboardInputSource` の戻り値（Create/Copy Rule）がすべて `.takeRetainedValue()` で受け取られ、`TISGetInputSourceProperty`（Get Rule）が `.takeUnretainedValue()` で参照されており、基本的な CF メモリ所有権ルールに沿っている。
- `L10n.hasCompleteCoverage()` により18言語 × 全キーの翻訳網羅性がセルフテストで自動検証されている。

---

## 2. [Critical] 致命的な問題

### C-1: `CGEventTap` 停止時の `CFMachPortInvalidate` 未呼び出しと `Unmanaged.passUnretained(self)` による Use-After-Free リスク

- **該当箇所**:
  - `Sources/LangChanger/Services/CommandKeyEventMonitor.swift:L28, L69-L77, L109-L128, L251-L276`
- **問題の内容と発生条件**:
  1. `stopMonitoring()`（`L70-L77`）において、`CGEvent.tapEnable(tap: eventTap, enable: false)` と `CFRunLoopRemoveSource` のみを呼び出し、`CFMachPortInvalidate(eventTap)` および `CFRunLoopSourceInvalidate(runLoopSource)` を呼んでいません。Mach ポートが明示的に無効化されないため、監視の再起動を繰り返すとポート参照やカーネルリソースが解放されにくくなります。
  2. `CommandKeyEventMonitor.init()`（`L28`）が `public` であるにもかかわらず `deinit` で `stopMonitoring()` が呼ばれません。また、`setupCGEventTap()`（`L109`）で `Unmanaged.passUnretained(self).toOpaque()` をコールバックの `userInfo` に渡しているため、万一シングルトン以外のインスタンスが生成・破棄された後にコールバックが発火すると、ダングリングポインタ参照によりクラッシュ（EXC_BAD_ACCESS）します。
  3. `cgEventTapCallback`（`L264, L272`）は `MainActor.assumeIsolated` を前提としていますが、万一別スレッドまたは特殊な RunLoop コンテキストから呼ばれた場合、Swiftランタイムが即座にトラップ（クラッシュ）します。
- **具体的な修正方針**:
  - `init()` を `private` に制約し（単一インスタンス保証）、`deinit` でもポートを無効化する。
  - `stopMonitoring()` で `CFRunLoopSourceInvalidate` と `CFMachPortInvalidate` を必ず実行する。
  - `cgEventTapCallback` 内で `Thread.isMainThread` を確認し、メインスレッド以外なら `DispatchQueue.main.async` へ逃がす防御を入れる。

```swift
// CommandKeyEventMonitor.swift
private init() { /* ... */ }

deinit {
    if let runLoopSource = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CFRunLoopSourceInvalidate(runLoopSource)
    }
    if let eventTap = eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: false)
        CFMachPortInvalidate(eventTap)
    }
}

public func stopMonitoring() {
    if let eventTap = eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: false)
        CFMachPortInvalidate(eventTap)
    }
    if let runLoopSource = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CFRunLoopSourceInvalidate(runLoopSource)
    }
    eventTap = nil
    runLoopSource = nil
    // ...
}
```

---

### C-2: 実行中の権限剥奪およびスリープ復帰・画面ロック解除時のイベント監視サイレント停止／状態固着

- **該当箇所**:
  - `Sources/LangChanger/Services/CommandKeyEventMonitor.swift:L43-L50, L263-L270`
  - `Sources/LangChanger/Services/AccessibilityService.swift:L18-L45`
- **問題の内容と発生条件**:
  1. **実行中の権限剥奪**: `CommandKeyEventMonitor.init()` の `onStatusChecked`（`L43-L50`）は `trusted == true` の場合のみ `restartMonitoring()` を呼び、`trusted == false` に転じた場合を無視しています。アプリ稼働中にユーザーが「システム設定」でアクセシビリティ権限をオフにすると、OSによりイベントタップが無効化・遮断されても `isUsingCGEventTap` が `true` のまま残り、`NSEvent` フォールバックへの降格も行われません。
  2. **スリープ復帰・ロック解除・タイムアウト**: `NSWorkspace.didWakeNotification`、`NSWorkspace.screensDidWakeNotification`、および `DistributedNotificationCenter` の `"com.apple.screenIsUnlocked"` を監視していないため、スリープ復帰や画面ロック解除後に HID / セッションイベントタップの配送が停止したまま復帰しないケースや、`CommandKeyTapDetector` が `.pending` 状態のまま取り残されるケースがあります。
  3. **タイムアウト後の再有効化確認不足**: `.tapDisabledByTimeout` 受信時（`L263-L270`）に `CGEvent.tapEnable` を呼んでいますが、直前に押しっぱなしだった状態（`detector.reset()`）をクリアしておらず、また権限剥奪等で `CGEvent.tapIsEnabled(tap: tap)` が `false` のままでも再生成（`restartMonitoring()`）にフォールバックしません。
- **具体的な修正方針**:

```swift
// CommandKeyEventMonitor.swift
AccessibilityService.shared.onStatusChecked = { [weak self] trusted in
    Task { @MainActor in
        guard let self = self else { return }
        if trusted && (!self.isMonitoring || !self.isUsingCGEventTap) {
            self.restartMonitoring()
        } else if !trusted && self.isUsingCGEventTap {
            // 権限剥奪時は速やかにNSEventフォールバックへ降格し、ステートを初期化
            self.restartMonitoring()
        }
    }
}

// スリープ復帰・画面ロック解除時にタップを再構築 & detectorをリセット
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor in
        self?.detector.reset()
        self?.restartMonitoring()
    }
}
```
```swift
// cgEventTapCallback 内 (.tapDisabledByTimeout / .tapDisabledByUserInput)
if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    MainActor.assumeIsolated {
        monitor.detector.reset()
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            if !CGEvent.tapIsEnabled(tap: tap) {
                monitor.restartMonitoring()
            }
        }
    }
    return Unmanaged.passUnretained(event)
}
```

---

### C-3: `TISSelectInputSource` 単発呼び出しによる CJKV IME 切り替え失敗（macOS HIToolbox 既知制約）およびフォールバック時の不整合

- **該当箇所**:
  - `Sources/LangChanger/Services/InputSourceManager.swift:L47-L96`
- **問題の内容と発生条件**:
  1. macOS（特に Sonoma / Sequoia 以降の Electron アプリ、ターミナル、Spotlight、一部ブラウザ）では、英数レイアウト（`TISTypeKeyboardLayout`）から日本語・中国語・韓国語等の入力モード（`TISTypeKeyboardInputMode`：Kotoeri、Google日本語入力、中国語ピンイン等）へ `TISSelectInputSource` を1回呼び出した際、戻り値が `noErr` でも実際には入力モードが切り替わらない既知の TIS 同期遅延現象が発生します。
  2. 切り替え後の検証（`TISCopyCurrentKeyboardInputSource` が目的IDになったかの確認）が行われていないため、切り替え失敗時でも `self.currentSource` を目的言語で上書き（`L90`）し、HUD通知まで表示してしまいます（表示上は切り替わったように見えるが実際の入力が英語のままになる）。
  3. フォールバック経路（`L66-L77`）で `TISEnableInputSource(fallbackSource)` の戻り値（`OSStatus`）を検証せず、`enabledSources` の再取得（`refreshInputSources()`）も行われていません。
- **具体的な修正方針**:
  - `TISSelectInputSource` 実行後に現在の入力ソースを検証し、未切替かつ `InputMode` 系の場合は微小遅延（15〜20ms）後に1回だけリトライする。
  - `TISEnableInputSource` の `OSStatus == noErr` を確認し、成功時に `refreshInputSources()` を呼ぶ。
  - HUD表示は実際に切り替えが完了した `InputSourceItem` に基づいて発火する。

```swift
let status = TISSelectInputSource(targetSource)
guard status == noErr else { return nil }

// CJKV InputMode の切り替え漏れ対策: 実際の現在ソースを検証し、未反映なら1度リトライ
if fetchCurrentInputSource()?.id != sourceID {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
        guard let self = self else { return }
        TISSelectInputSource(targetSource)
        self.currentSource = self.fetchCurrentInputSource()
    }
}
```

---

## 3. [Warning] 誤作動・メモリ・パフォーマンス・汎用性の問題

### W-1: 修飾キー判定から `Fn / Globe` キーが欠落 & ドラッグ中の誤発動リスク

- **該当箇所**:
  - `Sources/LangChanger/Services/CommandKeyTapDetector.swift:L60, L130-L138`
  - `Sources/LangChanger/Services/CommandKeyEventMonitor.swift:L101-L107, L204`
- **問題の内容と発生条件**:
  - `CommandKeyTapDetector.handleFlagsChanged` のドキュメントコメント（`L60`）には「`Shift / Control / Option / Fn 等の他修飾キーが押されているか`」と記載されていますが、`hasOtherModifiers(in:)`（`L130-L138`）には `.maskSecondaryFn` が含まれておらず、`processNSEvent`（`L204`）にも `.function` が含まれていません。
  - そのため、`⌘ + Fn`（`🌐` キー併用ショートカット）を押した際に単押しと誤認して言語が切り替わります。
  - また、`CGEventTap` の監視マスク（`L101-L107`）に `leftMouseDragged` / `rightMouseDragged` がないため、マウスボタンを押したまま `⌘` を押してドラッグ範囲選択を解除し先にマウスを離す操作等で状態がずれる可能性があります。
- **具体的な修正方針**:

```swift
// CommandKeyTapDetector.swift
public static func hasOtherModifiers(in flags: CGEventFlags) -> Bool {
    let otherMask: CGEventFlags = [
        .maskShift,
        .maskControl,
        .maskAlternate,
        .maskSecondaryFn,
        .maskHelp
    ]
    return !flags.intersection(otherMask).isEmpty
}

// CommandKeyEventMonitor.swift (processNSEvent)
let hasOtherModifiers = !flags.intersection([.shift, .control, .option, .function, .help]).isEmpty
```

---

### W-2: `NSEvent` フォールバック監視における `Task { @MainActor in }` のイベント順序逆転リスク

- **該当箇所**:
  - `Sources/LangChanger/Services/CommandKeyEventMonitor.swift:L143-L155`
- **問題の内容と発生条件**:
  - `setupNSEventFallbackMonitors()` の `addGlobalMonitorForEvents` / `addLocalMonitorForEvents` 内で `Task { @MainActor in self?.processNSEvent(event) }` により非同期タスクを新規生成しています。
  - 素早い `⌘+C` 入力で `flagsChanged`（Command押下）→ `keyDown`（C）→ `flagsChanged`（Command離上）がミリ秒単位で連続した際、非構造化 `Task` のスケジューリング順序によっては処理順が保証されない／`localMonitor` でイベント処理が遅れる恐れがあります。
- **具体的な修正方針**:
  - AppKit のグローバル／ローカルイベントモニタはメインスレッド上で配信されるため、`MainActor.assumeIsolated`（または `Thread.isMainThread` 分岐）で同期的に処理します。

```swift
globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
    if Thread.isMainThread {
        MainActor.assumeIsolated { self?.processNSEvent(event) }
    } else {
        DispatchQueue.main.async { self?.processNSEvent(event) }
    }
}
```

---

### W-3: `AccessibilityService` の常時2秒タイマーポーリングによる不要なCPU Wakeup

- **該当箇所**:
  - `Sources/LangChanger/Services/AccessibilityService.swift:L55-L62`
- **問題の内容と発生条件**:
  - `startPolling()` が権限取得済み（`isTrusted == true`）になった後も、アプリ終了まで一生 **2.0秒ごと** に `tolerance` 未指定のタイマーで `AXIsProcessTrustedWithOptions` を呼び出し続けます。常駐ユーティリティとしてバッテリー駆動時の不要なCPUウェイクアップ（App Nap阻害）を招きます。
- **具体的な修正方針**:
  - 権限未取得時（`!isTrusted`）のみ2秒間隔でポーリングし、取得済みになったらタイマーを停止するか、権限剥奪検知用でも `30.0秒` 間隔＋ `timer.tolerance = 5.0` に抑えて、`didBecomeActiveNotification` / ワークスペース復帰時の即時確認と組み合わせます。

```swift
private func adjustPollingInterval(isTrusted: Bool) {
    pollTimer?.invalidate()
    let interval: TimeInterval = isTrusted ? 30.0 : 2.0
    let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.checkPermission(prompt: false)
        }
    }
    timer.tolerance = isTrusted ? 5.0 : 0.3
    pollTimer = timer
}
```

---

### W-4: Kotoeri・Google日本語入力などの「英字入力モード (Roman)」が `JA` / `日本語` と誤判定される問題

- **該当箇所**:
  - `Sources/LangChanger/Models/InputSourceItem.swift:L40-L47, L77-L85, L158-L163`
- **問題の内容と発生条件**:
  - `isJapaneseLike`（`L244`）では `!lowerID.contains("roman") && !lowerID.contains("alphanumeric")` をチェックしていますが、`localizedLanguageLabel`（`L42`）と `badgeCode`（`L77`）と `iconEmoji`（`L158`）にはその除外判定がありません。
  - macOSの「ことえり」英字モード（`com.apple.inputmethod.Kotoeri.RomajiTyping.Roman`）や Google日本語入力の英数モード（`com.google.inputmethod.Japanese.Roman`）は、`id` に `"Kotoeri"` / `"Japanese"` を含みつつ `languages` が `["en"]` または英字用になっているため、`badgeCode` が `"EN"` ではなく **`"JA"`**、`localizedLanguageLabel` が **`"日本語"`** と表示されてしまいます（例：`U.S.` ではなく日本語IME内の「英字」を左⌘に割り当てた場合に両方 `JA` 表示になる）。
- **具体的な修正方針**:

```swift
private var isJapaneseRomanOrAlphanumericMode: Bool {
    let lowerID = id.lowercased()
    return (lowerID.contains("kotoeri") || lowerID.contains("japanese")) &&
           (lowerID.contains("roman") || lowerID.contains("alphanumeric"))
}
```
`badgeCode` / `localizedLanguageLabel` / `iconEmoji` の冒頭で `if isJapaneseRomanOrAlphanumericMode { return "EN" /* / "英語" */ }` を優先判定させます。

---

### W-5: `HUDNotificationController` の連続切り替え時のフェードアウト競合バグ

- **該当箇所**:
  - `Sources/LangChanger/Views/HUDNotificationWindow.swift:L15-L82`
- **問題の内容と発生条件**:
  1. 左⌘ → 右⌘ を約0.9秒間隔（フェードアウト開始直後〜0.2秒アニメーション中）で素早く連打すると、古い `NSAnimationContext` の `completionHandler`（`L73-L77`）が後から発火し、新しく表示したばかりの `panel` を `panel.orderOut(nil)` で即座に消してしまいます。
  2. また、`show()` のたびに `NSHostingView` を新規生成（`L25`）して `panel.contentView` を差し替えています。
- **具体的な修正方針**:
  - `displayGeneration: UInt64`（世代トークン）を導入し、`completionHandler` 内で現在の世代トークンと一致する場合のみ `orderOut` を実行する。さらに `NSAnimationContext` の開始時に現在のアニメーションをリセットするか、状態保持用 `ObservableObject` を1つの `NSHostingView` で再利用する。

```swift
private var displayGeneration: UInt64 = 0

// show() 内
displayGeneration &+= 1
let currentGen = displayGeneration
// ...
NSAnimationContext.runAnimationGroup({ context in
    context.duration = 0.2
    panel.animator().alphaValue = 0.0
}, completionHandler: {
    Task { @MainActor in
        guard self?.displayGeneration == currentGen else { return }
        panel.orderOut(nil)
    }
})
```

---

### W-6: CoreFoundation ポインタの型未検証キャストとリソースライフサイクル不備

- **該当箇所**:
  - `Sources/LangChanger/Services/InputSourceManager.swift:L200-L215, L217-L241`
  - `Sources/LangChanger/Services/AccessibilityService.swift:L13-L30`
- **問題の内容と発生条件**:
  1. `InputSourceManager` の `getStringProperty` / `getStringArrayProperty` / `getBoolProperty`（`L200-L215`）は、`TISGetInputSourceProperty` が返す `UnsafeMutableRawPointer` の `CFTypeID` を確認せずに `Unmanaged<CFString>` / `Unmanaged<CFArray>` / `Unmanaged<CFBoolean>` として解釈しています。サードパーティ製IMEが特定キーに想定外のCF型（例：`CFNumber` 等）を返した場合、不正キャストや未定義動作の原因になります。
  2. `InputSourceManager`（`notificationObservers`）および `AccessibilityService`（`pollTimer`, `activeObserver`）の `init()` が `public` なのに `deinit` で `removeObserver` / `invalidate()` を行っていません。テストコード等から一時インスタンスを生成するとリークします。
- **具体的な修正方針**:

```swift
private func getStringProperty(from source: TISInputSource, key: CFString) -> String? {
    guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
    let cfVal = Unmanaged<CFTypeRef>.fromOpaque(ptr).takeUnretainedValue()
    guard CFGetTypeID(cfVal) == CFStringGetTypeID() else { return nil }
    return (cfVal as! CFString) as String
}
```
同様に `CFArrayGetTypeID()`・`CFBooleanGetTypeID()` のチェックを追加し、`InputSourceManager` / `AccessibilityService` の `init()` を `private` 化（または `deinit` 解放を追加）します。

---

### W-7: 入力ソース一覧の50件打ち切り・初回プリセット名の日本語固定・無効化済みソース残留時の表示不整合

- **該当箇所**:
  - `Sources/LangChanger/Views/SettingsView.swift:L86-L96, L847`
  - `Sources/LangChanger/Models/AppSettings.swift:L186-L188`
  - `Sources/LangChanger/Models/InputSourceItem.swift:L61-L64`
- **問題の内容と発生条件**:
  1. `SettingsView.swift:L847` で `ForEach(filteredInstallableSources.prefix(50))` としているため、検索語が空の状態ではシステム内の51件目以降の言語レイアウトが表示されません（検索すれば出るが一覧探索不可）。
  2. `AppSettings.swift:L186-L188` で初回プリセット生成時のデフォルト名に `"英語"` / `"日本語"` / `"デフォルト (左⌘ / 右⌘)"` が日本語ハードコードされており、英語や他言語環境のユーザーでも初回プリセット名だけ日本語になります。また `InputSourceItem.localizedLanguageLabel`（`L62`）も `Locale(identifier: "ja_JP")` 固定です。
  3. `SettingsView.swift:L86-L96` において、ユーザーが過去に割り当てた入力ソースをmacOSのシステム設定側から削除・無効化した場合、`sourceManager.item(forID:)` が `nil` となり、`?? sourceManager.enabledSources.first` にフォールバック表示される一方、実際の `settings.leftCommandSourceID` には古いIDが残り続け、`Picker` の選択項目とプレビュー表示が食い違います。
- **具体的な修正方針**:
  - `L847` は `LazyVStack` を用いて `.prefix(50)` 制限を撤廃する。
  - `applySmartDefaultsIfNeeded` では `appLanguage` に応じた名称、または `"EN ↔ JA"` のような言語非依存・ローカライズ済み名称を使用する。
  - `enabledSources` に存在しないIDが設定されていた場合は警告マーク表示または `refreshInputSources()` 後に有効なソースへ補正（あるいは無効時フォールバック選択）を行う。

---

### W-8: `AppDelegate.relaunchApplication()` の非バンドル実行時フォールバック不足

- **該当箇所**:
  - `Sources/LangChanger/LangChangerApp.swift:L239-L246`
- **問題の内容と発生条件**:
  - `relaunchApplication()` は `Bundle.main.bundlePath` に対して `/usr/bin/open -n` を実行しています。`dist/LangChanger.app` として起動している場合は正常に再起動しますが、`swift run` や `.build/debug/LangChanger` から直接バイナリを実行している開発中に「再起動」ボタンを押すと、`Bundle.main.bundlePath` がバイナリの親ディレクトリ（`.build/arm64-apple-macosx/debug`）になり、Finder でフォルダが開くだけでアプリが再起動しません。
- **具体的な修正方針**:

```swift
public static func relaunchApplication() {
    let bundlePath = Bundle.main.bundlePath
    let target = bundlePath.hasSuffix(".app")
        ? bundlePath
        : (Bundle.main.executablePath ?? bundlePath)

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    if bundlePath.hasSuffix(".app") {
        task.arguments = ["-c", "sleep 0.4 && /usr/bin/open -n \"$1\"", "_", target]
    } else {
        task.arguments = ["-c", "sleep 0.4 && \"$1\" &", "_", target]
    }
    try? task.run()
    NSApplication.shared.terminate(nil)
}
```

---

## 4. [Info / Refactor] 保守性・可読性・運用改善提案

### R-1: 巨大ファイルの責務分割（Massive View / 巨大ローカライズ定義）

- **該当箇所**:
  - `Sources/LangChanger/Views/SettingsView.swift`（1,203行）
  - `Sources/LangChanger/Models/AppLocalization.swift`（1,586行）
- **問題の内容**:
  - `SettingsView.swift` 内にサイドバー、権限バナー、4つのタブ画面、共通コンポーネント（`VisualEffectBackground`, `InsetGroupedCard`, `LangCodeBadge`）がすべて同居しています。
  - `AppLocalization.swift` は18言語 × 76キーの辞書リテラルを1ファイルに直書きしており、今後の文言追加時の差分確認・マージ競合が起きやすい構造です。
- **修正方針**:
  - `Views/Settings/` 配下に `SettingsSidebarView.swift`、`KeyMappingTabView.swift`、`PresetsLanguagesTabView.swift`、`BehaviorTabView.swift`、`GuideTabView.swift`、`SharedComponents.swift` へ分割する。
  - 翻訳データは `Resources/Locales/{lang}.json`（SwiftPM `resources: [.process("Resources")]`）へ外出しし、`AppLocalization.swift` はローダーと型定義（約180行）のみにする。

---

### R-2: 未使用コード・未接続機能・一部ハードコード英語文言の整理

- **該当箇所**:
  - `Sources/LangChanger/Models/AppSettings.swift:L64-L66, L274-L276`（`excludedBundleIDs`, `localized(_:)`）
  - `Sources/LangChanger/Models/InputSourceItem.swift:L143-L148, L151-L227`（`menuPickerTitle`, `iconEmoji`, `displayTitle`, `shortDisplayTitle`）
  - `Sources/LangChanger/Services/CommandKeyTapDetector.swift:L17-L22`（`CommandKeySide.displayName`）
  - `Sources/LangChanger/LangChangerApp.swift:L84-L122, L170-L176`（`setupMainMenu()`, `updateStatusButtonAppearance` の英語固定文字列）
- **問題の内容**:
  - `excludedBundleIDs` はロジック層（`InputSourceManager.isFrontmostAppExcluded()`）には実装されているものの、UI上に設定画面が存在しないためユーザーから設定不可能なデッド機能となっています。
  - `InputSourceItem.menuPickerTitle` や `AppSettings.localized(_:)`, `CommandKeySide.displayName` は参照箇所のない未使用シンボルです（`iconEmoji` / `displayTitle` は旧テスト互換用のみ）。
  - `AppDelegate` のメニューバー `toolTip` や `NSMenu`（`"Settings…"`, `"Quit LangChanger"`）は選択中の `AppLanguage` に連動していません。
- **修正方針**:
  - 除外アプリ設定UIを「起動と動作」タブへ追加するか、不要なら `excludedBundleIDs` を削除してコードベースを簡素化する。
  - `AppDelegate` のメニュータイトル・`toolTip` を `AppSettings.shared.$appLanguage` 購読で動的ローカライズし、未使用メソッドを削除する。

---

### R-3: マジックナンバーの定数化

- **該当箇所**:
  - `CommandKeyTapDetector.swift:L12-L13, L26-L27, L47` (`55`, `54`, `0.4`)
  - `CommandKeyEventMonitor.swift:L244` (`0.01` 秒)
  - `AppSettings.swift:L45, L107` (`150`, `1000`, `400`)
  - `AccessibilityService.swift:L57` (`2.0`)
  - `HUDNotificationWindow.swift:L60, L71, L81` (`90`, `0.2`, `0.85`)
  - `SettingsView.swift:L110, L119, L847, L1051-L1052` (`680`, `520`, `0.55`, `50`, `150...1000`, `25`)
- **修正方針**:
  - Carbon `HIToolbox` の `kVK_Command` (`0x37 = 55`) / `kVK_RightCommand` (`0x36 = 54`) を明示定数化し、タイミング値・ウィンドウ寸法を `Constants` 名前空間へ集約する。

---

### R-4: 連続押下時のハイライトタイマーおよび切り替え遅延タスクのキャンセル管理

- **該当箇所**:
  - `Sources/LangChanger/Views/SettingsView.swift:L114-L126`
  - `Sources/LangChanger/Services/CommandKeyEventMonitor.swift:L244-L246`
- **問題の内容**:
  - `SettingsView` の `DispatchQueue.main.asyncAfter(deadline: .now() + 0.55)` は直前の予約をキャンセルしないため、同サイドのキーを0.55秒以内に2回タップすると、1回目の消灯予約が2回目のハイライトを途中で消してしまいます。
  - `CommandKeyEventMonitor.triggerLanguageSwitch` の10ms遅延も未キャンセルの `asyncAfter` のため、途中で `settings.isEnabled = false` にされた場合や連打時に先発タスクを取り消せません。
- **具体的な修正方針**:
  - 両箇所とも `DispatchWorkItem`（または `Task<Void, Never>` の `.cancel()`）を保持し、新規発火前や `stopMonitoring()` 時に前回分をキャンセルする。

---

### R-5: 配布・署名（Hardened Runtime / Entitlements）およびテスト基盤の統合

- **該当箇所**:
  - `build_app.sh:L26-L39`
  - `Info.plist`
  - `Sources/LangChanger/Services/SelfTestRunner.swift` と `Tests/LangChangerTests/CommandKeyLogicTests.swift`
- **問題の内容**:
  1. 外部配布を行う場合、アドホック署名では毎ビルド TCC 権限リセットが必要になるほか、Hardened Runtime（`codesign --options runtime`）と公証（Notarization）が未設定です。また、テスト用の `SelfTestRunner` と `CommandKeyLogicTests` でほぼ同じ検証コードが二重管理されています。
  2. `CommandKeyTapDetector` のユニットテストには「タイムアウト境界値（ちょうど `0.4s`）」「`Fn` キー併用」「スリープ復帰後リセット」「左⌘押下中に右⌘を離した場合」などの追加エッジケースを網羅する余地があります。
- **修正方針**:
  - リリースビルド向けオプション（`--options runtime` + 開発者証明書対応、不要なサンドボックス/Entitlementsを要求しない最小権限方針の維持）をドキュメント・スクリプト上で明確化する。
  - テスト用の検証スイートを共通関数化し、境界値テストを追加する。
