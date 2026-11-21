import Foundation
import CoreGraphics
import AppKit

/// 入力監視（Input Monitoring / kTCCServiceListenEvent）権限の確認・要求・監視を行うサービス
@MainActor
public final class InputMonitoringService: ObservableObject {
    public static let shared = InputMonitoringService()

    /// 現在プロセスがイベント監視に必要な入力監視（ListenEvent）権限を持つか
    @Published public private(set) var isTrusted: Bool = false

    private var pollTimer: Timer?
    private var currentPollInterval: TimeInterval?
    private var activeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    public var onStatusChecked: ((Bool) -> Void)?

    private init() {
        checkPermission(prompt: false)
        adjustPollingInterval(isTrusted: isTrusted)

        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermission(prompt: false)
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermission(prompt: false)
            }
        }
    }

    /// 終了時に監視タイマーおよび通知オブザーバを解放する
    public func shutdown() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let activeObserver = activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
        if let wakeObserver = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    /// 入力監視権限の状態を確認する（`prompt: true` の場合はシステム標準の許可ダイアログを表示）
    @discardableResult
    public func checkPermission(prompt: Bool = false) -> Bool {
        if prompt && !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        let trusted = CGPreflightListenEventAccess()

        if self.isTrusted != trusted {
            self.isTrusted = trusted
        }
        adjustPollingInterval(isTrusted: trusted)

        onStatusChecked?(trusted)
        return trusted
    }

    /// システム設定の「プライバシーとセキュリティ > 入力監視」画面を直接開く
    public func openInputMonitoringSettings(promptIfNeeded: Bool = true) {
        if promptIfNeeded && !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 権限状態に応じてポーリング間隔を切り替える（許可済み時は省電力のため低頻度化）
    private func adjustPollingInterval(isTrusted: Bool) {
        let desiredInterval = isTrusted
            ? AppConstants.Timing.inputMonitoringPollTrustedSeconds
            : AppConstants.Timing.inputMonitoringPollUntrustedSeconds

        guard currentPollInterval != desiredInterval else { return }
        currentPollInterval = desiredInterval

        pollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: desiredInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermission(prompt: false)
            }
        }
        timer.tolerance = isTrusted
            ? AppConstants.Timing.inputMonitoringPollTrustedTolerance
            : AppConstants.Timing.inputMonitoringPollUntrustedTolerance
        pollTimer = timer
    }
}
