import UIKit

extension UserDefaults {
    
    // MARK: - Methods
    
    func integer(for setting: Setting) -> Int {
        return self.integer(forKey: setting.rawValue)
    }
    
    func set(_ int: Int, for setting: Setting) {
        set(int, forKey: setting.rawValue)
    }
    
    func bool(for setting: Setting) -> Bool {
        return bool(forKey: setting.rawValue)
    }
    
    func set(_ bool: Bool, for setting: Setting) {
        set(bool, forKey: setting.rawValue)
    }
    
    func set(difficultyLevel level: Difficulty) {
        set(level.rawValue, forKey: Setting.difficulty.rawValue)
    }
    
    func getDifficultyLevel() -> Difficulty {
        let value = double(forKey: Setting.difficulty.rawValue)
        return Difficulty(rawValue: value) ?? .medium
    }
}

enum Setting: String {

    // MARK: - Cases

    case bestScore
    case lastScore
    case isSoundEffectsOn
    case isMusicOn
    case difficulty
    
    // MARK: - Methods
    
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Setting.bestScore.rawValue: 0,
            Setting.lastScore.rawValue: 0,
            Setting.isSoundEffectsOn.rawValue: true,
            Setting.isMusicOn.rawValue: true,
            Setting.difficulty.rawValue: Difficulty.medium.rawValue
        ])
    }
}

enum Difficulty: Double {
    case easy = 5.5
    case medium = 3.5
    case hard = 2.5
}
