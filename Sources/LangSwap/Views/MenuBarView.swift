import SwiftUI
import AppKit

/// メニューバーアイコンをクリックした際に表示されるクイック設定ポップオーバービュー
public struct MenuBarView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var sourceManager = InputSourceManager.shared
    @ObservedObject var inputMonitoring = InputMonitoringService.shared
    @ObservedObject var monitor = CommandKeyEventMonitor.shared

    var onOpenSettings: (SettingsTab?) -> Void
    var onQuit: () -> Void

    private var lang: AppLanguage { settings.appLanguage }

    private var isEffectivelyTrusted: Bool {
        inputMonitoring.isTrusted && (!monitor.isMonitoring || monitor.isUsingCGEventTap)
    }

    private var leftAssignedItem: InputSourceItem {
        InputSourcePickerHelper.resolvedItem(for: settings.leftCommandSourceID, manager: sourceManager)
    }

    private var rightAssignedItem: InputSourceItem {
        InputSourcePickerHelper.resolvedItem(for: settings.rightCommandSourceID, manager: sourceManager)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Header
            HStack(spacing: 7) {
                AppIconBadgeView(size: 24)
                Text(AppConstants.AppInfo.name)
                    .font(.system(size: 13.5, weight: .bold))

                Spacer()

                Button {
                    onOpenSettings(.guide)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.t(.infoTooltip, lang: lang))

                Button {
                    if let url = URL(string: L10n.kofiURLString) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "heart")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.t(.kofiTooltip, lang: lang))

                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            if !isEffectivelyTrusted {
                Button {
                    onOpenSettings(.mapping)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12.5))
                        Text(L10n.t(.permBannerTitle, lang: lang))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10.5))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
            }

            // Left & Right Command Quick Pickers
            VStack(spacing: 7) {
                popoverKeyRow(
                    keyLabel: "⌘L",
                    assignedID: settings.leftCommandSourceID,
                    item: leftAssignedItem,
                    selection: $settings.leftCommandSourceID
                )
                popoverKeyRow(
                    keyLabel: "⌘R",
                    assignedID: settings.rightCommandSourceID,
                    item: rightAssignedItem,
                    selection: $settings.rightCommandSourceID
                )
            }

            // Quick Presets
            if !settings.presets.isEmpty {
                Divider()
                ScrollView(.vertical, showsIndicators: settings.presets.count > 4) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(settings.presets) { preset in
                            let isCurrent = (settings.leftCommandSourceID == preset.leftCommandSourceID &&
                                             settings.rightCommandSourceID == preset.rightCommandSourceID)
                            let hasUnavailable = InputSourcePickerHelper.hasUnavailableSource(in: preset, manager: sourceManager)
                            let displayName = InputSourcePickerHelper.presetDisplayName(for: preset, manager: sourceManager, lang: lang)
                            Button {
                                settings.applyPreset(preset)
                            } label: {
                                HStack(spacing: 7) {
                                    Text(displayName)
                                        .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                                        .lineLimit(1)
                                    Spacer()
                                    if hasUnavailable {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(isCurrent ? .white : .orange)
                                    }
                                    if isCurrent {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .foregroundColor(isCurrent ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                                        .fill(isCurrent ? Color.accentColor : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(hasUnavailable ? "\(displayName) (\(L10n.t(.badgeUnavailable, lang: lang)))" : displayName)
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(settings.presets.count) * 34, 152))
            }

            Divider()

            // Footer Actions
            HStack {
                Button {
                    onOpenSettings(nil)
                } label: {
                    Text(L10n.t(.openSettings, lang: lang))
                        .font(.system(size: 12.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onQuit()
                } label: {
                    Text(L10n.t(.quitApp, lang: lang))
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: AppConstants.Layout.popoverWidth)
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }

    private func popoverKeyRow(
        keyLabel: String,
        assignedID: String,
        item: InputSourceItem,
        selection: Binding<String>
    ) -> some View {
        let options = InputSourcePickerHelper.options(for: assignedID, manager: sourceManager)
        let isUnavailable = InputSourcePickerHelper.isUnavailable(sourceID: assignedID, manager: sourceManager)
        return HStack(spacing: 8) {
            Text(keyLabel)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 26, alignment: .leading)

            Spacer()

            if isUnavailable {
                Button {
                    onOpenSettings(.presets)
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11.5))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help(L10n.t(.badgeUnavailable, lang: lang))
            }

            LangCodeBadge(code: item.badgeCode)

            Picker(keyLabel, selection: selection) {
                ForEach(options) { option in
                    Text(InputSourcePickerHelper.pickerTitle(for: option, short: true, lang: lang)).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 162)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
