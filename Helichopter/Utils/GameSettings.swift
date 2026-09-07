import Foundation
import CoreGraphics
import UIKit

// MARK: - Phase 4: Color palette system

/// Base tint swatches; texture shading and theme overrides change the rendered colors.
/// Swatch tests enforce helicopterColor vs pipeColor ≥ 4.5:1, but do not certify artwork.
/// Opaque black/white gameplay boundaries provide visibility independently of these tints.
struct ColorPalette: Equatable {
    let id: String
    let name: String
    let helicopterColor: UIColor
    let pipeColor: UIColor          // applied to both pipe body and cap
    let colorBlendFactor: CGFloat   // 1.0 = solid tint over white/grayscale art

    static func == (lhs: ColorPalette, rhs: ColorPalette) -> Bool { lhs.id == rhs.id }
}

extension GameSettings {

    // MARK: - Palettes

    /// Gold helicopter (#FFD700, L≈0.714) vs forest-green pipe (#006600, L≈0.095).
    /// Contrast ≈ 5.25:1 helicopter-vs-pipe.
    static let paletteDefault = ColorPalette(
        id: "default", name: "Default",
        helicopterColor: UIColor(red: 1.0,   green: 0.855, blue: 0.0,   alpha: 1.0),
        pipeColor:       UIColor(red: 0.0,   green: 0.4,   blue: 0.0,   alpha: 1.0),
        colorBlendFactor: 1.0
    )

    /// Yellow helicopter (#FFEE00, L≈0.826) vs deep blue pipe (#0033CC, L≈0.068). Contrast ≈ 8.3:1.
    static let paletteHighContrast = ColorPalette(
        id: "highContrast", name: "High Contrast",
        helicopterColor: UIColor(red: 1.0,   green: 0.933, blue: 0.0,   alpha: 1.0),
        pipeColor:       UIColor(red: 0.0,   green: 0.2,   blue: 0.8,   alpha: 1.0),
        colorBlendFactor: 1.0
    )

    /// Yellow helicopter vs dark blue pipe — both hue and luminance differ under deuteranopia.
    /// Helicopter #FFEE00 (L≈0.826), Pipe #0055AA (L≈0.094). Contrast ≈ 6.1:1.
    static let paletteDeuteranopia = ColorPalette(
        id: "deuteranopia", name: "Deuteranopia-safe",
        helicopterColor: UIColor(red: 1.0,   green: 0.933, blue: 0.0,   alpha: 1.0),
        pipeColor:       UIColor(red: 0.0,   green: 0.333, blue: 0.667, alpha: 1.0),
        colorBlendFactor: 1.0
    )

    /// Same yellow/blue pairing is safe for protanopia (also a red-green deficiency).
    /// Helicopter #FFEE00 (L≈0.826), Pipe #0044BB (L≈0.062). Contrast ≈ 7.1:1.
    static let paletteProtanopia = ColorPalette(
        id: "protanopia", name: "Protanopia-safe",
        helicopterColor: UIColor(red: 1.0,   green: 0.933, blue: 0.0,   alpha: 1.0),
        pipeColor:       UIColor(red: 0.0,   green: 0.267, blue: 0.733, alpha: 1.0),
        colorBlendFactor: 1.0
    )

    /// Avoids blue-yellow confusion. White helicopter (#FFFFFF, L=1.0) vs dark red pipe
    /// (#770000, L≈0.039). Contrast ≈ 11.8:1.
    static let paletteTritanopia = ColorPalette(
        id: "tritanopia", name: "Tritanopia-safe",
        helicopterColor: UIColor(red: 1.0,   green: 1.0,   blue: 1.0,   alpha: 1.0),
        pipeColor:       UIColor(red: 0.467, green: 0.0,   blue: 0.0,   alpha: 1.0),
        colorBlendFactor: 1.0
    )

    /// Muted steel-blue helicopter (#8BB8D4, L≈0.412) vs dark warm-brown pipe (#3D1A00, L≈0.017).
    /// Contrast ≈ 7.4:1. No high-saturation/high-luminance yellows — easier for photophobia users.
    static let paletteLowLuminance = ColorPalette(
        id: "lowLuminance", name: "Low Luminance",
        helicopterColor: UIColor(red: 0.545, green: 0.722, blue: 0.831, alpha: 1.0),
        pipeColor:       UIColor(red: 0.239, green: 0.102, blue: 0.0,   alpha: 1.0),
        colorBlendFactor: 1.0
    )

    static let allPalettes: [ColorPalette] = [
        paletteDefault, paletteHighContrast, paletteDeuteranopia,
        paletteProtanopia, paletteTritanopia, paletteLowLuminance
    ]
}

// MARK: - UI Theme system

/// A full color scheme for menus and the title screen, validated to WCAG 2.1 AA.
/// All foreground/background pairs carry a contrast ratio ≥ 4.5:1.
struct UITheme {
    let id: String
    let name: String
    let sceneBackgroundColor: UIColor
    /// Applied to button sprites via color + colorBlendFactor = 1.0.
    let buttonTintColor: UIColor
    /// Text on top of buttonTintColor — verified ≥ 4.5:1 contrast.
    let buttonTextColor: UIColor
    /// Large/title labels sitting on sceneBackgroundColor — verified ≥ 4.5:1 contrast.
    let titleTextColor: UIColor
    /// When non-nil, the SKSpriteNode named "Background" in each scene is tinted solid
    /// with this color (colorBlendFactor = 1.0), overriding the sky image texture.
    /// Use for light themes where the default dark sky would make text unreadable.
    let backgroundSpriteTintColor: UIColor?
    /// When non-nil, overrides the ColorPalette's helicopterColor for this theme.
    /// Use when the selected palette's helicopter color clashes with the background
    /// (e.g. gold on cream is low-contrast; warm red reads well on parchment).
    /// Contrast guarantee: each non-nil value must achieve ≥ 4.5:1 vs sceneBackgroundColor.
    let helicopterTintColor: UIColor?
}

extension GameSettings {

    // MARK: - UI Themes

    /// Dark navy background, dark-blue buttons, white button text, sky-blue title.
    /// Button text on button bg: 11.3:1  |  Title on bg: 8.2:1
    static let themeNightSky = UITheme(
        id: "nightSky", name: "Night Sky",
        sceneBackgroundColor:      UIColor(red: 0.047, green: 0.063, blue: 0.129, alpha: 1),
        buttonTintColor:           UIColor(red: 0.118, green: 0.227, blue: 0.431, alpha: 1),
        buttonTextColor:           .white,
        titleTextColor:            UIColor(red: 0.416, green: 0.675, blue: 1.000, alpha: 1),
        backgroundSpriteTintColor: nil,
        helicopterTintColor:       nil
    )

    /// Warm cream background (sky image replaced with solid cream), steel-blue buttons,
    /// white button text, dark-navy title.
    /// Button text on button bg: 7.3:1  |  Title on cream bg: 11.8:1
    /// Helicopter: warm red #CC2626 (L≈0.061) vs cream bg (L≈0.840) → contrast ≈ 8.0:1
    static let themeParchment = UITheme(
        id: "parchment", name: "Parchment",
        sceneBackgroundColor:      UIColor(red: 0.949, green: 0.925, blue: 0.847, alpha: 1),
        buttonTintColor:           UIColor(red: 0.169, green: 0.333, blue: 0.596, alpha: 1),
        buttonTextColor:           .white,
        titleTextColor:            UIColor(red: 0.102, green: 0.165, blue: 0.341, alpha: 1),
        backgroundSpriteTintColor: UIColor(red: 0.949, green: 0.925, blue: 0.847, alpha: 1),
        helicopterTintColor:       UIColor(red: 0.800, green: 0.149, blue: 0.149, alpha: 1)
    )

    /// Deep teal-black background, dark-teal buttons, near-white cyan text, bright-cyan title.
    /// Button text on button bg: 13.3:1  |  Title on bg: 10.7:1
    static let themeNeonNight = UITheme(
        id: "neonNight", name: "Neon Night",
        sceneBackgroundColor:      UIColor(red: 0.020, green: 0.055, blue: 0.063, alpha: 1),
        buttonTintColor:           UIColor(red: 0.039, green: 0.169, blue: 0.212, alpha: 1),
        buttonTextColor:           UIColor(red: 0.878, green: 0.969, blue: 1.000, alpha: 1),
        titleTextColor:            UIColor(red: 0.251, green: 0.820, blue: 0.914, alpha: 1),
        backgroundSpriteTintColor: nil,
        helicopterTintColor:       nil
    )

    static let allThemes: [UITheme] = [themeNightSky, themeParchment, themeNeonNight]
}

// MARK: - Phase 3 enums

/// In-game input scheme for the helicopter.
enum ControlScheme: Int {
    case tapFlap     = 0  // single tap / press to flap
    case holdHover   = 1  // hold to climb, release to fall
    case autoHover   = 2  // gravity off; switch nudges altitude up/down
    case twoSwitchUD = 3  // switch 1 = up, switch 2 = down; no gravity
}

/// Menu scanning mode.
enum ScanScheme: Int {
    case autoScan  = 0  // timer auto-advances; primary switch activates
    case twoSwitch = 1  // primary activates; secondary advances manually
}

// MARK: - GameSettings

/// Single source of truth for all tunable gameplay parameters.
/// All values persist independently to UserDefaults under gs_* keys.
/// Presets are starting points — every parameter can be overridden individually after applying one.
final class GameSettings {

    static let shared = GameSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateFromLegacySettingsIfNeeded()
    }

    // MARK: - Preset Definitions

    struct Preset {
        let gapMin: CGFloat
        let gapMax: CGFloat
        let pipeSpawnInterval: TimeInterval
        let pipeMoveDuration: TimeInterval
        let scrollSpeed: Double
        let gravity: CGFloat            // negative value, applied to physicsWorld
        let flapStrength: CGFloat
        let terminalVelocity: CGFloat
        let hitboxFraction: CGFloat     // 0.4 = forgiving, 1.0 = exact sprite boundary
        let pipeHeightVariance: CGFloat // 0.0 = all pipes same height, 1.0 = full variance
    }

    static let gentlePreset = Preset(
        gapMin: 350, gapMax: 600,
        pipeSpawnInterval: 5.5, pipeMoveDuration: 10.0,
        scrollSpeed: 60.0, gravity: -3.5,
        flapStrength: 35000, terminalVelocity: 300,
        hitboxFraction: 0.6, pipeHeightVariance: 0.5
    )

    static let standardPreset = Preset(
        gapMin: 240, gapMax: 380,
        pipeSpawnInterval: 3.5, pipeMoveDuration: 7.0,
        scrollSpeed: 100.0, gravity: -5.0,
        flapStrength: 50000, terminalVelocity: 480,
        hitboxFraction: 0.8, pipeHeightVariance: 1.0
    )

    static let challengePreset = Preset(
        gapMin: 180, gapMax: 280,
        pipeSpawnInterval: 2.5, pipeMoveDuration: 4.0,
        scrollSpeed: 140.0, gravity: -6.5,
        flapStrength: 60000, terminalVelocity: 600,
        hitboxFraction: 0.95, pipeHeightVariance: 1.0
    )

    // MARK: - Storage

    private enum Key: String {
        case gapMin             = "gs_gapMin"
        case gapMax             = "gs_gapMax"
        case pipeSpawnInterval  = "gs_pipeSpawnInterval"
        case pipeMoveDuration   = "gs_pipeMoveDuration"
        case scrollSpeed        = "gs_scrollSpeed"
        case gravity            = "gs_gravity"
        case flapStrength       = "gs_flapStrength"
        case terminalVelocity   = "gs_terminalVelocity"
        case hitboxFraction     = "gs_hitboxFraction"
        case pipeHeightVariance = "gs_pipeHeightVariance"
        case hasMigrated        = "gs_hasMigrated"
        // Phase 3
        case controlScheme      = "gs_controlScheme"
        case scanScheme         = "gs_scanScheme"
        case scanDwellTime      = "gs_scanDwellTime"
        // Phase 4
        case backgroundScrollSpeed = "gs_backgroundScrollSpeed"
        // Phase 5
        case noFailMode              = "gs_noFailMode"
        case showScore               = "gs_showScore"
        case calmMode                = "gs_calmMode"
        case invulnerabilityDuration = "gs_invulnerabilityDuration"
        case isSettingsLocked        = "gs_isSettingsLocked"
    }

    private func read(_ key: Key) -> Double {
        defaults.double(forKey: key.rawValue)
    }

    private func write(_ value: Double, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    // MARK: - Parameters (each independently persisted)

    var gapMin: CGFloat {
        get { CGFloat(read(.gapMin)) }
        set { write(Double(newValue), for: .gapMin) }
    }

    var gapMax: CGFloat {
        get { CGFloat(read(.gapMax)) }
        set { write(Double(newValue), for: .gapMax) }
    }

    var pipeSpawnInterval: TimeInterval {
        get { read(.pipeSpawnInterval) }
        set { write(newValue, for: .pipeSpawnInterval) }
    }

    var pipeMoveDuration: TimeInterval {
        get { read(.pipeMoveDuration) }
        set { write(newValue, for: .pipeMoveDuration) }
    }

    var scrollSpeed: Double {
        get { read(.scrollSpeed) }
        set { write(newValue, for: .scrollSpeed) }
    }

    var gravity: CGFloat {
        get { CGFloat(read(.gravity)) }
        set { write(Double(newValue), for: .gravity) }
    }

    var flapStrength: CGFloat {
        get { CGFloat(read(.flapStrength)) }
        set { write(Double(newValue), for: .flapStrength) }
    }

    var terminalVelocity: CGFloat {
        get { CGFloat(read(.terminalVelocity)) }
        set { write(Double(newValue), for: .terminalVelocity) }
    }

    var hitboxFraction: CGFloat {
        get { CGFloat(read(.hitboxFraction)) }
        set { write(Double(newValue), for: .hitboxFraction) }
    }

    var pipeHeightVariance: CGFloat {
        get { CGFloat(read(.pipeHeightVariance)) }
        set { write(Double(newValue), for: .pipeHeightVariance) }
    }

    // MARK: - Phase 3: Switch access parameters

    /// Which input scheme the helicopter uses during gameplay.
    var controlScheme: ControlScheme {
        get { ControlScheme(rawValue: Int(read(.controlScheme))) ?? .tapFlap }
        set { write(Double(newValue.rawValue), for: .controlScheme) }
    }

    /// A deliberate primary-switch hold pauses flight. Longer delays allow sustained hover.
    var switchPauseHoldDuration: TimeInterval {
        get {
            guard let value = defaults.object(forKey: "gs_switchPauseHoldDuration") as? Double,
                  value.isFinite else { return 3.0 }
            return min(max(value, 2.0), 10.0)
        }
        set {
            defaults.set(newValue.isFinite ? min(max(newValue, 2.0), 10.0) : 3.0,
                         forKey: "gs_switchPauseHoldDuration")
        }
    }

    /// Whether menu scanning auto-advances (timer) or requires a second switch to step.
    var scanScheme: ScanScheme {
        get { ScanScheme(rawValue: Int(read(.scanScheme))) ?? .autoScan }
        set { write(Double(newValue.rawValue), for: .scanScheme) }
    }

    /// Seconds the focus ring dwells on each item before auto-advancing. Range: 0.5 – 10.0.
    var scanDwellTime: TimeInterval {
        get { let v = read(.scanDwellTime); return v > 0 ? v : 2.0 }
        set { write(newValue, for: .scanDwellTime) }
    }

    /// When true the focus scanner auto-starts in menus and announces items aloud.
    var scanningEnabled: Bool {
        get { defaults.bool(forKey: "gs_scanningEnabled") }
        set { defaults.set(newValue, forKey: "gs_scanningEnabled") }
    }

    // MARK: - Phase 4: Vision and motion parameters

    /// Scroll speed of the parallax background, independent of gameplay speed.
    /// Presets do NOT write this value — it can be tuned without affecting difficulty.
    /// Defaults to 80 pt/s. Set to 0 to stop background motion entirely.
    var backgroundScrollSpeed: Double {
        get {
            guard defaults.object(forKey: Key.backgroundScrollSpeed.rawValue) != nil else { return 80 }
            let value = read(.backgroundScrollSpeed)
            return value.isFinite && value >= 0 ? value : 80
        }
        set { write(newValue, for: .backgroundScrollSpeed) }
    }

    /// Persisted ID of the active color palette.
    var selectedPaletteID: String {
        get { defaults.string(forKey: "gs_selectedPaletteID") ?? "default" }
        set { defaults.set(newValue, forKey: "gs_selectedPaletteID") }
    }

    var selectedPalette: ColorPalette {
        GameSettings.allPalettes.first { $0.id == selectedPaletteID } ?? GameSettings.paletteDefault
    }

    /// Persisted ID of the active UI theme (menus / title screen). Defaults to "nightSky".
    var selectedThemeID: String {
        get { defaults.string(forKey: "gs_selectedThemeID") ?? "nightSky" }
        set { defaults.set(newValue, forKey: "gs_selectedThemeID") }
    }

    var selectedTheme: UITheme {
        GameSettings.allThemes.first { $0.id == selectedThemeID } ?? GameSettings.themeNightSky
    }

    // MARK: - Phase 5: Cognitive and sensory parameters

    /// When true, pipe and boundary collisions trigger brief invulnerability instead of game over.
    /// Defaults true — the recommended first experience for accessibility users.
    var noFailMode: Bool {
        get {
            let key = Key.noFailMode.rawValue
            guard defaults.object(forKey: key) != nil else { return true }
            return defaults.bool(forKey: key)
        }
        set { defaults.set(newValue, forKey: Key.noFailMode.rawValue) }
    }

    /// When false, the score HUD and end-of-run score labels are hidden.
    /// Defaults true (score visible). Can be disabled for players for whom scoring is discouraging.
    var showScore: Bool {
        get {
            let key = Key.showScore.rawValue
            guard defaults.object(forKey: key) != nil else { return true }
            return defaults.bool(forKey: key)
        }
        set { defaults.set(newValue, forKey: Key.showScore.rawValue) }
    }

    /// When true, suppresses the collision hit sound and impact haptic.
    /// The game still plays normally — it just removes the startling audio/haptic stinger.
    var calmMode: Bool {
        get { defaults.bool(forKey: Key.calmMode.rawValue) }
        set { defaults.set(newValue, forKey: Key.calmMode.rawValue) }
    }

    /// Duration (seconds) of the invulnerability window after a no-fail collision. Default 1.5s.
    var invulnerabilityDuration: TimeInterval {
        get { let v = read(.invulnerabilityDuration); return v > 0 ? v : 1.5 }
        set { write(newValue, for: .invulnerabilityDuration) }
    }

    /// When true, the Settings button is disabled so the active configuration can't be changed
    /// accidentally mid-session. Useful in classroom / caregiver setups.
    var isSettingsLocked: Bool {
        get { defaults.bool(forKey: Key.isSettingsLocked.rawValue) }
        set { defaults.set(newValue, forKey: Key.isSettingsLocked.rawValue) }
    }

    // MARK: - Preset Application

    func apply(_ preset: Preset) {
        gapMin             = preset.gapMin
        gapMax             = preset.gapMax
        pipeSpawnInterval  = preset.pipeSpawnInterval
        pipeMoveDuration   = preset.pipeMoveDuration
        scrollSpeed        = preset.scrollSpeed
        gravity            = preset.gravity
        flapStrength       = preset.flapStrength
        terminalVelocity   = preset.terminalVelocity
        hitboxFraction     = preset.hitboxFraction
        pipeHeightVariance = preset.pipeHeightVariance
    }

    func applyGentle()    { apply(GameSettings.gentlePreset) }
    func applyStandard()  { apply(GameSettings.standardPreset) }
    func applyChallenge() { apply(GameSettings.challengePreset) }

    // MARK: - Migration from legacy UserDefaults keys

    private func migrateFromLegacySettingsIfNeeded() {
        guard !defaults.bool(forKey: Key.hasMigrated.rawValue) else { return }

        // Map old Difficulty setting to the nearest preset so existing users
        // experience the same gameplay feel they had before.
        switch defaults.getDifficultyLevel() {
        case .easy:   applyGentle()
        case .medium: applyStandard()
        case .hard:   applyChallenge()
        }

        defaults.set(true, forKey: Key.hasMigrated.rawValue)
    }
}
