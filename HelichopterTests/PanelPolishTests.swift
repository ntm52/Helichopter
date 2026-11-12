import Testing
import UIKit
@testable import Helichopter

/// Plan 03 Stage 4: the Settings and Hangar panels as cards on a page, with a real header.
@MainActor struct PanelPolishTests {

    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        view.subviews.flatMap { ($0 as? T).map { [$0] } ?? [] + descendants($0, T.self) }
    }

    private func settingsPanel(_ page: SettingsPage = .menu, _ category: UIContentSizeCategory = .large,
                               width: CGFloat = 390) -> SettingsPanelView {
        let panel = SettingsPanelView(frame: CGRect(x: 0, y: 0, width: width, height: 844),
                                      theme: GameSettings.shared.selectedTheme,
                                      fontTraits: UITraitCollection(preferredContentSizeCategory: category), page: page)
        panel.layoutIfNeeded()
        return panel
    }

    /// Back is a real button with a chevron picture, named "Back" with no arrow character,
    /// before the title; at accessibility text sizes the title goes below it.
    @Test func headerHasBackBeforeTheTitle() throws {
        for (category, sideBySide) in [(UIContentSizeCategory.large, true), (.accessibilityExtraExtraExtraLarge, false)] {
            let panel = settingsPanel(.menu, category)
            let back = try #require(panel.header.arrangedSubviews.first as? ArcadeButton)
            let title = try #require(panel.header.arrangedSubviews.last as? UILabel)
            #expect(back.currentTitle == "Back" && back.accessibilityLabel == "Back" && back.kind == .secondary)
            #expect(title.text == "Settings" && title.accessibilityTraits.contains(.header))
            #expect(back.bounds.height >= Layout.minButtonHeight)
            #expect((back.frame.maxX <= title.frame.minX) == sideBySide)
            #expect((back.frame.maxY <= title.frame.minY) == !sideBySide)
            // Back is still the first thing the scanner reaches.
            #expect(panel.controls(in: panel).first === back)
        }
    }

    /// Every switch, slider, and list of choices sits on a card, inside the screen's margins.
    @Test func rowsSitOnCardsWithMargins() {
        var cardCount = 0
        for category in SettingsCategory.allCases {
            let panel = settingsPanel(.category(category))
            let cards = descendants(panel, SurfaceView.self)
            cardCount += cards.count
            for card in cards {
                let frame = card.convert(card.bounds, to: panel)
                #expect(frame.minX >= Spacing.l && frame.maxX <= panel.bounds.width - Spacing.l)
            }
            let rowControls = descendants(panel, UISwitch.self) as [UIControl] + descendants(panel, UISlider.self)
                + descendants(panel, ChoiceButton.self)
            #expect(!rowControls.isEmpty || category == .colours)
            #expect(rowControls.allSatisfy { control in
                sequence(first: control.superview, next: { $0?.superview }).contains { $0 is SurfaceView }
            })
            // Nothing in Settings is a text-only button except "More about this".
            let quiet = descendants(panel, ArcadeButton.self).filter { $0.kind == .quiet }
            #expect(quiet.allSatisfy { $0.currentTitle == "More about this" })
        }
        #expect(cardCount >= 9)
    }

    /// The Settings menu: one large card per category, each with its name and what is
    /// inside, then Reset and the About pages. Nothing else.
    @Test func menuIsACardPerCategory() {
        let panel = settingsPanel()
        let cards = descendants(panel, CardButton.self)
        #expect(cards.map(\.accessibilityLabel) == SettingsCategory.allCases.map(\.title))
        for (card, category) in zip(cards, SettingsCategory.allCases) {
            let texts = descendants(card, UILabel.self).compactMap(\.text)
            #expect(texts == [category.title, category.detail])
            #expect(card.bounds.height >= Layout.minButtonHeight)
            #expect(descendants(card, UIImageView.self).count == 2) // The picture and the chevron.
        }
        #expect(descendants(panel, UISwitch.self).isEmpty && descendants(panel, UISlider.self).isEmpty)
        #expect(descendants(panel, ArcadeButton.self).compactMap(\.currentTitle)
                == ["Back", "Reset Settings", "Privacy Policy", "Acknowledgements"])
    }

    /// A long explanation is one press away, and VoiceOver still hears it as the hint.
    @Test func moreAboutThisOpensTheLongExplanation() throws {
        let panel = settingsPanel(.category(.controls))
        let more = descendants(panel, ArcadeButton.self).filter { $0.currentTitle == "More about this" }
        #expect(more.map(\.accessibilityLabel) == ["More about VoiceOver Direct Touch", "More about Pause by Holding Switch"])
        #expect(more.allSatisfy { $0.accessibilityUserInputLabels?.first == "More about this" })
        #expect(more.allSatisfy { $0.bounds.height >= Layout.minButtonHeight })
        let toggle = try #require(descendants(panel, UISwitch.self).first { $0.accessibilityLabel == "Pause by Holding Switch" })
        let long = try #require(toggle.accessibilityHint)
        #expect(long.contains("holding both switches pauses Up/Down Switches"))

        more[1].sendActions(for: .touchUpInside)
        let page = try #require(panel.adjustmentPanel)
        #expect(descendants(page, UILabel.self).contains { $0.text == long })
        let done = try #require(descendants(page, UIButton.self).first { $0.currentTitle == "Done" })
        done.sendActions(for: .touchUpInside)
        #expect(panel.adjustmentPanel == nil)
        panel.stopScanning()
    }

    /// A slider's page of larger buttons also carries its long explanation.
    @Test func adjustmentPageShowsALongExplanation() throws {
        let panel = settingsPanel(.category(.controls))
        let hold = try #require(descendants(panel, UISlider.self).first { $0.accessibilityLabel == "Hold Switch to Pause" })
        panel.showAdjustment(for: hold)
        let page = try #require(panel.adjustmentPanel)
        #expect(descendants(page, UILabel.self).contains { ($0.text ?? "").contains("Release it before choosing a menu item") })
        panel.closeAdjustment()
        panel.stopScanning()
    }

    /// Each slider shows its value beside its name, and the value follows the slider.
    @Test func sliderShowsItsValue() throws {
        let saved = GameSettings.shared.hitboxFraction
        defer { GameSettings.shared.hitboxFraction = saved }
        let panel = settingsPanel(.category(.difficulty))
        let slider = try #require(descendants(panel, UISlider.self).first { $0.accessibilityLabel == "Hitbox Size" })
        let row = try #require(sequence(first: slider.superview, next: { $0?.superview }).first { $0?.superview is UIStackView && $0?.superview?.superview is SurfaceView } ?? nil)
        slider.value = slider.maximumValue
        slider.sendActions(for: .valueChanged)
        let value = try #require(descendants(row, UILabel.self).first { $0.text == "100%" })
        #expect(value.accessibilityElementsHidden)
        slider.value = slider.minimumValue
        slider.sendActions(for: .valueChanged)
        #expect(value.text == "0%")
    }

    /// A list of choices is one button per choice, none cut off, with the chosen one
    /// marked by a different picture as well as a colour.
    @Test func choicesAreAListOfButtons() throws {
        let saved = GameSettings.shared.controlScheme
        defer { GameSettings.shared.controlScheme = saved }
        GameSettings.shared.controlScheme = .tapFlap
        let panel = settingsPanel(.category(.controls), width: 375)
        let choices = try #require(panel.choiceGroups["In-Game Control"])
        #expect(choices.map(\.accessibilityLabel) == ["Tap to Flap", "Hold to Hover", "Auto Hover", "Up/Down Switches"])
        #expect(Set(choices.map { $0.frame.minY }).count == 4)
        for choice in choices {
            let name = try #require(descendants(choice, UILabel.self).first)
            #expect(name.bounds.width >= name.intrinsicContentSize.width - 0.5, "\(name.text ?? "") is cut off")
            #expect(choice.bounds.height >= Layout.minButtonHeight)
        }
        func marks() -> [Data?] { choices.map { descendants($0, UIImageView.self).first?.image?.pngData() } }
        #expect(marks()[0] != marks()[1] && marks()[1] == marks()[2])
        choices[2].sendActions(for: .touchUpInside)
        #expect(GameSettings.shared.controlScheme == .autoHover)
        #expect(choices.map(\.isChosen) == [false, false, true, false])
        #expect(choices.map(\.isSelected) == [false, false, true, false])
        #expect(marks()[2] != marks()[1])
    }

    /// Hangar cards are chosen cards on the page, with pictures larger than before.
    @Test func hangarCardsAreSurfacesWithLargePictures() throws {
        let panel = HangarPanelView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                    theme: GameSettings.shared.selectedTheme,
                                    fontTraits: UITraitCollection(preferredContentSizeCategory: .large))
        panel.layoutIfNeeded()
        let cards = panel.themeCards + panel.helicopterCards + panel.pipeCards
        #expect(cards.allSatisfy { $0 is CardButton })
        #expect(cards.allSatisfy { ($0 as? CardButton)?.isChosen == $0.isSelected })
        #expect(cards.allSatisfy { $0.backgroundColor == panel.theme.cardColor })
        for card in panel.helicopterCards + panel.pipeCards {
            let picture = try #require(descendants(card, UIImageView.self).first)
            #expect(picture.bounds.width >= 100 && picture.bounds.height >= 100)
        }
    }
}
