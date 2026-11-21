import SwiftUI
import AppKit

/// 設定ウィンドウのサイドバータブ
public enum SettingsTab: String, CaseIterable, Identifiable {
    case mapping
    case presets
    case behavior
    case guide

    public var id: String { rawValue }

    var iconName: String {
        switch self {
        case .mapping: return "command"
        case .presets: return "bookmark"
        case .behavior: return "slider.horizontal.3"
        case .guide: return "info.circle"
        }
    }

    func title(lang: AppLanguage) -> String {
        switch self {
        case .mapping: return L10n.t(.tabMapping, lang: lang)
        case .presets: return L10n.t(.tabPresets, lang: lang)
        case .behavior: return L10n.t(.tabBehavior, lang: lang)
        case .guide: return L10n.t(.tabGuide, lang: lang)
        }
    }
}

/// 設定画面の一時的なUI状態
@MainActor
public final class SettingsUIState: ObservableObject {
    public static let shared = SettingsUIState()

    @Published public var selectedTab: SettingsTab = .mapping
    @Published public var highlightedSide: CommandKeySide? = nil
    @Published public var searchText: String = ""

    private var highlightWorkItem: DispatchWorkItem?

    public init() {}

    /// プレビューキーを一時的にハイライト表示する（連続押下時は前回の消灯予約をキャンセル）
    public func flashHighlight(for side: CommandKeySide) {
        highlightWorkItem?.cancel()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            highlightedSide = side
        }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.25)) {
                    if self?.highlightedSide == side {
                        self?.highlightedSide = nil
                    }
                }
            }
        }
        highlightWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Timing.keyHighlightDurationSeconds,
            execute: workItem
        )
    }
}
