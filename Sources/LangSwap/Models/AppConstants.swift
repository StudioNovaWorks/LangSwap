import Foundation
import CoreGraphics

/// アプリケーション全体で使用する定数定義
public enum AppConstants {
    /// アプリ基本名称
    public enum AppInfo {
        public static let name: String = "LangSwap"
        public static let fullTitle: String = "LangSwap for Mac US Keyboard"
        public static let fallbackVersion: String = "1.0.0"
        public static let reopenNotificationName = NSNotification.Name("com.studionovaworks.LangSwap.reopenSettings")
    }

    /// ハードウェア仮想キーコード (Carbon HIToolbox kVK_Command / kVK_RightCommand)
    public enum KeyCode {
        public static let leftCommand: UInt16 = 55
        public static let rightCommand: UInt16 = 54
    }

    /// タイミング・しきい値・アニメーション時間
    public enum Timing {
        public static let defaultTapTimeoutMs: Int = 400
        public static let minTapTimeoutMs: Int = 150
        public static let maxTapTimeoutMs: Int = 1000
        public static let tapTimeoutStepMs: Int = 25

        /// 修飾フラグ解除が最前面アプリへ伝播するのを待つ微小遅延（秒）
        public static let switchDispatchDelaySeconds: TimeInterval = 0.01
        /// CJKV InputMode 切り替え時の TIS 反映確認・リトライ遅延（秒）
        public static let cjkvRetryDelaySeconds: TimeInterval = 0.02

        /// 入力監視権限未許可時のポーリング間隔・許容誤差（秒）
        public static let inputMonitoringPollUntrustedSeconds: TimeInterval = 2.0
        public static let inputMonitoringPollUntrustedTolerance: TimeInterval = 0.3
        /// 入力監視権限許可済み時のバックグラウンド再確認間隔・許容誤差（秒）
        public static let inputMonitoringPollTrustedSeconds: TimeInterval = 30.0
        public static let inputMonitoringPollTrustedTolerance: TimeInterval = 5.0

        /// スリープ復帰・画面ロック解除通知のデバウンス時間（秒）
        public static let environmentChangeDebounceSeconds: TimeInterval = 0.25

        /// CGEventTap 無効化通知時の再起動バックオフウィンドウと上限回数
        public static let tapDisableRetryWindowSeconds: TimeInterval = 5.0
        public static let maxTapDisableRestartsInWindow: Int = 3

        /// HUD表示およびフェードアウト時間（秒）
        public static let hudDisplayDurationSeconds: TimeInterval = 0.85
        public static let hudFadeOutDurationSeconds: TimeInterval = 0.20

        /// キーボードプレビューのハイライト持続時間（秒）
        public static let keyHighlightDurationSeconds: TimeInterval = 0.55
    }

    /// クレジット・著作権表記
    public enum Credits {
        public static let studioName: String = "Studio Nova Works"
        public static let copyrightYear: String = "2026"
    }

    /// ウィンドウおよびコンポーネント寸法
    public enum Layout {
        public static let settingsWindowWidth: CGFloat = 720
        public static let settingsWindowHeight: CGFloat = 590
        public static let sidebarWidth: CGFloat = 192
        public static let popoverWidth: CGFloat = 294
        public static let hudBottomOffset: CGFloat = 90
    }
}
