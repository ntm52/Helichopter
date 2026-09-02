import Foundation
import CoreGraphics

/// Single source of truth for all tunable gameplay parameters.
/// All values persist independently to UserDefaults under gs_* keys.
/// Presets are starting points — every parameter can be overridden individually after applying one.
final class GameSettings {

    static let shared = GameSettings()

    private init() {
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
    }

    private func read(_ key: Key) -> Double {
        UserDefaults.standard.double(forKey: key.rawValue)
    }

    private func write(_ value: Double, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
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
        guard !UserDefaults.standard.bool(forKey: Key.hasMigrated.rawValue) else { return }

        // Map old Difficulty setting to the nearest preset so existing users
        // experience the same gameplay feel they had before.
        switch UserDefaults.standard.getDifficultyLevel() {
        case .easy:   applyGentle()
        case .medium: applyStandard()
        case .hard:   applyChallenge()
        }

        UserDefaults.standard.set(true, forKey: Key.hasMigrated.rawValue)
    }
}
