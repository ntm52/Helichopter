import UIKit

// MARK: - Pages

/// The groups Settings is split into. Each has its own page, opened from the menu.
enum SettingsCategory: CaseIterable {
    case difficulty, comfort, controls, colours, sound, caregiver

    var title: String {
        switch self {
        case .difficulty: return "Difficulty"
        case .comfort: return "Comfort"
        case .controls: return "Controls and Switches"
        case .colours: return "Colours"
        case .sound: return "Sound"
        case .caregiver: return "Caregiver"
        }
    }

    /// What is on the page, shown under the title and read as the hint.
    var detail: String {
        switch self {
        case .difficulty: return "Presets, gap size, pipe speed, and hitbox"
        case .comfort: return "No-Fail, Calm Mode, outline, and score"
        case .controls: return "Flying, menu scanning, and pausing"
        case .colours: return "Helicopter and pipe colours"
        case .sound: return "Sound effects and music"
        case .caregiver: return "Lock settings"
        }
    }

    /// The SF Symbol on the category's card. Decoration only.
    var symbolName: String {
        switch self {
        case .difficulty: return "speedometer"
        case .comfort: return "heart.fill"
        case .controls: return "hand.tap.fill"
        case .colours: return "paintpalette.fill"
        case .sound: return "speaker.wave.2.fill"
        case .caregiver: return "lock.fill"
        }
    }
}

/// What a Settings panel shows: the menu of categories, or one category.
enum SettingsPage: Equatable {
    case menu
    case category(SettingsCategory)

    var category: SettingsCategory? {
        if case .category(let category) = self { return category }
        return nil
    }
}

// MARK: - SettingsPanelView
// One page of Settings, shown by SettingsViewController: the menu of categories, or a
// category's settings. Rows are built in SettingsRows.swift; the switch-friendly
// adjustment page in SettingsAdjustmentPanel.swift.

final class SettingsPanelView: ScrollingPanelView {

    let page: SettingsPage

    init(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection? = nil, page: SettingsPage) {
        self.page = page
        super.init(frame: frame, theme: theme, fontTraits: fontTraits)
    }

    /// The menu of categories.
    required init(frame: CGRect, theme: UITheme, fontTraits: UITraitCollection? = nil) {
        page = .menu
        super.init(frame: frame, theme: theme, fontTraits: fontTraits)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var title: String { page.category?.title ?? "Settings" }
    override var backHint: String { page == .menu ? "Goes to the home screen" : "Goes back to Settings" }

    static let lockedMessage = "Locked by a caregiver. To change these, turn off Lock Settings on the Caregiver page."

    /// Opens a category's page.
    var onOpenCategory: ((SettingsCategory) -> Void)?

    var adjustmentPanel: UIView?
    var adjustmentTargets: [NSObject] = []
    var returnControlLabel: String?
    var paletteViews: [UIView] = []
    /// Long explanations, by the name of the control whose page shows them.
    var infoPages: [String: String] = [:]
    /// The buttons of each list of choices, by the list's name.
    var choiceGroups: [String: [ChoiceButton]] = [:]

    /// Opens the Hangar, where the menu theme is now chosen.
    var onOpenHangar: (() -> Void)?

    static var hangarPointerTitle: String {
        "Menu Theme: \(GameSettings.shared.selectedTheme.name). Change it in the Hangar"
    }

    override var isAdjusting: Bool { adjustmentPanel != nil }

    override var focusedSetting: String? { returnControlLabel ?? super.focusedSetting }

    /// Sliders open the adjustment page instead of changing directly.
    override func activate(_ control: UIControl) {
        if control is UISlider {
            showAdjustment(for: control)
        } else {
            super.activate(control)
        }
    }

    // MARK: - Sections

    override func buildSections() {
        guard let category = page.category else { return buildMenu() }
        let locked = GameSettings.shared.isSettingsLocked && category != .caregiver
        if locked {
            noteRow(Self.lockedMessage)
            // The note has a card of its own: the page's rows are dimmed, the note is not.
            endCard()
        }
        let note = stack.arrangedSubviews
        switch category {
        case .difficulty: buildDifficulty()
        case .comfort: buildComfort()
        case .controls: buildControls()
        case .colours: buildColours()
        case .sound: buildSound()
        case .caregiver: buildCaregiver()
        }
        // The page stays readable, and Back stays reachable, while preventing edits.
        if locked { lock(stack.arrangedSubviews.filter { !note.contains($0) }) }
    }

    /// The menu: one card per category, then Reset and the About pages.
    private func buildMenu() {
        for category in SettingsCategory.allCases { appendToPage(categoryCard(category)) }

        sectionHeader("Reset")
        let reset = panelButton("Reset Settings", icon: "arrow.counterclockwise", target: self,
                                action: #selector(showAdjustment(from:)))
        reset.accessibilityLabel = "Reset Settings"
        appendToPage(reset)
        if GameSettings.shared.isSettingsLocked { lock([reset]) }

        // Informational only, so it stays available when Settings is locked.
        sectionHeader("About")
        for title in ["Privacy Policy", "Acknowledgements"] {
            let button = panelButton(title, target: self, action: #selector(showAdjustment(from:)))
            button.accessibilityLabel = title
            appendToPage(button)
        }
    }

    private func buildDifficulty() {
        let gs = GameSettings.shared
        sectionHeader("Difficulty Preset")
        presetButtons()

        sectionHeader("Gameplay")
        // Gap: gentle midpoint≈475, standard≈310, challenge≈230. Wider = easier.
        sliderRow("Gap Size",
                  detail: "How wide the opening between pipes is",
                  lo: "Narrow", hi: "Wide",
                  min: 200, max: 500,
                  value: Float((gs.gapMin + gs.gapMax) / 2)) { [weak self] v in
            self?.applyGap(CGFloat(v))
        }
        // Pipe speed: inverted so slider-right = faster pipes.
        sliderRow("Pipe Speed",
                  detail: "How fast pipes cross the screen",
                  lo: "Slow", hi: "Fast",
                  min: 4, max: 10,
                  value: Float(14 - gs.pipeMoveDuration)) { v in
            gs.pipeMoveDuration = TimeInterval(14 - Double(v))
        }
        sliderRow("Hitbox Size",
                  detail: "How closely collisions follow the helicopter's visual edge",
                  lo: "Generous", hi: "Exact",
                  min: 0.4, max: 1.0,
                  value: Float(gs.hitboxFraction)) { v in
            gs.hitboxFraction = CGFloat(v)
        }

        sectionHeader("Motion")
        sliderRow("Background Scroll",
                  detail: "How fast the sky moves behind the game",
                  more: "Speed of the sky behind the game — independent of pipe speed",
                  lo: "Still", hi: "Fast",
                  min: 0, max: 200,
                  value: Float(gs.backgroundScrollSpeed)) { v in
            gs.backgroundScrollSpeed = Double(v)
        }
    }

    private func buildComfort() {
        let gs = GameSettings.shared
        toggleRow("No-Fail Mode",
                  detail: "Helicopter passes through pipes — no game over",
                  isOn: gs.noFailMode) { v in gs.noFailMode = v }
        toggleRow("Calm Mode",
                  detail: "No collision sounds or vibration on impact",
                  isOn: gs.calmMode) { v in gs.calmMode = v }
        toggleRow("Helicopter Outline",
                  detail: "Black and white contrast marker around the helicopter",
                  isOn: gs.helicopterOutline) { v in gs.helicopterOutline = v }
        toggleRow("Hide Game While Paused",
                  detail: "A plain background behind the pause menu",
                  hint: "Use a solid background behind the pause menu to reduce distractions",
                  isOn: gs.hideGameWhilePaused) { v in gs.hideGameWhilePaused = v }
        toggleRow("Show Score",
                  detail: "Your score and best score, in play and after",
                  hint: "Display current and best scores during play and at the end of a run",
                  isOn: gs.showScore) { v in gs.showScore = v }
    }

    private func buildControls() {
        let gs = GameSettings.shared
        sectionHeader("Menu Scanning")
        toggleRow("Auto-Scan Menus",
                  detail: "Menus start scanning as soon as they open. When off, your first switch press starts scanning.",
                  isOn: gs.scanningEnabled) { v in gs.scanningEnabled = v }
        choiceRow("Menu Scan Mode",
                  detail: "Timed moves the highlight on a timer. Step with Switch 2 waits for your second switch to move it.",
                  items: ["Timed", "Step with Switch 2"],
                  selectedIndex: gs.scanScheme.rawValue) { idx in
            if let scheme = ScanScheme(rawValue: idx) { gs.scanScheme = scheme }
        }
        sliderRow("Scan Dwell Time",
                  detail: "How long the scanner pauses on each button before moving on",
                  lo: "0.5 s", hi: "10 s",
                  min: 0.5, max: 10.0,
                  value: Float(gs.scanDwellTime), seconds: true) { v in
            gs.scanDwellTime = TimeInterval(v)
        }

        sectionHeader("Flying")
        choiceRow("In-Game Control",
                  detail: "How you control the helicopter's altitude while playing",
                  items: ["Tap to Flap", "Hold to Hover", "Auto Hover", "Up/Down Switches"],
                  selectedIndex: gs.controlScheme.rawValue) { idx in
            if let scheme = ControlScheme(rawValue: idx) { gs.controlScheme = scheme }
        }
        toggleRow("VoiceOver Direct Touch",
                  detail: "With VoiceOver on, touch the lower half of the game to fly",
                  more: "With VoiceOver on, touching the lower half of the game flies the helicopter at once, with no double-tap. Turn off to fly with double-taps and VoiceOver actions instead.",
                  isOn: gs.voiceOverDirectTouch) { v in gs.voiceOverDirectTouch = v }

        sectionHeader("Pausing")
        toggleRow("Pause by Holding Switch",
                  detail: "Hold the primary switch to pause the game",
                  more: "Hold the primary switch to pause in Tap to Flap, Hold to Hover, and Auto Hover. Turn off if a player pauses by accident; the Pause button still works. The secondary switch pauses Tap to Flap and Hold to Hover, and holding both switches pauses Up/Down Switches.",
                  isOn: gs.holdToPauseEnabled) { v in gs.holdToPauseEnabled = v }
        sliderRow("Hold Switch to Pause",
                  detail: "How long to hold the primary switch to pause",
                  more: "How long to hold the primary switch to pause. Release it before choosing a menu item.",
                  lo: "2 s", hi: "10 s",
                  min: 2, max: 10,
                  value: Float(gs.switchPauseHoldDuration), seconds: true) { v in
            gs.switchPauseHoldDuration = TimeInterval(v)
        }
    }

    private func buildColours() {
        sectionHeader("Colour Accessibility")
        paletteRow()

        // The theme is chosen in the Hangar; this points players who look for it here.
        sectionHeader("Menu Theme")
        // No icon at accessibility text sizes: the long title needs the width.
        let large = (fontTraits ?? traitCollection).preferredContentSizeCategory.isAccessibilityCategory
        let hangar = panelButton(Self.hangarPointerTitle, icon: large ? nil : "paintbrush.fill", target: self,
                                 action: #selector(openHangar))
        hangar.accessibilityLabel = Self.hangarPointerTitle
        hangar.accessibilityHint = "Opens the Hangar"
        // Voice Control users can say the short name.
        hangar.accessibilityUserInputLabels = ["Menu Theme", Self.hangarPointerTitle]
        appendToPage(hangar)
    }

    private func buildSound() {
        toggleRow("Sound Effects",
                  detail: "Play sounds during the game",
                  isOn: UserDefaults.standard.bool(for: .isSoundEffectsOn)) { v in
            UserDefaults.standard.set(v, for: .isSoundEffectsOn)
        }
        toggleRow("Music",
                  detail: "Play background music",
                  isOn: UserDefaults.standard.bool(for: .isMusicOn)) { v in
            UserDefaults.standard.set(v, for: .isMusicOn)
        }
    }

    private func buildCaregiver() {
        let gs = GameSettings.shared
        toggleRow("Lock Settings",
                  detail: "Prevents changes to every other setting and to the Hangar. Turn this off to edit them.",
                  isOn: gs.isSettingsLocked) { [weak self] v in
            gs.isSettingsLocked = v
            self?.onThemeChanged?()
        }
    }

    @objc private func openHangar() { onOpenHangar?() }

    /// Reset, Privacy Policy, and Acknowledgements open the adjustment page.
    @objc private func showAdjustment(from sender: UIButton) {
        showAdjustment(for: sender)
    }

    // MARK: - Gap helper

    private func applyGap(_ midpoint: CGFloat) {
        let spread = max(60, midpoint * 0.22)
        GameSettings.shared.gapMin = max(160, midpoint - spread)
        GameSettings.shared.gapMax = min(600, midpoint + spread)
    }
}
