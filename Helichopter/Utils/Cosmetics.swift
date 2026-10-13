import SpriteKit
import UIKit

// MARK: - Cosmetics (Plan 02)
// Looks for the helicopter and pipes. Cosmetic only: no skin changes the hitbox, speed,
// physics, score, or difficulty, and every palette, outline, and theme works with every skin.

enum CosmeticKind {
    case helicopter, pipe
}

struct Cosmetic: Identifiable, Equatable {
    let id: String                // "heli.classic", "pipe.classic"
    let kind: CosmeticKind
    let name: String              // Shown and spoken; Voice Control users say it.
    let spokenDescription: String // Read as the card's VoiceOver hint.
    /// A helicopter's texture atlas, or the suffix of a pipe's `pipe-` and `cap-` images.
    let assetName: String
    let productID: String?        // nil = free

    static func == (lhs: Cosmetic, rhs: Cosmetic) -> Bool { lhs.id == rhs.id }

    /// Free items are always owned. Purchases (Plan 02 Phase 2) will add StoreKit entitlements.
    var isOwned: Bool { productID == nil }
}

extension Cosmetic {

    // MARK: Helicopter art

    static let helicopterFrameCount = 60

    /// The name of rotor frame `index` (1 to 60) in the helicopter's atlas.
    static func helicopterFrameName(_ index: Int) -> String { "r_player\(index)" }

    /// Rotor frame `index` as an image, for UIKit screens.
    func helicopterImage(frame index: Int = 1) -> UIImage {
        let atlas = SKTextureAtlas(named: assetName)
        return UIImage(cgImage: atlas.textureNamed(Self.helicopterFrameName(index)).cgImage())
    }

    // MARK: Pipe art

    var pipeTextureName: String { "pipe-\(assetName)" }
    var capTextureName: String { "cap-\(assetName)" }
}

enum CosmeticsCatalog {

    static let classicHelicopter = Cosmetic(
        id: "heli.classic", kind: .helicopter, name: "Classic Helicopter",
        spokenDescription: "The original helicopter",
        assetName: "Helicopter Player", productID: nil)

    static let classicPipes = Cosmetic(
        id: "pipe.classic", kind: .pipe, name: "Classic Pipes",
        spokenDescription: "Plain pipes with a wider cap at the open end",
        assetName: "yellow", productID: nil)

    /// Every item, in the order the Hangar shows them.
    static let all: [Cosmetic] = [classicHelicopter, classicPipes]

    static func items(of kind: CosmeticKind) -> [Cosmetic] { all.filter { $0.kind == kind } }

    static func defaultItem(of kind: CosmeticKind) -> Cosmetic {
        kind == .helicopter ? classicHelicopter : classicPipes
    }

    /// The item with `id` if it is of `kind` and owned; otherwise the default, so a stale,
    /// unknown, or refunded choice falls back to Classic.
    static func item(id: String?, of kind: CosmeticKind) -> Cosmetic {
        all.first { $0.id == id && $0.kind == kind && $0.isOwned } ?? defaultItem(of: kind)
    }
}
