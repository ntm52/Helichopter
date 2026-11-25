import Testing
import SpriteKit
@testable import Helichopter

/// Hold to Hover as the guide describes it: hold to rise, let go to fall gently. Until
/// 2026-11-24 the hold force was about 1/150 of what it should be, so the helicopter fell
/// almost as fast while held as when let go, and could not lift off the floor.
@MainActor struct HoldToHoverTests {

    /// Scene units per second squared that world gravity pulls at.
    private var gravity: CGFloat { abs(GameSettings.shared.gravity) * HelicopterNode.sceneUnitsPerMeter }

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

    /// Acceleration over game time (the frames' own clock, not the wall clock, so a slow
    /// simulator does not change the answer) from now until `seconds` of game time pass.
    private func acceleration(of heli: HelicopterNode, over seconds: TimeInterval) async throws -> CGFloat {
        let t0 = heli.lastUpdateTime, v0 = heli.physicsBody!.velocity.dy
        #expect(try await waitUntil { heli.lastUpdateTime - t0 >= seconds })
        return (heli.physicsBody!.velocity.dy - v0) / CGFloat(heli.lastUpdateTime - t0)
    }

    @Test func holdingRisesAndLettingGoFallsGently() async throws {
        try await withHoldToHover {
            let (scene, heli, window) = try play()
            defer { window.isHidden = true; scene.view?.presentScene(nil) }
            #expect(try await waitUntil { heli.lastUpdateTime > 0 })
            let start = heli.position.y

            heli.switchPrimaryBegan()
            let rising = try await acceleration(of: heli, over: 0.2)
            // Designed: about 1.2 times gravity upwards.
            #expect(rising > 0.9 * gravity && rising < 1.5 * gravity, "held: \(rising), gravity \(gravity)")
            #expect(heli.position.y > start)

            heli.switchPrimaryEnded()
            #expect(try await waitUntil { heli.physicsBody!.velocity.dy < -20 })
            let falling = try await acceleration(of: heli, over: 0.3)
            // Designed: about 0.3 times gravity downwards, far gentler than a free fall.
            #expect(falling < -0.2 * gravity && falling > -0.45 * gravity, "released: \(falling), gravity \(gravity)")
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
            #expect(try await waitUntil(timeout: 15) {
                heli.position.y < scene.size.height * 0.2 && abs(heli.physicsBody!.velocity.dy) < 5
            }, "let go, it settles on the floor")
            let floor = heli.position.y
            heli.touchBegan(up: true)
            #expect(try await waitUntil { heli.position.y > floor + 100 }, "held, it climbs off the floor")
            heli.touchEnded()
        }
    }
}
