# Helichopter — Project Reference

**Status (2026-10-08):** Version 2.0 (build 2, git tag `2.0`) is live on the App Store. Development is now post-launch improvement work, ordered in [Plans/ROADMAP.md](Plans/ROADMAP.md). Next release is 2.1 (build 3; version already set): Plan 01 Stage B. Stage A's transition helper is merged but will not ship on its own; Stage B code steps 1–5 are done, and 2.1 now waits on the owner's device recordings. 102 automated tests pass.

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

The app has one `RootViewController` holding an `SKView`. Home, the first-run guide, and Settings are UIKit child view controllers shown over an empty `SKView`; gameplay is an `SKScene` loaded from `GameScene.sks` (`GameScene iPad.sks` on iPad, a wider scene). Those archives hold only scene settings; SpriteKit draws gameplay and nothing else. The HUD, Pause, and Round Over are UIKit, built in Swift. Nothing polls the UI: there is no refresh timer.

| File (under `Helichopter/`) | Role |
|---|---|
| `View Controllers/RootViewController.swift` | Hosts the `SKView`, the `SceneTextOverlay`, and Home, the guide, or Settings as a child controller; plays the menu theme (`MenuMusic`) on Home and the guide. **Owns every screen change:** `present(_:transition:)` takes a `Screen` (`.home`, `.guide`, `.settings`, `.scene(_:)`; static form `present(_:in:)` for scenes) and is the only code that calls `presentScene`. It covers the swap with a snapshot of both layers, holds input, scanners, and `screenChanged` posts (`ScreenChangeAnnouncer`), and cross-fades (0.3 s; 0.2 s with Reduce Motion). Routes keyboard and game-controller switch input to the UIKit screen or the scene. Picks the scale mode for any window shape (`scaleMode(for:in:)`). |
| `Scenes/SceneTextOverlay.swift` | The gameplay HUD, built in Swift: Score, Best, Pause, the flight hint, and the new-high-score banner, updated only through `GameSceneHUDDelegate`. Hosts `GameMenuView` during Pause and Round Over; hidden and emptied on every other screen. Defines the VoiceOver `FlightAccessibilityElement`. |
| `Scenes/MenuStackView.swift` | Shared UIKit menu pieces: `MenuChoice`/`MenuItem` (scanner models), `MenuButton` (focus border by callback), `MenuStackView` (centred scrolling column), `BackdropView` (starry sky or theme colour), `ScreenViewController` (base for every UIKit screen: navigation, announcement, switch input, scanners to freeze during a fade), and `MenuViewController` (base for Home and the guide: owns a `FocusScanner`, ignores choices during a fade). |
| `Scenes/HomeViewController.swift` | Home: mascot (60-frame `UIImageView` animation, still under Reduce Motion), title, and `HomeAction` Play, Settings, How to Play. |
| `Scenes/GuideViewController.swift` | First-run guide: three pages, Read this step aloud, Next/Back/Skip/Done. Shown at launch until `onboarding_completed_v1` is set, and from How to Play. |
| `Scenes/SettingsViewController.swift` | The Settings screen. Hosts a `SettingsPanelView` and swaps in a fresh one (0.25 s fade) when the theme, a preset, the lock, Reset, or text size changes, keeping scroll position, scanner focus, and an open adjustment page. Back goes Home. |
| `Scenes/SettingsPanelView.swift` | The Settings list: sections, its own switch scanner (`SettingsScanItem`), focus ring, and the caregiver lock. |
| `Scenes/SettingsRows.swift` | `SettingsStyle` (theme-derived colours), the row builders (preset, slider, toggle, segmented, palette), and font/label/button helpers. |
| `Scenes/SettingsAdjustmentPanel.swift` | The full-panel page of plain choices for sliders, segmented controls, Reset, Privacy, and Acknowledgements, so one switch press changes one thing. |
| `Scenes/AppLinks.swift` | Privacy URL, support email, privacy summary, and acknowledgements text. |
| `Scenes/GameScene.swift` | Gameplay. `GKStateMachine` (Playing, Paused, GameOver), switch routing, hold-to-pause, VoiceOver flight, flight hint text, and `pauseFromHUD()`. Hides the starfield for plain-backdrop themes. Owns the Pause and Round Over menu items (`GameMenuItem`) that the switch scanner moves through, and acts on them in `perform(_:from:)`. |
| `Scenes/GameMenuView.swift` | Pause and Round Over in UIKit: `MenuAction`, `GameMenuItem` (scanner model owned by the scene), and `GameMenuView`, a `MenuStackView` whose buttons follow their items' focus with no polling. |
| `Adapters/GameSceneAdapter.swift` | Gameplay hub: physics, scoring, best-score saving, sounds, collisions, and the HUD delegate calls. |
| `Game States/*.swift` | `PlayingState` (pipe spawning, first-input start), `PausedState`, `GameOverState`. |
| `Nodes/Playables/HelicopterNode.swift` | Player sprite: atlas animation, physics, all four control schemes, contrast marker, No-Fail pulse. |
| `Nodes/Game Componens/PipeNode.swift` | 9-slice pipe body and cap, tinted by palette, with a contrast border. (The folder name's typo is real.) |
| `Nodes/Game Componens/InfiniteSpriteScrollNode.swift` | Tiling parallax background. |
| `Factories/PipeFactory.swift` | Spawns pipe pairs from `GameSettings`. Texture names `pipe-yellow`/`cap-yellow` are hard-coded here. |
| `Control/FocusScanner.swift` | Timed and manual scanning for every UIKit menu and Settings (`FocusScannable`). |
| `Extensions/SKNode+GameplayBoundary.swift` | `addGameplayBoundary(path:)`: the black/white outline on the helicopter and pipes. |
| `Utils/GameSettings.swift` | Singleton for every setting, preset, palette, and theme. Bounded, validated, persisted with `gs_` keys. |
| `Utils/UserDefaults.swift` | Legacy `Setting` and `Difficulty` enums, kept for migration and best score. |

Tests live in `HelichopterTests/` (Swift Testing): settings, scanner, lifecycle, onboarding, palette contrast, presentation, Dynamic Type, and window sizes.

### Colour systems (both in `GameSettings.swift`)

- **`ColorPalette`** colours the helicopter and pipes. Pipes use `colorBlendFactor = 1.0`; the detailed helicopter art uses `0.35` so its shading survives. Six palettes: Default, High Contrast, Deuteranopia, Protanopia, Tritanopia, Low Luminance (`gs_selectedPaletteID`).
- **`UITheme`** colours menus and scene backgrounds. Three themes: Night Sky, Parchment, Neon Night (`gs_selectedThemeID`). Light themes (`backgroundSpriteTintColor` set) hide the scrolling starfield, because tinting a dark texture cannot make it light. `helicopterTintColor` overrides the palette colour (Parchment uses `#CC2626`).
- Gameplay contrast does not rely on fill colours: the helicopter has a black/white marker and pipes have black/white borders. `PaletteContrastTests` render all 18 theme/palette combinations.

### Helicopter atlas

`Assets/Assets.xcassets/Playable Characters/Helicopter Player.spriteatlas/`: 60 frames, `r_player1`–`r_player60`, white/greyscale, 1×/2×/3×, played at 60 FPS. Regenerate with `python3 Tools/helicopter-kit/make_frames.py`. **The folder must keep its `.spriteatlas` extension**; without it `SKTextureAtlas` returns an empty atlas and gameplay crashes. The name `"Helicopter Player"` is hard-coded in `HomeViewController` and `UserDefaults.swift`.

---

## Known issues and debt

- **Double page during screen changes:** live in 2.0 (owner accepted it). Fixed on `master` by Plan 01 Stage B (every menu is UIKit, one cross-fade per change); ships as 2.1 once the owner's device recordings pass: [Plans/01_SINGLE_LAYER_UI.md](Plans/01_SINGLE_LAYER_UI.md).
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
