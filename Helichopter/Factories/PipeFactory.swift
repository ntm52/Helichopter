import SpriteKit

struct PipeFactory {

    // MARK: - Typealiases

    typealias PipeParts = (top: PipeNode, bottom: PipeNode, threshold: SKSpriteNode)

    // MARK: - Constants

    static let pipeWidth: CGFloat = 110
    static let thresholdWidth: CGFloat = 20
    static let zPosition: CGFloat = 20

    // MARK: - Factory Methods

    static func launch(for scene: SKScene, targetNode: SKNode) -> SKAction {
        let pipeName = "pipe"
        let settings = GameSettings.shared

        let cleanUpAction = SKAction.run {
            targetNode.childNode(withName: pipeName)?.removeFromParent()
        }

        let waitAction = SKAction.wait(forDuration: settings.pipeSpawnInterval)
        let pipeMoveDuration = settings.pipeMoveDuration

        let producePipeAction = SKAction.run {
            guard let standardPipe = PipeFactory.produceStandardPipe(sceneSize: scene.size) else {
                return
            }
            let pipe = standardPipe
            pipe.name = pipeName
            targetNode.addChild(pipe)

            let moveAction = SKAction.move(to: CGPoint(x: -(pipe.size.width + scene.size.width), y: pipe.position.y), duration: pipeMoveDuration)
            let sequence = SKAction.sequence([moveAction, cleanUpAction])
            pipe.run(sequence)
        }

        let sequence = SKAction.sequence([waitAction, producePipeAction])
        return SKAction.repeatForever(sequence)
    }

    private static func produceStandardPipe(sceneSize: CGSize) -> SKSpriteNode? {
        guard let pipeParts = PipeFactory.standardPipeParts(for: sceneSize) else {
            debugPrint(#function + " could not unwrap PipeParts type since it's nil")
            return nil
        }

        let pipeNode = SKSpriteNode(texture: nil, color: .clear, size: pipeParts.top.size)
        pipeNode.addChild(pipeParts.top)
        pipeNode.addChild(pipeParts.threshold)
        pipeNode.addChild(pipeParts.bottom)
        return pipeNode
    }

    // MARK: - Pipe parts production

    private static func standardPipeParts(for sceneSize: CGSize) -> PipeParts? {
        let settings = GameSettings.shared
        let pipeX: CGFloat = sceneSize.width
        let sceneHeight = sceneSize.height
        let minPipeHeight: CGFloat = 50

        // Palette tinting — Phase 6 art is designed as white/grayscale so blendFactor=1 gives
        // clean colour swaps at runtime without a second set of PNGs.
        let palette = GameSettings.shared.selectedPalette

        // Variance 0.0 = all pipes at minimum height (predictable), 1.0 = full range
        let maxBottomHeight = max(70, sceneHeight * 0.55 * settings.pipeHeightVariance)
        let bottomHeight = CGFloat.range(min: 70, max: max(70, maxBottomHeight))
        let pipeBottomSize = CGSize(width: pipeWidth, height: bottomHeight)
        let pipeBottom = PipeNode(textures: (pipe: "pipe-yellow", cap: "cap-yellow"),
                                  of: pipeBottomSize, side: false,
                                  tintColor: palette.pipeColor, blendFactor: palette.colorBlendFactor)
        pipeBottom?.position = CGPoint(x: pipeX, y: bottomHeight / 2)

        guard let unwrappedPipeBottom = pipeBottom else {
            debugPrint(#function + " could not construct PipeNode instance")
            return nil
        }

        // Gap from GameSettings — B2 fixed: values now directly represent gap size (wider = easier)
        var minimum = settings.gapMin
        var maximum = settings.gapMax

        // Clamp gap so the top pipe always has at least minPipeHeight
        let absoluteMaxGap = sceneHeight - unwrappedPipeBottom.size.height - minPipeHeight
        maximum = min(maximum, max(minimum, absoluteMaxGap))

        let threshold = SKSpriteNode(color: .clear, size: CGSize(width: thresholdWidth, height: CGFloat.range(min: minimum, max: maximum)))
        threshold.position = CGPoint(x: pipeX, y: unwrappedPipeBottom.size.height + threshold.size.height / 2)

        threshold.physicsBody = SKPhysicsBody(rectangleOf: threshold.size)
        threshold.physicsBody?.categoryBitMask = PhysicsCategories.gap.rawValue
        threshold.physicsBody?.contactTestBitMask = PhysicsCategories.player.rawValue
        threshold.physicsBody?.collisionBitMask = 0
        threshold.physicsBody?.isDynamic = false
        threshold.zPosition = zPosition

        let topHeight = max(minPipeHeight, sceneHeight - unwrappedPipeBottom.size.height - threshold.size.height)
        let pipeTopSize = CGSize(width: pipeWidth, height: topHeight)
        let pipeTop = PipeNode(textures: (pipe: "pipe-yellow", cap: "cap-yellow"),
                               of: pipeTopSize, side: true,
                               tintColor: palette.pipeColor, blendFactor: palette.colorBlendFactor)
        pipeTop?.position = CGPoint(x: pipeX, y: unwrappedPipeBottom.size.height + threshold.size.height + topHeight / 2)

        guard let unwrappedPipeTop = pipeTop else {
            return nil
        }

        return PipeParts(top: unwrappedPipeTop, bottom: unwrappedPipeBottom, threshold: threshold)
    }

}
