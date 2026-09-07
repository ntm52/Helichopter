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

}
