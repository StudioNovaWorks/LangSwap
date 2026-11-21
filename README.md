# LangSwap for Mac (US Keyboard)

**English** | **[日本語はこちら](#日本語)**

[![Platform](https://img.shields.io/badge/macOS-13.0%2B-blue)](#requirements)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64%20Native-black)](#why-langswap)
[![Release](https://img.shields.io/github/v/release/StudioNovaWorks/LangSwap?label=Release)](https://github.com/StudioNovaWorks/LangSwap/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Switch between *any* two macOS input sources with a single tap of Left `⌘` or Right `⌘` on a US keyboard — lightweight, privacy-first, and no Accessibility permission or virtual keyboard driver required.**

---

## Why LangSwap?

Many Mac users on US keyboards want instant JIS-style language switching using the Left and Right Command (`⌘`) keys — without installing heavy virtual keyboard drivers or granting broad Accessibility control.

- **Works with *All* macOS Languages & IMEs (Not Just EN/JA)** — Map Left `⌘` and Right `⌘` to *any* keyboard layout or IME installed on macOS (English, Japanese, Chinese Simplified/Traditional, Korean, German, French, Spanish, Italian, Arabic, third-party IMEs, etc.). Save favorite pairs as presets with duplicate protection, and search, enable, or safely remove macOS input sources directly inside the app (protecting the last remaining and sole ASCII-capable sources, with clear unavailable-source warnings if removed).
- **Least-Privilege Security (Input Monitoring Only)** — Unlike traditional key remappers that require broad **Accessibility** permissions (which can inject or alter keystrokes) or **DriverKit** virtual keyboard extensions, LangSwap uses a **read-only** `CGEventTapOptions.listenOnly` tap (`kTCCServiceListenEvent`) and switches languages directly via Apple's Carbon TIS API.
- **100% Offline & Zero Telemetry** — No analytics, no background network calls, and no keystroke logging. Only opens external URLs when you explicitly click Privacy Policy, Ko-fi, or System Settings shortcuts. Includes an 18-language [Privacy Policy](https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html) and MIT-licensed open-source code.
- **Apple Silicon Native & Ultra-Compact** — Pure Swift / SwiftUI / AppKit / CoreGraphics / Carbon implementation with **zero third-party dependencies**. Runs as a single menu bar process (`LSUIElement`), **1.7 MB** app bundle (< 1 MB executable), and **~0% idle CPU usage**. *(Intel Macs are also supported via `--universal` source builds.)*
- **Zero Accidental Triggers** — A dedicated state machine reliably ignores `⌘+C` / `⌘+V` / `⌘+Tab` shortcuts, other modifiers (`Shift` / `Control` / `Option` / `Fn`), simultaneous Left+Right `⌘`, `⌘+Click`, drag-and-drop, scrolling, and holds exceeding your configured threshold (`150–1000 ms`, default `400 ms`).
- **Native macOS UX & 18-Language UI** — Non-focus-stealing mini HUD notification, reliable CJKV IME switching retry, automatic wake/screen-unlock recovery, Launch at Login (`SMAppService`) & background startup toggle, System/Light/Dark window appearance, and complete 18-language localization (including RTL layout for Arabic).

### How LangSwap Compares

| Feature | **LangSwap** | Traditional EN/JA Switchers | Karabiner-Elements | Input Source Pro |
| --- | --- | --- | --- | --- |
| Primary goal | Instant **Left/Right `⌘` tap** to any 2 input sources | Left/Right `⌘` tap for EN/JA | General-purpose key remapper | **Auto-switch** per app/URL *(pairs well with LangSwap)* |
| Language support | **Any macOS layout / IME** + presets + 18-lang UI | Mainly EN/JA | Any *(JSON rules required; CJKV caveats)* | Any |
| Required permissions | **Input Monitoring only** (read-only) | Accessibility (+ Input Monitoring) | **DriverKit virtual keyboard** + Input Monitoring | Accessibility |
| Footprint & setup | **1.7 MB**, single process, zero external deps, GUI setup | Lightweight, older architecture | Multi-daemon + DriverKit extension | Native OSS |

---

## Requirements

- **macOS 13.0 (Ventura)** or later (`LSMinimumSystemVersion = 13.0`)
- **Apple Silicon (`arm64`)** Mac *(prebuilt DMG release; Intel `x86_64` supported via `./build_app.sh --universal`)*

---

## Installation & Setup

### 1. Download & Install from GitHub Releases
1. Download `LangSwap-v1.0.0.dmg` from [GitHub Releases](https://github.com/StudioNovaWorks/LangSwap/releases/latest).
2. Open the DMG and drag **`LangSwap.app`** onto **`Applications`** (`/Applications`).
   - Installing into `/Applications` keeps Login Items and Input Monitoring permissions stable across launches.
3. Launch **`LangSwap`** from `/Applications/LangSwap.app`.

> **First-Launch Gatekeeper Notice (Ad-hoc Signed Release):**  
> Because `v1.0.0` is currently distributed with an ad-hoc signature (without Apple Developer ID notarization), macOS Gatekeeper may display *"LangSwap.app cannot be opened because the developer cannot be verified."* on first launch:
> - **macOS 15 Sequoia or later**: Dismiss the dialog, open **System Settings > Privacy & Security**, scroll to the **Security** section, and click **Open Anyway**.
> - **macOS 13 Ventura / 14 Sonoma**: In Finder, right-click (or Control-click) `/Applications/LangSwap.app` → **Open** → **Open**.
> - **Terminal option** *(after verifying the download)*:
>   ```bash
>   xattr -dr com.apple.quarantine /Applications/LangSwap.app
>   ```

### 2. Grant Input Monitoring Permission (Required)
1. Click **Open System Settings** in the orange banner at the top of LangSwap (**System Settings > Privacy & Security > Input Monitoring**).
2. Enable the toggle for **`LangSwap`** (if missing, click `+` and choose `/Applications/LangSwap.app`).
3. If switching in other apps does not take effect immediately, click **Recheck** or **Relaunch** in the banner.

> **Note after Rebuilding or Ad-hoc Updates:** Rebuilding with an ad-hoc signature changes the binary's CDHash. If macOS still appears checked in Input Monitoring yet ignores background apps, remove `LangSwap` with **`−`** in **Privacy & Security > Input Monitoring**, re-add it (or toggle off → on), and click **Relaunch**.

---

## Usage Overview

- **General Tab**: Click `⌘L` / `⌘R` dropdowns to assign any macOS input source (or *Disabled*), swap sides, switch/delete quick presets, save the current pair, or quit safely from the bottom-right button (`⌘Q`).
- **Languages Tab**: Manage saved presets, search installed macOS input sources, click **Add** to enable layouts/IMEs, or safely remove unused ones with the trash icon.
- **Behavior Tab**: Configure **Open at Login**, **Launch in Background**, **Appearance** (`System` / `Light` / `Dark`), **App Language** (18 languages), on-screen HUD notification, **Tap Timeout** (`150–1000 ms`), and Input Monitoring status.
- **Guide Tab**: Built-in setup steps, 6 troubleshooting Q&As, Privacy Policy link, and Ko-fi support link.
- **Menu Bar (`⌘`)**: Toggle Active/Paused, change Left/Right assignments, switch presets, open Settings (`⌘,`), or quit (`⌘Q`).

---

## Build from Source

Requires Swift 5.9+ (Xcode Command Line Tools only is sufficient):

```bash
chmod +x build_app.sh scripts/package_dmg.sh

# Build Apple Silicon (arm64) native .app bundle -> dist/LangSwap.app
./build_app.sh

# Build Universal Binary (arm64 + x86_64)
./build_app.sh --universal

# Build & package verified Retina DMG -> dist/LangSwap-v1.0.0.dmg
./scripts/package_dmg.sh --build

# Package Universal DMG (or skip Finder GUI layout in headless CI/SSH)
./scripts/package_dmg.sh --build --universal
./scripts/package_dmg.sh --no-finder-layout

# Run built-in self-test suite (56 tests, works without Xcode)
swift build && .build/debug/LangSwap --self-test

# Run XCTest suite (requires full Xcode)
swift test
```

> **Code Signing & Notarization:** If a valid `Developer ID Application` certificate exists in Keychain (or `LANGSWAP_SIGN_IDENTITY` is set), `build_app.sh` and `scripts/package_dmg.sh` sign automatically with `--options runtime --timestamp`. To eliminate Gatekeeper warnings for public distribution, submit and staple the DMG with `xcrun notarytool submit` and `xcrun stapler staple`. Otherwise, ad-hoc signing (`codesign --sign -`) is applied automatically.

---

## Uninstall / Complete Reset

Turn off **Open at Login** inside LangSwap and quit the app (`⌘Q`), then run:

```bash
pkill -x LangSwap 2>/dev/null || true
defaults delete com.studionovaworks.LangSwap 2>/dev/null || true
killall cfprefsd 2>/dev/null || true
tccutil reset ListenEvent com.studionovaworks.LangSwap
rm -rf /Applications/LangSwap.app
```

---

## Privacy, Docs & Support

- **GitHub Releases & Bug Reports**: <https://github.com/StudioNovaWorks/LangSwap/releases> · [Issues](https://github.com/StudioNovaWorks/LangSwap/issues)
- **Privacy Policy (18 Languages)**: <https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html> ([HTML Source](docs/LangSwap_PrivacyPolicy.html))
- **Architecture & Technical Docs (JA)**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Code Review History (JA)**: [docs/CODE_REVIEW.md](docs/CODE_REVIEW.md)
- **Support Development**: [Ko-fi](https://ko-fi.com/E1E81S63Z8)
- **License**: [MIT License](LICENSE) — Developed by **Studio Nova Works** © 2026

---
---

## 日本語

**[English Version Above](#langswap-for-mac-us-keyboard)**

**Mac（Apple Silicon 搭載 Mac）の US キーボードにおいて、スペースバー左右の左 Command (`⌘L`)・右 Command (`⌘R`) を単押し（タップ）するだけで、JIS キーボードの「英数 / かな」キーのように macOS 上のあらゆる 2 つの入力ソース／言語を瞬時に切り替えられる軽量ネイティブユーティリティ（`v1.0.0`）です。**

### LangSwap が選ばれる理由（他ツールとの差別化）

- **日英に限らず macOS の全言語・全 IME に対応（＋ 18 言語 UI）**  
  英語 ↔ 日本語だけでなく、中国語（簡体字/繁体字）・韓国語・ドイツ語・フランス語・スペイン語・イタリア語・アラビア語（RTL 対応）・サードパーティ製 IME など、macOS に登録可能な全入力ソースを左右 `⌘` に割り当てられます。よく使う言語ペアの重複なしプリセット管理に加え、アプリ内から macOS 入力ソースの検索・追加・安全削除（最後の 1 件／唯一の英字ソース保護・未追加警告表示付き）まで完結します。
- **最小権限設計（アクセシビリティ権限も仮想ドライバも不要）**  
  他アプリへのキー送信や入力改変が行える強い「アクセシビリティ」権限や、DriverKit 仮想キーボード拡張は一切不要です。読み取り専用の **「入力監視（`kTCCServiceListenEvent` / `.listenOnly`）」のみ** で押下を検知し、macOS 標準の Carbon TIS API で安全に言語を切り替えます。
- **完全オフライン・テレメトリゼロ・MIT オープンソース**  
  解析通信やバックグラウンド通信、キーロギング機能は一切ありません（ブラウザを開くのはプライバシーポリシー・Ko-fi・システム設定リンクを明示クリックした時のみ）。18 言語の[プライバシーポリシー](https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html?lang=ja)と MIT ライセンスのソースコードを公開しています。
- **Apple Silicon ネイティブ・1.7 MB の超コンパクト実装**  
  外部ライブラリ依存ゼロの純粋 Swift / SwiftUI / AppKit 実装。アプリ本体 **1.7 MB**（実行バイナリ 1 MB 未満）、単一プロセス常駐（`LSUIElement`）、**待機時 CPU 使用率ほぼ 0%** で動作します（※ Intel Mac 向けもソースビルドの `--universal` に対応）。
- **日常操作を邪魔しない誤動作防止とネイティブ体験**  
  `⌘+C` / `⌘+V` / `⌘+Tab` 等のショートカット、他修飾キー（`Shift` / `Control` / `Option` / `Fn`）、左右 `⌘` 同時押し、`⌘+クリック`・ドラッグ＆ドロップ・スクロール、設定時間超過の長押し（`150–1000 ms` 調整可・初期値 `400 ms`）を純粋ステートマシンで厳密に抑止。フォーカスを奪わないミニ HUD 通知、CJKV IME の切り替え遅延リトライ、スリープ／画面ロック解除後の自動復旧、外観モード（システム／ライト／ダーク）にも対応しています。

### 類似ツールとの比較

| 観点 | **LangSwap** | 従来の英かな系ツール | Karabiner-Elements | Input Source Pro |
| --- | --- | --- | --- | --- |
| 主な用途 | **左右 `⌘` 単押し**で任意 2 言語を切替 | 左右 `⌘` で英数 / かな切替 | 汎用キーリマップ全般 | アプリ・URL ごとの**自動**切替（※併用可） |
| 対応言語 | **macOS 全言語・全 IME**＋プリセット＋18 言語 UI | 主に日英中心 | 全般（JSON 設定が必要・CJKV 切替に制約あり） | 全言語 |
| 必要権限・拡張 | **入力監視のみ**（読み取り専用） | アクセシビリティ（＋入力監視） | **DriverKit 仮想キーボード拡張**＋入力監視 | アクセシビリティ |
| 構成・導入 | **1.7 MB**・単一プロセス・外部依存ゼロ・GUI で完結 | 小型だが旧設計ベース | 複数常駐デーモン＋拡張承認が必要 | ネイティブ OSS |

### 動作環境

- **macOS 13.0 (Ventura)** 以降（`LSMinimumSystemVersion = 13.0`）
- **Apple Silicon (`arm64`)** 搭載 Mac（配布 DMG は `arm64` ネイティブ。Intel Mac はソースから `./build_app.sh --universal` でビルド可能）

### インストールと初期設定

#### 1. 配布 DMG からのインストール（推奨）
1. [GitHub Releases](https://github.com/StudioNovaWorks/LangSwap/releases/latest) から `LangSwap-v1.0.0.dmg` をダウンロードしてダブルクリックで開きます。
2. 案内ウインドウ内の **`LangSwap.app`** を隣の **`Applications`** フォルダへドラッグしてコピーし、`/Applications/LangSwap.app` から起動します。
   - ログイン項目登録と入力監視権限を安定維持するため、必ず `/Applications` に移動してから起動してください。

> **Ad-hoc 署名版を初回起動する際の Gatekeeper 手順（重要）:**  
> 本リリース（`v1.0.0`）は Apple Developer ID による公証を含まない Ad-hoc 署名版のため、初回のみ「"LangSwap.app"は開発元が未確認のため開けません」等の警告が表示される場合があります。
> - **macOS 15 Sequoia 以降**: ダイアログを閉じ、**「システム設定」＞「プライバシーとセキュリティ」** 下部の「セキュリティ」欄にある **「このまま開く」** をクリックして認証してください。
> - **macOS 13 Ventura / 14 Sonoma**: Finder で `/Applications/LangSwap.app` を **右クリック（Control＋クリック）＞「開く」** から許可してください。
> - **ターミナルから検疫属性を解除する場合**（信頼できる配布物であることを確認の上で実行）:
>   ```bash
>   xattr -dr com.apple.quarantine /Applications/LangSwap.app
>   ```

#### 2. 【必須】「入力監視」権限の許可
1. 設定ウインドウ上部のオレンジ色の案内バナー（**「「入力監視」の許可が必要です」**）から **「システム設定を開く」** をクリックします（**プライバシーとセキュリティ ＞ 入力監視**）。
2. **`LangSwap`** のスイッチをオンにします（一覧にない場合は `+` から `/Applications/LangSwap.app` を追加）。
3. 権限許可後、切り替わらない場合はバナー内の **「再確認」** または **「再起動」** をクリックしてください。

> **Ad-hoc 署名版での再ビルド・アップデート後に背景アプリで反応しない場合:** バイナリの署名ハッシュ（CDHash）が変わるため、**「入力監視」** から一度 `LangSwap` を **「−」で削除して再追加（またはオフ→オン）** し、「再起動」をクリックしてください。

### 基本的な使い方（設定画面 4 タブ & メニューバー）

- **基本設定**: ハードウェアプレビュー（`⌘L` / `space` / `⌘R`）、左右キーの割り当て・入れ替え、プリセットのワンクリック切替・保存・削除、ログイン時自動起動／バックグラウンド起動、右下 **「LangSwap を終了」**（`⌘Q`）。
- **言語設定**: 保存済みプリセットの管理（表示名は UI 言語へ自動追従・削除済みソースには警告表示）、macOS にインストール済みの入力ソース検索・追加（**「追加する」**）・安全削除（**「追加済み」** 横のゴミ箱ボタン）。
- **動作設定**: 起動設定、外観モード（システム・ライト・ダーク）、18 言語の表示切替、切り替え HUD 通知のオン／オフ、単押し判定時間スライダー（`150–1000 ms`）、アクセス権限確認ボタン。
- **使い方**: Ko-fi 開発支援＋Studio Nova Works クレジット、アプリ概要＋[プライバシーポリシー](https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html?lang=ja)、導入 4 ステップ、よくあるトラブル 6 項目。
- **メニューバー（`⌘`）**: 機能の有効／一時停止、左右割り当て変更、プリセット切り替え、設定を開く／終了。ショートカットは設定 (`⌘,`)・閉じる (`⌘W`)・しまう (`⌘M`)・終了 (`⌘Q`) に対応。

### ソースコードからのビルド・テスト（開発者向け）

Swift 5.9 以降（Xcode Command Line Tools のみでビルド可能）：

```bash
chmod +x build_app.sh scripts/package_dmg.sh

./build_app.sh                              # Apple Silicon (arm64) ネイティブビルド -> dist/LangSwap.app
./build_app.sh --universal                  # Universal Binary (arm64 + x86_64)
./scripts/package_dmg.sh --build            # ビルド〜Retina DMG 作成・検証まで一括実行
./scripts/package_dmg.sh --build --universal # Universal Binary DMG 作成
./scripts/package_dmg.sh --no-finder-layout # CI/SSH 等で Finder GUI レイアウトを省略

swift build && .build/debug/LangSwap --self-test  # 内蔵セルフテスト（56項目）
swift test                                        # Xcode 導入環境での XCTest 実行
```

> **コード署名と公証（Notarization）:** キーチェーンに `Developer ID Application` 証明書が存在する場合（または `LANGSWAP_SIGN_IDENTITY` 指定時）は、証明書 SHA-1 ハッシュで `--options runtime --timestamp` 署名されます。一般配布時の警告を消すには `xcrun notarytool submit` / `xcrun stapler staple` を実行してください。証明書がない場合は Ad-hoc 署名（`--sign -`）になります。

### アンインストール・設定の完全初期化

アプリ内の **「Macログイン時に自動起動」** を OFF にして終了（`⌘Q`）後、以下を実行します。

```bash
pkill -x LangSwap 2>/dev/null || true
defaults delete com.studionovaworks.LangSwap 2>/dev/null || true
killall cfprefsd 2>/dev/null || true
tccutil reset ListenEvent com.studionovaworks.LangSwap
rm -rf /Applications/LangSwap.app
```

---

Developed by **Studio Nova Works** © 2026 | [MIT License](LICENSE) | [Privacy Policy](https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html?lang=ja) | [Ko-fi](https://ko-fi.com/E1E81S63Z8)
