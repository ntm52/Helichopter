import SpriteKit

class SettingsScene: RoutingUtilityScene, ToggleButtonNodeResponderType, TriggleButtonNodeResponderType {

    // MARK: - Overrides

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        let soundEffectsButton = scene?.childNode(withName: "SoundEffects") as? ToggleButtonNode
        soundEffectsButton?.isOn = UserDefaults.standard.bool(for: .isSoundEffectsOn)
        soundEffectsButton?.type = "SoundEffects"

        let musicButton = scene?.childNode(withName: "Music") as? ToggleButtonNode
        musicButton?.isOn = UserDefaults.standard.bool(for: .isMusicOn)
        musicButton?.type = "Music"

        // B2 fix: isOn now correctly means wide/far gaps (was inverted before)
        let pipeDistanceButton = scene?.childNode(withName: "PipeDistance") as? ToggleButtonNode
        pipeDistanceButton?.isOn = GameSettings.shared.gapMax >= 500
        pipeDistanceButton?.type = "PipeDistance"

        let difficultyButton = scene?.childNode(withName: "Difficulty") as? TriggleButtonNode
        let difficultyLevel = UserDefaults.standard.getDifficultyLevel()
        let difficultyState = TriggleButtonNode.TriggleState.convert(from: difficultyLevel)
        difficultyButton?.triggle = .init(state: difficultyState)
    }

    // MARK: - Conformance to ToggleButtonNodeResponderType

    func toggleButtonTriggered(toggle: ToggleButtonNode) {
        switch toggle.type {
        case "SoundEffects":
            UserDefaults.standard.set(toggle.isOn, for: .isSoundEffectsOn)
        case "Music":
            UserDefaults.standard.set(toggle.isOn, for: .isMusicOn)
        case "PipeDistance":
            // B2 fix: isOn = true now means wide/far gaps (was backwards before)
            if toggle.isOn {
                GameSettings.shared.gapMin = 350
                GameSettings.shared.gapMax = 600
            } else {
                GameSettings.shared.gapMin = GameSettings.standardPreset.gapMin
                GameSettings.shared.gapMax = GameSettings.standardPreset.gapMax
            }
        default:
            return
        }
    }

    // MARK: - Conformance to TriggleButtonNodeResponderType

    func triggleButtonTriggered(triggle: TriggleButtonNode) {
        let difficulty = triggle.triggle.toDifficultyLevel()
        // Apply the full preset — all tuning parameters update together
        switch difficulty {
        case .easy:   GameSettings.shared.applyGentle()
        case .medium: GameSettings.shared.applyStandard()
        case .hard:   GameSettings.shared.applyChallenge()
        }
        // Keep legacy key in sync so the triggle button shows the right state on re-open
        UserDefaults.standard.set(difficultyLevel: difficulty)
    }

}
