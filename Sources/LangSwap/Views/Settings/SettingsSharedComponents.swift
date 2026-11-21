import SwiftUI
import AppKit

/// macOS標準サイドバーの半透明マテリアル (Vibrancy) 背景
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// macOS システム設定風のインセット・グループカード
struct InsetGroupedCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
            )
    }
}

/// セクション見出し
struct SettingsSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 2)
            .padding(.bottom, -6)
    }
}

/// バンドル内の AppIcon.icns を表示するアプリアイコンバッジ（非バンドル実行時は SF Symbol フォールバック）
public struct AppIconBadgeView: View {
    public let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    private static let bundledIcon: NSImage? = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }()

    public var body: some View {
        if let icon = Self.bundledIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.primary.opacity(0.10))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "command")
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundColor(.primary)
                )
        }
    }
}

/// 国旗絵文字の代わりに使用するモノスペース言語コードバッジ
public struct LangCodeBadge: View {
    public let code: String
    public var highlighted: Bool = false

    public init(code: String, highlighted: Bool = false) {
        self.code = code
        self.highlighted = highlighted
    }

    public var body: some View {
        Text(code)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(highlighted ? .white : .primary)
            .padding(.horizontal, 6.5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(highlighted ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(highlighted ? Color.white.opacity(0.25) : Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

/// 入力監視権限未許可時の目立つ上段バナー
struct PermissionBannerView: View {
    let lang: AppLanguage
    let onRecheck: () -> Void
    let onRelaunch: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(.permBannerTitle, lang: lang))
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.primary)

                    Text(L10n.t(.permBannerBody, lang: lang))
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.t(.permBannerUpdateHint, lang: lang))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Spacer()

                Button(L10n.t(.btnRecheck, lang: lang), action: onRecheck)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button(L10n.t(.btnRelaunch, lang: lang), action: onRelaunch)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                Button(L10n.t(.btnOpenSystemSettings, lang: lang), action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.regular)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1)
        )
    }
}

/// Picker選択肢・未検出IDの整合性を保つためのヘルパー
@MainActor
enum InputSourcePickerHelper {
    static func options(for assignedID: String, manager: InputSourceManager) -> [InputSourceItem] {
        var list = manager.enabledSources + [.disabledItem]
        if !assignedID.isEmpty &&
            assignedID != InputSourceItem.disabledID &&
            !list.contains(where: { $0.id == assignedID }) {
            let resolved = manager.item(forID: assignedID)
            let missingItem = resolved.map {
                InputSourceItem(
                    id: $0.id,
                    localizedName: $0.localizedName,
                    sourceType: $0.sourceType,
                    languages: $0.languages,
                    isEnabled: false,
                    isASCIICapable: $0.isASCIICapable
                )
            } ?? InputSourceItem(id: assignedID, localizedName: assignedID, isEnabled: false)
            list.append(missingItem)
        }
        return list
    }

    static func resolvedItem(for assignedID: String, manager: InputSourceManager) -> InputSourceItem {
        if assignedID.isEmpty || assignedID == InputSourceItem.disabledID {
            return .disabledItem
        }
        return manager.item(forID: assignedID)
            ?? InputSourceItem(id: assignedID, localizedName: assignedID, isEnabled: false)
    }

    static func isUnavailable(sourceID: String, enabledSourceIDs: Set<String>) -> Bool {
        !sourceID.isEmpty &&
            sourceID != InputSourceItem.disabledID &&
            !enabledSourceIDs.contains(sourceID)
    }

    static func isUnavailable(sourceID: String, manager: InputSourceManager) -> Bool {
        let enabledIDs = Set(manager.enabledSources.map(\.id))
        return isUnavailable(sourceID: sourceID, enabledSourceIDs: enabledIDs)
    }

    static func hasUnavailableSource(in preset: LanguagePreset, enabledSourceIDs: Set<String>) -> Bool {
        isUnavailable(sourceID: preset.leftCommandSourceID, enabledSourceIDs: enabledSourceIDs) ||
            isUnavailable(sourceID: preset.rightCommandSourceID, enabledSourceIDs: enabledSourceIDs)
    }

    static func hasUnavailableSource(in preset: LanguagePreset, manager: InputSourceManager) -> Bool {
        let enabledIDs = Set(manager.enabledSources.map(\.id))
        return hasUnavailableSource(in: preset, enabledSourceIDs: enabledIDs)
    }

    static func pickerTitle(for option: InputSourceItem, short: Bool = false, lang: AppLanguage) -> String {
        let baseTitle = short ? option.cleanShortName(lang: lang) : option.cleanTitle(lang: lang)
        if option.id != InputSourceItem.disabledID && !option.isEnabled {
            return "\(baseTitle) (\(L10n.t(.badgeUnavailable, lang: lang)))"
        }
        return baseTitle
    }

    static func presetDisplayName(for preset: LanguagePreset, manager: InputSourceManager, lang: AppLanguage) -> String {
        let leftKnown = preset.leftCommandSourceID == InputSourceItem.disabledID || manager.item(forID: preset.leftCommandSourceID) != nil
        let rightKnown = preset.rightCommandSourceID == InputSourceItem.disabledID || manager.item(forID: preset.rightCommandSourceID) != nil
        if leftKnown && rightKnown {
            let leftItem = resolvedItem(for: preset.leftCommandSourceID, manager: manager)
            let rightItem = resolvedItem(for: preset.rightCommandSourceID, manager: manager)
            return "\(leftItem.cleanShortName(lang: lang)) ↔ \(rightItem.cleanShortName(lang: lang))"
        }
        return preset.name
    }
}

/// ログイン項目の承認待ち・登録失敗時に案内とシステム設定リンクを表示する共通ビュー
struct LoginItemStatusHintView: View {
    @ObservedObject var settings: AppSettings
    let lang: AppLanguage

    var body: some View {
        if settings.launchAtLoginNeedsApproval || settings.launchAtLoginError {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12.5))
                    .foregroundColor(.orange)

                Text(L10n.t(settings.launchAtLoginNeedsApproval ? .launchAtLoginApprovalHint : .launchAtLoginErrorHint, lang: lang))
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Button(L10n.t(.btnOpenLoginItems, lang: lang)) {
                    settings.openLoginItemsSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }
}
