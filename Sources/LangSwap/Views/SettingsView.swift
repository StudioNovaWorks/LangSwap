import SwiftUI
import AppKit

/// メイン設定ウィンドウのSwiftUIコンテナビュー（Compact Split Inspector + macOS Native Vibrancy）
public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var monitor = CommandKeyEventMonitor.shared
    @ObservedObject var inputMonitoring = InputMonitoringService.shared
    @ObservedObject var uiState = SettingsUIState.shared

    @Environment(\.colorScheme) private var systemColorScheme

    public init() {}

    private var lang: AppLanguage { settings.appLanguage }

    private var isEffectivelyTrusted: Bool {
        inputMonitoring.isTrusted && (!monitor.isMonitoring || monitor.isUsingCGEventTap)
    }

    public var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView()
                .frame(width: AppConstants.Layout.sidebarWidth)
                .frame(maxHeight: .infinity)
                .background(
                    VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                        .ignoresSafeArea(.all, edges: .top)
                )

            Divider()
                .ignoresSafeArea(.all, edges: .top)

            detailContainerView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color(NSColor.windowBackgroundColor)
                        .ignoresSafeArea(.all, edges: .top)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
        .onChange(of: monitor.lastDetectedTimestamp) { _ in
            guard let side = monitor.lastDetectedSide else { return }
            uiState.flashHighlight(for: side)
        }
    }

    private var detailContainerView: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.top, lang.isRTL ? 38 : 16)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)

            Divider()

            if !isEffectivelyTrusted {
                PermissionBannerView(
                    lang: lang,
                    onRecheck: {
                        inputMonitoring.checkPermission(prompt: false)
                        CommandKeyEventMonitor.shared.restartMonitoring()
                    },
                    onRelaunch: { AppDelegate.relaunchApplication() },
                    onOpenSettings: {
                        inputMonitoring.openInputMonitoringSettings(promptIfNeeded: true)
                    }
                )
                .padding(.horizontal, 22)
                .padding(.top, 14)
            }

            Group {
                switch uiState.selectedTab {
                case .mapping:
                    KeyMappingTabView()
                case .presets:
                    PresetsLanguagesTabView()
                case .behavior:
                    BehaviorTabView()
                case .guide:
                    GuideTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Text(uiState.selectedTab.title(lang: lang))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            activeStatusTogglePill
                .fixedSize()

            headerUtilityActions
        }
    }

    private var activeStatusTogglePill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(settings.isEnabled ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 7, height: 7)
            Text(L10n.t(settings.isEnabled ? .statusActive : .statusPaused, lang: lang))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(settings.isEnabled ? .primary : .secondary)
                .lineLimit(1)
            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(settings.isEnabled ? Color.green.opacity(0.11) : Color.primary.opacity(0.05))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    settings.isEnabled ? Color.green.opacity(0.28) : Color.primary.opacity(0.08),
                    lineWidth: 0.75
                )
        )
    }

    private var headerUtilityActions: some View {
        HStack(spacing: 6) {
            // 18言語切替メニュー
            Menu {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        settings.appLanguage = option
                    } label: {
                        HStack {
                            Text(option.nativeName)
                            if settings.appLanguage == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 13))
                    Text(settings.appLanguage.shortBadge)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .fill(Color.primary.opacity(0.055))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L10n.t(.languageTooltip, lang: lang))

            // 外観モード切替メニュー
            Menu {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        settings.appTheme = theme
                    } label: {
                        HStack {
                            Text(themeTitle(theme))
                            if settings.appTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: themeIconName)
                    .font(.system(size: 13.5))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .fill(Color.primary.opacity(0.055))
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(L10n.t(.themeTooltip, lang: lang))

            // Info ボタン
            Button {
                uiState.selectedTab = (uiState.selectedTab == .guide) ? .mapping : .guide
            } label: {
                Image(systemName: uiState.selectedTab == .guide ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(uiState.selectedTab == .guide ? .accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .fill(uiState.selectedTab == .guide ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.055))
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.t(.infoTooltip, lang: lang))

            // Ko-fi サポートボタン
            Button {
                if let url = URL(string: L10n.kofiURLString) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 13.5))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .fill(Color.primary.opacity(0.055))
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.t(.kofiTooltip, lang: lang))
        }
    }

    private var themeIconName: String {
        switch settings.appTheme {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return systemColorScheme == .dark ? "moon.stars" : "sun.max"
        }
    }

    private func themeTitle(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return L10n.t(.themeSystem, lang: lang)
        case .light: return L10n.t(.themeLight, lang: lang)
        case .dark: return L10n.t(.themeDark, lang: lang)
        }
    }
}
