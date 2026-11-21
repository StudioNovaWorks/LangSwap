import SwiftUI

/// タブ3: 起動・外観・言語・キー判定タイミング設定
struct BehaviorTabView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var inputMonitoring = InputMonitoringService.shared
    @ObservedObject var monitor = CommandKeyEventMonitor.shared

    private var lang: AppLanguage { settings.appLanguage }

    private var isEffectivelyTrusted: Bool {
        inputMonitoring.isTrusted && (!monitor.isMonitoring || monitor.isUsingCGEventTap)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSectionHeader(L10n.t(.startupSectionTitle, lang: lang))

                InsetGroupedCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text(L10n.t(.launchAtLogin, lang: lang))
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { settings.launchAtLogin },
                                set: { settings.setLaunchAtLogin($0) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8.5)

                        LoginItemStatusHintView(settings: settings, lang: lang)

                        Divider().padding(.leading, 14)

                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.t(.launchInBackground, lang: lang))
                                    .font(.system(size: 13))
                                Text(L10n.t(.launchInBackgroundDesc, lang: lang))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.launchInBackground)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8.5)
                    }
                }

                SettingsSectionHeader(L10n.t(.appearanceSectionTitle, lang: lang))

                InsetGroupedCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text(L10n.t(.themeLabel, lang: lang))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $settings.appTheme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(themeTitle(theme)).tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(minWidth: 220, maxWidth: 295)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8.5)

                        Divider().padding(.leading, 14)

                        HStack {
                            Text(L10n.t(.uiLanguageLabel, lang: lang))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $settings.appLanguage) {
                                ForEach(AppLanguage.allCases) { option in
                                    Text(option.nativeName).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 195)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8.5)

                        Divider().padding(.leading, 14)

                        HStack {
                            Text(L10n.t(.showHudLabel, lang: lang))
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: $settings.showHUDNotification)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8.5)
                    }
                }

                SettingsSectionHeader(L10n.t(.detectionSectionTitle, lang: lang))

                InsetGroupedCard {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.t(.tapTimeoutLabel, lang: lang))
                                .font(.system(size: 13))
                            Spacer()
                            Text("\(settings.tapTimeoutMs) ms")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.tapTimeoutMs) },
                                set: { settings.tapTimeoutMs = Int($0.rounded()) }
                            ),
                            in: Double(AppConstants.Timing.minTapTimeoutMs)...Double(AppConstants.Timing.maxTapTimeoutMs),
                            step: Double(AppConstants.Timing.tapTimeoutStepMs)
                        )
                        Text(L10n.t(.tapTimeoutDesc, lang: lang))
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                }

                SettingsSectionHeader(L10n.t(.permSectionTitle, lang: lang))

                InsetGroupedCard {
                    HStack(spacing: 8) {
                        Image(systemName: isEffectivelyTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isEffectivelyTrusted ? .green : .orange)

                        Text(L10n.t(isEffectivelyTrusted ? .permGranted : .permRequired, lang: lang))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)

                        Spacer()

                        Button(L10n.t(isEffectivelyTrusted ? .btnViewPermissionSettings : .btnOpenSystemSettings, lang: lang)) {
                            inputMonitoring.openInputMonitoringSettings(promptIfNeeded: !isEffectivelyTrusted)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8.5)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
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
