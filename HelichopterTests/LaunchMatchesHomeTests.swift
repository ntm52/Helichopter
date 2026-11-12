import Testing
import UIKit
@testable import Helichopter

/// The launch screen is a still picture that iOS shows before Home. Its helicopter must
/// sit where Home's mascot appears, at the same size, so nothing jumps when Home fades in.
/// The launch storyboard cannot read Home's layout, so its numbers are copied by hand;
/// this fails when Home's layout moves and the storyboard has not followed.
@MainActor struct LaunchMatchesHomeTests {

    /// Each iPhone and iPad shape the app launches full screen in, with its size classes.
    private static let screens: [(size: CGSize, regular: Bool)] = [
        (CGSize(width: 375, height: 667), false), (CGSize(width: 390, height: 844), false),
        (CGSize(width: 402, height: 874), false), (CGSize(width: 440, height: 956), false),
        (CGSize(width: 744, height: 1133), true), (CGSize(width: 820, height: 1180), true),
        (CGSize(width: 1024, height: 1366), true), (CGSize(width: 1366, height: 1024), true)
    ]

    @Test func launchHelicopterSitsWhereHomeShowsTheMascot() throws {
        for screen in Self.screens {
            let frame = CGRect(origin: .zero, size: screen.size)
            let home = HomeViewController()
            home.traitOverrides.preferredContentSizeCategory = .large
            home.view.frame = frame
            home.view.layoutIfNeeded()
            // The mascot view is as wide as the column; its picture is a centred square.
            let view = home.mascot.convert(home.mascot.bounds, to: home.view)
            let mascot = CGRect(x: view.midX - view.height / 2, y: view.minY, width: view.height, height: view.height)

            let launch = try #require(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
            let sizeClass: UIUserInterfaceSizeClass = screen.regular ? .regular : .compact
            launch.traitOverrides.horizontalSizeClass = sizeClass
            launch.traitOverrides.verticalSizeClass = .regular
            launch.view.frame = frame
            launch.view.layoutIfNeeded()
            let helicopter = try #require(launch.view.subviews.compactMap { $0 as? UIImageView }.last)

            // The sky is drawn as Home draws it: from the top, as wide as the screen.
            let sky = try #require(launch.view.subviews.compactMap { $0 as? UIImageView }.first)
            let homeSky = try #require((home.view as? BackdropView)?.sky)
            #expect(sky.frame.minY == 0 && abs(sky.frame.width - homeSky.frame.width) <= 1, "\(screen.size)")
            #expect(sky.frame.height >= screen.size.height, "\(screen.size): the launch sky must reach the bottom")
            let launchScale = sky.frame.height / (sky.image?.size.height ?? 1)
            let homeScale = homeSky.frame.height / (homeSky.image?.size.height ?? 1)
            #expect(abs(launchScale - homeScale) < 0.005, "\(screen.size): stars must be the same size")

            #expect(abs(helicopter.frame.minX - mascot.minX) <= 1, "\(screen.size)")
            #expect(abs(helicopter.frame.minY - mascot.minY) <= 1, "\(screen.size): launch \(helicopter.frame.minY), Home \(mascot.minY)")
            #expect(abs(helicopter.frame.width - mascot.width) <= 1 && abs(helicopter.frame.height - mascot.height) <= 1, "\(screen.size)")
        }
    }

    /// The launch picture is the first rotor frame of the Classic helicopter, the frame
    /// Home's mascot starts on.
    @Test func launchPictureIsTheClassicHelicoptersFirstFrame() throws {
        let launch = try #require(UIImage(named: "LaunchHelicopter"))
        let classic = CosmeticsCatalog.classicHelicopter.helicopterImage(frame: 1)
        #expect(abs(launch.size.width / launch.size.height - classic.size.width / classic.size.height) < 0.01)
    }
}
