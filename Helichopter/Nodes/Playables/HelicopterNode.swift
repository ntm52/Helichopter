import SpriteKit
import UIKit

class HelicopterNode: SKSpriteNode, Updatable, Playable {

    // MARK: - Protocol conformance

    var delta: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0
    var shouldUpdate: Bool = true {
        didSet {
            if shouldUpdate {
                // Clear any stale invulnerability state before the next round starts,
                // and pick up a No-Fail change made since the last round.
                if isInvulnerable { endInvulnerability() }
                physicsBody?.collisionBitMask = collisionBitMask
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

    /// In No-Fail mode pipes only report contact and never push back: a solid pipe corner
    /// would shove the helicopter forward or backward before the pass-through window began.
    var collisionBitMask: UInt32 {
        GameSettings.shared.noFailMode
            ? PhysicsCategories.boundary.rawValue
            : PhysicsCategories.pipe.rawValue | PhysicsCategories.boundary.rawValue
    }

    /// Set by PlayingState at the start of each run. Called and self-cleared on the player's
    /// first input so that pipe spawning (and the hint fade) is deferred until the player acts.
    /// Setting it starts a new run, so Hold to Hover waits in place again.
    var onFirstInput: (() -> Void)? {
        didSet { if onFirstInput != nil { hasTakenOff = false } }
    }

    // MARK: - Phase 5: Invulnerability

    /// True while the helicopter is in a no-fail invulnerability window.
    /// Checked by GameSceneAdapter before entering GameOverState.
    private(set) var isInvulnerable: Bool = false

    /// Begins a no-fail invulnerability window. Pipe collision is disabled so the helicopter
    /// passes through pipes; boundary collision is kept so it stays on screen.
    /// The helicopter tint pulses for the duration, then full physics are restored.
    func triggerInvulnerability() {
        guard !isInvulnerable else { return }
        isInvulnerable = true
        physicsBody?.collisionBitMask = PhysicsCategories.boundary.rawValue

        // Pulse the artwork tint, never the opacity of its contrast boundary. Two and a
        // half pulses a second: under the three a second that flashing must stay below.
        let flash = SKAction.repeatForever(SKAction.sequence([
            SKAction.colorize(withColorBlendFactor: Self.bumpTint, duration: Self.bumpPulseHalfPeriod),
            SKAction.colorize(withColorBlendFactor: 0.35, duration: Self.bumpPulseHalfPeriod)
        ]))
        if !GameSettings.shared.calmMode {
            if UIAccessibility.isReduceMotionEnabled {
                // Nothing pulses, but the bump still shows: a steady stronger tint until it
                // ends, for players who cannot hear or feel the bump (an iPad has no haptics).
                colorBlendFactor = Self.bumpTint
            } else {
                run(flash, withKey: "invulnerabilityFlash")
            }
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
        colorBlendFactor = 0.35
    }

    // MARK: - Properties

    static let rotorFrameInterval: TimeInterval = 1.0 / 60.0
    /// Scene units per second for Hold to Hover and Up/Down Switches, up and down alike.
    /// Those schemes set the speed directly: no gravity, no build-up, no coasting.
    static let steadyFlightSpeed: CGFloat = 260
    /// How far Hold to Hover leans at that speed, in radians (about 14 degrees).
    static let steadyFlightTilt: CGFloat = 0.25
    /// How strongly the helicopter is tinted while a No-Fail bump lasts.
    static let bumpTint: CGFloat = 0.75
    /// Half of one pulse of that tint.
    static let bumpPulseHalfPeriod: TimeInterval = 0.2

    var flyTextures: [SKTexture]? = nil
    private(set) var animationTimeInterval: TimeInterval = 0
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    // Control-scheme state — set by switch/touch handlers, read by update loop
    private(set) var isHoveringHeld = false
    /// Auto Hover nudge speed; with per-frame damping each nudge moves about 100 scene units.
    static var autoHoverNudgeSpeed: CGFloat { GameSettings.shared.terminalVelocity }

    /// Hold to Hover: true once the run's first hold has happened, so the helicopter goes
    /// down whenever it is not held. Before that it waits in place. A pause keeps it.
    private(set) var hasTakenOff = false

    private(set) var isTwoSwitchUpHeld = false
    private(set) var isTwoSwitchDownHeld = false
    /// The direction of the touch in progress, so its release ends the matching input.
    private var touchIsUp = true
    // Cached after physics body creation; avoids per-frame optional unwrapping
    private var cachedMass: CGFloat = 1.0

    // MARK: - Initializers

    convenience init(animationTimeInterval: TimeInterval, skin: Cosmetic, size: CGSize) {
        var textures = [SKTexture]()
        do {
            textures = try SKTextureAtlas.upload(named: skin.assetName, beginIndex: 1) { _, index in
                skin.helicopterFrameName(index)
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

        // A stable rounded flight marker surrounds all rotor frames. It remains opaque
        // during no-fail feedback and does not alter the forgiving circular hitbox.
        // On a dark sky its black middle reads as part of the sky, so only the ring
        // shows; a light sky (Parchment) gets the ring alone, not a black disc.
        let boundary = SKNode()
        boundary.name = "flightBoundary"
        boundary.zPosition = -2
        boundary.isHidden = !GameSettings.shared.helicopterOutline
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2,
                          width: size.width, height: size.height)
        boundary.addGameplayBoundary(path: CGPath(roundedRect: rect,
                                                  cornerWidth: size.height / 2,
                                                  cornerHeight: size.height / 2,
                                                  transform: nil),
                                     filled: !theme.hasLightSky)
        addChild(boundary)

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
        physicsBody?.collisionBitMask   = collisionBitMask
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

        // The helicopter only ever moves vertically; pipes scroll past it.
        body.velocity.dx = 0

        let velocityY = body.velocity.dy
        let scheme    = GameSettings.shared.controlScheme

        // Cap upward launch speed for the scheme that uses standard physics
        if scheme == .tapFlap {
            let cap = GameSettings.shared.terminalVelocity
            if velocityY > cap { body.velocity = CGVector(dx: 0, dy: cap) }
        }

        // Tilt the helicopter to match vertical velocity. Hold to Hover spends most of its
        // time going down at a steady speed, so it leans gently rather than diving.
        if scheme == .holdHover {
            zRotation = (velocityY / Self.steadyFlightSpeed * Self.steadyFlightTilt).clamp(min: -Self.steadyFlightTilt,
                                                                                          max: Self.steadyFlightTilt)
        } else {
            let tiltFactor = velocityY * (velocityY < 0 ? 0.004 : 0.002)
            zRotation = tiltFactor.clamp(min: -1, max: 1.0)
        }
    }

    private func applyControlSchemeUpdate(body: SKPhysicsBody) {
        switch GameSettings.shared.controlScheme {

        case .tapFlap:
            break  // standard impulse + gravity; nothing to do per-frame

        case .holdHover:
            // isAffectedByGravity remains false. Held, it goes up; let go, it goes down; both
            // at one steady speed that starts and stops at once, as in Up/Down Switches.
            if isHoveringHeld {
                body.velocity.dy = Self.steadyFlightSpeed
            } else if hasTakenOff {
                body.velocity.dy = -Self.steadyFlightSpeed
            }

        case .autoHover:
            // isAffectedByGravity remains false (set by PlayingState).
            // Dampen any velocity from nudge impulses so the helicopter settles.
            body.velocity.dy *= CGFloat(pow(0.92, delta * 60))
            if abs(body.velocity.dy) < 2 { body.velocity.dy = 0 }

        case .twoSwitchUD:
            // isAffectedByGravity remains false. Direct velocity control.
            // Both held is the pause gesture, so the helicopter holds still rather than rising.
            let speed = Self.steadyFlightSpeed
            if isTwoSwitchUpHeld && !isTwoSwitchDownHeld {
                body.velocity.dy = speed
            } else if isTwoSwitchDownHeld && !isTwoSwitchUpHeld {
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

    /// The vibration that answers a flap, hold, or nudge; Calm Mode can turn it off.
    private func flightHaptic() {
        if GameSettings.shared.playsFlightHaptics { impact.impactOccurred() }
    }

    private func flap() {
        flightHaptic()
        isAffectedByGravity = true
        physicsBody?.applyImpulse(CGVector(dx: 0, dy: GameSettings.shared.flapStrength))
    }

    private func handleInputBegan(primary: Bool) {
        let scheme = GameSettings.shared.controlScheme
        // Tap to Flap and Hold to Hover have no use for the secondary switch. It must not
        // start the run either: pipes would come while the helicopter floats with gravity off.
        guard primary || scheme == .autoHover || scheme == .twoSwitchUD else { return }

        // Fire the first-input hook (starts pipe spawning, fades hint) exactly once per run.
        if let cb = onFirstInput { onFirstInput = nil; cb() }

        switch scheme {
        case .tapFlap:
            flap()

        case .holdHover:
            isHoveringHeld = true
            hasTakenOff = true  // from now on, letting go means going down
            flightHaptic()

        case .autoHover:
            // Nudge up on primary, nudge down on secondary. Set a bounded speed rather than
            // applying an impulse: a quarter flap impulse reached ~56,000 pt/s and flung the
            // helicopter into the floor. Damping then glides it ~0.2 s × speed and stops.
            physicsBody?.velocity.dy = primary ? HelicopterNode.autoHoverNudgeSpeed
                                               : -HelicopterNode.autoHoverNudgeSpeed
            flightHaptic()

        case .twoSwitchUD:
            if primary { isTwoSwitchUpHeld = true } else { isTwoSwitchDownHeld = true }
            flightHaptic()
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

    /// True when a touch at this height in the view means up. Only Auto Hover and Up/Down
    /// Switches split the screen; the line sits at the view's middle, where the HUD draws it.
    static func touchMeansUp(atY y: CGFloat, inViewHeight height: CGFloat,
                             scheme: ControlScheme = GameSettings.shared.controlScheme) -> Bool {
        !scheme.splitsTouchIntoUpAndDown || y < height / 2
    }

    /// A touch keeps the direction it started with, even if the finger slides across the line.
    func touchBegan(up: Bool) {
        guard shouldAcceptTouches else { return }
        touchIsUp = up
        handleInputBegan(primary: up)
    }

    func touchEnded() {
        handleInputEnded(primary: touchIsUp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view = touch.view else { return touchBegan(up: true) }
        touchBegan(up: Self.touchMeansUp(atY: touch.location(in: view).y, inViewHeight: view.bounds.height))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard shouldAcceptTouches else { return }
        touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        touchEnded()
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
