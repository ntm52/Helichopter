import Testing
import UIKit
@testable import Helichopter

// WCAG 2.1 relative luminance — sRGB gamma-expanded per IEC 61966-2-1
private func wcagLuminance(_ color: UIColor) -> Double {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    func lin(_ c: CGFloat) -> Double {
        let v = Double(c)
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

private func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
    let la = wcagLuminance(a), lb = wcagLuminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

@Suite("Palette WCAG Contrast") struct PaletteContrastTests {

    // Enforces the invariant declared in GameSettings.swift:
    // helicopterColor vs pipeColor >= 4.5:1 for every palette.
    @Test func paletteSwatchesHaveDistinctLuminance() {
        for palette in GameSettings.allPalettes {
            let ratio = contrastRatio(palette.helicopterColor, palette.pipeColor)
            #expect(ratio >= 4.5, "\(palette.id): ratio \(String(format: "%.2f", ratio)) < 4.5:1")
        }
    }
    @Test func dualBoundaryCoversEveryBackdropLuminance() {
        #expect(contrastRatio(.black, .white) == 21)
        // The worst case is where (L + .05)/.05 == 1.05/(L + .05).
        let worstCaseLuminance = sqrt(0.05 * 1.05) - 0.05
        #expect((worstCaseLuminance + 0.05) / 0.05 > 4.5)
        for theme in GameSettings.allThemes {
            #expect(max(contrastRatio(.black, theme.sceneBackgroundColor),
                        contrastRatio(.white, theme.sceneBackgroundColor)) >= 4.5)
        }
    }


    // Every Settings label and segment title meets WCAG AA (4.5:1) against the colours
    // actually behind it, in every theme. Parchment once measured under 2:1 on presets.
    @MainActor @Test func settingsTextMeetsAAInEveryTheme() {
        func composite(_ fg: UIColor, over bg: UIColor) -> UIColor {
            var fr: CGFloat = 0, fgG: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
            var br: CGFloat = 0, bgG: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            fg.getRed(&fr, green: &fgG, blue: &fb, alpha: &fa)
            bg.getRed(&br, green: &bgG, blue: &bb, alpha: &ba)
            return UIColor(red: fr * fa + br * (1 - fa), green: fgG * fa + bgG * (1 - fa),
                           blue: fb * fa + bb * (1 - fa), alpha: 1)
        }
        for theme in GameSettings.allThemes {
            let panel = SettingsPanelView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), theme: theme)
            panel.layoutIfNeeded()
            func background(of view: UIView) -> UIColor {
                var chain: [UIView] = []
                var next: UIView? = view
                while let item = next { chain.append(item); next = item.superview }
                return chain.reversed().reduce(theme.sceneBackgroundColor) { base, item in
                    item.backgroundColor.map { composite($0, over: base) } ?? base
                }
            }
            var checked = 0
            var pending: [UIView] = [panel]
            while let view = pending.popLast() {
                if let seg = view as? UISegmentedControl {
                    let tray = background(of: seg)
                    let normal = seg.titleTextAttributes(for: .normal)?[.foregroundColor] as? UIColor
                    let segmentRatio = normal.map { contrastRatio(composite($0, over: tray), tray) } ?? 0
                    #expect(segmentRatio >= 4.5, Comment(rawValue: "\(theme.name) segment \(segmentRatio)"))
                    checked += 1
                    continue
                }
                if let label = view as? UILabel, !label.isHidden, !(label.text ?? "").isEmpty {
                    let behind = background(of: label.superview ?? label)
                    let ratio = contrastRatio(composite(label.textColor, over: behind), behind)
                    let text = label.text ?? ""
                    #expect(ratio >= 4.5, Comment(rawValue: "\(theme.name): '\(text)' \(ratio)"))
                    checked += 1
                }
                pending += view.subviews
            }
            #expect(checked > 20)
        }
    }
}
