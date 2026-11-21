import XCTest
@testable import LangSwap

final class CommandKeyLogicTests: XCTestCase {

    func testLeftCommandStandaloneTapTriggersLeft() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Left Command (55) down at t = 10.0
        let downResult = detector.handleFlagsChanged(
            keyCode: 55,
            isCommandDown: true,
            hasOtherModifiers: false,
            timestamp: 10.0
        )
        XCTAssertNil(downResult)
        XCTAssertEqual(detector.state, .pending(side: .left, pressedAt: 10.0))

        // Left Command (55) up at t = 10.15 (150ms < 400ms)
        let upResult = detector.handleFlagsChanged(
            keyCode: 55,
            isCommandDown: false,
            hasOtherModifiers: false,
            timestamp: 10.15
        )
        XCTAssertEqual(upResult, .left)
        XCTAssertEqual(detector.state, .idle)
    }

    func testRightCommandStandaloneTapTriggersRight() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Right Command (54) down at t = 20.0
        let downResult = detector.handleFlagsChanged(
            keyCode: 54,
            isCommandDown: true,
            hasOtherModifiers: false,
            timestamp: 20.0
        )
        XCTAssertNil(downResult)
        XCTAssertEqual(detector.state, .pending(side: .right, pressedAt: 20.0))

        // Right Command (54) up at t = 20.20 (200ms < 400ms)
        let upResult = detector.handleFlagsChanged(
            keyCode: 54,
            isCommandDown: false,
            hasOtherModifiers: false,
            timestamp: 20.20
        )
        XCTAssertEqual(upResult, .right)
        XCTAssertEqual(detector.state, .idle)
    }

    func testCommandPlusRegularKeyCancelsSwitch() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Left Command down
        detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
        // 'C' key pressed (⌘+C copy shortcut)
        detector.handleOtherKeyDown()
        XCTAssertEqual(detector.state, .cancelled)

        // Left Command up -> should NOT switch language
        let upResult = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.1)
        XCTAssertNil(upResult)
        XCTAssertEqual(detector.state, .idle)
    }

    func testCommandPlusOtherModifierCancelsSwitch() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Left Command down
        detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
        // Shift pressed while Command held
        detector.handleFlagsChanged(keyCode: 56, isCommandDown: true, hasOtherModifiers: true, timestamp: 1.05)
        XCTAssertEqual(detector.state, .cancelled)

        // Shift released first while Command still held
        detector.handleFlagsChanged(keyCode: 56, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.10)
        XCTAssertEqual(detector.state, .cancelled)

        // Left Command released -> should NOT switch language
        let upResult = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
        XCTAssertNil(upResult)
        XCTAssertEqual(detector.state, .idle)
    }

    func testBothCommandKeysPressedSimultaneouslyCancelsSwitch() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Left Command down
        detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
        // Right Command also pressed while Left Command is held
        let secondDown = detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.05)
        XCTAssertNil(secondDown)
        XCTAssertEqual(detector.state, .cancelled)

        // Simultaneous Left + Right Command full 4-event release sequence
        let releaseRight = detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.10)
        XCTAssertNil(releaseRight)
        let upResult = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
        XCTAssertNil(upResult)
        XCTAssertEqual(detector.state, .idle)
    }

    func testFnModifierCancelsAndCapsLockDoesNotBlock() {
        XCTAssertTrue(CommandKeyTapDetector.hasOtherModifiers(in: [.maskCommand, .maskSecondaryFn]))
        XCTAssertFalse(CommandKeyTapDetector.hasOtherModifiers(in: [.maskCommand, .maskAlphaShift]))

        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
        detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
        detector.handleFlagsChanged(keyCode: 63, isCommandDown: true, hasOtherModifiers: true, timestamp: 1.05)
        let upResult = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
        XCTAssertNil(upResult)
        XCTAssertEqual(detector.state, .idle)
    }

    func testExactTimeoutBoundaryTriggersSwitch() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)
        detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
        let upResult = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.4)
        XCTAssertEqual(upResult, .left)
        XCTAssertEqual(detector.state, .idle)
    }

    func testLongHoldExceedingTimeoutDoesNotTrigger() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Right Command down at t = 5.0
        detector.handleFlagsChanged(keyCode: 54, isCommandDown: true, hasOtherModifiers: false, timestamp: 5.0)
        // Released at t = 5.55 (550ms > 400ms timeout)
        let upResult = detector.handleFlagsChanged(keyCode: 54, isCommandDown: false, hasOtherModifiers: false, timestamp: 5.55)
        XCTAssertNil(upResult)
        XCTAssertEqual(detector.state, .idle)
    }

    func testCommandPlusMouseClickCancelsSwitch() {
        let detector = CommandKeyTapDetector(timeoutSeconds: 0.4)

        // Left Command down
        detector.handleFlagsChanged(keyCode: 55, isCommandDown: true, hasOtherModifiers: false, timestamp: 1.0)
        // Mouse click (⌘+Click on a link)
        detector.handleMouseInteraction()
        XCTAssertEqual(detector.state, .cancelled)

        // Left Command up
        let upResult = detector.handleFlagsChanged(keyCode: 55, isCommandDown: false, hasOtherModifiers: false, timestamp: 1.15)
        XCTAssertNil(upResult)
        XCTAssertEqual(detector.state, .idle)
    }

    @MainActor
    func testMultiLanguageInputSourceModelsAndSmartDefaults() {
        let us = InputSourceItem(
            id: "com.apple.keylayout.US",
            localizedName: "U.S.",
            sourceType: "TISTypeKeyboardLayout",
            languages: ["en"]
        )
        let japanese = InputSourceItem(
            id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
            localizedName: "Hiragana",
            sourceType: "TISTypeKeyboardInputMode",
            languages: ["ja"]
        )
        let german = InputSourceItem(
            id: "com.apple.keylayout.German",
            localizedName: "German",
            sourceType: "TISTypeKeyboardLayout",
            languages: ["de"]
        )
        let italian = InputSourceItem(
            id: "com.apple.keylayout.Italian",
            localizedName: "Italian",
            sourceType: "TISTypeKeyboardLayout",
            languages: ["it"]
        )
        let spanish = InputSourceItem(
            id: "com.apple.keylayout.Spanish",
            localizedName: "Spanish",
            sourceType: "TISTypeKeyboardLayout",
            languages: ["es"]
        )

        let kotoeriRoman = InputSourceItem(
            id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman",
            localizedName: "Romaji",
            sourceType: "TISTypeKeyboardInputMode",
            languages: ["en"]
        )
        let googleRoman = InputSourceItem(
            id: "com.google.inputmethod.Japanese.Roman",
            localizedName: "Alphanumeric (Google)",
            sourceType: "TISTypeKeyboardInputMode",
            languages: ["ja"]
        )
        let kotoeriFullWidthRoman = InputSourceItem(
            id: "com.apple.inputmethod.Kotoeri.RomajiTyping.FullWidthRoman",
            localizedName: "Full-width Romaji",
            sourceType: "TISTypeKeyboardInputMode",
            languages: ["ja"]
        )
        let googleFullWidthRoman = InputSourceItem(
            id: "com.google.inputmethod.Japanese.FullWidthRoman",
            localizedName: "Full-width Alphanumeric (Google)",
            sourceType: "TISTypeKeyboardInputMode",
            languages: ["ja"]
        )
        XCTAssertEqual(kotoeriRoman.badgeCode, "EN")
        XCTAssertTrue(kotoeriRoman.isEnglishLike)
        XCTAssertFalse(kotoeriRoman.isJapaneseLike)
        XCTAssertEqual(googleRoman.badgeCode, "EN")
        XCTAssertTrue(googleRoman.isEnglishLike)
        XCTAssertFalse(googleRoman.isJapaneseLike)

        XCTAssertFalse(kotoeriFullWidthRoman.isJapaneseRomanOrAlphanumericMode)
        XCTAssertEqual(kotoeriFullWidthRoman.badgeCode, "JA")
        XCTAssertFalse(kotoeriFullWidthRoman.isEnglishLike)
        XCTAssertTrue(kotoeriFullWidthRoman.isJapaneseLike)
        XCTAssertFalse(googleFullWidthRoman.isJapaneseRomanOrAlphanumericMode)
        XCTAssertEqual(googleFullWidthRoman.badgeCode, "JA")
        XCTAssertFalse(googleFullWidthRoman.isEnglishLike)
        XCTAssertTrue(googleFullWidthRoman.isJapaneseLike)

        XCTAssertTrue(us.isEnglishLike)
        XCTAssertTrue(japanese.isJapaneseLike)

        let suiteName = "LangSwapTestSuite_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        let settings = AppSettings(defaults: testDefaults, loginItemStatusProvider: { .notRegistered })
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertFalse(settings.launchAtLoginNeedsApproval)
        XCTAssertFalse(settings.launchAtLoginError)

        let approvalSuite = "LangSwapTestSuite_Approval_\(UUID().uuidString)"
        let approvalDefaults = UserDefaults(suiteName: approvalSuite)!
        let approvalSettings = AppSettings(defaults: approvalDefaults, loginItemStatusProvider: { .requiresApproval })
        XCTAssertFalse(approvalSettings.launchAtLogin)
        XCTAssertTrue(approvalSettings.launchAtLoginNeedsApproval)
        XCTAssertFalse(approvalSettings.launchAtLoginError)
        approvalDefaults.removePersistentDomain(forName: approvalSuite)

        settings.applySmartDefaultsIfNeeded(
            availableSources: [us, japanese, german, italian, spanish],
            preferredLanguages: ["ja-JP", "en-US"]
        )
        XCTAssertEqual(settings.leftCommandSourceID, us.id)
        XCTAssertEqual(settings.rightCommandSourceID, japanese.id)
        XCTAssertTrue(settings.presets.isEmpty)
        XCTAssertTrue(settings.hasInitializedDefaults)

        // German locale smart default
        let deSuite = "LangSwapTestSuite_DE_\(UUID().uuidString)"
        let deDefaults = UserDefaults(suiteName: deSuite)!
        let deSettings = AppSettings(defaults: deDefaults, loginItemStatusProvider: { .notRegistered })
        deSettings.applySmartDefaultsIfNeeded(
            availableSources: [us, japanese, german, italian, spanish],
            preferredLanguages: ["de-DE", "en-US"]
        )
        XCTAssertEqual(deSettings.leftCommandSourceID, us.id)
        XCTAssertEqual(deSettings.rightCommandSourceID, german.id)
        XCTAssertTrue(deSettings.presets.isEmpty)
        deDefaults.removePersistentDomain(forName: deSuite)

        // Traditional Chinese locale smart defaults
        let zhHans = InputSourceItem(id: "com.apple.inputmethod.SCIM.ITABC", localizedName: "Pinyin - Simplified", sourceType: "TISTypeKeyboardInputMode", languages: ["zh-Hans"])
        let zhHant = InputSourceItem(id: "com.apple.inputmethod.TCIM.Zhuyin", localizedName: "Zhuyin", sourceType: "TISTypeKeyboardInputMode", languages: ["zh-Hant"])
        let twSuite = "LangSwapTestSuite_TW_\(UUID().uuidString)"
        let twDefaults = UserDefaults(suiteName: twSuite)!
        let twSettings = AppSettings(defaults: twDefaults, loginItemStatusProvider: { .notRegistered })
        twSettings.applySmartDefaultsIfNeeded(availableSources: [us, zhHans, zhHant], preferredLanguages: ["zh-Hant-TW", "en-US"])
        XCTAssertEqual(twSettings.leftCommandSourceID, us.id)
        XCTAssertEqual(twSettings.rightCommandSourceID, zhHant.id)
        twDefaults.removePersistentDomain(forName: twSuite)

        // English-only locale falls back to first non-English source
        let enSuite = "LangSwapTestSuite_EN_\(UUID().uuidString)"
        let enDefaults = UserDefaults(suiteName: enSuite)!
        let enSettings = AppSettings(defaults: enDefaults, loginItemStatusProvider: { .notRegistered })
        enSettings.applySmartDefaultsIfNeeded(availableSources: [us, spanish], preferredLanguages: ["en-US"])
        XCTAssertEqual(enSettings.leftCommandSourceID, us.id)
        XCTAssertEqual(enSettings.rightCommandSourceID, spanish.id)
        enDefaults.removePersistentDomain(forName: enSuite)

        // Swap test
        settings.swapLeftAndRightSources()
        XCTAssertEqual(settings.leftCommandSourceID, japanese.id)
        XCTAssertEqual(settings.rightCommandSourceID, us.id)

        // Custom assignment (e.g., German <-> Japanese)
        settings.leftCommandSourceID = german.id
        settings.rightCommandSourceID = japanese.id
        settings.addPreset(name: "ドイツ語 ↔ 日本語")
        XCTAssertTrue(settings.presets.contains(where: { $0.name == "ドイツ語 ↔ 日本語" }))

        // Duplicate pair moves existing preset to front without adding a second entry
        let countBeforeDup = settings.presets.count
        settings.leftCommandSourceID = japanese.id
        settings.rightCommandSourceID = german.id
        settings.addPreset(name: "日本語 ↔ ドイツ語")
        settings.leftCommandSourceID = german.id
        settings.rightCommandSourceID = japanese.id
        settings.addPreset(name: "重複テスト", isCustomName: false)
        XCTAssertEqual(settings.presets.count, countBeforeDup + 1)
        XCTAssertEqual(settings.presets.first?.leftCommandSourceID, german.id)
        XCTAssertEqual(settings.presets.first?.rightCommandSourceID, japanese.id)
        XCTAssertEqual(settings.presets.first?.name, "ドイツ語 ↔ 日本語")

        if let toRemove = settings.presets.first {
            settings.removePreset(toRemove)
        }
        XCTAssertFalse(settings.presets.contains(where: { $0.leftCommandSourceID == german.id && $0.rightCommandSourceID == japanese.id }))

        // Pre-existing duplicate presets deduplicate on init
        let dupList = [
            LanguagePreset(name: "First", leftCommandSourceID: us.id, rightCommandSourceID: japanese.id),
            LanguagePreset(name: "Dup", leftCommandSourceID: us.id, rightCommandSourceID: japanese.id),
            LanguagePreset(name: "ES", leftCommandSourceID: spanish.id, rightCommandSourceID: us.id)
        ]
        if let dupData = try? JSONEncoder().encode(dupList) {
            testDefaults.set(dupData, forKey: "LangSwap.presets")
        }
        let dedupReloaded = AppSettings(defaults: testDefaults, loginItemStatusProvider: { .notRegistered })
        XCTAssertEqual(dedupReloaded.presets.count, 2)
        XCTAssertEqual(dedupReloaded.presets.first?.name, "First")

        XCTAssertFalse(settings.launchInBackground)
        XCTAssertEqual(us.badgeCode, "EN")
        XCTAssertEqual(japanese.badgeCode, "JA")
        XCTAssertEqual(german.badgeCode, "DE")
        XCTAssertEqual(italian.badgeCode, "IT")
        XCTAssertEqual(spanish.badgeCode, "ES")
        XCTAssertEqual(InputSourceItem.disabledItem.badgeCode, "OFF")
        XCTAssertEqual(InputSourceItem.disabledItem.localizedName, "Disabled")

        let offPreset = LanguagePreset(name: "Stored", leftCommandSourceID: InputSourceItem.disabledID, rightCommandSourceID: InputSourceItem.disabledID)
        let unknownPreset = LanguagePreset(name: "Fallback", leftCommandSourceID: "com.unknown.a", rightCommandSourceID: "com.unknown.b")
        let partialPreset = LanguagePreset(name: "Partial", leftCommandSourceID: us.id, rightCommandSourceID: japanese.id)
        let unavailableJa = InputSourceItem(id: japanese.id, localizedName: "Hiragana", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"], isEnabled: false)
        XCTAssertEqual(InputSourcePickerHelper.presetDisplayName(for: offPreset, manager: .shared, lang: .ja), "無効 ↔ 無効")
        XCTAssertEqual(InputSourcePickerHelper.presetDisplayName(for: offPreset, manager: .shared, lang: .en), "Off ↔ Off")
        XCTAssertEqual(InputSourcePickerHelper.presetDisplayName(for: unknownPreset, manager: .shared, lang: .en), "Fallback")
        XCTAssertFalse(InputSourcePickerHelper.isUnavailable(sourceID: us.id, enabledSourceIDs: [us.id]))
        XCTAssertFalse(InputSourcePickerHelper.isUnavailable(sourceID: InputSourceItem.disabledID, enabledSourceIDs: [us.id]))
        XCTAssertTrue(InputSourcePickerHelper.isUnavailable(sourceID: japanese.id, enabledSourceIDs: [us.id]))
        XCTAssertTrue(InputSourcePickerHelper.hasUnavailableSource(in: partialPreset, enabledSourceIDs: [us.id]))
        XCTAssertFalse(InputSourcePickerHelper.hasUnavailableSource(in: partialPreset, enabledSourceIDs: [us.id, japanese.id]))
        XCTAssertEqual(InputSourcePickerHelper.pickerTitle(for: us, lang: .en), "U.S.")
        XCTAssertEqual(InputSourcePickerHelper.pickerTitle(for: .disabledItem, lang: .en), "Disabled (No Action)")
        XCTAssertEqual(InputSourcePickerHelper.pickerTitle(for: unavailableJa, short: true, lang: .ja), "Hiragana (未追加)")

        settings.launchInBackground = true
        settings.appTheme = .dark
        settings.appLanguage = .es
        let reloaded = AppSettings(defaults: testDefaults, loginItemStatusProvider: { .notRegistered })
        XCTAssertTrue(reloaded.launchInBackground)
        XCTAssertEqual(reloaded.appTheme, .dark)
        XCTAssertEqual(reloaded.appLanguage, .es)

        XCTAssertNil(AppTheme.system.nsAppearance)
        XCTAssertEqual(AppTheme.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppTheme.dark.nsAppearance?.name, .darkAqua)

        testDefaults.removePersistentDomain(forName: suiteName)
    }

    func testLocalizationAndEnglishFallback() {
        XCTAssertEqual(AppLanguage.allCases.count, 18)
        XCTAssertEqual(L10nKey.allCases.count, 103)
        XCTAssertTrue(L10n.hasCompleteCoverage())
        XCTAssertEqual(L10n.t(.themeSystem, lang: .ja), "システム")
        XCTAssertEqual(AppLanguage.pt.localeIdentifier, "pt_BR")
        XCTAssertEqual(L10n.t(.disabledShort, lang: .es), "Desact.")
        XCTAssertTrue(L10n.t(.guideStep4, lang: .ar).contains("أسفل اليسار"))
        XCTAssertTrue(AppLanguage.allCases.allSatisfy { lang in
            L10nKey.allCases.allSatisfy { !L10n.t($0, lang: lang).contains("LangChanger") }
        })
        XCTAssertTrue(AppLanguage.allCases.allSatisfy { lang in
            L10nKey.allCases.allSatisfy { key in
                let value = L10n.t(key, lang: lang)
                return !value.localizedCaseInsensitiveContains("accessibility") && !value.contains("アクセシビリティ")
            }
        })
        XCTAssertEqual(AppConstants.Credits.studioName, "Studio Nova Works")
        XCTAssertEqual(
            L10n.privacyPolicyURL(lang: .ja)?.absoluteString,
            "https://studionovaworks.github.io/Information/LangSwap_PrivacyPolicy.html?lang=ja"
        )
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: ["ja-JP"]), .ja)
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: ["zh-Hans-CN"]), .zh_CN)
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: ["zh-Hant-TW"]), .zh_TW)
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: ["de-DE"]), .de)
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: ["sv-SE"]), .en)
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: ["pl-PL"]), .en)
        XCTAssertEqual(AppLanguage.detectDefault(preferredLanguages: []), .en)
    }

    @MainActor
    func testInstallableEnabledStatusMatchesEnabledSources() {
        let manager = InputSourceManager.shared
        manager.refreshInputSources()
        let enabledBefore = Set(manager.enabledSources.map(\.id))
        manager.loadInstallableSources()
        manager.refreshInputSources()
        let enabledAfter = Set(manager.enabledSources.map(\.id))
        let installableEnabledIDs = Set(manager.installableSources.filter(\.isEnabled).map(\.id))
        XCTAssertFalse(enabledBefore.isEmpty)
        XCTAssertEqual(enabledBefore, enabledAfter)
        XCTAssertEqual(enabledAfter, installableEnabledIDs)
    }

    @MainActor
    func testCanDisableProtectionRules() {
        let us = InputSourceItem(id: "com.apple.keylayout.US", localizedName: "U.S.", sourceType: "TISTypeKeyboardLayout", languages: ["en"], isEnabled: true, isASCIICapable: true)
        let de = InputSourceItem(id: "com.apple.keylayout.German", localizedName: "German", sourceType: "TISTypeKeyboardLayout", languages: ["de"], isEnabled: true, isASCIICapable: true)
        let ja = InputSourceItem(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", localizedName: "Hiragana", sourceType: "TISTypeKeyboardInputMode", languages: ["ja"], isEnabled: true, isASCIICapable: false)

        XCTAssertFalse(InputSourceManager.canDisable(sourceID: us.id, in: [us]))
        XCTAssertFalse(InputSourceManager.canDisable(sourceID: us.id, in: [us, ja]))
        XCTAssertTrue(InputSourceManager.canDisable(sourceID: ja.id, in: [us, ja]))
        XCTAssertTrue(InputSourceManager.canDisable(sourceID: us.id, in: [us, de, ja]))
        XCTAssertTrue(InputSourceManager.canDisable(sourceID: de.id, in: [us, de, ja]))
        XCTAssertTrue(InputSourceManager.canDisable(sourceID: ja.id, in: [us, de, ja]))
    }
}
