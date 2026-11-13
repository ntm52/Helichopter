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
    /// Pipes only. False: the art is a 9-slice that stretches to the pipe's height.
    /// True: the art is one tall pattern that is cropped (and repeated if the pipe is taller),
    /// because stretching would change the pattern's shape.
    var repeatsPipeArt = false
    /// Helicopters only. The start of each rotor frame's image name. An asset catalog needs
    /// every image name to be unique, so each helicopter's atlas has its own prefix.
    var framePrefix = "r_player"

    static func == (lhs: Cosmetic, rhs: Cosmetic) -> Bool { lhs.id == rhs.id }

    /// Free items are always owned. Purchases (Plan 02 Phase 2) will add StoreKit entitlements.
    var isOwned: Bool { productID == nil }
}

extension Cosmetic {

    // MARK: Helicopter art

    static let helicopterFrameCount = 60

    /// The name of rotor frame `index` (1 to 60) in the helicopter's atlas.
    func helicopterFrameName(_ index: Int) -> String { "\(framePrefix)\(index)" }

    /// Rotor frame `index` as an image, for UIKit screens.
    func helicopterImage(frame index: Int = 1) -> UIImage {
        let atlas = SKTextureAtlas(named: assetName)
        return UIImage(cgImage: atlas.textureNamed(helicopterFrameName(index)).cgImage())
    }

    /// The first rotor frame with the empty space around the helicopter cut away, for a
    /// picture that should fill its place. The frames keep that space so the rotor fits.
    func helicopterPortraitImage() -> UIImage {
        let whole = helicopterImage()
        guard let art = whole.cgImage else { return whole }
        let width = art.width, height = art.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &alpha, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
        else { return whole }
        context.draw(art, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 8 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let cut = art.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
        else { return whole }
        return UIImage(cgImage: cut)
    }

    // MARK: Pipe art

    var pipeTextureName: String { "pipe-\(assetName)" }
    var capTextureName: String { "cap-\(assetName)" }

    /// The open end of the pipe body in `tint`, coloured as in play, for UIKit screens.
    func pipePreviewImage(tint: UIColor) -> UIImage? {
        guard let art = UIImage(named: pipeTextureName), let whole = art.cgImage else { return nil }
        // Classic's whole body is twice as tall as wide; show the same shape of any taller art.
        let rows = min(whole.height, whole.width * 2)
        guard let top = whole.cropping(to: CGRect(x: 0, y: 0, width: whole.width, height: rows)) else { return nil }
        let picture = UIImage(cgImage: top, scale: art.scale, orientation: .up)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = art.scale
        return UIGraphicsImageRenderer(size: picture.size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: picture.size)
            picture.draw(in: rect)
            tint.setFill()
            context.fill(rect, blendMode: .multiply)   // as SpriteKit blends the palette colour
            picture.draw(in: rect, blendMode: .destinationIn, alpha: 1)
        }
    }
}

enum CosmeticsCatalog {

    static let classicHelicopter = Cosmetic(
        id: "heli.classic", kind: .helicopter, name: "Classic Helicopter",
        spokenDescription: "The original helicopter",
        assetName: "Helicopter Player", productID: nil)

    /// The Classic art with a dark underside (`Tools/helicopter-kit/make_frames.py two-tone`).
    static let twoToneHelicopter = Cosmetic(
        id: "heli.twotone", kind: .helicopter, name: "Two Tone Helicopter",
        spokenDescription: "Light on top with a dark underside",
        assetName: "Helicopter Two-Tone", productID: nil, framePrefix: "r_twotone")

    static let classicPipes = Cosmetic(
        id: "pipe.classic", kind: .pipe, name: "Classic Pipes",
        spokenDescription: "Plain pipes with a wider cap at the open end",
        assetName: "yellow", productID: nil)

    /// Light and dark stripes, so pipes stand out by pattern as well as colour
    /// (`Tools/pipe-kit/make_pipes.py`).
    static let stripedPipes = Cosmetic(
        id: "pipe.striped", kind: .pipe, name: "Striped Pipes",
        spokenDescription: "Diagonal light and dark stripes that show without relying on colour",
        assetName: "striped", productID: nil, repeatsPipeArt: true)

    /// Every item, in the order the Hangar shows them.
    static let all: [Cosmetic] = [classicHelicopter, twoToneHelicopter, classicPipes, stripedPipes]

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
