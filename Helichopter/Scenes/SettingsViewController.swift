import UIKit

/// A Settings screen: the menu of categories, or one category's page. It hosts a
/// `SettingsPanelView`; `PanelScreenViewController` swaps in a fresh one when the theme,
/// a preset, the lock, Reset, or the text size changes, keeping the scroll position,
/// scanner focus, and any open adjustment page.
final class SettingsViewController: PanelScreenViewController<SettingsPanelView> {
    let page: SettingsPage
    /// The category the player just left, so the menu starts on its button.
    private let returningFrom: SettingsCategory?

    init(page: SettingsPage = .menu, returningFrom: SettingsCategory? = nil) {
        self.page = page
        self.returningFrom = returningFrom
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func createPanel(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection) -> SettingsPanelView {
        SettingsPanelView(frame: frame, theme: theme, fontTraits: fontTraits, page: page)
    }

    /// A category goes back to the menu; the menu goes Home.
    override var backDestination: Screen { page == .menu ? .home : .settings }

    override var focusOnAppear: String? { returningFrom?.title }

    override func configure(_ panel: SettingsPanelView) {
        panel.onOpenHangar = { [weak self, weak panel] in
            guard let self = self, !self.isChangingScreen else { return }
            panel?.stopScanning()
            self.navigate(.hangar)
        }
        panel.onOpenCategory = { [weak self, weak panel] category in
            guard let self = self, !self.isChangingScreen else { return }
            panel?.stopScanning()
            self.navigate(.settingsCategory(category))
        }
    }
}
