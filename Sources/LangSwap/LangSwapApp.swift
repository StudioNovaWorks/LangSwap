import SwiftUI
import AppKit
import Combine

@main
@MainActor
public enum LangSwapMain {
    private static var appDelegate: AppDelegate?

    public static func main() {
        if CommandLine.arguments.contains("--self-test") {
            let success = SelfTestRunner.runAllTests()
            exit(success ? 0 : 1)
        }

        if let bundleID = Bundle.main.bundleIdentifier {
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first { $0.processIdentifier != currentPID && !$0.isTerminated }
            if let existing = existing {
                DistributedNotificationCenter.default().postNotificationName(
                    AppConstants.AppInfo.reopenNotificationName,
                    object: bundleID,
                    userInfo: nil,
                    deliverImmediately: true
                )
                existing.activate(options: [.activateIgnoringOtherApps])
                exit(0)
            }
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        self.appDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var reopenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let isFirstRun = !AppSettings.shared.hasInitializedDefaults
        ProcessInfo.processInfo.disableAutomaticTermination("LangSwap menu bar resident service")
        AppSettings.shared.applyTheme()

        // 1. 入力ソース情報の初期化とHUD通知コールバック設定
        let sourceManager = InputSourceManager.shared
        sourceManager.refreshInputSources()
        sourceManager.onInputSourceSwitched = { side, item in
            HUDNotificationController.shared.show(side: side, item: item)
        }

        // 2. 標準ショートカットメニュー（⌘, / ⌘W / ⌘C / ⌘V / ⌘Q）の構築とUI言語連動
        setupMainMenu(lang: AppSettings.shared.appLanguage)
        AppSettings.shared.$appLanguage
            .dropFirst()
            .sink { [weak self] newLang in
                self?.setupMainMenu(lang: newLang)
                if let button = self?.statusItem?.button {
                    let trusted = InputMonitoringService.shared.isTrusted &&
                        (!CommandKeyEventMonitor.shared.isMonitoring || CommandKeyEventMonitor.shared.isUsingCGEventTap)
                    self?.updateStatusButtonAppearance(
                        button: button,
                        isEnabled: AppSettings.shared.isEnabled,
                        isTrusted: trusted,
                        lang: newLang
                    )
                }
            }
            .store(in: &cancellables)

        AppSettings.shared.$appTheme
            .dropFirst()
            .sink { [weak self] newTheme in
                let appearance = newTheme.nsAppearance
                self?.popover.appearance = appearance
                self?.popover.contentViewController?.view.window?.appearance = appearance
                self?.settingsWindow?.appearance = appearance
                self?.settingsWindow?.contentView?.appearance = nil
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { _ in
                Task { @MainActor in
                    AppSettings.shared.refreshLaunchAtLoginStatus()
                }
            }
            .store(in: &cancellables)

        if let bundleID = Bundle.main.bundleIdentifier {
            reopenObserver = DistributedNotificationCenter.default().addObserver(
                forName: AppConstants.AppInfo.reopenNotificationName,
                object: bundleID,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.openSettingsWindow()
                }
            }
        }

        // 3. メニューバー常駐アイコンとポップオーバーの構築
        setupMenuBarStatusItem()

        // 4. キーイベント監視の開始
        CommandKeyEventMonitor.shared.startMonitoring()

        // 5. 初回起動またはバックグラウンド起動OFFの場合のみ設定ウィンドウを開く
        let shouldOpenOnLaunch = isFirstRun || !AppSettings.shared.launchInBackground
        if shouldOpenOnLaunch {
            openSettingsWindow()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsWindow()
        return true
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let reopenObserver = reopenObserver {
            DistributedNotificationCenter.default().removeObserver(reopenObserver)
            self.reopenObserver = nil
        }
        CommandKeyEventMonitor.shared.shutdown()
        InputMonitoringService.shared.shutdown()
        InputSourceManager.shared.shutdown()
    }

    // MARK: - Main Menu (Keyboard Shortcuts for LSUIElement)

    private func setupMainMenu(lang: AppLanguage) {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(
            title: L10n.t(.menuSettings, lang: lang),
            action: #selector(openSettingsFromMenu(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.t(.menuQuit, lang: lang),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        // Edit Menu (TextField のコピー/ペースト等を有効化)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: L10n.t(.menuEdit, lang: lang))
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: L10n.t(.menuUndo, lang: lang), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.t(.menuRedo, lang: lang), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.t(.menuCut, lang: lang), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.t(.menuCopy, lang: lang), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.t(.menuPaste, lang: lang), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.t(.menuSelectAll, lang: lang), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: L10n.t(.menuWindow, lang: lang))
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(withTitle: L10n.t(.menuClose, lang: lang), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L10n.t(.menuMinimize, lang: lang), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        NSApplication.shared.mainMenu = mainMenu
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBarStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            button.appearance = nil
            button.window?.appearance = nil
            updateStatusButtonAppearance(
                button: button,
                isEnabled: AppSettings.shared.isEnabled,
                isTrusted: InputMonitoringService.shared.isTrusted,
                lang: AppSettings.shared.appLanguage
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let menuBarView = MenuBarView(
            onOpenSettings: { [weak self] tab in
                self?.popover.performClose(nil)
                self?.openSettingsWindow(tab: tab)
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        let hostingController = NSHostingController(rootView: menuBarView)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = AppSettings.shared.appTheme.nsAppearance
        popover.contentViewController = hostingController

        Publishers.CombineLatest4(
            AppSettings.shared.$isEnabled,
            InputMonitoringService.shared.$isTrusted,
            CommandKeyEventMonitor.shared.$isMonitoring,
            CommandKeyEventMonitor.shared.$isUsingCGEventTap
        )
        .sink { [weak self] enabled, trusted, monitoring, usingTap in
            guard let button = self?.statusItem?.button else { return }
            let effectivelyTrusted = trusted && (!monitoring || usingTap)
            self?.updateStatusButtonAppearance(
                button: button,
                isEnabled: enabled,
                isTrusted: effectivelyTrusted,
                lang: AppSettings.shared.appLanguage
            )
        }
        .store(in: &cancellables)
    }

    private func updateStatusButtonAppearance(
        button: NSStatusBarButton,
        isEnabled: Bool,
        isTrusted: Bool,
        lang: AppLanguage
    ) {
        let symbolName: String
        let description: String
        if !isEnabled {
            symbolName = "command"
            description = L10n.t(.statusTooltipPaused, lang: lang)
        } else if !isTrusted {
            symbolName = "exclamationmark.triangle"
            description = L10n.t(.statusTooltipPermRequired, lang: lang)
        } else {
            symbolName = "command"
            description = L10n.t(.statusTooltipActive, lang: lang)
        }

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .medium)
        if let baseImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: description),
           let image = baseImage.withSymbolConfiguration(symbolConfig) {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else if let fallbackImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) {
            fallbackImage.isTemplate = true
            button.image = fallbackImage
            button.title = ""
        } else {
            button.image = nil
            button.title = isEnabled ? (isTrusted ? "⌘" : "⌘!") : "⌘"
        }
        button.appearance = nil
        button.window?.appearance = nil
        button.alphaValue = isEnabled ? 1.0 : 0.42
        button.toolTip = description
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            AppSettings.shared.applyTheme()
            popover.appearance = AppSettings.shared.appTheme.nsAppearance
            InputMonitoringService.shared.checkPermission(prompt: false)
            InputSourceManager.shared.refreshInputSources()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func openSettingsFromMenu(_ sender: AnyObject?) {
        openSettingsWindow()
    }

    // MARK: - Settings Window Management

    public func openSettingsWindow(tab: SettingsTab? = nil) {
        if let tab = tab {
            SettingsUIState.shared.selectedTab = tab
        }
        AppSettings.shared.applyTheme()
        AppSettings.shared.refreshLaunchAtLoginStatus()
        InputMonitoringService.shared.checkPermission(prompt: false)

        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            hostingController.sizingOptions = []
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: AppConstants.Layout.settingsWindowWidth,
                    height: AppConstants.Layout.settingsWindowHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = AppConstants.AppInfo.name
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = false
            window.isRestorable = false
            window.appearance = AppSettings.shared.appTheme.nsAppearance
            window.contentViewController = hostingController
            window.setContentSize(NSSize(
                width: AppConstants.Layout.settingsWindowWidth,
                height: AppConstants.Layout.settingsWindowHeight
            ))
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }

        settingsWindow?.appearance = AppSettings.shared.appTheme.nsAppearance
        settingsWindow?.contentView?.appearance = nil
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// 権限更新後などにアプリ自体を安全に再起動するヘルパー（旧プロセス終了待機・単一インスタンス起動対応）
    public static func relaunchApplication() {
        let bundlePath = Bundle.main.bundlePath
        let isAppBundle = bundlePath.hasSuffix(".app")
        let targetPath = isAppBundle ? bundlePath : (Bundle.main.executablePath ?? bundlePath)
        let currentPID = String(ProcessInfo.processInfo.processIdentifier)

        let script = isAppBundle
            ? "for _ in $(seq 1 50); do kill -0 \"$2\" 2>/dev/null || break; sleep 0.1; done; /usr/bin/open \"$1\""
            : "for _ in $(seq 1 50); do kill -0 \"$2\" 2>/dev/null || break; sleep 0.1; done; \"$1\" >/dev/null 2>&1 &"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script, "_", targetPath, currentPID]
        do {
            try task.run()
            NSApplication.shared.terminate(nil)
        } catch {
            // 再起動プロセスの起動に失敗した場合は現在プロセスを維持する
        }
    }
}
