import Testing
import Foundation
@testable import Helichopter

@Suite("GameSettings UserDefaults Round-Trips", .serialized) struct GameSettingsTests {

    private var gs: GameSettings { GameSettings.shared }

    // MARK: - Numeric round-trips

    @Test func gapMinRoundTrip() {
        let saved = gs.gapMin
        defer { gs.gapMin = saved }
        gs.gapMin = 312.5
        #expect(gs.gapMin == 312.5)
    }

    @Test func pipeSpawnIntervalRoundTrip() {
        let saved = gs.pipeSpawnInterval
        defer { gs.pipeSpawnInterval = saved }
        gs.pipeSpawnInterval = 4.75
        #expect(gs.pipeSpawnInterval == 4.75)
    }

    @Test func scrollSpeedRoundTrip() {
        let saved = gs.scrollSpeed
        defer { gs.scrollSpeed = saved }
        gs.scrollSpeed = 123.0
        #expect(gs.scrollSpeed == 123.0)
    }

    @Test func gravityRoundTrip() {
        let saved = gs.gravity
        defer { gs.gravity = saved }
        gs.gravity = -4.2
        #expect(gs.gravity == -4.2)
    }

    @Test func hitboxFractionRoundTrip() {
        let saved = gs.hitboxFraction
        defer { gs.hitboxFraction = saved }
        gs.hitboxFraction = 0.65
        #expect(gs.hitboxFraction == 0.65)
    }

    // MARK: - Bool round-trips

    @Test func calmModeRoundTrip() {
        let saved = gs.calmMode
        defer { gs.calmMode = saved }
        gs.calmMode = true
        #expect(gs.calmMode == true)
        gs.calmMode = false
        #expect(gs.calmMode == false)
    }

    @Test func isSettingsLockedRoundTrip() {
        let saved = gs.isSettingsLocked
        defer { gs.isSettingsLocked = saved }
        gs.isSettingsLocked = true
        #expect(gs.isSettingsLocked == true)
        gs.isSettingsLocked = false
        #expect(gs.isSettingsLocked == false)
    }

    // MARK: - Bool defaults (key absent -> true)

    @Test func noFailModeDefaultsTrue() {
        let key = "gs_noFailMode"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { restoreObject(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        #expect(gs.noFailMode == true)
    }

    @Test func showScoreDefaultsTrue() {
        let key = "gs_showScore"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { restoreObject(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        #expect(gs.showScore == true)
    }

    // MARK: - Custom numeric defaults

    @Test func scanDwellTimeDefaultsTwoSeconds() {
        let key = "gs_scanDwellTime"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { restoreObject(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        #expect(gs.scanDwellTime == 2.0)
    }

    @Test func backgroundScrollSpeedDefaults80() {
        let key = "gs_backgroundScrollSpeed"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { restoreObject(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        #expect(gs.backgroundScrollSpeed == 80.0)
    }

    // MARK: - Enum round-trips

    @Test func controlSchemeAllCasesRoundTrip() {
        let saved = gs.controlScheme
        defer { gs.controlScheme = saved }
        for scheme in [ControlScheme.tapFlap, .holdHover, .autoHover, .twoSwitchUD] {
            gs.controlScheme = scheme
            #expect(gs.controlScheme == scheme)
        }
    }

    @Test func scanSchemeAllCasesRoundTrip() {
        let saved = gs.scanScheme
        defer { gs.scanScheme = saved }
        gs.scanScheme = .twoSwitch
        #expect(gs.scanScheme == .twoSwitch)
        gs.scanScheme = .autoScan
        #expect(gs.scanScheme == .autoScan)
    }

    // MARK: - Preset application

    @Test func gentlePresetAppliesAllValues() {
        let p = GameSettings.gentlePreset
        let saved = capturePresetValues()
        defer { restorePresetValues(saved) }
        gs.applyGentle()
        #expect(gs.gapMin             == p.gapMin)
        #expect(gs.gapMax             == p.gapMax)
        #expect(gs.pipeSpawnInterval  == p.pipeSpawnInterval)
        #expect(gs.pipeMoveDuration   == p.pipeMoveDuration)
        #expect(gs.scrollSpeed        == p.scrollSpeed)
        #expect(gs.gravity            == p.gravity)
        #expect(gs.flapStrength       == p.flapStrength)
        #expect(gs.terminalVelocity   == p.terminalVelocity)
        #expect(gs.hitboxFraction     == p.hitboxFraction)
        #expect(gs.pipeHeightVariance == p.pipeHeightVariance)
    }

    @Test func standardPresetAppliesKeyValues() {
        let p = GameSettings.standardPreset
        let saved = capturePresetValues()
        defer { restorePresetValues(saved) }
        gs.applyStandard()
        #expect(gs.gapMin      == p.gapMin)
        #expect(gs.scrollSpeed == p.scrollSpeed)
        #expect(gs.gravity     == p.gravity)
    }

    // MARK: - Palette / theme selection

    @Test func paletteSelectionRoundTrip() {
        let saved = gs.selectedPaletteID
        defer { gs.selectedPaletteID = saved }
        gs.selectedPaletteID = "highContrast"
        #expect(gs.selectedPalette.id == "highContrast")
        gs.selectedPaletteID = "default"
        #expect(gs.selectedPalette.id == "default")
    }

    @Test func unknownPaletteIDFallsBackToDefault() {
        let saved = gs.selectedPaletteID
        defer { gs.selectedPaletteID = saved }
        gs.selectedPaletteID = "nonexistent_palette"
        #expect(gs.selectedPalette.id == "default")
    }

    @Test func themeSelectionRoundTrip() {
        let saved = gs.selectedThemeID
        defer { gs.selectedThemeID = saved }
        gs.selectedThemeID = "parchment"
        #expect(gs.selectedTheme.id == "parchment")
        gs.selectedThemeID = "neonNight"
        #expect(gs.selectedTheme.id == "neonNight")
    }

    @Test func unknownThemeIDFallsBackToNightSky() {
        let saved = gs.selectedThemeID
        defer { gs.selectedThemeID = saved }
        gs.selectedThemeID = "nonexistent_theme"
        #expect(gs.selectedTheme.id == "nightSky")
    }

    // MARK: - Helpers

    private func restoreObject(_ value: Any?, forKey key: String) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }

    private typealias PresetSnapshot = (
        gapMin: CGFloat, gapMax: CGFloat,
        pipeSpawnInterval: TimeInterval, pipeMoveDuration: TimeInterval,
        scrollSpeed: Double, gravity: CGFloat,
        flapStrength: CGFloat, terminalVelocity: CGFloat,
        hitboxFraction: CGFloat, pipeHeightVariance: CGFloat
    )

    private func capturePresetValues() -> PresetSnapshot {
        (gs.gapMin, gs.gapMax, gs.pipeSpawnInterval, gs.pipeMoveDuration,
         gs.scrollSpeed, gs.gravity, gs.flapStrength, gs.terminalVelocity,
         gs.hitboxFraction, gs.pipeHeightVariance)
    }

    private func restorePresetValues(_ s: PresetSnapshot) {
        gs.gapMin             = s.gapMin
        gs.gapMax             = s.gapMax
        gs.pipeSpawnInterval  = s.pipeSpawnInterval
        gs.pipeMoveDuration   = s.pipeMoveDuration
        gs.scrollSpeed        = s.scrollSpeed
        gs.gravity            = s.gravity
        gs.flapStrength       = s.flapStrength
        gs.terminalVelocity   = s.terminalVelocity
        gs.hitboxFraction     = s.hitboxFraction
        gs.pipeHeightVariance = s.pipeHeightVariance
    }
}
