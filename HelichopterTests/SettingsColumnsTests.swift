import Testing
import UIKit
@testable import Helichopter

/// On a phone on its side (2026-11-18), Settings goes two to a line: categories on the
/// menu, and rows on a page's cards, read and scanned left to right, then down.
@MainActor @Suite("Settings columns", .serialized)
struct SettingsColumnsTests {
    static let landscape = CGSize(width: 874, height: 402)
    static let notch = UIEdgeInsets(top: 0, left: 62, bottom: 21, right: 62)

    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    private func panel(_ page: SettingsPage, size: CGSize = landscape, columns: Bool = true) -> SettingsPanelView {
        let panel = SettingsPanelView(frame: CGRect(origin: .zero, size: size), theme: GameSettings.shared.selectedTheme,
                                      fontTraits: UITraitCollection(preferredContentSizeCategory: .large),
                                      page: page, columns: columns)
        panel.layoutIfNeeded()
        panel.layoutIfNeeded()
        return panel
    }

    private func frame(_ view: UIView, in panel: UIView) -> CGRect { view.convert(view.bounds, to: panel) }

    @Test func onlyAWideShortScreenAtOrdinaryTextSizesGetsColumns() {
        let large = UITraitCollection(preferredContentSizeCategory: .large)
        let huge = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        #expect(ScrollingPanelView.fitsColumns(in: Self.landscape, safeArea: Self.notch, traits: large))
        #expect(ScrollingPanelView.fitsColumns(in: CGSize(width: 667, height: 375), safeArea: .zero, traits: large))
        #expect(ScrollingPanelView.fitsColumns(in: CGSize(width: 1180, height: 820), safeArea: .zero, traits: large))
        #expect(!ScrollingPanelView.fitsColumns(in: CGSize(width: 402, height: 874), safeArea: .zero, traits: large))
        #expect(!ScrollingPanelView.fitsColumns(in: CGSize(width: 1180, height: 1300), safeArea: .zero, traits: large))
        #expect(!ScrollingPanelView.fitsColumns(in: Self.landscape, safeArea: Self.notch, traits: huge))
        #expect(!ScrollingPanelView.fitsColumns(in: CGSize(width: 560, height: 320), safeArea: .zero, traits: large))
    }

    @Test func menuCategoriesGoTwoToALine() throws {
        let panel = panel(.menu)
        let cards = SettingsCategory.allCases.map { panel.control(labelled: $0.title)! }
        for pair in stride(from: 0, to: cards.count, by: 2) {
            let left = frame(cards[pair], in: panel), right = frame(cards[pair + 1], in: panel)
            #expect(abs(left.minY - right.minY) < 1, "\(SettingsCategory.allCases[pair].title) row")
            #expect(left.maxX < right.minX)
            #expect(abs(left.width - right.width) < 1)
        }
        #expect(frame(cards[2], in: panel).minY > frame(cards[0], in: panel).maxY)
        // Privacy Policy and Acknowledgements share a line; Reset, alone, takes the width.
        let privacy = frame(try #require(panel.control(labelled: "Privacy Policy")), in: panel)
        let thanks = frame(try #require(panel.control(labelled: "Acknowledgements")), in: panel)
        #expect(abs(privacy.minY - thanks.minY) < 1)
        let reset = frame(try #require(panel.control(labelled: "Reset Settings")), in: panel)
        #expect(reset.width > privacy.width * 1.8)
    }

    @Test func rowsOnACardGoTwoToALineAndScanLeftToRight() throws {
        let panel = panel(.category(.comfort))
        let names = ["No-Fail Mode", "Calm Mode", "Helicopter Outline", "Hide Game While Paused", "Show Score"]
        let switches = try names.map { try #require(panel.control(labelled: $0)) }
        let noFail = frame(switches[0], in: panel), calm = frame(switches[1], in: panel)
        #expect(noFail.maxX < calm.minX, "Calm Mode sits beside No-Fail Mode")
        #expect(abs(noFail.midY - calm.midY) < 40)
        #expect(frame(switches[2], in: panel).minY > noFail.maxY)
        // One card for the page, with a line between the columns.
        #expect(descendants(panel, SurfaceView.self).count == 1)
        // The scanner reads in the order the page is read.
        panel.startScanning()
        let spoken = panel.switchScanner.items.map(\.accessibilityScanLabel)
        panel.stopScanning()
        let order = names.compactMap { name in spoken.firstIndex { $0.hasPrefix(name + ",") } }
        #expect(order == order.sorted() && order.count == names.count, "\(spoken)")
    }

    @Test func aLoneLastRowTakesTheWholeCard() throws {
        let panel = panel(.category(.difficulty))
        let gap = frame(try #require(panel.control(labelled: "Gap Size")), in: panel)
        let speed = frame(try #require(panel.control(labelled: "Pipe Speed")), in: panel)
        let hitbox = frame(try #require(panel.control(labelled: "Hitbox Size")), in: panel)
        #expect(gap.maxX < speed.minX)
        #expect(hitbox.width > gap.width * 1.8)
        // The presets read across, Gentle to Challenge.
        let gentle = frame(try #require(panel.control(labelled: "Gentle")), in: panel)
        let challenge = frame(try #require(panel.control(labelled: "Challenge")), in: panel)
        #expect(abs(gentle.minY - challenge.minY) < 1 && gentle.maxX < challenge.minX)
    }

    @Test func everyPageFitsAndNothingIsSqueezed() {
        let pages: [SettingsPage] = [.menu] + SettingsCategory.allCases.map { .category($0) }
        for size in [Self.landscape, CGSize(width: 667, height: 375), CGSize(width: 1180, height: 820)] { for page in pages {
            let panel = panel(page, size: size)
            for control in descendants(panel, UIControl.self) where !(control.superview is UIControl) && !control.isHidden {
                let rect = frame(control, in: panel)
                #expect(rect.minX >= -0.5 && rect.maxX <= size.width + 0.5, "\(page) at \(size): \(control.accessibilityLabel ?? "") off screen")
            }
            for label in descendants(panel, UILabel.self) where !label.isHidden && label.text?.isEmpty == false && label.bounds.width > 0 {
                let fits = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                #expect(fits.height <= label.bounds.height + 1, "\(page) at \(size): \"\(label.text!)\" clipped")
            }
        } }
    }

    @Test func turningThePhoneSwitchesBetweenOneColumnAndTwo() throws {
        let screen = SettingsViewController(page: .category(.comfort))
        screen.view.frame = CGRect(origin: .zero, size: Self.landscape)
        screen.view.layoutIfNeeded()
        #expect(try #require(screen.panel).usesColumns)
        screen.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        screen.view.layoutIfNeeded()
        #expect(try #require(screen.panel).usesColumns == false)
        // The Hangar keeps one column.
        let hangar = HangarViewController()
        hangar.view.frame = CGRect(origin: .zero, size: Self.landscape)
        hangar.view.layoutIfNeeded()
        #expect(try #require(hangar.panel).usesColumns == false)
    }
}
