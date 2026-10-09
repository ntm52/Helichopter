import UIKit

/// The Settings screen. It hosts a `SettingsPanelView` and swaps in a fresh one when
/// the theme, a preset, the lock, Reset, or the text size changes, keeping the scroll
/// position, scanner focus, and any open adjustment page.
final class SettingsViewController: ScreenViewController {
    private(set) var panel: SettingsPanelView!

    override var announcement: Any? { panel }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
        self.view = view
        install(makePanel(fontTraits: traitCollection))
    }

    private func makePanel(fontTraits: UITraitCollection) -> SettingsPanelView {
        let panel = SettingsPanelView(frame: view.bounds, theme: GameSettings.shared.selectedTheme,
                                      fontTraits: fontTraits)
        // Only Settings is read, never the empty SpriteKit view underneath.
        panel.accessibilityViewIsModal = true
        panel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        panel.onBack = { [weak self] in
            guard let self = self, !self.isChangingScreen else { return }
            self.panel.stopScanning()
            self.navigate(.home)
        }
        panel.onThemeChanged = { [weak self] in self?.rebuildPanel() }
        return panel
    }

    private func install(_ panel: SettingsPanelView) {
        view.addSubview(panel)
        self.panel = panel
    }

    private func rebuildPanel() {
        let old = panel!
        let savedOffset = old.scrollPosition
        let wasScanning = old.switchScanner.isActive
        let focusedSetting = old.focusedSetting
        let wasAdjusting = old.isAdjusting
        old.stopScanning()
        old.isUserInteractionEnabled = false
        let new = makePanel(fontTraits: view.traitCollection)
        new.alpha = 0
        install(new)
        new.restoreScrollPosition(savedOffset)
        if wasScanning || GameSettings.shared.scanningEnabled {
            new.startScanning(focusing: focusedSetting)
            if wasAdjusting { new.primaryActivate() }
        }
        view.backgroundColor = GameSettings.shared.selectedTheme.sceneBackgroundColor
        UIView.animate(withDuration: 0.25) {
            new.alpha = 1
            old.alpha = 0
        } completion: { _ in
            old.removeFromSuperview()
            ScreenChangeAnnouncer.post(new)
        }
    }

    override func screenDidAppear() {
        if GameSettings.shared.scanningEnabled { panel.startScanning() }
        super.screenDidAppear()
    }

    override func screenWillDisappear() {
        panel.stopScanning()
    }

    override var scannersDuringTransition: [FocusScanner] { [panel.switchScanner] }

    override func switchPrimaryBegan() { panel.primaryActivate() }
    override func switchSecondaryBegan() { panel.secondaryAdvance() }
}
