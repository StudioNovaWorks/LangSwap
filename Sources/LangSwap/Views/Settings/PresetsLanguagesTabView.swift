import SwiftUI

/// タブ2: プリセット管理とmacOS入力ソースの検索・追加
struct PresetsLanguagesTabView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var sourceManager = InputSourceManager.shared
    @ObservedObject var uiState = SettingsUIState.shared

    private var lang: AppLanguage { settings.appLanguage }

    private var filteredInstallableSources: [InputSourceItem] {
        let all = sourceManager.installableSources
        let q = uiState.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { item in
            item.localizedName.lowercased().contains(q) ||
            item.localizedLanguageLabel(for: lang).lowercased().contains(q) ||
            item.badgeCode.lowercased().contains(q) ||
            item.id.lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(L10n.t(.presetSectionTitle, lang: lang))

                // プリセット管理カード
                InsetGroupedCard {
                    VStack(alignment: .leading, spacing: 0) {
                        if settings.presets.isEmpty {
                            Text(L10n.t(.presetEmptyHint, lang: lang))
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        } else {
                            ForEach(Array(settings.presets.enumerated()), id: \.element.id) { index, preset in
                                if index > 0 {
                                    Divider().padding(.leading, 14)
                                }
                                presetManagementRow(preset)
                            }
                        }
                    }
                }

                // 入力ソースの追加セクション
                HStack {
                    Text(L10n.t(.inputSourcesSectionTitle, lang: lang))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        sourceManager.refreshInputSources()
                        sourceManager.loadInstallableSources()
                    } label: {
                        Label(L10n.t(.btnRefresh, lang: lang), systemImage: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(L10n.t(.btnSystemKeyboard, lang: lang)) {
                        sourceManager.openSystemKeyboardSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                InsetGroupedCard {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                            TextField(L10n.t(.searchLanguagePlaceholder, lang: lang), text: $uiState.searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        LazyVStack(spacing: 0) {
                            ForEach(filteredInstallableSources) { item in
                                Divider().padding(.leading, 14)
                                HStack(spacing: 10) {
                                    LangCodeBadge(code: item.badgeCode)
                                    Text(item.cleanTitle(lang: lang))
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    Spacer()
                                    if item.isEnabled {
                                        let canDisable = sourceManager.canDisableInputSource(withID: item.id)
                                        HStack(spacing: 8) {
                                            Text(L10n.t(.badgeEnabled, lang: lang))
                                                .font(.system(size: 11.5, weight: .medium))
                                                .foregroundColor(.secondary)

                                            Button {
                                                sourceManager.disableInputSource(withID: item.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(canDisable ? .secondary : .secondary.opacity(0.35))
                                                    .frame(width: 26, height: 26)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                            .fill(Color.primary.opacity(canDisable ? 0.05 : 0.02))
                                                    )
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(!canDisable)
                                            .help(L10n.t(canDisable ? .deleteInputSourceTooltip : .deleteInputSourceProtectedTooltip, lang: lang))
                                        }
                                    } else {
                                        Button(L10n.t(.btnEnable, lang: lang)) {
                                            sourceManager.enableInputSource(withID: item.id)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .onAppear {
            if sourceManager.installableSources.isEmpty {
                sourceManager.loadInstallableSources()
            }
        }
    }

    private func presetManagementRow(_ preset: LanguagePreset) -> some View {
        let isCurrent = (settings.leftCommandSourceID == preset.leftCommandSourceID &&
                         settings.rightCommandSourceID == preset.rightCommandSourceID)
        let hasUnavailable = InputSourcePickerHelper.hasUnavailableSource(in: preset, manager: sourceManager)
        let leftBadge = sourceManager.item(forID: preset.leftCommandSourceID)?.badgeCode ?? "?"
        let rightBadge = sourceManager.item(forID: preset.rightCommandSourceID)?.badgeCode ?? "?"

        return HStack(spacing: 9) {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isCurrent ? .accentColor : .secondary)

            Text(InputSourcePickerHelper.presetDisplayName(for: preset, manager: sourceManager, lang: lang))
                .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                .lineLimit(1)

            Text("⌘L \(leftBadge) / ⌘R \(rightBadge)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)

            if hasUnavailable {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(L10n.t(.badgeUnavailable, lang: lang))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.14))
                )
            }

            Spacer()

            if isCurrent {
                Text(L10n.t(.badgeActive, lang: lang))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.accentColor)
            } else {
                Button(L10n.t(.btnApply, lang: lang)) {
                    settings.applyPreset(preset)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                settings.removePreset(preset)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.t(.deletePresetTooltip, lang: lang))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
