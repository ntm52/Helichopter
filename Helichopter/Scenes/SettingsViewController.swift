import UIKit

/// The Settings screen. It hosts a `SettingsPanelView`; `PanelScreenViewController`
/// swaps in a fresh one when the theme, a preset, the lock, Reset, or the text size
/// changes, keeping the scroll position, scanner focus, and any open adjustment page.
final class SettingsViewController: PanelScreenViewController<SettingsPanelView> {
    override func configure(_ panel: SettingsPanelView) {
        panel.onOpenHangar = { [weak self, weak panel] in
            guard let self = self, !self.isChangingScreen else { return }
            panel?.stopScanning()
            self.navigate(.hangar)
        }
    }
}
