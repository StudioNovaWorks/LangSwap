import SwiftUI
import AppKit

/// タブ4: 開発支援・クレジット・アプリ概要・使い方ガイド・よくあるトラブル
struct GuideTabView: View {
    @ObservedObject var settings = AppSettings.shared

    private var lang: AppLanguage { settings.appLanguage }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AppConstants.AppInfo.fallbackVersion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                SettingsSectionHeader(L10n.t(.supportTitle, lang: lang))

                InsetGroupedCard {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.pink)
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.pink.opacity(0.12))
                                )

                            Text(L10n.t(.supportDesc, lang: lang))
                                .font(.system(size: 12.5))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()

                            Button(L10n.t(.donateBtn, lang: lang)) {
                                if let url = URL(string: L10n.kofiURLString) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                        .padding(13)

                        Divider()
                            .padding(.horizontal, 13)
                            .opacity(0.7)

                        creditStripView
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                    }
                }

                SettingsSectionHeader(L10n.t(.guideOverviewTitle, lang: lang))

                InsetGroupedCard {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(AppConstants.AppInfo.fullTitle)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("v\(appVersion)")
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                            }
                            Text(L10n.t(.guideOverviewDesc, lang: lang))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(13)

                        Divider()
                            .padding(.horizontal, 13)
                            .opacity(0.7)

                        Button {
                            if let url = L10n.privacyPolicyURL(lang: lang) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.secondary)
                                Text(L10n.t(.privacyPolicyBtn, lang: lang))
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.88))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9.5)
                        }
                        .buttonStyle(OverviewLinkRowButtonStyle())
                        .help(L10n.privacyPolicyURLString)
                    }
                }

                SettingsSectionHeader(L10n.t(.guideStepsTitle, lang: lang))

                InsetGroupedCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t(.guideStep1, lang: lang))
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text(L10n.t(.guideStep2, lang: lang))
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text(L10n.t(.guideStep3, lang: lang))
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text(L10n.t(.guideStep4, lang: lang))
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(13)
                }

                SettingsSectionHeader(L10n.t(.guideTroubleshootTitle, lang: lang))

                InsetGroupedCard {
                    VStack(alignment: .leading, spacing: 10) {
                        troubleshootItem(
                            question: L10n.t(.troubleshootQ1, lang: lang),
                            answer: L10n.t(.troubleshootA1, lang: lang)
                        )
                        Divider()
                        troubleshootItem(
                            question: L10n.t(.troubleshootQ2, lang: lang),
                            answer: L10n.t(.troubleshootA2, lang: lang)
                        )
                        Divider()
                        troubleshootItem(
                            question: L10n.t(.troubleshootQ3, lang: lang),
                            answer: L10n.t(.troubleshootA3, lang: lang)
                        )
                        Divider()
                        troubleshootItem(
                            question: L10n.t(.troubleshootQ4, lang: lang),
                            answer: L10n.t(.troubleshootA4, lang: lang)
                        )
                        Divider()
                        troubleshootItem(
                            question: L10n.t(.troubleshootQ5, lang: lang),
                            answer: L10n.t(.troubleshootA5, lang: lang)
                        )
                        Divider()
                        troubleshootItem(
                            question: L10n.t(.troubleshootQ6, lang: lang),
                            answer: L10n.t(.troubleshootA6, lang: lang)
                        )
                    }
                    .padding(13)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
    }

    private var creditStripView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(L10n.t(.creditDevelopedBy, lang: lang))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)

            Text(AppConstants.Credits.studioName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary.opacity(0.84))
                .tracking(0.2)

            Spacer(minLength: 8)

            Text("© \(AppConstants.Credits.copyrightYear)")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func troubleshootItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12.5))
                    .foregroundColor(.accentColor)
                    .padding(.top, 1.5)
                Text(question)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(answer)
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 18.5)
        }
    }
}

private struct OverviewLinkRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.065) : Color.clear)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            )
            .contentShape(Rectangle())
    }
}
