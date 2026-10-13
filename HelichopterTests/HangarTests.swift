import Testing
import UIKit
@testable import Helichopter

/// The Hangar (Plan 02 Phase 1 steps 1–2): Menu Theme cards moved from Settings, plus
/// a card for each helicopter and pipe look in `CosmeticsCatalog` (only Classic so far).
@MainActor @Suite("Hangar", .serialized)
struct HangarTests {
    private func withSettings(_ work: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let saved = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("gs_") || $0.key == "isMusicOn" }
        defer {
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("gs_") || key == "isMusicOn" {
                defaults.removeObject(forKey: key)
            }
            for (key, value) in saved { defaults.set(value, forKey: key) }
        }
        defaults.set(false, for: .isMusicOn)
        GameSettings.shared.scanningEnabled = false
        GameSettings.shared.isSettingsLocked = false
        GameSettings.shared.selectedThemeID = GameSettings.themeNightSky.id
        defaults.removeObject(forKey: "gs_selectedHelicopterSkinID")
        defaults.removeObject(forKey: "gs_selectedPipeSkinID")
        try await work()
    }

    /// The Hangar as the root controller installs it, without a window.
    private func hangarScreen(scheme: ScanScheme = .twoSwitch) -> HangarViewController {
        GameSettings.shared.scanScheme = scheme
        let screen = HangarViewController()
        screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        screen.screenDidAppear()
        return screen
    }

    private func scanLabels(_ panel: ScrollingPanelView) -> [String] {
        panel.switchScanner.items.map(\.accessibilityScanLabel)
    }

    private var themeNames: [String] { GameSettings.allThemes.map(\.name) }
    private var skinNames: [String] { CosmeticsCatalog.all.map(\.name) }
    /// Every Hangar control in scan order after Back.
    private var cardNames: [String] { themeNames + skinNames }

    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    // MARK: Home

    @Test func homeOrderIsPlayHangarSettingsHowToPlay() {
        #expect(HomeAction.allCases == [.play, .hangar, .settings, .howToPlay])
        #expect(HomeAction.allCases.map(\.title) == ["Play", "Hangar", "Settings", "How to Play"])
        #expect(HomeAction.hangar.hint == "Changes how the game looks")
        let home = HomeViewController()
        var shown: Screen?
        home.navigate = { shown = $0 }
        home.loadViewIfNeeded()
        home.perform(.hangar)
        guard case .hangar = shown else {
            Issue.record("Hangar did not open: \(String(describing: shown))")
            return
        }
    }

    // MARK: Layout and labels

    @Test func hangarShowsHeadedSectionsAndLabelledCards() async throws {
        try await withSettings {
            let screen = hangarScreen()
            defer { screen.screenWillDisappear() }
            let panel = try #require(screen.panel)
            panel.layoutIfNeeded()
            let headers = descendants(panel, UILabel.self).filter { $0.accessibilityTraits.contains(.header) }
            #expect(headers.map { $0.accessibilityLabel ?? $0.text ?? "" } == ["Hangar", "Menu Theme", "Helicopters", "Pipes"])
            #expect(panel.themeCards.map(\.accessibilityLabel) == themeNames)
            #expect(panel.themeCards.allSatisfy { $0.accessibilityHint == "Menu theme" })
            #expect(panel.themeCards.filter { $0.accessibilityTraits.contains(.selected) }.map(\.accessibilityLabel) == ["Night Sky"])
            // Each look is a button: its name, "Equipped" as its value, its description as the hint.
            let skins = panel.helicopterCards + panel.pipeCards
            #expect(skins.map(\.accessibilityLabel) == ["Classic Helicopter", "Classic Pipes"])
            #expect(skins.allSatisfy { $0.accessibilityTraits.contains(.selected) && $0.isSelected })
            #expect(skins.allSatisfy { $0.accessibilityValue == "Equipped" })
            #expect(skins.map(\.accessibilityHint) == CosmeticsCatalog.all.map(\.spokenDescription))
            #expect(descendants(panel, UILabel.self).filter { $0.text == "Equipped" }.count == 2)
            #expect(panel.controls(in: panel).count == 1 + cardNames.count)
            // No placeholder text or locked tiles.
            #expect(!descendants(panel, UILabel.self).contains { ($0.text ?? "").localizedCaseInsensitiveContains("on the way") })
            #expect(screen.scannersDuringTransition.first === panel.switchScanner)
        }
    }

    // MARK: Choosing a theme

    @Test func choosingAThemeCardPersistsAndKeepsFocus() async throws {
        try await withSettings {
            let screen = hangarScreen()
            defer { screen.screenWillDisappear() }
            let first = try #require(screen.panel)
            screen.switchPrimaryBegan() // Starts scanning on Back.
            screen.switchSecondaryBegan()
            screen.switchSecondaryBegan() // Parchment.
            #expect(first.focusedSetting == "Parchment")
            screen.switchPrimaryBegan()
            #expect(GameSettings.shared.selectedThemeID == GameSettings.themeParchment.id)
            let rebuilt = try #require(screen.panel)
            #expect(rebuilt !== first)
            #expect(!first.switchScanner.isActive)
            #expect(rebuilt.focusedSetting == "Parchment")
            #expect(rebuilt.style.bg == SettingsStyle(theme: GameSettings.themeParchment).bg)
            let chosen = try #require(rebuilt.themeCards.first { $0.accessibilityTraits.contains(.selected) })
            #expect(chosen.accessibilityLabel == "Parchment")
            #expect(rebuilt.announcementAfterRebuild as? UIButton === chosen)

            // A finger tap, with the scanner elsewhere, also lands focus on the chosen card.
            rebuilt.startScanning(focusing: "Back")
            rebuilt.themeCards[2].sendActions(for: .touchUpInside)
            #expect(GameSettings.shared.selectedThemeID == GameSettings.allThemes[2].id)
            #expect(screen.panel?.focusedSetting == GameSettings.allThemes[2].name)
        }
    }

    // MARK: Choosing a look

    @Test func choosingASkinCardPersistsAndKeepsFocus() async throws {
        try await withSettings {
            // A stale choice (for example a look removed in an update) reads as Classic.
            UserDefaults.standard.set("pipe.removed", forKey: "gs_selectedPipeSkinID")
            let screen = hangarScreen()
            defer { screen.screenWillDisappear() }
            let first = try #require(screen.panel)
            #expect(first.pipeCards.first?.accessibilityTraits.contains(.selected) == true)
            screen.switchPrimaryBegan() // Starts scanning on Back.
            for _ in first.switchScanner.items where first.focusedSetting != "Classic Pipes" {
                screen.switchSecondaryBegan()
            }
            #expect(first.focusedSetting == "Classic Pipes")
            screen.switchPrimaryBegan()
            #expect(UserDefaults.standard.string(forKey: "gs_selectedPipeSkinID") == "pipe.classic")
            let rebuilt = try #require(screen.panel)
            #expect(rebuilt !== first)
            #expect(rebuilt.focusedSetting == "Classic Pipes")
            #expect(rebuilt.announcementAfterRebuild as? UIButton === rebuilt.pipeCards.first)

            // A finger tap on the helicopter card does the same.
            rebuilt.startScanning(focusing: "Back")
            rebuilt.helicopterCards[0].sendActions(for: .touchUpInside)
            #expect(UserDefaults.standard.string(forKey: "gs_selectedHelicopterSkinID") == "heli.classic")
            #expect(screen.panel?.focusedSetting == "Classic Helicopter")
        }
    }

    // MARK: Art

    @Test func everyLookHasItsArt() throws {
        for skin in CosmeticsCatalog.all {
            switch skin.kind {
            case .helicopter:
                let image = skin.helicopterImage(frame: Cosmetic.helicopterFrameCount)
                #expect(image.size.width > 0, "\(skin.name) is missing frames")
            case .pipe:
                #expect(UIImage(named: skin.pipeTextureName) != nil, "\(skin.name) is missing its pipe")
                #expect(UIImage(named: skin.capTextureName) != nil, "\(skin.name) is missing its cap")
            }
        }
    }

    /// Art is chosen only through `CosmeticsCatalog`, so a new look needs no code changes.
    @Test func artNamesLiveOnlyInTheCatalog() throws {
        let appSources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Helichopter")
        let files = try #require(FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        var swiftFiles = 0
        for case let url as URL in files where url.pathExtension == "swift" && url.lastPathComponent != "Cosmetics.swift" {
            swiftFiles += 1
            let source = try String(contentsOf: url, encoding: .utf8)
            for name in ["\"Helicopter Player\"", "pipe-yellow", "cap-yellow", "r_player"] where source.contains(name) {
                offenders.append("\(url.lastPathComponent): \(name)")
            }
        }
        #expect(swiftFiles > 20)
        #expect(offenders.isEmpty, "Hard-coded art names: \(offenders)")
    }

    // MARK: Caregiver lock

    @Test func lockDisablesThemeCardsButKeepsBack() async throws {
        try await withSettings {
            GameSettings.shared.isSettingsLocked = true
            let screen = hangarScreen()
            defer { screen.screenWillDisappear() }
            let panel = try #require(screen.panel)
            let cards = panel.themeCards + panel.helicopterCards + panel.pipeCards
            #expect(cards.allSatisfy { !$0.isEnabled })
            #expect(cards.allSatisfy { $0.superview?.superview?.alpha == 0.5 })
            #expect(descendants(panel, UILabel.self).contains { $0.text == "Locked by a caregiver in Settings." })
            screen.switchPrimaryBegan()
            #expect(scanLabels(panel) == ["Back"])
            panel.themeCards[1].sendActions(for: .touchUpInside)
            #expect(GameSettings.shared.selectedThemeID == GameSettings.themeNightSky.id)
            panel.pipeCards[0].sendActions(for: .touchUpInside)
            #expect(UserDefaults.standard.object(forKey: "gs_selectedPipeSkinID") == nil)
            var shown: Screen?
            screen.navigate = { shown = $0 }
            screen.switchPrimaryBegan()
            guard case .home = shown else {
            Issue.record("Back did not go Home while locked")
            return
        }
        }
    }

    @Test func lockedLineIsAbsentWhenUnlocked() async throws {
        try await withSettings {
            let screen = hangarScreen()
            defer { screen.screenWillDisappear() }
            let panel = try #require(screen.panel)
            #expect(!descendants(panel, UILabel.self).contains { $0.text == HangarPanelView.lockedMessage })
            #expect((panel.themeCards + panel.helicopterCards + panel.pipeCards).allSatisfy { $0.isEnabled })
        }
    }

    // MARK: Scanning

    @Test func stepScanningReachesBackAndEveryCard() async throws {
        try await withSettings {
            let screen = hangarScreen(scheme: .twoSwitch)
            defer { screen.screenWillDisappear() }
            let panel = try #require(screen.panel)
            screen.switchPrimaryBegan()
            #expect(scanLabels(panel) == ["Back"] + cardNames)
            var visited: [String] = []
            for _ in scanLabels(panel) {
                visited.append(try #require(panel.focusedSetting))
                screen.switchSecondaryBegan()
            }
            #expect(visited == ["Back"] + cardNames)
            #expect(panel.focusedSetting == "Back") // Wraps around.
        }
    }

    @Test func timedScanningReachesBackAndEveryCard() async throws {
        try await withSettings {
            GameSettings.shared.scanDwellTime = 0.5
            let screen = hangarScreen(scheme: .autoScan)
            defer { screen.screenWillDisappear() }
            let panel = try #require(screen.panel)
            screen.switchPrimaryBegan()
            #expect(scanLabels(panel) == ["Back"] + cardNames)
            var seen = Set<String>()
            let reachedAll = try await waitUntil(timeout: 20) {
                if let label = panel.focusedSetting { seen.insert(label) }
                return seen.isSuperset(of: ["Back"] + cardNames)
            }
            #expect(reachedAll, "Timed scan reached only \(seen)")

            // Selecting a card while the timer runs chooses it and keeps focus there.
            let neon = try #require(themeNames.last)
            let onNeon = try await waitUntil(timeout: 20) { panel.focusedSetting == neon }
            #expect(onNeon)
            screen.switchPrimaryBegan()
            #expect(GameSettings.shared.selectedThemeID == GameSettings.allThemes.last?.id)
            #expect(screen.panel?.focusedSetting == neon)
            #expect(screen.panel?.switchScanner.isActive == true)
        }
    }

    // MARK: Leaving

    @Test func backReturnsHome() async throws {
        try await withSettings {
            let screen = hangarScreen()
            var shown: Screen?
            screen.navigate = { shown = $0 }
            screen.switchPrimaryBegan() // Back is first.
            #expect(screen.panel.focusedSetting == "Back")
            screen.switchPrimaryBegan()
            guard case .home = shown else {
            Issue.record("Back did not go Home")
            return
        }
            #expect(!screen.panel.switchScanner.isActive)
        }
    }

    @Test func settingsPointerOpensTheHangar() async throws {
        try await withSettings {
            GameSettings.shared.scanScheme = .twoSwitch
            GameSettings.shared.selectedThemeID = GameSettings.themeNeonNight.id
            let settings = SettingsViewController()
            settings.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            settings.screenDidAppear()
            defer { settings.screenWillDisappear() }
            var shown: Screen?
            settings.navigate = { shown = $0 }
            let title = "Menu Theme: Neon Night. Change it in the Hangar"
            #expect(SettingsPanelView.hangarPointerTitle == title)
            settings.switchPrimaryBegan()
            let panel = try #require(settings.panel)
            #expect(panel.switchScanner.items.contains { $0.accessibilityScanLabel == title })
            // Settings no longer holds a theme control.
            #expect(!descendants(panel, UISegmentedControl.self).contains { $0.accessibilityLabel == "Menu Theme" })
            #expect(descendants(panel, UILabel.self).contains { ($0.text ?? "").contains("Independent of the menu theme in the Hangar") })
            for _ in panel.switchScanner.items where panel.focusedSetting != title { settings.switchSecondaryBegan() }
            #expect(panel.focusedSetting == title)
            settings.switchPrimaryBegan()
            guard case .hangar = shown else {
            Issue.record("Pointer did not open the Hangar")
            return
        }
            #expect(!panel.switchScanner.isActive)
        }
    }

    @Test func settingsPointerIsDisabledWhenLocked() async throws {
        try await withSettings {
            GameSettings.shared.isSettingsLocked = true
            let settings = SettingsViewController()
            settings.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            settings.loadViewIfNeeded()
            let pointer = try #require(descendants(settings.panel, UIButton.self).first {
                $0.accessibilityLabel == SettingsPanelView.hangarPointerTitle
            })
            #expect(!pointer.isEnabled)
        }
    }

    // MARK: Dynamic Type

    @Test func largestTextUsesOneColumnWithScalableUnclippedText() async throws {
        try await withSettings {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 768)] {
                let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
                let panel = HangarPanelView(frame: CGRect(origin: .zero, size: size),
                                            theme: GameSettings.shared.selectedTheme, fontTraits: traits)
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                let host = UIViewController()
                host.view = panel
                window.rootViewController = host
                window.makeKeyAndVisible()
                defer { window.isHidden = true }
                panel.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
                panel.updateTraitsIfNeeded()
                panel.layoutIfNeeded()
                panel.layoutIfNeeded()
                let cards = panel.themeCards
                // One column: every card is as wide as the row, one under the next.
                #expect(Set(cards.map { $0.frame.minX }).count == 1)
                #expect(zip(cards, cards.dropFirst()).allSatisfy { $0.frame.maxY <= $1.frame.minY })
                for label in descendants(panel, UILabel.self) where !(label.text ?? "").isEmpty {
                    #expect(label.adjustsFontForContentSizeCategory, "Unscaled label: \(label.text ?? "")")
                    #expect(label.font.pointSize > 17 || label.adjustsFontSizeToFitWidth, "Small label: \(label.text ?? "")")
                    if label.bounds.width > 0 && !label.adjustsFontSizeToFitWidth {
                        let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                        #expect(label.bounds.height + 2 >= needed.height, "Clipped: \(label.text ?? "")")
                    }
                }
                for card in cards {
                    let frame = card.convert(card.bounds, to: panel)
                    #expect(frame.minX >= 0 && frame.maxX <= size.width + 0.5)
                }
                let image = UIGraphicsImageRenderer(bounds: panel.bounds).image { panel.layer.render(in: $0.cgContext) }
                Attachment.record(try #require(image.pngData()), named: "Hangar-largest-\(Int(size.width)).png")
            }
        }
    }

    @Test func standardTextShowsCardsSideBySide() async throws {
        try await withSettings {
            let traits = UITraitCollection(preferredContentSizeCategory: .large)
            let panel = HangarPanelView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                        theme: GameSettings.shared.selectedTheme, fontTraits: traits)
            panel.layoutIfNeeded()
            let cards = panel.themeCards
            #expect(Set(cards.map { $0.frame.minY }).count == 1)
            #expect(Set(cards.map { $0.frame.height }).count == 1)
        }
    }
}
