import Foundation
import CoreGraphics

/// 左右のCommandキーを表す列挙型
public enum CommandKeySide: String, Sendable, Equatable {
    case left
    case right

    /// macOS Virtual KeyCode (kVK_Command = 55, kVK_RightCommand = 54)
    public var keyCode: UInt16 {
        switch self {
        case .left: return AppConstants.KeyCode.leftCommand
        case .right: return AppConstants.KeyCode.rightCommand
        }
    }

    public static func from(keyCode: UInt16) -> CommandKeySide? {
        switch keyCode {
        case AppConstants.KeyCode.leftCommand: return .left
        case AppConstants.KeyCode.rightCommand: return .right
        default: return nil
        }
    }
}

/// 左右Commandキーの「単押し（タップ）」を厳密に判定するステートマシン
public final class CommandKeyTapDetector {
    public enum State: Equatable {
        case idle
        case pending(side: CommandKeySide, pressedAt: TimeInterval)
        case cancelled
    }

    /// 単押しと判定する最大押下時間（秒）
    public var timeoutSeconds: TimeInterval

    /// 現在の内部状態（テスト検証用にも公開）
    public private(set) var state: State = .idle

    public init(timeoutSeconds: TimeInterval = TimeInterval(AppConstants.Timing.defaultTapTimeoutMs) / 1000.0) {
        self.timeoutSeconds = timeoutSeconds
    }

    /// 状態をリセットする
    public func reset() {
        state = .idle
    }

    /// 修飾キー状態変化 (flagsChanged) イベントを処理する
    /// - Parameters:
    ///   - keyCode: イベントを発生させたハードウェアキーコード (左⌘=55, 右⌘=54 等)
    ///   - isCommandDown: 現在Commandモディファイアが押下状態かどうか
    ///   - hasOtherModifiers: Shift / Control / Option / Fn 等の他修飾キーが押されているか
    ///   - timestamp: イベント発生時刻（秒）
    /// - Returns: 単押しが確定した場合は `.left` または `.right`、それ以外は `nil`
    @discardableResult
    public func handleFlagsChanged(
        keyCode: UInt16,
        isCommandDown: Bool,
        hasOtherModifiers: Bool,
        timestamp: TimeInterval
    ) -> CommandKeySide? {
        // 他の修飾キーが押されている場合は、いかなる場合も単押しではないためキャンセル状態へ遷移
        if hasOtherModifiers {
            if isCommandDown {
                state = .cancelled
            } else {
                state = .idle
            }
            return nil
        }

        switch state {
        case .idle:
            // アイドル状態から左右どちらかのCommandキーが単独で押下された場合
            if isCommandDown, let side = CommandKeySide.from(keyCode: keyCode) {
                state = .pending(side: side, pressedAt: timestamp)
            }
            return nil

        case let .pending(side, pressedAt):
            if !isCommandDown {
                // Commandキーが離された場合
                state = .idle
                guard CommandKeySide.from(keyCode: keyCode) == side else {
                    return nil
                }
                let elapsed = timestamp - pressedAt
                if elapsed >= 0 && elapsed <= timeoutSeconds {
                    return side
                }
                return nil
            } else {
                // Commandキー押下中に反対側のCommandキー等が押された場合はキャンセル
                state = .cancelled
                return nil
            }

        case .cancelled:
            // すべてのCommandキーが離されたらアイドル状態へ復帰
            if !isCommandDown {
                state = .idle
            }
            return nil
        }
    }

    /// 通常キーの押下 (keyDown) イベントが発生した際に呼び出す（ショートカット操作とみなして単押しをキャンセル）
    public func handleOtherKeyDown() {
        if case .pending = state {
            state = .cancelled
        }
    }

    /// マウスクリックやドラッグ等のマウス操作が発生した際に呼び出す（⌘+クリック等をキャンセル）
    public func handleMouseInteraction() {
        if case .pending = state {
            state = .cancelled
        }
    }

    /// CGEventFlags から Shift / Control / Option / Fn / Help の他修飾キーが押されているかを判定するヘルパー
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
}
