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
            ("Your flight controls", "Fly through the gaps between pipes.\n\n" + flightInstructions(for: settings.controlScheme, directTouch: settings.voiceOverDirectTouch) + "\n\nYou can change controls in Settings → Switch Access."),
            ("Go at your own pace", "No-fail mode is currently \(settings.noFailMode ? "on: bumps let you keep flying" : "off: a collision ends the round, and you can retry"). Change it in Settings → Comfort.\n\n\(pauseInstructions(for: settings)) With VoiceOver, use the Pause button at the top of the screen\(settings.voiceOverDirectTouch ? "" : ", the Pause action, or the escape gesture"). Choose Resume when ready.\n\nSettings → Difficulty Preset offers Gentle, Standard, and Challenge. Start with Gentle for wider gaps and slower pipes."),
            ("Switches and menus", "Press your primary switch (Space or Enter on a keyboard) to start menu scanning, then press it again to choose the highlighted item. \(settings.scanScheme == .autoScan ? "Your menus currently advance automatically." : "Your menus currently wait for your secondary switch to advance.") Use your secondary switch (2 or an arrow key other than Up) to move to the next item.\n\nSettings → Switch Access lets you choose Timed or Step with Switch 2 scanning, scan timing, and the hold-to-pause delay.\n\nThis guide waits for you. Replay it anytime with How to Play on the home screen.")
        ]
    }

    static func flightInstructions(for scheme: ControlScheme, directTouch: Bool) -> String {
        if directTouch {
            let area = scheme.splitsTouchIntoUpAndDown ? "the top or bottom half" : "the lower half"
            return touchAndSwitchInstructions(for: scheme)
                + " With VoiceOver, touch \(area) of the screen; it responds straight away, without double-tapping."
        }
        return touchAndSwitchInstructions(for: scheme) + " " + voiceOverInstructions(for: scheme)
    }

    private static func touchAndSwitchInstructions(for scheme: ControlScheme) -> String {
        switch scheme {
        case .tapFlap:
            return "Tap the screen or press your primary switch to rise. Between taps, the helicopter falls."
        case .holdHover:
            return "Hold the screen or your primary switch to rise. Release to fall gently."
        case .autoHover:
            return "The helicopter hovers automatically. Tap the top half of the screen or press your primary switch to nudge up; tap the bottom half or press your secondary switch to nudge down."
        case .twoSwitchUD:
            return "Hold the top half of the screen or your primary switch to move up, or the bottom half or your secondary switch to move down. Release to settle."
        }
    }

    private static func voiceOverInstructions(for scheme: ControlScheme) -> String {
        switch scheme {
        case .tapFlap: return "With VoiceOver, double-tap to rise."
        case .holdHover: return "With VoiceOver, double-tap to switch between rising and falling."
        case .autoHover: return "With VoiceOver, double-tap Fly up or Fly down to nudge."
        case .twoSwitchUD: return "With VoiceOver, double-tap Fly up or Fly down to start moving, and again to stop."
        }
    }

    /// How this player pauses with switches; the Pause button works in every scheme.
    static func pauseInstructions(for settings: GameSettings) -> String {
        let hold = settings.holdToPauseEnabled
            ? "hold your primary switch for \(String(format: "%.0f", settings.switchPauseHoldDuration)) seconds" : nil
        switch settings.controlScheme {
        case .tapFlap:
            return "Tap Pause during flight, " + (hold.map { "\($0), " } ?? "") + "or press your secondary switch."
        case .holdHover:
            return "Tap Pause during flight or press your secondary switch." + (hold.map { " With one switch, \($0)." } ?? "")
        case .autoHover:
            return hold.map { "Tap Pause during flight, or \($0)." } ?? "Tap Pause during flight."
        case .twoSwitchUD:
            return "Tap Pause during flight, or hold both switches together for half a second."
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
