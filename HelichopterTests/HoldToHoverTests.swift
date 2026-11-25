import Testing
import SpriteKit
@testable import Helichopter

/// Hold to Hover, as the owner asked on 2026-11-24: hold to go up, let go to go down, at
/// one steady speed that starts and stops at once, like Up/Down Switches with one input.
/// Before that it used forces: first far too weak to climb, then, once fixed, it coasted
/// upward for about two seconds after being let go.
@MainActor struct HoldToHoverTests {

    private let speed = HelicopterNode.steadyFlightSpeed

    /// The vertical speed, within SpriteKit's own small per-step damping of the speed set.
    private func moves(_ heli: HelicopterNode, at expected: CGFloat) -> Bool {
        abs(heli.physicsBody!.velocity.dy - expected) <= abs(expected) * 0.02
    }

    /// A live game in a window, so SpriteKit runs its physics each frame.
    private func play() throws -> (GameScene, HelicopterNode, UIWindow) {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let window = makeTestWindow(frame: view.frame)
        let host = UIViewController()
        host.view = view
        window.rootViewController = host
        window.isHidden = false
        let scene = try #require(GameScene(fileNamed: "GameScene"))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        let heli = try #require(scene.sceneAdapter?.playerCharacter as? HelicopterNode)
        return (scene, heli, window)
    }

    private func withHoldToHover(_ work: () async throws -> Void) async rethrows {
        let gs = GameSettings.shared
        let saved = (gs.controlScheme, gs.noFailMode, gs.scanningEnabled)
        defer { (gs.controlScheme, gs.noFailMode, gs.scanningEnabled) = saved }
        gs.controlScheme = .holdHover
        gs.noFailMode = true  // so no pipe or floor contact ends the round mid-measurement
        gs.scanningEnabled = false
        try await work()
    }

    /// Waits for `seconds` of game time (the frames' own clock, so a slow simulator does
    /// not change the answer).
    private func frames(of heli: HelicopterNode, for seconds: TimeInterval) async throws {
        let t0 = heli.lastUpdateTime
        #expect(try await waitUntil { heli.lastUpdateTime - t0 >= seconds })
    }

    @Test func holdingGoesUpAndLettingGoGoesDownAtOnce() async throws {
        try await withHoldToHover {
            let (scene, heli, window) = try play()
            defer { window.isHidden = true; scene.view?.presentScene(nil) }
            #expect(try await waitUntil { heli.lastUpdateTime > 0 })

            // Before the first hold it waits in place.
            let start = heli.position.y
            try await frames(of: heli, for: 0.2)
            #expect(abs(heli.position.y - start) < 1 && !heli.isAffectedByGravity, "\(start) → \(heli.position.y)")

            heli.switchPrimaryBegan()
            try await frames(of: heli, for: 0.05)
            #expect(moves(heli, at: speed), "up at full speed straight away (\(heli.physicsBody!.velocity.dy))")
            try await frames(of: heli, for: 0.2)
            #expect(moves(heli, at: speed), "and no faster (\(heli.physicsBody!.velocity.dy))")
            let released = heli.position.y
            #expect(released > start + 0.2 * speed * 0.8)

            heli.switchPrimaryEnded()
            try await frames(of: heli, for: 0.05)
            #expect(moves(heli, at: -speed), "down at once, with no coasting up (\(heli.physicsBody!.velocity.dy))")
            // At most a frame or two of upward travel after letting go.
            #expect(heli.position.y < released + speed / 20)
            try await frames(of: heli, for: 0.3)
            #expect(moves(heli, at: -speed), "a steady speed, not a fall that speeds up (\(heli.physicsBody!.velocity.dy))")
            // A gentle lean, not a nose-down dive.
            #expect(abs(heli.zRotation) <= HelicopterNode.steadyFlightTilt + 0.01, "tilt \(heli.zRotation)")
            #expect(!heli.isAffectedByGravity)
        }
    }

    /// A touch takes the same path as a switch, and a helicopter resting on the floor
    /// (No-Fail) climbs off it when held.
    @Test func holdingLiftsOffTheFloor() async throws {
        try await withHoldToHover {
            let (scene, heli, window) = try play()
            defer { window.isHidden = true; scene.view?.presentScene(nil) }
            #expect(try await waitUntil { heli.lastUpdateTime > 0 })
            heli.touchBegan(up: true)
            heli.touchEnded()
            #expect(try await waitUntil(timeout: 15) { heli.position.y < scene.size.height * 0.2 }, "let go, it goes down")
            try await frames(of: heli, for: 1)
            let floor = heli.position.y
            try await frames(of: heli, for: 0.2)
            #expect(abs(heli.position.y - floor) < 2, "and rests on the floor")
            heli.touchBegan(up: true)
            #expect(try await waitUntil { heli.position.y > floor + 100 }, "held, it climbs off the floor")
            heli.touchEnded()
        }
    }
}
