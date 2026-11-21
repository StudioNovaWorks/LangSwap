import Foundation
import CoreGraphics

/// CommandLineTools環境（XCTest非搭載環境）でも全ロジックを自動検証できるセルフテストランナー
@MainActor
public enum SelfTestRunner {
    public static func runAllTests() -> Bool {
        print("🧪 Running LangSwap Self-Tests...")
        var passed = 0
        var failed = 0

        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            if condition() {
                print("  ✅ PASS: \(name)")
                passed += 1
            } else {
                print("  ❌ FAIL: \(name)")
                failed += 1
            }
        }

        // 1. Left Command standalone tap
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            let r1 = detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 10.0)
            let r2 = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 10.12)
            check(r1 == nil && r2 == .left && detector.state == .idle, "Left Command standalone tap triggers .left")
        }

        // 2. Right Command standalone tap
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            let r1 = detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 20.0)
            let r2 = detector.handleFlagsChanged(keyCode: 54, isCommandDown: false, hasOtherModifiers: false, timestamp: 20.18)
            check(r1 == nil && r2 == .right && detector.state == .idle, "Right Command standalone tap triggers .right")
        }

        // 3. Command + Key shortcut cancellation (e.g. ⌘+C)
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
            detector.handleOtherKeyDown()
            let r2 = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
            check(r2 == nil && detector.state == .idle, "Command + regular key (⌘+C) cancels language switch")
        }

        // 4. Command + Other modifier cancellation (e.g. ⌘+Shift)
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
            detector.handleFlagsChanged(keyCode: 56, isCommandDown: true, hasOtherModifiers: true, timestamp: 1.05)
            detector.handleFlagsChanged(keyCode: 56, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.10)
            let r2 = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
            check(r2 == nil && detector.state == .idle, "Command + Shift cancels language switch")
        }

        // 5. Fn / Globe modifier cancels single tap, CapsLock does not block
        do {
            let fnFlags: CGEventFlags = [.maskCommand, .maskSecondaryFn]
            let capsFlags: CGEventFlags = [.maskCommand, .maskAlphaShift]
            check(CommandKeyTapDetector.hasOtherModifiers(in: fnFlags) == true, "Fn / Globe modifier detected as other modifier")
            check(CommandKeyTapDetector.hasOtherModifiers(in: capsFlags) == false, "CapsLock does not block Command standalone tap")

            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
            detector.handleFlagsChanged(keyCode: 63, isCommandDown: true, hasOtherModifiers: CommandKeyTapDetector.hasOtherModifiers(in: fnFlags), timestamp: 1.05)
            let r = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
            check(r == nil && detector.state == .idle, "Command + Fn cancels language switch")
        }

        // 6. Simultaneous Left + Right Command 4-event release sequence
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
            detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.05)
            let r1 = detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.10)
            let r2 = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
            check(r1 == nil && r2 == nil && detector.state == .idle, "Both Command keys full 4-event release cancels switch cleanly")
        }

        // 7. Exact timeout boundary & long press timeout cancellation
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
            let exactBoundary = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.4)
            check(exactBoundary == .left && detector.state == .idle, "Exact timeout boundary (elapsed == 0.4s) triggers switch")

            detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 5.0)
            let overBoundary = detector.handleFlagsChanged(keyCode: 54, isCommandDown: false, hasOtherModifiers: false, timestamp: 5.55)
            check(overBoundary == nil && detector.state == .idle, "Long hold (>400ms) cancels language switch")
        }

        // 8. Mouse click / drag cancellation
        do {
            let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
            detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
            detector.handleMouseInteraction()
            let r2 = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
            check(r2 == nil && detector.state == .idle, "Command + mouse click/drag cancels language switch")
        }

        // 9. Multi-language models, Roman/Alphanumeric IME fix, & AppSettings defaults / presets
        do {
            let us = InputSourceItem(id: "com.apple.keylayout.US", localizedName: "U.S.", sourceType: "TISTypeKeyboardLayout", languages: ["en"])
            let ja = InputSourceItem(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", localizedName: "Hiragana", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"])
            let kotoeriRoman = InputSourceItem(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman", localizedName: "Romaji", sourceType: "TISTypeKeyboardInputMode", languages: ["en"])
            let googleRoman = InputSourceItem(id: "com.google.inputmethod.Japanese.Roman", localizedName: "Alphanumeric (Google)", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"])
            let kotoeriFullWidthRoman = InputSourceItem(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.FullWidthRoman", localizedName: "Full-width Romaji", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"])
            let googleFullWidthRoman = InputSourceItem(id: "com.google.inputmethod.Japanese.FullWidthRoman", localizedName: "Full-width Alphanumeric (Google)", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"])
            let de = InputSourceItem(id: "com.apple.keylayout.German", localizedName: "German", sourceType: "TISTypeKeyboardLayout", languages: ["de"])
            let es = InputSourceItem(id: "com.apple.keylayout.Spanish", localizedName: "Spanish", sourceType: "TISTypeKeyboardLayout", languages: ["es"])

            check(kotoeriRoman.badgeCode == "EN" && kotoeriRoman.isEnglishLike && !kotoeriRoman.isJapaneseLike, "Kotoeri Roman mode classified as EN (not JA)")
            check(googleRoman.badgeCode == "EN" && googleRoman.isEnglishLike && !googleRoman.isJapaneseLike, "Google Japanese Roman mode classified as EN (not JA)")
            check(
                !kotoeriFullWidthRoman.isJapaneseRomanOrAlphanumericMode &&
                kotoeriFullWidthRoman.badgeCode == "JA" &&
                !kotoeriFullWidthRoman.isEnglishLike &&
                kotoeriFullWidthRoman.isJapaneseLike,
                "Kotoeri FullWidthRoman mode excluded from EN/Roman and classified as JA"
            )
            check(
                !googleFullWidthRoman.isJapaneseRomanOrAlphanumericMode &&
                googleFullWidthRoman.badgeCode == "JA" &&
                !googleFullWidthRoman.isEnglishLike &&
                googleFullWidthRoman.isJapaneseLike,
                "Google FullWidthRoman mode excluded from EN/Roman and classified as JA"
            )

            let suiteName = "LangSwapSelfTest_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: suiteName)!
            let settings = AppSettings(defaults: testDefaults, loginItemStatusProvider: { .notRegistered })
            settings.appLanguage = .en
            settings.applySmartDefaultsIfNeeded(availableSources: [us, ja, de, es], preferredLanguages: ["ja-JP", "en-US"])

            check(settings.leftCommandSourceID == us.id && settings.rightCommandSourceID == ja.id, "Smart defaults assign Left ⌘ = English, Right ⌘ = Japanese for ja-JP locale")
            check(settings.presets.isEmpty && settings.hasInitializedDefaults, "Initial launch does not auto-create any presets")

            // German locale smart defaults
            let deSuite = "LangSwapSelfTest_DE_\(UUID().uuidString)"
            let deDefaults = UserDefaults(suiteName: deSuite)!
            let deSettings = AppSettings(defaults: deDefaults, loginItemStatusProvider: { .notRegistered })
            deSettings.applySmartDefaultsIfNeeded(availableSources: [us, ja, de, es], preferredLanguages: ["de-DE", "en-US"])
            check(deSettings.leftCommandSourceID == us.id && deSettings.rightCommandSourceID == de.id && deSettings.presets.isEmpty, "Smart defaults assign Left ⌘ = English, Right ⌘ = German for de-DE locale")
            deDefaults.removePersistentDomain(forName: deSuite)

            // Traditional Chinese locale smart defaults
            let zhHans = InputSourceItem(id: "com.apple.inputmethod.SCIM.ITABC", localizedName: "Pinyin - Simplified", sourceType: "TISTypeKeyboardInputMode", languages: ["zh-Hans"])
            let zhHant = InputSourceItem(id: "com.apple.inputmethod.TCIM.Zhuyin", localizedName: "Zhuyin", sourceType: "TISTypeKeyboardInputMode", languages: ["zh-Hant"])
            let twSuite = "LangSwapSelfTest_TW_\(UUID().uuidString)"
            let twDefaults = UserDefaults(suiteName: twSuite)!
            let twSettings = AppSettings(defaults: twDefaults, loginItemStatusProvider: { .notRegistered })
            twSettings.applySmartDefaultsIfNeeded(availableSources: [us, zhHans, zhHant], preferredLanguages: ["zh-Hant-TW", "en-US"])
            check(twSettings.leftCommandSourceID == us.id && twSettings.rightCommandSourceID == zhHant.id, "Smart defaults distinguish zh-Hant vs zh-Hans")
            twDefaults.removePersistentDomain(forName: twSuite)

            // English-only locale falls back to first non-English source
            let enSuite = "LangSwapSelfTest_EN_\(UUID().uuidString)"
            let enDefaults = UserDefaults(suiteName: enSuite)!
            let enSettings = AppSettings(defaults: enDefaults, loginItemStatusProvider: { .notRegistered })
            enSettings.applySmartDefaultsIfNeeded(availableSources: [us, es], preferredLanguages: ["en-US"])
            check(enSettings.leftCommandSourceID == us.id && enSettings.rightCommandSourceID == es.id, "English-only locale falls back Right ⌘ to first non-English source")
            enDefaults.removePersistentDomain(forName: enSuite)

            settings.addPreset(name: "U.S. ↔ Hiragana", isCustomName: false)
            settings.leftCommandSourceID = de.id
            settings.rightCommandSourceID = ja.id
            settings.addPreset(name: "ドイツ語 ↔ 日本語")
            check(settings.presets.contains(where: { $0.name == "ドイツ語 ↔ 日本語" && $0.leftCommandSourceID == de.id }), "Custom language preset (German ↔ Japanese) saved and verified")

            // Duplicate pair should NOT add a second entry and should move existing preset to index 0
            let countBeforeDup = settings.presets.count
            settings.leftCommandSourceID = us.id
            settings.rightCommandSourceID = ja.id
            settings.addPreset(name: "EN ↔ JA", isCustomName: false)
            check(settings.presets.count == countBeforeDup && settings.presets.first?.leftCommandSourceID == us.id && settings.presets.first?.rightCommandSourceID == ja.id, "Duplicate language pair moves existing preset to front without duplicating")

            // Remove preset works
            if let dePreset = settings.presets.first(where: { $0.leftCommandSourceID == de.id }) {
                settings.removePreset(dePreset)
            }
            check(!settings.presets.contains(where: { $0.leftCommandSourceID == de.id }), "removePreset deletes preset")

            // Pre-existing duplicate presets in UserDefaults get deduplicated on init
            let dupList = [
                LanguagePreset(name: "First EN-JA", leftCommandSourceID: us.id, rightCommandSourceID: ja.id),
                LanguagePreset(name: "Dup EN-JA", leftCommandSourceID: us.id, rightCommandSourceID: ja.id),
                LanguagePreset(name: "ES-EN", leftCommandSourceID: es.id, rightCommandSourceID: us.id)
            ]
            if let dupData = try? JSONEncoder().encode(dupList) {
                testDefaults.set(dupData, forKey: "LangSwap.presets")
            }
            let dedupReloaded = AppSettings(defaults: testDefaults, loginItemStatusProvider: { .notRegistered })
            check(dedupReloaded.presets.count == 2 && dedupReloaded.presets.first?.name == "First EN-JA", "Pre-existing duplicate presets deduplicate on load")

            settings.swapLeftAndRightSources()
            check(settings.leftCommandSourceID == ja.id && settings.rightCommandSourceID == us.id, "Swap Left and Right Command sources works")
            check(settings.launchInBackground == false, "launchInBackground defaults to false")
            check(!settings.launchAtLogin && !settings.launchAtLoginNeedsApproval && !settings.launchAtLoginError, "Login item flags reflect .notRegistered provider deterministically")

            let approvalSuite = "LangSwapSelfTest_Approval_\(UUID().uuidString)"
            let approvalDefaults = UserDefaults(suiteName: approvalSuite)!
            let approvalSettings = AppSettings(defaults: approvalDefaults, loginItemStatusProvider: { .requiresApproval })
            check(!approvalSettings.launchAtLogin && approvalSettings.launchAtLoginNeedsApproval && !approvalSettings.launchAtLoginError, "Login item approval flag reflects .requiresApproval provider deterministically")
            approvalDefaults.removePersistentDomain(forName: approvalSuite)

            settings.launchInBackground = true
            settings.appTheme = .dark
            settings.appLanguage = .fr
            let reloaded = AppSettings(defaults: testDefaults, loginItemStatusProvider: { .notRegistered })
            check(reloaded.launchInBackground == true && reloaded.appTheme == .dark && reloaded.appLanguage == .fr, "Background launch, theme, and language persist")

            check(
                AppTheme.system.nsAppearance == nil &&
                AppTheme.light.nsAppearance?.name == .aqua &&
                AppTheme.dark.nsAppearance?.name == .darkAqua,
                "AppTheme nsAppearance maps system/light/dark correctly"
            )

            check(us.badgeCode == "EN" && ja.badgeCode == "JA" && de.badgeCode == "DE" && InputSourceItem.disabledItem.badgeCode == "OFF", "InputSourceItem badgeCode formatting works")
            check(InputSourceItem.disabledItem.localizedName == "Disabled", "disabledItem fallback localizedName is English")

            let offPreset = LanguagePreset(name: "Stored", leftCommandSourceID: InputSourceItem.disabledID, rightCommandSourceID: InputSourceItem.disabledID)
            let unknownPreset = LanguagePreset(name: "Custom Fallback", leftCommandSourceID: "com.unknown.source.a", rightCommandSourceID: "com.unknown.source.b")
            let partialPreset = LanguagePreset(name: "Partial", leftCommandSourceID: us.id, rightCommandSourceID: ja.id)
            let unavailableJa = InputSourceItem(id: ja.id, localizedName: "Hiragana", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"], isEnabled: false)
            check(
                InputSourcePickerHelper.presetDisplayName(for: offPreset, manager: .shared, lang: .ja) == "無効 ↔ 無効" &&
                InputSourcePickerHelper.presetDisplayName(for: offPreset, manager: .shared, lang: .en) == "Off ↔ Off" &&
                InputSourcePickerHelper.presetDisplayName(for: unknownPreset, manager: .shared, lang: .en) == "Custom Fallback",
                "Preset display name dynamically localizes known IDs and falls back safely"
            )
            check(
                !InputSourcePickerHelper.isUnavailable(sourceID: us.id, enabledSourceIDs: [us.id]) &&
                !InputSourcePickerHelper.isUnavailable(sourceID: InputSourceItem.disabledID, enabledSourceIDs: [us.id]) &&
                InputSourcePickerHelper.isUnavailable(sourceID: ja.id, enabledSourceIDs: [us.id]) &&
                InputSourcePickerHelper.hasUnavailableSource(in: partialPreset, enabledSourceIDs: [us.id]) &&
                !InputSourcePickerHelper.hasUnavailableSource(in: partialPreset, enabledSourceIDs: [us.id, ja.id]) &&
                InputSourcePickerHelper.pickerTitle(for: us, lang: .en) == "U.S." &&
                InputSourcePickerHelper.pickerTitle(for: .disabledItem, lang: .en) == "Disabled (No Action)" &&
                InputSourcePickerHelper.pickerTitle(for: unavailableJa, short: true, lang: .ja) == "Hiragana (未追加)",
                "InputSourcePickerHelper detects unavailable sources and formats picker titles accurately"
            )

            testDefaults.removePersistentDomain(forName: suiteName)
        }

        // 10. 18-language localization & English fallback
        do {
            check(AppLanguage.allCases.count == 18, "Exactly 18 languages supported")
            check(L10nKey.allCases.count == 103, "Localization schema contains all 103 keys")
            check(L10n.hasCompleteCoverage(), "All 18 languages have complete localization coverage")
            check(L10n.t(.statusActive, lang: .ja) == "起動中", "Japanese active status uses 起動中")
            check(L10n.t(.themeSystem, lang: .ja) == "システム", "Japanese system theme label is concise")
            check(AppLanguage.pt.localeIdentifier == "pt_BR", "Portuguese locale identifier uses pt_BR")
            check(L10n.t(.disabledShort, lang: .es) == "Desact.", "Spanish disabledShort uses Desact.")
            check(L10n.t(.guideStep4, lang: .ar).contains("أسفل اليسار"), "Arabic guideStep4 references RTL bottom-left quit button")
            let hasNoLegacyName = AppLanguage.allCases.allSatisfy { l in
                L10nKey.allCases.allSatisfy { k in !L10n.t(k, lang: l).contains("LangChanger") }
            }
            check(hasNoLegacyName, "No legacy LangChanger brand name remains in any of the 18 localizations")
            let hasNoAccessibilityTerms = AppLanguage.allCases.allSatisfy { l in
                L10nKey.allCases.allSatisfy { k in
                    let val = L10n.t(k, lang: l)
                    return !val.localizedCaseInsensitiveContains("accessibility") && !val.contains("アクセシビリティ")
                }
            }
            check(hasNoAccessibilityTerms, "All 18 localizations use Input Monitoring terminology without Accessibility references")
            check(
                AppConstants.Credits.studioName == "Studio Nova Works" && !AppConstants.Credits.copyrightYear.isEmpty,
                "Studio credit constants are configured"
            )
            check(
                L10n.privacyPolicyURL(lang: .ja)?.absoluteString == "https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html?lang=ja",
                "Privacy policy URL includes localized language query parameter"
            )
            check(AppLanguage.detectDefault(preferredLanguages: ["ja-JP"]) == .ja, "Detects Japanese locale")
            check(AppLanguage.detectDefault(preferredLanguages: ["zh-Hans-CN"]) == .zh_CN, "Detects Simplified Chinese locale")
            check(AppLanguage.detectDefault(preferredLanguages: ["zh-Hant-TW"]) == .zh_TW, "Detects Traditional Chinese locale")
            check(AppLanguage.detectDefault(preferredLanguages: ["sv-SE"]) == .en, "Unsupported locale (sv-SE) falls back to English")
            check(AppLanguage.detectDefault(preferredLanguages: ["nl-NL"]) == .en, "Unsupported locale (nl-NL) falls back to English")
            check(AppLanguage.detectDefault(preferredLanguages: []) == .en, "Empty preferredLanguages falls back to English")
        }

        // 11. System InputSourceManager live query (including post-installable HIToolbox cache pollution test)
        do {
            let manager = InputSourceManager.shared
            manager.refreshInputSources()
            let enabledBefore = Set(manager.enabledSources.map(\.id))
            manager.loadInstallableSources()
            manager.refreshInputSources()
            let enabledAfter = Set(manager.enabledSources.map(\.id))
            let installableEnabledIDs = Set(manager.installableSources.filter(\.isEnabled).map(\.id))
            check(!enabledBefore.isEmpty, "InputSourceManager detected \(enabledBefore.count) enabled macOS input sources")
            check(
                enabledBefore == enabledAfter,
                "Enabled input sources stay consistent after loadInstallableSources() (\(enabledAfter.count) enabled)"
            )
            check(
                enabledAfter == installableEnabledIDs,
                "Installable list enabled status matches active macOS input sources (\(installableEnabledIDs.count) enabled)"
            )
            for src in manager.enabledSources {
                print("     • Detected source: [\(src.badgeCode)] \(src.cleanTitle(lang: .ja)) [\(src.id)]")
            }

            let asciiUS = InputSourceItem(id: "com.apple.keylayout.US", localizedName: "U.S.", sourceType: "TISTypeKeyboardLayout", languages: ["en"], isEnabled: true, isASCIICapable: true)
            let asciiDE = InputSourceItem(id: "com.apple.keylayout.German", localizedName: "German", sourceType: "TISTypeKeyboardLayout", languages: ["de"], isEnabled: true, isASCIICapable: true)
            let nonAsciiJA = InputSourceItem(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", localizedName: "Hiragana", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"], isEnabled: true, isASCIICapable: false)
            let protectionOK =
                !InputSourceManager.canDisable(sourceID: asciiUS.id, in: [asciiUS]) &&
                !InputSourceManager.canDisable(sourceID: asciiUS.id, in: [asciiUS, nonAsciiJA]) &&
                InputSourceManager.canDisable(sourceID: nonAsciiJA.id, in: [asciiUS, nonAsciiJA]) &&
                InputSourceManager.canDisable(sourceID: asciiUS.id, in: [asciiUS, asciiDE, nonAsciiJA]) &&
                InputSourceManager.canDisable(sourceID: asciiDE.id, in: [asciiUS, asciiDE, nonAsciiJA]) &&
                InputSourceManager.canDisable(sourceID: nonAsciiJA.id, in: [asciiUS, asciiDE, nonAsciiJA])
            check(protectionOK, "InputSourceManager protects last input source and sole ASCII source from removal")
        }

        print("📊 Results: \(passed) passed, \(failed) failed.")
        return failed == 0
    }
}
