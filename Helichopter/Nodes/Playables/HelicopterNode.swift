import SpriteKit
import UIKit

class HelicopterNode: SKSpriteNode, Updatable, Playable, PhysicsContactable {

    // MARK: - Protocol conformance

    var delta: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0
    var shouldUpdate: Bool = true {
        didSet {
            if shouldUpdate {
                // Clear any stale invulnerability state before the next round starts
                if isInvulnerable { endInvulnerability() }
                animate(with: animationTimeInterval)
            } else {
                self.removeAllActions()
            }
        }
    }

    var isAffectedByGravity: Bool = true {
        didSet { physicsBody?.affectedByGravity = isAffectedByGravity }
    }

    var shouldAcceptTouches: Bool = true {
        didSet { isUserInteractionEnabled = shouldAcceptTouches }
    }

    var shouldEnablePhysics: Bool = true {
        didSet { physicsBody?.collisionBitMask = shouldEnablePhysics ? collisionBitMask : 0 }
    }

    var collisionBitMask: UInt32 = PhysicsCategories.pipe.rawValue | PhysicsCategories.boundary.rawValue

    /// Set by PlayingState at the start of each run. Called and self-cleared on the player's
    /// first input so that pipe spawning (and the hint fade) is deferred until the player acts.
    var onFirstInput: (() -> Void)?

    // MARK: - Phase 5: Invulnerability

    /// True while the helicopter is in a no-fail invulnerability window.
    /// Checked by GameSceneAdapter before entering GameOverState.
    private(set) var isInvulnerable: Bool = false

    /// Begins a no-fail invulnerability window. Pipe collision is disabled so the helicopter
    /// passes through pipes; boundary collision is kept so it stays on screen.
    /// The helicopter flashes for the duration, then full physics are restored.
    func triggerInvulnerability() {
        guard !isInvulnerable else { return }
        isInvulnerable = true
        physicsBody?.collisionBitMask = PhysicsCategories.boundary.rawValue

        let flash = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 0.15),
            SKAction.fadeAlpha(to: 1.0,  duration: 0.15)
        ]))
        if !UIAccessibility.isReduceMotionEnabled && !GameSettings.shared.calmMode {
            run(flash, withKey: "invulnerabilityFlash")
        }

        let duration = GameSettings.shared.invulnerabilityDuration
        run(SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run { [weak self] in self?.endInvulnerability() }
        ]), withKey: "invulnerabilityTimer")
    }

    func endInvulnerability() {
        isInvulnerable = false
        physicsBody?.collisionBitMask = collisionBitMask
        removeAction(forKey: "invulnerabilityFlash")
        removeAction(forKey: "invulnerabilityTimer")
        alpha = 1.0
    }

    // MARK: - Properties

    static let rotorFrameInterval: TimeInterval = 1.0 / 60.0

    var flyTextures: [SKTexture]? = nil
    private(set) var animationTimeInterval: TimeInterval = 0
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    // Control-scheme state — set by switch/touch handlers, read by update loop
    private(set) var isHoveringHeld = false
    private(set) var isTwoSwitchUpHeld = false
    private(set) var isTwoSwitchDownHeld = false
    // Cached after physics body creation; avoids per-frame optional unwrapping
    private var cachedMass: CGFloat = 1.0

    // MARK: - Initializers

    convenience init(animationTimeInterval: TimeInterval, withTextureAtlas named: String, size: CGSize) {
        var textures = [SKTexture]()
        do {
            textures = try SKTextureAtlas.upload(named: named, beginIndex: 1) { _, index in
                "r_player\(index)"
            }
        } catch {
            debugPrint(#function, "texture atlas upload error:", error)
        }

        self.init(texture: textures.first, color: .clear, size: size)
        self.animationTimeInterval = animationTimeInterval
        preparePhysicsBody()
        physicsBody?.velocity.dx = 0
        flyTextures = textures
        texture = textures.first

        // Theme overrides palette helicopter color when set (e.g. red on parchment).
        // A light tint preserves the supplied cockpit, outlines, and body shading.
        let theme = GameSettings.shared.selectedTheme
        let palette = GameSettings.shared.selectedPalette
        color = theme.helicopterTintColor ?? palette.helicopterColor
        colorBlendFactor = 0.35

        animate(with: animationTimeInterval)

        // Re-apply animation preference if the user toggles Reduce Motion while the app runs.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil)
    }

    @objc private func reduceMotionStatusChanged() {
        removeAction(forKey: "rotorAnimation")
        if shouldUpdate { animate(with: animationTimeInterval) }
    }

    // MARK: - Setup

    private func preparePhysicsBody() {
        let radius = (size.width / 2.0) * GameSettings.shared.hitboxFraction
        physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody?.categoryBitMask    = PhysicsCategories.player.rawValue
        physicsBody?.contactTestBitMask = PhysicsCategories.pipe.rawValue
                                        | PhysicsCategories.gap.rawValue
                                        | PhysicsCategories.boundary.rawValue
        physicsBody?.collisionBitMask   = PhysicsCategories.pipe.rawValue
                                        | PhysicsCategories.boundary.rawValue
        physicsBody?.allowsRotation = false
        physicsBody?.restitution    = 0.0
        cachedMass = physicsBody?.mass ?? 1.0
    }

    private func animate(with timing: TimeInterval) {
        guard let textures = flyTextures, !textures.isEmpty else { return }
        // 60 aligned frames at 60 Hz keep the body fixed through a seamless one-second loop.
        // Reduce Motion shows a single static frame to eliminate all motion.
        guard !UIAccessibility.isReduceMotionEnabled else {
            texture = textures.first
            return
        }
        let anim = SKAction.animate(with: textures, timePerFrame: timing, resize: false, restore: false)
        run(SKAction.repeatForever(anim), withKey: "rotorAnimation")
    }

    // MARK: - Updatable

    func update(_ timeInterval: CFTimeInterval) {
        (delta, lastUpdateTime) = computeUpdatable(currentTime: timeInterval)

        guard let body = physicsBody else { return }

        applyControlSchemeUpdate(body: body)

        let velocityY = body.velocity.dy
        let scheme    = GameSettings.shared.controlScheme

        // Cap upward launch speed for schemes that use standard physics
        if scheme == .tapFlap || scheme == .holdHover {
            let cap = GameSettings.shared.terminalVelocity
            if velocityY > cap { body.velocity = CGVector(dx: 0, dy: cap) }
        }

        // Tilt the helicopter to match vertical velocity
        let tiltFactor = velocityY * (velocityY < 0 ? 0.004 : 0.002)
        zRotation = tiltFactor.clamp(min: -1, max: 1.0)
    }

    private func applyControlSchemeUpdate(body: SKPhysicsBody) {
        switch GameSettings.shared.controlScheme {

        case .tapFlap:
            break  // standard impulse + gravity; nothing to do per-frame

        case .holdHover:
            let counterGravity = abs(GameSettings.shared.gravity) * cachedMass
            if isHoveringHeld {
                // Net upward acceleration ≈ 1.2× gravity.
                body.applyForce(CGVector(dx: 0, dy: counterGravity * 2.2))
            } else if isAffectedByGravity {
                // Net downward acceleration ≈ 0.3× gravity — slow fall so the player can recover.
                body.applyForce(CGVector(dx: 0, dy: counterGravity * 0.7))
            }

        case .autoHover:
            // isAffectedByGravity remains false (set by PlayingState).
            // Dampen any velocity from nudge impulses so the helicopter settles.
            body.velocity.dy *= CGFloat(pow(0.92, delta * 60))
            if abs(body.velocity.dy) < 2 { body.velocity.dy = 0 }

        case .twoSwitchUD:
            // isAffectedByGravity remains false. Direct velocity control.
            let speed: CGFloat = 260
            if isTwoSwitchUpHeld {
                body.velocity.dy = speed
            } else if isTwoSwitchDownHeld {
                body.velocity.dy = -speed
            } else {
                body.velocity.dy *= CGFloat(pow(0.85, delta * 60))
                if abs(body.velocity.dy) < 5 { body.velocity.dy = 0 }
            }
        }
    }

    // MARK: - Run lifecycle

    func prepareForNewRun() {
        lastUpdateTime = 0
        delta = 0
        isHoveringHeld = false
        isTwoSwitchUpHeld = false
        isTwoSwitchDownHeld = false
    }

    // MARK: - Private input helpers

    private func flap() {
        impact.impactOccurred()
        isAffectedByGravity = true
        physicsBody?.applyImpulse(CGVector(dx: 0, dy: GameSettings.shared.flapStrength))
    }

    private func handleInputBegan(primary: Bool) {
        // Fire the first-input hook (starts pipe spawning, fades hint) exactly once per run.
        if let cb = onFirstInput { onFirstInput = nil; cb() }

        switch GameSettings.shared.controlScheme {
        case .tapFlap:
            if primary { flap() }

        case .holdHover:
            if primary {
                isHoveringHeld = true
                isAffectedByGravity = true  // enable gravity so it falls when released
                impact.impactOccurred()
            }

        case .autoHover:
            // Nudge up on primary, nudge down on secondary
            let nudge: CGFloat = GameSettings.shared.flapStrength * 0.25
            physicsBody?.applyImpulse(CGVector(dx: 0, dy: primary ? nudge : -nudge))
            impact.impactOccurred()

        case .twoSwitchUD:
            if primary { isTwoSwitchUpHeld = true } else { isTwoSwitchDownHeld = true }
            impact.impactOccurred()
        }
    }

    private func handleInputEnded(primary: Bool) {
        switch GameSettings.shared.controlScheme {
        case .holdHover:
            if primary { isHoveringHeld = false }
        case .twoSwitchUD:
            if primary { isTwoSwitchUpHeld = false } else { isTwoSwitchDownHeld = false }
        default:
            break
        }
    }
}

// MARK: - Touch input (Touchable protocol)

extension HelicopterNode: Touchable {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard shouldAcceptTouches else { return }
        handleInputBegan(primary: true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard shouldAcceptTouches else { return }
        handleInputEnded(primary: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        handleInputEnded(primary: true)
    }
}

// MARK: - Switch / keyboard / controller input

extension HelicopterNode: SwitchInputReceivable {

    func switchPrimaryBegan() {
        guard shouldAcceptTouches else { return }
        handleInputBegan(primary: true)
    }

    func switchPrimaryEnded() {
        handleInputEnded(primary: true)
    }

    func switchSecondaryBegan() {
        guard shouldAcceptTouches else { return }
        handleInputBegan(primary: false)
    }

    func switchSecondaryEnded() {
        handleInputEnded(primary: false)
    }
}
