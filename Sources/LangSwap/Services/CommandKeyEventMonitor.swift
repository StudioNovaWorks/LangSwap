import Foundation
import CoreGraphics
import AppKit
import Combine

/// システム全体のキーボード＆マウスイベントを監視し、左右Commandキーの単押しを検出して言語を切り替えるクラス
@MainActor
public final class CommandKeyEventMonitor: ObservableObject {
    public static let shared = CommandKeyEventMonitor()

    /// 現在イベント監視が稼働しているかどうか
    @Published public private(set) var isMonitoring: Bool = false

    /// CGEventTapによる高精度監視が有効かどうか（falseの場合はNSEventフォールバック動作）
    @Published public private(set) var isUsingCGEventTap: Bool = false

    /// 設定画面でのテスト確認用：最後に単押し検出されたキー
    @Published public private(set) var lastDetectedSide: CommandKeySide?
    @Published public private(set) var lastDetectedTimestamp: Date?

    fileprivate let detector = CommandKeyTapDetector()
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var switchWorkItem: DispatchWorkItem?
    private var environmentChangeWorkItem: DispatchWorkItem?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var monitoringRestartGeneration: UInt64 = 0
    private var recentTapDisableRestartTimestamps: [TimeInterval] = []
    private var pendingTapRecovery: Bool = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        detector.timeoutSeconds = AppSettings.shared.tapTimeoutSeconds

        AppSettings.shared.$tapTimeoutMs
            .sink { [weak self] newMs in
                self?.detector.timeoutSeconds = TimeInterval(newMs) / 1000.0
            }
            .store(in: &cancellables)

        InputMonitoringService.shared.onStatusChecked = { [weak self] trusted in
            guard let self = self else { return }
            if trusted && (!self.isMonitoring || !self.isUsingCGEventTap) {
                self.restartMonitoring()
            } else if !trusted && self.isUsingCGEventTap {
                // 実行中に権限が剥奪された場合はフォールバックへ降格し、保留状態を破棄する
                self.detector.reset()
                self.restartMonitoring()
            }
        }

        setupSystemLifecycleObservers()
    }

    /// 終了時にすべてのイベントタップ・モニター・ライフサイクル監視を解放する
    public func shutdown() {
        environmentChangeWorkItem?.cancel()
        environmentChangeWorkItem = nil
        recentTapDisableRestartTimestamps.removeAll()
        stopMonitoring()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        for observer in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        distributedObservers.removeAll()
    }

    /// 監視を開始する
    public func startMonitoring() {
        stopMonitoring()
        monitoringRestartGeneration &+= 1

        if setupCGEventTap() {
            isUsingCGEventTap = true
            isMonitoring = true
        } else {
            // 入力監視権限が未許可の場合でも、NSEventによるフォールバック監視を起動
            setupNSEventFallbackMonitors()
            isUsingCGEventTap = false
            isMonitoring = true
        }
    }

    /// タップ無効化の短時間ループ発生時に安全なNSEventフォールバック監視へ降格する
    private func fallbackToNSEventMonitoring() {
        stopMonitoring()
        recentTapDisableRestartTimestamps.removeAll()
        monitoringRestartGeneration &+= 1
        setupNSEventFallbackMonitors()
        isUsingCGEventTap = false
        isMonitoring = true
    }

    /// 監視を停止する
    public func stopMonitoring() {
        switchWorkItem?.cancel()
        switchWorkItem = nil

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil

        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        pendingTapRecovery = false
        detector.reset()
        isMonitoring = false
        isUsingCGEventTap = false
    }

    /// 監視を再起動する（権限付与・剥奪・スリープ復帰後などに呼び出し）
    public func restartMonitoring() {
        startMonitoring()
    }

    // MARK: - Lifecycle Observers (Sleep / Wake / Screen Unlock)

    private func setupSystemLifecycleObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter

        let wakeObs = wsCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnvironmentChange()
            }
        }

        let screenWakeObs = wsCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnvironmentChange()
            }
        }

        workspaceObservers = [wakeObs, screenWakeObs]

        let unlockObs = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnvironmentChange()
            }
        }

        distributedObservers = [unlockObs]
    }

    private func handleEnvironmentChange() {
        environmentChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.detector.reset()
                let generationBefore = self.monitoringRestartGeneration
                let trusted = InputMonitoringService.shared.checkPermission(prompt: false)
                let restartedByCheck = (self.monitoringRestartGeneration != generationBefore)
                if !restartedByCheck && (!self.isMonitoring || (trusted && self.isUsingCGEventTap)) {
                    self.restartMonitoring()
                }
            }
        }
        environmentChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Timing.environmentChangeDebounceSeconds,
            execute: workItem
        )
    }

    // MARK: - CGEventTap Setup

    private func setupCGEventTap() -> Bool {
        // 入力監視 (kTCCServiceListenEvent) が未許可のままだと .listenOnly タップ作成自体が非 nil を返しつつ
        // 他アプリのイベントだけサイレント遮断されるため、必ず事前確認してからタップを生成する。
        guard CGPreflightListenEventAccess() else {
            return false
        }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: cgEventTapCallback,
            userInfo: selfPtr
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    // MARK: - NSEvent Fallback Setup

    private func setupNSEventFallbackMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .leftMouseDragged,
            .rightMouseDragged,
            .scrollWheel
        ]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.processNSEvent(event)
                }
            } else {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.processNSEvent(event)
                    }
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.processNSEvent(event)
                }
            } else {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.processNSEvent(event)
                    }
                }
            }
            return event
        }
    }

    // MARK: - Event Handling

    fileprivate func handleTapDisabled(isUserInput: Bool) {
        detector.reset()
        if isUserInput {
            InputMonitoringService.shared.checkPermission(prompt: false)
        }
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        if CGEvent.tapIsEnabled(tap: tap) {
            return
        }

        guard !pendingTapRecovery else { return }
        pendingTapRecovery = true

        let now = ProcessInfo.processInfo.systemUptime
        recentTapDisableRestartTimestamps = recentTapDisableRestartTimestamps.filter {
            now - $0 <= AppConstants.Timing.tapDisableRetryWindowSeconds
        }
        recentTapDisableRestartTimestamps.append(now)
        let exceededLimit = recentTapDisableRestartTimestamps.count > AppConstants.Timing.maxTapDisableRestartsInWindow

        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.pendingTapRecovery = false
                guard self.isMonitoring, self.isUsingCGEventTap else { return }
                if exceededLimit {
                    self.fallbackToNSEventMonitoring()
                } else {
                    self.restartMonitoring()
                }
            }
        }
    }

    fileprivate func handleCapturedCGEvent(_ captured: CapturedCGEvent) {
        if !recentTapDisableRestartTimestamps.isEmpty {
            recentTapDisableRestartTimestamps.removeAll()
        }
        guard AppSettings.shared.isEnabled else {
            detector.reset()
            return
        }

        switch captured {
        case let .flagsChanged(keyCode, isCommandDown, hasOtherModifiers, timestamp):
            if let triggeredSide = detector.handleFlagsChanged(
                keyCode: keyCode,
                isCommandDown: isCommandDown,
                hasOtherModifiers: hasOtherModifiers,
                timestamp: timestamp
            ) {
                triggerLanguageSwitch(for: triggeredSide)
            }

        case .keyDown:
            detector.handleOtherKeyDown()

        case .mouseInteraction:
            detector.handleMouseInteraction()
        }
    }

    private func processNSEvent(_ event: NSEvent) {
        guard AppSettings.shared.isEnabled else {
            detector.reset()
            return
        }

        switch event.type {
        case .flagsChanged:
            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCommandDown = flags.contains(.command)
            let hasOtherModifiers = !flags.intersection([.shift, .control, .option, .function, .help]).isEmpty
            let now = ProcessInfo.processInfo.systemUptime

            if let triggeredSide = detector.handleFlagsChanged(
                keyCode: keyCode,
                isCommandDown: isCommandDown,
                hasOtherModifiers: hasOtherModifiers,
                timestamp: now
            ) {
                triggerLanguageSwitch(for: triggeredSide)
            }

        case .keyDown:
            detector.handleOtherKeyDown()

        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged, .scrollWheel:
            detector.handleMouseInteraction()

        default:
            break
        }
    }

    private func triggerLanguageSwitch(for side: CommandKeySide) {
        lastDetectedSide = side
        lastDetectedTimestamp = Date()

        let targetID: String
        switch side {
        case .left:
            targetID = AppSettings.shared.leftCommandSourceID
        case .right:
            targetID = AppSettings.shared.rightCommandSourceID
        }

        guard !targetID.isEmpty, targetID != InputSourceItem.disabledID else {
            return
        }

        switchWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            MainActor.assumeIsolated {
                guard AppSettings.shared.isEnabled else { return }
                InputSourceManager.shared.selectInputSource(withID: targetID, triggeredBy: side)
            }
        }
        switchWorkItem = workItem

        // Commandキー離上の修飾フラグ解除が最前面アプリへ伝播した直後に切り替えを実行する
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Timing.switchDispatchDelaySeconds,
            execute: workItem
        )
    }
}

/// Cコールバックからメインアクターへ安全に渡すためのSendable値表現
fileprivate enum CapturedCGEvent: Sendable {
    case flagsChanged(keyCode: UInt16, isCommandDown: Bool, hasOtherModifiers: Bool, timestamp: TimeInterval)
    case keyDown
    case mouseInteraction
}

/// CGEventTap コールバック内からメインアクターへ安全かつ同期優先でディスパッチするヘルパー
private func runOnMain(_ block: @escaping @MainActor @Sendable () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated {
            block()
        }
    } else {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                block()
            }
        }
    }
}

/// CGEventTap のC関数コールバック
private func cgEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<CommandKeyEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        let isUserInputDisable = (type == .tapDisabledByUserInput)
        runOnMain {
            monitor.handleTapDisabled(isUserInput: isUserInputDisable)
        }
        return Unmanaged.passUnretained(event)
    }

    let captured: CapturedCGEvent?
    switch type {
    case .flagsChanged:
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        captured = .flagsChanged(
            keyCode: keyCode,
            isCommandDown: flags.contains(.maskCommand),
            hasOtherModifiers: CommandKeyTapDetector.hasOtherModifiers(in: flags),
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    case .keyDown:
        captured = .keyDown
    case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged, .scrollWheel:
        captured = .mouseInteraction
    default:
        captured = nil
    }

    if let captured = captured {
        runOnMain {
            monitor.handleCapturedCGEvent(captured)
        }
    }

    return Unmanaged.passUnretained(event)
}
