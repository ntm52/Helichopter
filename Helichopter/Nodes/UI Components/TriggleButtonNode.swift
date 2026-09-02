import SpriteKit

/// A type that can respond to `TriggleButtonNode` button press events.
protocol TriggleButtonNodeResponderType: AnyObject {
    func triggleButtonTriggered(triggle: TriggleButtonNode)
}

class TriggleButtonNode: ButtonNode {

    // MARK: - Custom types

    enum TriggleState {
        case off
        case switched
        case on

        static func convert(from difficultyLevel: Difficulty) -> TriggleState {
            switch difficultyLevel {
            case .easy:   return .off
            case .medium: return .switched
            case .hard:   return .on
            }
        }
    }

    struct Triggle {

        private(set) var off: Bool
        private(set) var switched: Bool
        private(set) var on: Bool
        private var lastTriggleState: TriggleState

        init(state: TriggleState) {
            switch state {
            case .off:
                off = true; switched = false; on = false; lastTriggleState = .off
            case .switched:
                off = false; switched = true; on = false; lastTriggleState = .switched
            case .on:
                off = false; switched = false; on = true; lastTriggleState = .on
            }
        }

        mutating func switchState() {
            if off {
                off = !off; switched = !switched; lastTriggleState = .switched
            } else if switched {
                switched = !switched; on = !on; lastTriggleState = .on
            } else if on {
                on = !on; off = !off; lastTriggleState = .off
            }
        }

        func state() -> TriggleState { return lastTriggleState }

        func toDifficultyLevel() -> Difficulty {
            switch lastTriggleState {
            case .off:     return .easy
            case .switched: return .medium
            case .on:      return .hard
            }
        }
    }

    // MARK: - Properties

    var triggle: Triggle {
        didSet {
            guard let off = state.off, let switched = state.switched, let on = state.on else {
                return
            }
            on.isHidden = !triggle.on
            off.isHidden = !triggle.off
            switched.isHidden = !triggle.switched

            if isUserInteractionEnabled {
                triggleResponder.triggleButtonTriggered(triggle: self)
            }
        }
    }

    private var state: (off: SKLabelNode?, switched: SKLabelNode?, on: SKLabelNode?) = (off: nil, switched: nil, on: nil)

    var triggleResponder: TriggleButtonNodeResponderType {
        guard let responder = scene as? TriggleButtonNodeResponderType else {
            fatalError("TriggleButtonNode may only be used within a `TriggleButtonNodeResponderType` scene.")
        }
        return responder
    }

    // MARK: - Initialisers

    required init?(coder aDecoder: NSCoder) {
        let difficultyLevel = UserDefaults.standard.getDifficultyLevel()
        triggle = .init(state: TriggleState.convert(from: difficultyLevel))

        super.init(coder: aDecoder)

        // B8 fix: return nil instead of fatalError when expected child labels are absent
        guard let offState = childNode(withName: "Easy") as? SKLabelNode else {
            return nil
        }
        state.off = offState

        guard let switchedState = childNode(withName: "Medium") as? SKLabelNode else {
            return nil
        }
        state.switched = switchedState

        guard let onState = childNode(withName: "Hard") as? SKLabelNode else {
            return nil
        }
        state.on = onState
    }

    // MARK: - Methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        triggle.switchState()
    }
}
