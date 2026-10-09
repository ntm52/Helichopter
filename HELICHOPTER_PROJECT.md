# Helichopter — Project Reference

**Status (2026-10-08):** Version 2.0 (build 2, git tag `2.0`) is live on the App Store. Development is now post-launch improvement work, ordered in [Plans/ROADMAP.md](Plans/ROADMAP.md). Next release is 2.1 (build 3; version already set): Plan 01 Stage B. Stage A's transition helper is merged but will not ship on its own; Stage B steps 1–3 are done. 100 automated tests pass.

> **Starting a session:** read this file, then the roadmap, then the plan file for the work you are doing. Before you finish, append an entry to [Audit/PROGRESS_LOG.md](Audit/PROGRESS_LOG.md).
> **If this file and the code disagree, trust the code** and fix this file.

---

## What the app is

Helichopter is a Flappy Bird–style helicopter game for iPhone and iPad (iOS 17.6+), built with Swift, SpriteKit, GameplayKit, and UIKit. Its purpose is to be playable by people with a wide range of disabilities. It is offline, has no accounts, ads, analytics, or purchases, and stores settings and scores in `UserDefaults` only.

Main features: four flight schemes (Tap to Flap, Hold to Hover, Auto Hover, Two-Switch), one- and two-switch scanning in every menu, hold-to-pause for switch users, VoiceOver flight actions and spoken gap guidance, Dynamic Type everywhere, three UI themes, six colour palettes, contrast outlines, No-Fail and Calm modes, Reduce Motion handling, a replayable first-run guide, a caregiver Settings lock, and Settings reset.

## Design principles

These apply to every change, including cosmetics and the store.

1. **Nothing punishes.** No-Fail is the default first experience.
2. **Figures must contrast.** The player, the pipes, and the background must stay distinguishable by brightness and outline, not only by colour.
3. **The player never has to read.** Use icons and spoken labels.
4. **Switch access is first-class.** Every control must be reachable by the app's own scanner, iOS Switch Control, and VoiceOver, and must use Dynamic Type.
5. Visible controls tune gap size, pipe speed, hitbox size, and background scroll. Other physics values are preset-controlled.
6. Keep the original intent: a trackable helicopter, wide gaps, and the option to slow down.
7. **Accessibility is never paid for.** Any future purchases are cosmetic only.

---

## Where things are

| Document | Purpose |
|---|---|
| `CLAUDE.md` | Short rules for AI agents: build, test, and the architecture traps. |
| `HELICHOPTER_PROJECT.md` (this file) | Current state, architecture, known issues, release checklist. |
| `Plans/ROADMAP.md` | Ordered list of future work, with links to detailed plans. |
| `Plans/01_SINGLE_LAYER_UI.md` | Plan to remove the "double page" effect by giving every screen one drawing layer. |
| `Plans/02_COSMETICS_AND_STORE.md` | Plan for cosmetic helicopter and pipe skins, a Hangar/Store screen, and in-app purchases. |
| `Audit/PROGRESS_LOG.md` | Session-by-session history. Append here. |
| `Audit/REVIEW_2026-09-05.md`, `Audit/APP_STORE_READINESS.md` | Historical pre-release audits. Read only for background. |
| `Release/` | App Store listing copy, asset rights register, privacy notes, screenshots. |
| `docs/` | Public GitHub Pages site (privacy and support pages). Changes here go live when pushed. |
| `Tools/release_check.sh` | Pre-submission checks. Accepts a `.xcarchive`. |
| `Tools/helicopter-kit/` | Source art and the converter that builds the 60-frame helicopter atlas. |

---

## Architecture

The app has one `GameViewController` holding an `SKView`. Home and the first-run guide are UIKit child view controllers shown over an empty `SKView`; Settings and gameplay are `SKScene`s loaded from `.sks` archives. **UIKit draws everything the player sees in menus and the HUD.** On Settings, the `.sks` buttons and labels are kept only as invisible models. Pause and Round Over have no archive: they are built in Swift (`GameMenuView`). Nothing polls the UI: there is no refresh timer.

| File (under `Helichopter/`) | Role |
|---|---|
| `View Controllers/GameViewController.swift` | Hosts the `SKView`, the `SceneTextOverlay`, and Home or the guide as a child controller; plays the menu theme (`MenuMusic`) on those two. **Owns every screen change:** `present(_:transition:)` takes a `Screen` (`.home`, `.guide`, `.scene(_:)`; static form `present(_:in:)` for scenes) and is the only code that calls `presentScene`. It covers the swap with a snapshot of both layers, holds input, scanners, and `screenChanged` posts (`ScreenChangeAnnouncer`), and cross-fades (0.3 s; 0.2 s with Reduce Motion). Routes keyboard and game-controller switch input to the UIKit screen or the scene. Picks the scale mode for any window shape (`scaleMode(for:in:)`). |
| `Scenes/SceneTextOverlay.swift` | The gameplay HUD (updated only through `GameSceneHUDDelegate`); hosts `GameMenuView` during Pause and Round Over; hidden and emptied on every other screen. Defines `suppressArchivedPresentation()` and the VoiceOver `FlightAccessibilityElement`. |
| `Scenes/MenuStackView.swift` | Shared UIKit menu pieces: `MenuChoice`/`MenuItem` (scanner models), `MenuButton` (focus border by callback), `MenuStackView` (centred scrolling column), `BackdropView` (starry sky or theme colour), and `MenuViewController` (base for Home and the guide: owns a `FocusScanner`, takes switch input, ignores choices during a fade). |
| `Scenes/HomeViewController.swift` | Home: mascot (60-frame `UIImageView` animation, still under Reduce Motion), title, and `HomeAction` Play, Settings, How to Play. |
| `Scenes/GuideViewController.swift` | First-run guide: three pages, Read this step aloud, Next/Back/Skip/Done. Shown at launch until `onboarding_completed_v1` is set, and from How to Play. |
| `Scenes/SettingsScene.swift` | `SettingsScene` hides its whole archive and shows `SettingsOverlayView`, a full UIKit Settings panel with its own switch scanner. Also holds `AppLinks` (privacy URL, support email, acknowledgements text). ~1,160 lines. |
| `Scenes/RoutingUtilityScene.swift` | Base class for the Settings scene (removed in Stage B step 5). Owns a `FocusScanner` and routes archived buttons through `GameViewController.present`. |
| `Scenes/GameScene.swift` | Gameplay. `GKStateMachine` (Playing, Paused, GameOver), switch routing, hold-to-pause, VoiceOver flight, flight hint text. Owns the Pause and Round Over menu items (`GameMenuItem`) that the switch scanner moves through, and acts on them in `perform(_:from:)`. |
| `Scenes/GameMenuView.swift` | Pause and Round Over in UIKit: `MenuAction`, `GameMenuItem` (scanner model owned by the scene), and `GameMenuView`, a `MenuStackView` whose buttons follow their items' focus with no polling. |
| `Adapters/GameSceneAdapter.swift` | Gameplay hub: physics, scoring, best-score saving, sounds, collisions, HUD visibility. |
| `Game States/*.swift` | `PlayingState` (pipe spawning, first-input start), `PausedState`, `GameOverState`. |
| `Nodes/Playables/HelicopterNode.swift` | Player sprite: atlas animation, physics, all four control schemes, contrast marker, No-Fail pulse. |
| `Nodes/Game Componens/PipeNode.swift` | 9-slice pipe body and cap, tinted by palette, with a contrast border. (The folder name's typo is real.) |
| `Nodes/Game Componens/InfiniteSpriteScrollNode.swift` | Tiling parallax background. |
| `Factories/PipeFactory.swift` | Spawns pipe pairs from `GameSettings`. Texture names `pipe-yellow`/`cap-yellow` are hard-coded here. |
| `Nodes/UI Components/ButtonNode.swift` | Archived button model: identifier, labels, scanner focus, activation. |
| `Nodes/UI Components/ToggleButtonNode.swift`, `TriggleButtonNode.swift` | Legacy classes referenced by `SettingsScene.sks`. Must stay while that archive exists. |
| `Control/FocusScanner.swift` | Timed and manual scanning shared by SpriteKit buttons and UIKit Settings (`FocusScannable`). |
| `Extensions/SKNode+Theme.swift` | `applyUITheme(_:)`: recursive theming of archived nodes. |
| `Utils/GameSettings.swift` | Singleton for every setting, preset, palette, and theme. Bounded, validated, persisted with `gs_` keys. |
| `Utils/UserDefaults.swift` | Legacy `Setting` and `Difficulty` enums, kept for migration and best score. |

Tests live in `HelichopterTests/` (Swift Testing): settings, scanner, lifecycle, onboarding, palette contrast, presentation, Dynamic Type, and window sizes.

### Colour systems (both in `GameSettings.swift`)

- **`ColorPalette`** colours the helicopter and pipes. Pipes use `colorBlendFactor = 1.0`; the detailed helicopter art uses `0.35` so its shading survives. Six palettes: Default, High Contrast, Deuteranopia, Protanopia, Tritanopia, Low Luminance (`gs_selectedPaletteID`).
- **`UITheme`** colours menus and scene backgrounds. Three themes: Night Sky, Parchment, Neon Night (`gs_selectedThemeID`). Light themes hide sprites whose names start with `background`, because tinting dark textures cannot make them light. `helicopterTintColor` overrides the palette colour (Parchment uses `#CC2626`).
- Gameplay contrast does not rely on fill colours: the helicopter has a black/white marker and pipes have black/white borders. `PaletteContrastTests` render all 18 theme/palette combinations.

### Helicopter atlas

`Assets/Assets.xcassets/Playable Characters/Helicopter Player.spriteatlas/`: 60 frames, `r_player1`–`r_player60`, white/greyscale, 1×/2×/3×, played at 60 FPS. Regenerate with `python3 Tools/helicopter-kit/make_frames.py`. **The folder must keep its `.spriteatlas` extension**; without it `SKTextureAtlas` returns an empty atlas and gameplay crashes. The name `"Helicopter Player"` is hard-coded in `HomeViewController` and `UserDefaults.swift`.

---

## Known issues and debt

- **Double page during screen changes:** live in 2.0 (owner accepted it). On `master`, Plan 01 Stage A hides it with one snapshot cross-fade of both layers, but each screen is still drawn by two layers. Stage B removes the cause and ships as 2.1: [Plans/01_SINGLE_LAYER_UI.md](Plans/01_SINGLE_LAYER_UI.md).
- **Hidden `.sks` menus** (Settings only; Home, Pause, and Round Over are gone) duplicate their menus and have iPad copies. They are the root of the "two versions of a screen" bug class. Removed by the same plan.
- `fatalError` remains in the legacy `ToggleButtonNode`/`TriggleButtonNode` responders.
- Narrow iPad windows show wide top and bottom bars instead of a larger phone-shaped layout.
- The full test suite occasionally hangs with parallel simulator clones. Use `-parallel-testing-enabled NO` if it does.
- **Not yet verified on a physical device:** VoiceOver, Voice Control, Switch Control, hardware switches, adaptive controllers, the oldest supported device, iPad window resizing, and real transitions.

---

## Releasing an update

Use this list for every version after 2.0. Details of the 2.0 submission are in the progress log.

1. Bump `MARKETING_VERSION` for user-visible releases and always bump `CURRENT_PROJECT_VERSION` (build number) for each upload.
2. Run the full test suite, then `Tools/release_check.sh` on an unsigned Release build.
3. Archive with an Apple Distribution certificate. Run `Tools/release_check.sh path/to/Helichopter.xcarchive`; it fails on a development-signed build. Bundle ID `com.nathanmayo.helichopter`, team `9HJ5466NL8`.
4. Build with the SDK Apple currently requires (Xcode 26 / iOS 26 SDK since April 2026); check [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/).
5. If anything touches data, networking, SDKs, or purchases, update together: `docs/privacy.html` and its date, `AppLinks.privacySummary`, `PrivacyInfo.xcprivacy`, the App Privacy answers, and `Release/APP_STORE_COPY.md`.
6. If any art, sound, or music is added, record it in `Release/ASSET_RIGHTS.md` first (Guideline 5.2).
7. Update What's New, screenshots if screens changed, and the Accessibility Nutrition Labels if support changed.
8. After approval, tag the release in git (for example `2.0`, `2.1`).

App Store Connect facts for 2.0: category Games → Casual, age rating 4+, EU DSA status **non-trader** (must change before selling anything; see the store plan), App Privacy "Data Not Collected", export compliance "No" (`ITSAppUsesNonExemptEncryption = false`). Accessibility Nutrition Labels are published (2026-10-08): Larger Text, Dark Interface, Sufficient Contrast, Reduced Motion, Differentiate Without Color Alone. VoiceOver and Voice Control are held until device testing.
