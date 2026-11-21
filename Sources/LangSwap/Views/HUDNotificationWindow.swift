import AppKit
import SwiftUI

@MainActor
private final class HUDViewModel: ObservableObject {
    @Published var side: CommandKeySide = .left
    @Published var item: InputSourceItem = .disabledItem
    @Published var lang: AppLanguage = .en
}

/// 言語切り替え時にフォーカスを奪わずに画面下部へ一時表示するミニHUDウィンドウ
@MainActor
public final class HUDNotificationController {
    public static let shared = HUDNotificationController()

    private let viewModel = HUDViewModel()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<HUDContentView>?
    private var hideWorkItem: DispatchWorkItem?
    private var displayGeneration: UInt64 = 0

    private init() {}

    /// 切り替え通知HUDを表示する
    public func show(side: CommandKeySide, item: InputSourceItem) {
        guard AppSettings.shared.showHUDNotification else { return }

        hideWorkItem?.cancel()
        displayGeneration &+= 1
        let currentGeneration = displayGeneration

        viewModel.side = side
        viewModel.item = item
        viewModel.lang = AppSettings.shared.appLanguage

        if panel == nil || hostingView == nil {
            let newHostingView = NSHostingView(rootView: HUDContentView(viewModel: viewModel))
            newHostingView.frame = NSRect(x: 0, y: 0, width: 240, height: 54)

            let newPanel = NSPanel(
                contentRect: newHostingView.frame,
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .statusBar
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true
            newPanel.ignoresMouseEvents = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            newPanel.contentView = newHostingView

            self.hostingView = newHostingView
            self.panel = newPanel
        }

        guard let panel = panel, let hostingView = hostingView else { return }

        // 進行中のフェードアウトアニメーションを即座にリセットする
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1.0
        }

        updatePanelFrame(panel: panel, hostingView: hostingView)
        panel.orderFrontRegardless()

        // SwiftUI状態反映後のサイズ変化にも追従して中央座標を再確定する
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self,
                      self.displayGeneration == currentGeneration,
                      let panel = self.panel,
                      let hostingView = self.hostingView else {
                    return
                }
                self.updatePanelFrame(panel: panel, hostingView: hostingView)
            }
        }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self,
                      self.displayGeneration == currentGeneration,
                      let panel = self.panel else {
                    return
                }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = AppConstants.Timing.hudFadeOutDurationSeconds
                    panel.animator().alphaValue = 0.0
                }, completionHandler: {
                    Task { @MainActor in
                        guard self.displayGeneration == currentGeneration else { return }
                        panel.orderOut(nil)
                    }
                })
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.Timing.hudDisplayDurationSeconds,
            execute: workItem
        )
    }

    private func updatePanelFrame(panel: NSPanel, hostingView: NSHostingView<HUDContentView>) {
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        if let screen = activeScreen {
            let visibleFrame = screen.visibleFrame
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
            let panelSize = hostingView.fittingSize
            let width = max(panelSize.width, 196)
            let height = max(panelSize.height, 50)
            let x = visibleFrame.midX - (width / 2)
            let y = visibleFrame.minY + AppConstants.Layout.hudBottomOffset
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }
    }
}

private struct HUDContentView: View {
    @ObservedObject var viewModel: HUDViewModel

    var body: some View {
        let lang = viewModel.lang
        HStack(spacing: 12) {
            Text(viewModel.item.badgeCode)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.item.localizedName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(viewModel.side == .left ? L10n.t(.leftTapLabel, lang: lang) : L10n.t(.rightTapLabel, lang: lang))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.11, opacity: 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .environment(\.layoutDirection, lang.isRTL ? .rightToLeft : .leftToRight)
    }
}
