import UIKit

/// The Settings screen. It hosts a `SettingsPanelView`; `PanelScreenViewController`
/// swaps in a fresh one when the theme, a preset, the lock, Reset, or the text size
/// changes, keeping the scroll position, scanner focus, and any open adjustment page.
final class SettingsViewController: PanelScreenViewController<SettingsPanelView> { }
