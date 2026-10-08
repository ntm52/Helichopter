import UIKit

/// The three-page first-run guide, shown at first launch and from How to Play.
final class GuideViewController: MenuViewController {
    /// Saved once the guide is finished or skipped. Never rename: 2.0 players have it set.
    static let completedKey = "onboarding_completed_v1"

    static func isCompleted(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: completedKey)
    }

    let defaults: UserDefaults
    private(set) var page = 0
    private(set) var headingLabel: UILabel?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var announcement: Any? { headingLabel }

    /// The pages, worded for the player's current settings.
    static func pages(for settings: GameSettings = .shared) -> [(heading: String, body: String)] {
        [
            ("Your flight controls", "Fly through the gaps between pipes.\n\n" + flightInstructions(for: settings.controlScheme) + "\n\nYou can change controls in Settings → Switch Access."),
            ("Go at your own pace", "No-fail mode is currently \(settings.noFailMode ? "on: bumps let you keep flying" : "off: a collision ends the round, and you can retry"). Change it in Settings → Comfort.\n\nTap Pause during flight, or hold your primary switch for \(String(format: "%.0f", settings.switchPauseHoldDuration)) seconds. With VoiceOver, use the Pause action or the escape gesture. Choose Resume when ready.\n\nSettings → Difficulty Preset offers Gentle, Standard, and Challenge. Start with Gentle for wider gaps and slower pipes."),
            ("Switches and menus", "Press your primary switch (Space or Enter on a keyboard) to start menu scanning, then press it again to choose the highlighted item. \(settings.scanScheme == .autoScan ? "Your menus currently advance automatically." : "Your menus currently wait for your secondary switch to advance.") Use your secondary switch (2 or an arrow key other than Up) to move to the next item.\n\nSettings → Switch Access lets you choose automatic or two-switch scanning, scan timing, and the hold-to-pause delay.\n\nThis guide waits for you. Replay it anytime with How to Play on the home screen.")
        ]
    }

    static func flightInstructions(for scheme: ControlScheme) -> String {
        switch scheme {
        case .tapFlap:
            return "Tap the screen or press your primary switch to rise. Between taps, the helicopter falls. With VoiceOver, double-tap to rise."
        case .holdHover:
            return "Hold the screen or your primary switch to rise. Release to fall gently. With VoiceOver, double-tap to switch between rising and falling."
        case .autoHover:
            return "The helicopter hovers automatically. Tap the screen or press your primary switch to nudge up; use your secondary switch to nudge down. With VoiceOver, double-tap to nudge up or use the Move down action."
        case .twoSwitchUD:
            return "Hold your primary switch to move up or your secondary switch to move down. Release to settle. Touching the screen also moves up. With VoiceOver, double-tap to toggle moving up or use Move down to toggle moving down."
        }
    }

    override func buildMenu() {
        show(page: 0)
    }

    /// Replaces the page in place. A new page is announced; the first one is announced
    /// by the screen change that shows the guide.
    func show(page: Int) {
        let pages = Self.pages()
        guard pages.indices.contains(page) else { return }
        let isFirstBuild = headingLabel == nil
        self.page = page
        let wasScanning = scanner.isActive
        scanner.stop()
        menu.removeAll()

        let content = pages[page]
        headingLabel = menu.addLabel(content.heading, style: .title1, alignment: .natural)
        menu.addLabel("Step \(page + 1) of \(pages.count)", style: .subheadline, alignment: .natural)
        menu.addLabel(content.body, style: .body, alignment: .natural)

        let isLast = page == pages.count - 1
        var items: [MenuItem] = [
            // Switch users can hear the full instructions without navigating static text.
            item("Read this step aloud", hint: "Reads this page with the menu scanner paused") { [weak self] in
                self?.scanner.readInstructions(content.heading + ". " + content.body + " Press your switch to resume menu scanning.")
            },
            item(isLast ? "Done" : "Next", hint: isLast ? "Finishes the guide and goes to the home screen" : "Shows the next step") { [weak self] in
                isLast ? self?.finish() : self?.show(page: page + 1)
            }
        ]
        if page > 0 {
            items.append(item("Back", hint: "Shows the previous step") { [weak self] in self?.show(page: page - 1) })
        }
        items.append(item("Skip guide", hint: "Goes to the home screen") { [weak self] in self?.finish() })
        items.forEach { menu.addButton(for: $0) }
        scanner.items = items
        if wasScanning { scanner.start() }
        if !isFirstBuild { ScreenChangeAnnouncer.post(headingLabel) }
    }

    /// Done and Skip both mark the guide finished, so it doesn't open at the next launch.
    func finish() {
        defaults.set(true, forKey: Self.completedKey)
        navigate(.home)
    }
}
