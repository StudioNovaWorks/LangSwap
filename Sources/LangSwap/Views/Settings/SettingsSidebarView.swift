import SwiftUI
import AppKit

/// 設定ウィンドウ左側の半透明ナビゲーションサイドバー
struct SettingsSidebarView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var uiState = SettingsUIState.shared

    private var lang: AppLanguage { settings.appLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // macOS信号ボタン用スペース + アプリ識別ヘッダー
            HStack(spacing: 9) {
                AppIconBadgeView(size: 28)
                Text(AppConstants.AppInfo.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 38)
            .padding(.horizontal, 14)
            .padding(.bottom, 16)

            VStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    sidebarTabButton(tab)
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
    }

    private func sidebarTabButton(_ tab: SettingsTab) -> some View {
        let isSelected = uiState.selectedTab == tab
        return Button {
            uiState.selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18)
                Text(tab.title(lang: lang))
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color(NSColor.controlBackgroundColor).opacity(0.90) : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 1.5, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.08) : Color.clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
