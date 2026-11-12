import Testing
import UIKit
@testable import Helichopter

/// Plan 03 Stage 1: every text colour a theme offers must be readable on every surface
/// it can sit on, and the scanner's focus colour must stand out from the page.
struct ThemeSurfaceContrastTests {

    private func luminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    private func ratio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test func textMeetsAAOnEverySurfaceInEveryTheme() {
        for theme in GameSettings.allThemes {
            let surfaces = [("page", theme.sceneBackgroundColor), ("card", theme.cardColor), ("raised", theme.raisedColor)]
            let texts = [("text", theme.textColor), ("secondary text", theme.secondaryTextColor),
                         ("accent text", theme.accentTextColor)]
            for (surfaceName, surface) in surfaces {
                for (textName, text) in texts {
                    let value = ratio(text, surface)
                    #expect(value >= 4.5, "\(theme.name): \(textName) on \(surfaceName) is \(value)")
                }
            }
            let pairs = [("text on accent", theme.onAccentColor, theme.accentColor),
                         ("text on focus", theme.onFocusColor, theme.focusColor),
                         ("title on page", theme.titleTextColor, theme.sceneBackgroundColor)]
            for (name, text, surface) in pairs {
                let value = ratio(text, surface)
                #expect(value >= 4.5, "\(theme.name): \(name) is \(value)")
            }
        }
    }

    /// Non-text contrast (WCAG 1.4.11): what marks focus, the main action, and a chosen
    /// card must differ from what is beside it by 3:1 or more. A focused primary button
    /// is not checked against its own unfocused accent face: those are two states of one
    /// button, never side by side, and differ in hue as well.
    @Test func focusAndAccentStandOutInEveryTheme() {
        for theme in GameSettings.allThemes {
            let pairs = [("focus on page", theme.focusColor, theme.sceneBackgroundColor),
                         ("focused face beside a card face", theme.focusColor, theme.cardColor),
                         ("accent on page", theme.accentColor, theme.sceneBackgroundColor),
                         ("accent border on a raised card", theme.accentColor, theme.raisedColor)]
            for (name, a, b) in pairs {
                let value = ratio(a, b)
                #expect(value >= 3, "\(theme.name): \(name) is \(value)")
            }
        }
    }

    /// The three button kinds take their colours from the theme, and focus changes the face.
    @MainActor @Test func buttonKindsUseThemeColours() {
        for theme in GameSettings.allThemes {
            let primary = ArcadeButton(kind: .primary, theme: theme)
            #expect(primary.backgroundColor == theme.accentColor)
            #expect(primary.titleColor(for: .normal) == theme.onAccentColor)
            let secondary = ArcadeButton(kind: .secondary, theme: theme)
            #expect(secondary.backgroundColor == theme.cardColor)
            #expect(secondary.titleColor(for: .normal) == theme.textColor)
            let quiet = ArcadeButton(kind: .quiet, theme: theme)
            #expect(quiet.backgroundColor == nil)
            #expect(quiet.titleColor(for: .normal) == theme.accentTextColor)
            secondary.showsFocus = true
            #expect(secondary.backgroundColor == theme.focusColor)
            #expect(secondary.titleColor(for: .normal) == theme.onFocusColor)
            secondary.showsFocus = false
            #expect(secondary.backgroundColor == theme.cardColor)
            for button in [primary, secondary, quiet] {
                button.frame = CGRect(x: 0, y: 0, width: 300, height: 10)
                #expect(button.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height >= Layout.minButtonHeight)
            }
        }
    }
}

/// Plan 03 Stage 2: Home has one large primary button and a row of icon tiles that
/// becomes a column at accessibility text sizes, with the scanning order unchanged.
@MainActor struct HomeLayoutTests {

    private func home(_ category: UIContentSizeCategory) -> HomeViewController {
        let home = HomeViewController()
        home.traitOverrides.preferredContentSizeCategory = category
        home.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        home.view.layoutIfNeeded()
        return home
    }

    @Test func playIsTheOnlyPrimaryAndTheLargestButton() {
        let home = home(.large)
        let buttons = home.menu.buttons
        #expect(buttons.map { $0.currentTitle } == ["Play", "Hangar", "Settings", "How to Play"])
        #expect(buttons.map { $0.kind } == [.primary, .secondary, .secondary, .secondary])
        #expect(buttons[0].bounds.height >= Layout.largeButtonHeight)
        #expect(buttons[0].bounds.width > buttons[1].bounds.width * 2)
        // The scanner still walks the same four choices in the same order.
        #expect(home.scanner.items.count == 4)
        #expect(home.wordmarkHolder.transform != .identity && home.titleLabel.transform == .identity)
        // The name fits on one line at this width, and still does at the largest text size.
        for screen in [home, self.home(.accessibilityExtraExtraExtraLarge)] {
            let label = screen.titleLabel
            let oneLine = ("Helichopter" as NSString).size(withAttributes: [.font: label.font!])
            #expect(oneLine.width <= label.bounds.width)
            #expect(label.bounds.height < oneLine.height * 1.5)
            #expect(label.font.pointSize >= 34)
        }
    }

    @Test func tilesShareARowAndBecomeAColumnAtAccessibilitySizes() {
        let row = home(.large).menu.buttons.dropFirst()
        #expect(Set(row.map { $0.frame.minY }).count == 1)
        #expect(Set(row.map { $0.frame.height }).count == 1)
        #expect(row.allSatisfy { $0.iconPlacement == .top && $0.bounds.height >= Layout.minButtonHeight })

        let column = home(.accessibilityExtraExtraExtraLarge).menu.buttons.dropFirst()
        #expect(Set(column.map { $0.frame.minY }).count == 3)
        #expect(column.allSatisfy { $0.iconPlacement == .leading })
        #expect(Set(column.map { $0.frame.width }).count == 1)
    }

    /// Icons are decoration: each button exposes only itself, named by its title.
    @Test func iconsAreHiddenFromAssistiveTechnology() {
        for button in home(.large).menu.buttons {
            let images = button.subviews.compactMap { $0 as? UIImageView }
            #expect(images.count == 1)
            #expect(images.allSatisfy { !$0.isAccessibilityElement && $0.image != nil })
            // UIKit derives the spoken name from the title; the icon must not add to it.
            #expect(button.accessibilityLabel == nil || button.accessibilityLabel == button.currentTitle)
        }
    }
}
