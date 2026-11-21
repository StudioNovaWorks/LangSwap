import SwiftUI
import AppKit

/// タブ1: 左右Commandキーの割り当て・プレビュー・クイックプリセット
struct KeyMappingTabView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var sourceManager = InputSourceManager.shared
    @ObservedObject var uiState = SettingsUIState.shared

    private var lang: AppLanguage { settings.appLanguage }

    private var leftAssignedItem: InputSourceItem {
        InputSourcePickerHelper.resolvedItem(for: settings.leftCommandSourceID, manager: sourceManager)
    }

    private var rightAssignedItem: InputSourceItem {
        InputSourcePickerHelper.resolvedItem(for: settings.rightCommandSourceID, manager: sourceManager)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                compactKeyPreviewBar

                // Inset Grouped Card: 左右Command割り当て
                InsetGroupedCard {
                    VStack(spacing: 0) {
                        assignmentRow(
                            label: L10n.t(.leftCommand, lang: lang),
                            assignedID: settings.leftCommandSourceID,
                            item: leftAssignedItem,
                            selection: $settings.leftCommandSourceID
                        )
                        Divider().padding(.leading, 14)
                        assignmentRow(
                            label: L10n.t(.rightCommand, lang: lang),
                            assignedID: settings.rightCommandSourceID,
                            item: rightAssignedItem,
                            selection: $settings.rightCommandSourceID
                        )
                        Divider().padding(.leading, 14)
                        HStack {
                            Spacer()
                            Button {
                                settings.swapLeftAndRightSources()
                            } label: {
                                Label(L10n.t(.swapKeys, lang: lang), systemImage: "arrow.left.arrow.right")
                                    .font(.system(size: 12.5, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                    }
                }

                // クイックプリセットチップ
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(L10n.t(.presetsHeader, lang: lang))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            let name = "\(leftAssignedItem.cleanShortName(lang: lang)) ↔ \(rightAssignedItem.cleanShortName(lang: lang))"
                            settings.addPreset(name: name, isCustomName: false)
                        } label: {
                            Label(L10n.t(.saveCurrentPair, lang: lang), systemImage: "plus")
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }

                    if settings.presets.isEmpty {
                        Text(L10n.t(.presetEmptyHint, lang: lang))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(settings.presets) { preset in
                                    presetChip(preset)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // 起動設定カード（自動起動・バックグラウンド起動）
                InsetGroupedCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text(L10n.t(.launchAtLogin, lang: lang))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
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
                        .padding(.vertical, 10)

                        LoginItemStatusHintView(settings: settings, lang: lang)

                        Divider().padding(.leading, 14)

                        HStack {
                            Text(L10n.t(.launchInBackground, lang: lang))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            Spacer()
                            Toggle("", isOn: $settings.launchInBackground)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                quitFooterView
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    private var quitFooterView: some View {
        VStack(spacing: 10) {
            Divider()
                .opacity(0.6)

            HStack {
                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(L10n.t(.menuQuit, lang: lang), systemImage: "power")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("\(L10n.t(.menuQuit, lang: lang)) (⌘Q)")
            }
        }
        .padding(.top, 4)
    }

    private var compactKeyPreviewBar: some View {
        HStack(spacing: 7) {
            compactKeyCap(
                keyLabel: "⌘L",
                badge: leftAssignedItem.badgeCode,
                isHighlighted: uiState.highlightedSide == .left,
                isLeft: true
            )

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
                .frame(width: 96, height: 40)
                .overlay(
                    Text("space")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.75))
                )

            compactKeyCap(
                keyLabel: "⌘R",
                badge: rightAssignedItem.badgeCode,
                isHighlighted: uiState.highlightedSide == .right,
                isLeft: false
            )
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .environment(\.layoutDirection, .leftToRight)
    }

    private func compactKeyCap(keyLabel: String, badge: String, isHighlighted: Bool, isLeft: Bool) -> some View {
        HStack {
            if isLeft {
                Text(keyLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isHighlighted ? .white : .primary)
                Spacer()
                LangCodeBadge(code: badge, highlighted: isHighlighted)
            } else {
                LangCodeBadge(code: badge, highlighted: isHighlighted)
                Spacer()
                Text(keyLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isHighlighted ? .white : .primary)
            }
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHighlighted ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Color.accentColor : Color.primary.opacity(0.14),
                    lineWidth: isHighlighted ? 1.5 : 1
                )
        )
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
    }

    private func assignmentRow(
        label: String,
        assignedID: String,
        item: InputSourceItem,
        selection: Binding<String>
    ) -> some View {
        let options = InputSourcePickerHelper.options(for: assignedID, manager: sourceManager)
        let isUnavailable = InputSourcePickerHelper.isUnavailable(sourceID: assignedID, manager: sourceManager)
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 118, maxWidth: .infinity, alignment: .leading)

            if isUnavailable {
                Button {
                    uiState.selectedTab = .presets
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12.5))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help(L10n.t(.badgeUnavailable, lang: lang))
            }

            LangCodeBadge(code: item.badgeCode)

            Picker(label, selection: selection) {
                ForEach(options) { option in
                    Text(InputSourcePickerHelper.pickerTitle(for: option, short: false, lang: lang)).tag(option.id)
                }
            }
            .labelsHidden()
            .frame(width: 245)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func presetChip(_ preset: LanguagePreset) -> some View {
        let isCurrent = (settings.leftCommandSourceID == preset.leftCommandSourceID &&
                         settings.rightCommandSourceID == preset.rightCommandSourceID)
        let hasUnavailable = InputSourcePickerHelper.hasUnavailableSource(in: preset, manager: sourceManager)
        let leftBadge = sourceManager.item(forID: preset.leftCommandSourceID)?.badgeCode ?? "?"
        let rightBadge = sourceManager.item(forID: preset.rightCommandSourceID)?.badgeCode ?? "?"
        let presetHelp = InputSourcePickerHelper.presetDisplayName(for: preset, manager: sourceManager, lang: lang)

        return HStack(spacing: 4) {
            Button {
                settings.applyPreset(preset)
            } label: {
                HStack(spacing: 6) {
                    if hasUnavailable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isCurrent ? .white : .orange)
                    } else {
                        Circle()
                            .fill(isCurrent ? Color.white : Color.secondary.opacity(0.45))
                            .frame(width: 6, height: 6)
                    }
                    Text("\(leftBadge) ↔ \(rightBadge)")
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                }
                .padding(.leading, 11)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(hasUnavailable ? "\(presetHelp) (\(L10n.t(.badgeUnavailable, lang: lang)))" : presetHelp)

            Button {
                settings.removePreset(preset)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(isCurrent ? Color.white.opacity(0.85) : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isCurrent ? Color.white.opacity(0.18) : Color.primary.opacity(0.06))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .help(L10n.t(.deletePresetTooltip, lang: lang))
        }
        .foregroundColor(isCurrent ? .white : .primary)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCurrent ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isCurrent ? Color.accentColor : (hasUnavailable ? Color.orange.opacity(0.45) : Color.primary.opacity(0.14)),
                    lineWidth: 1
                )
        )
        .contextMenu {
            Button(role: .destructive) {
                settings.removePreset(preset)
            } label: {
                Label(L10n.t(.deleteMenuAction, lang: lang), systemImage: "trash")
            }
        }
    }
}
