import Testing
import UIKit
@testable import Helichopter

/// Plan 03 Stage 6: the guide's words on a card, one picture per step, Next as the
/// one primary button.
@MainActor @Suite("Guide polish", .serialized)
struct GuidePolishTests {
    private func descendants<T: UIView>(_ view: UIView, _: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, T.self) }
    }

    private func isOnCard(_ view: UIView) -> Bool {
        sequence(first: view, next: \.superview).contains { $0 is SurfaceView }
    }

    private func makeGuide() throws -> (GuideViewController, UIWindow) {
        let guide = GuideViewController(defaults: try #require(UserDefaults(suiteName: "GuidePolishTests")))
        guide.navigate = { _ in }
        let window = makeTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = guide
        window.isHidden = false
        return (guide, window)
    }

    @Test func everyStepPutsItsWordsOnACardWithOnePicture() throws {
        let (guide, window) = try makeGuide()
        defer { window.isHidden = true }
        let theme = guide.menu.theme
        var pictures: [UIImage] = []
        for page in 0..<3 {
            guide.show(page: page)
            guide.view.layoutIfNeeded()
            let cards = descendants(guide.view, SurfaceView.self)
            #expect(cards.count == 1)
            // Every word is on the card, in the card's colours; no button is.
            let texts = descendants(guide.view, UILabel.self).filter { !($0.superview is UIButton) }
            #expect(texts.count == 3 && texts.allSatisfy(isOnCard))
            #expect(texts.allSatisfy { $0.textColor == theme.textColor || $0.textColor == theme.accentTextColor })
            #expect(guide.headingLabel?.accessibilityTraits.contains(.header) == true)
            #expect(guide.menu.buttons.allSatisfy { !isOnCard($0) })
            // One picture, on the card, not read by VoiceOver.
            let images = descendants(cards[0], UIImageView.self)
            #expect(images.count == 1 && images[0] === guide.picture)
            #expect(!images[0].isAccessibilityElement)
            pictures.append(try #require(images[0].image))
            // A symbol's view is a point or two taller than its layout height.
            #expect(abs(images[0].bounds.height - GuideViewController.pictureHeight) < 3, "\(images[0].bounds.height)")
        }
        #expect(Set(pictures.map(ObjectIdentifier.init)).count == 3, "each step has its own picture")
    }

    @Test func nextIsTheOnePrimaryButton() throws {
        let (guide, window) = try makeGuide()
        defer { window.isHidden = true }
        for page in 0..<3 {
            guide.show(page: page)
            let primary = guide.menu.buttons.filter { $0.kind == .primary }.map(\.currentTitle)
            #expect(primary == [page == 2 ? "Done" : "Next"])
            #expect(guide.menu.buttons.allSatisfy { $0.kind != .quiet })
            // Each button has a picture beside its name.
            #expect(guide.menu.buttons.allSatisfy { button in
                button.subviews.contains { ($0 as? UIImageView)?.image != nil }
            })
        }
        let expected = ["Read this step aloud", "Done", "Back", "Skip guide"]
        #expect(guide.menu.buttons.map(\.currentTitle) == expected)
        #expect(guide.scanner.items.compactMap { ($0 as? MenuItem)?.title } == expected)
    }

    /// The helicopter fills its picture: the frame's empty margins are cut away.
    @Test func helicopterPictureHasNoEmptyMargins() throws {
        for skin in CosmeticsCatalog.items(of: .helicopter) {
            let whole = skin.helicopterImage(), cut = skin.helicopterPortraitImage()
            #expect(cut.size.width <= whole.size.width && cut.size.height < whole.size.height * 0.7, "\(skin.id)")
            // Wider than tall, and still most of the frame's width.
            #expect(cut.size.width > cut.size.height && cut.size.width > whole.size.width * 0.6, "\(skin.id)")
        }
    }

    @Test func pictureIsSmallerAtAccessibilityTextSizes() throws {
        let theme = GameSettings.shared.selectedTheme
        let compact = GuideViewController.picture(for: 1, theme: theme, compact: true)
        compact.layoutIfNeeded()
        #expect(compact.constraints.contains { $0.constant == GuideViewController.compactPictureHeight })
    }
}
