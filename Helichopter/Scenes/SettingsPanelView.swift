import UIKit

// MARK: - SettingsPanelView
// The scrolling list of settings shown by SettingsViewController. Rows are built in
// SettingsRows.swift; the switch-friendly adjustment page in SettingsAdjustmentPanel.swift.

final class SettingsPanelView: ScrollingPanelView {

    override class var title: String { "Settings" }

    var adjustmentPanel: UIView?
    var adjustmentTargets: [NSObject] = []
    var returnControlLabel: String?
    var paletteViews: [(UIView, String)] = []

    /// Opens the Hangar, where the menu theme is now chosen.
    var onOpenHangar: (() -> Void)?

    static var hangarPointerTitle: String {
        "Menu Theme: \(GameSettings.shared.selectedTheme.name). Change it in the Hangar"
    }

    override var isAdjusting: Bool { adjustmentPanel != nil }

    override var focusedSetting: String? { returnControlLabel ?? super.focusedSetting }

    /// Sliders and segmented controls open the adjustment page instead of changing directly.
    override func activate(_ control: UIControl) {
        if control is UISlider || control is UISegmentedControl {
            showAdjustment(for: control)
        } else {
            super.activate(control)
        }
    }

    // MARK: - Sections

    override func buildSections() {
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
                  detail: "Speed of the sky behind the game — independent of pipe speed",
                  lo: "Still", hi: "Fast",
                  min: 0, max: 200,
                  value: Float(gs.backgroundScrollSpeed)) { v in
            gs.backgroundScrollSpeed = Double(v)
        }

        sectionHeader("Comfort")
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
                  detail: "Use a solid background behind the pause menu to reduce distractions",
                  isOn: gs.hideGameWhilePaused) { v in gs.hideGameWhilePaused = v }
        toggleRow("Show Score",
                  detail: "Display current and best scores during play and at the end of a run",
                  isOn: gs.showScore) { v in gs.showScore = v }

        sectionHeader("Switch Access")
        toggleRow("Auto-Scan Menus",
                  detail: "Menus start scanning as soon as they open. When off, your first switch press starts scanning.",
                  isOn: gs.scanningEnabled) { v in gs.scanningEnabled = v }
        segmentedRow("Menu Scan Mode",
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
        segmentedRow("In-Game Control",
                     detail: "How you control the helicopter's altitude while playing",
                     items: ["Tap to Flap", "Hold to Hover", "Auto Hover", "Up/Down Switches"],
                     selectedIndex: gs.controlScheme.rawValue) { idx in
            if let scheme = ControlScheme(rawValue: idx) { gs.controlScheme = scheme }
        }

        sliderRow("Hold Switch to Pause",
                  detail: "Hold the primary switch to pause, then release before choosing a menu item. For longer hover holds, increase this delay.",
                  lo: "2 s", hi: "10 s",
                  min: 2, max: 10,
                  value: Float(gs.switchPauseHoldDuration), seconds: true) { v in
            gs.switchPauseHoldDuration = TimeInterval(v)
        }

        // The theme is chosen in the Hangar; this points players who look for it here.
        sectionHeader("Menu Theme")
        let hangar = plainButton(Self.hangarPointerTitle, color: style.accent, target: self,
                                 action: #selector(openHangar))
        hangar.accessibilityLabel = Self.hangarPointerTitle
        hangar.accessibilityHint = "Opens the Hangar"
        // Voice Control users can say the short name.
        hangar.accessibilityUserInputLabels = ["Menu Theme", Self.hangarPointerTitle]
        hangar.titleLabel?.numberOfLines = 0
        hangar.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        stack.addArrangedSubview(hangar)

        sectionHeader("Colour Accessibility")
        paletteRow()

        sectionHeader("Audio")
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

        sectionHeader("Reset")
        let reset = plainButton("Reset Settings", color: style.accent, target: self,
                                action: #selector(showAdjustment(from:)))
        reset.accessibilityLabel = "Reset Settings"
        reset.titleLabel?.numberOfLines = 0
        reset.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        stack.addArrangedSubview(reset)

        if gs.isSettingsLocked {
            // Keep the panel and Back reachable, while preventing accidental edits.
            lock(stack.arrangedSubviews)
        }
        sectionHeader("Caregiver")
        toggleRow("Lock Settings",
                  detail: "Prevents changes to the controls above. Turn this off to edit settings.",
                  isOn: gs.isSettingsLocked) { [weak self] v in
            gs.isSettingsLocked = v
            self?.onThemeChanged?()
        }

        // Informational only, so it stays available when Settings is locked.
        sectionHeader("About")
        for title in ["Privacy Policy", "Acknowledgements"] {
            let button = plainButton(title, color: style.accent, target: self, action: #selector(showAdjustment(from:)))
            button.accessibilityLabel = title
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            stack.addArrangedSubview(button)
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
