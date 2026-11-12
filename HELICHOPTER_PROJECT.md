# Helichopter — Project Reference

**Status (2026-11-12):** Version 2.1 (build 5, git tag `2.1`) is live on the App Store, distributed 2026-10-30. It carries Plan 01 Stage B (every menu in UIKit, one cross-fade per screen change), the Hangar (Plan 02 Phase 1 steps 1–2), VoiceOver Direct Touch, the top/bottom touch split, and per-scheme switch pausing. Development is post-launch improvement work, ordered in [Plans/ROADMAP.md](Plans/ROADMAP.md). Next release is 2.2 (build 6; version already set): Plan 02 Phase 1 step 3, whose code and art are done on `master` (Striped Pipes and a Two Tone Helicopter, both free). The owner decided on 2026-11-11 to hold these skins and ship them together with the UI polish ([Plans/03_UI_POLISH.md](Plans/03_UI_POLISH.md), direction "Bold arcade", Stages 0–5 done; Stage 6 next), so release prep and the owner's device check wait for that plan's Stage 8. The device accessibility checks in roadmap step 2 are still unticked. 157 unit tests and 4 UI tests pass (2026-11-12); the UI tests run Apple's accessibility audit on every screen.

> **Starting a session:** read this file, then the roadmap, then the plan file for the work you are doing. Before you finish, append an entry to [Audit/PROGRESS_LOG.md](Audit/PROGRESS_LOG.md).
> **If this file and the code disagree, trust the code** and fix this file.

---

## What the app is

Helichopter is a Flappy Bird–style helicopter game for iPhone and iPad (iOS 17.6+), built with Swift, SpriteKit, GameplayKit, and UIKit. Its purpose is to be playable by people with a wide range of disabilities. It is offline, has no accounts, ads, analytics, or purchases, and stores settings and scores in `UserDefaults` only.

Main features: four flight schemes (Tap to Flap, Hold to Hover, Auto Hover, Up/Down Switches), Timed or Step with Switch 2 scanning in every menu, switch pausing suited to each scheme (hold the primary switch in Tap to Flap, Hold to Hover, and Auto Hover, which caregivers can turn off; the secondary switch in Tap to Flap and Hold to Hover; both switches for half a second in Up/Down Switches), a top-half-up, bottom-half-down touch split with a divider in Auto Hover and Up/Down Switches, VoiceOver Direct Touch flight (taps and holds reach the game with no double-tap; can be turned off for double-tap flight actions) and spoken gap guidance, Dynamic Type everywhere, three UI themes, six colour palettes, contrast outlines, No-Fail and Calm modes, Reduce Motion handling, a replayable first-run guide, a caregiver Settings lock, and Settings reset.

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
| `Plans/03_UI_POLISH.md` | Plan to make every screen look designed and open: shared tokens, type, buttons, and a new Home, Settings, Hangar, HUD, and guide. |
| `Plans/02_COSMETICS_AND_STORE.md` | Plan for cosmetic helicopter and pipe skins, a Hangar/Store screen, and in-app purchases. |
| `Audit/PROGRESS_LOG.md` | Session-by-session history. Append here. |
| `Audit/REVIEW_2026-09-05.md`, `Audit/APP_STORE_READINESS.md` | Historical pre-release audits. Read only for background. |
| `Release/` | App Store listing copy, asset rights register, privacy notes, screenshots. |
| `docs/` | Public GitHub Pages site (privacy and support pages). Changes here go live when pushed. |
| `Tools/release_check.sh` | Pre-submission checks. Accepts a `.xcarchive`. |
| `Tools/helicopter-kit/` | Source art and the converter that builds each helicopter skin's 60-frame atlas. |
| `Tools/pipe-kit/` | The script that draws the Striped Pipes art. |

---

## Architecture

The app has one `RootViewController` holding an `SKView`. Home, the first-run guide, the Hangar, and Settings are UIKit child view controllers shown over an empty `SKView`; gameplay is an `SKScene` loaded from `GameScene.sks` or the wider `GameScene iPad.sks`, whichever `GameLayout.best(for:)` finds covers more of the window when Play is pressed. Those archives hold only scene settings; SpriteKit draws gameplay and nothing else. The HUD, Pause, and Round Over are UIKit, built in Swift. Nothing polls the UI: there is no refresh timer.

| File (under `Helichopter/`) | Role |
|---|---|
| `View Controllers/RootViewController.swift` | Hosts the `SKView`, the `SceneTextOverlay`, and Home, the guide, the Hangar, or Settings as a child controller; plays the menu theme (`MenuMusic`) on Home and the guide. **Owns every screen change:** `present(_:transition:)` takes a `Screen` (`.home`, `.guide`, `.hangar`, `.settings`, `.scene(_:)`; static form `present(_:in:)` for scenes) and is the only code that calls `presentScene`. It covers the swap with a snapshot of both layers, holds input, scanners, and `screenChanged` posts (`ScreenChangeAnnouncer`), and cross-fades (0.3 s; 0.2 s with Reduce Motion). Routes keyboard and game-controller switch input to the UIKit screen or the scene. Picks the scale mode for any window shape (`scaleMode(for:in:)`). Defines `GameLayout`, the phone and iPad gameplay layouts, chosen by window shape. |
| `Scenes/SceneTextOverlay.swift` | The gameplay HUD, built in Swift: Score, Best, Pause, the flight hint, and the new-high-score banner, updated only through `GameSceneHUDDelegate`. Hosts `GameMenuView` during Pause and Round Over; hidden and emptied on every other screen. Defines the VoiceOver `FlightAccessibilityElement`, which covers the lower half of the screen (in Auto Hover and Up/Down Switches, two: "Fly up" from below the HUD row to the middle and "Fly down" below it, beside a divider with Up and Down labels); with Settings → VoiceOver Direct Touch on (the default) it has `.allowsDirectInteraction` and `.silentOnTouch`, so VoiceOver passes touches straight to the scene. Pause stays above it as a normal button. |
| `Scenes/MenuStackView.swift` | Shared UIKit menu pieces: `MenuChoice`/`MenuItem` (scanner models), `MenuButton` (focus border by callback), `MenuStackView` (centred scrolling column), `BackdropView` (starry sky or theme colour), `ScreenViewController` (base for every UIKit screen: navigation, announcement, switch input, scanners to freeze during a fade), and `MenuViewController` (base for Home and the guide: owns a `FocusScanner`, ignores choices during a fade). |
| `Scenes/DesignSystem.swift` | The design tokens (Plan 03): `Spacing`, `Radius`, `Stroke`, `Layout` (560 pt content width, 56 pt minimum button height), `TypeStyle` (five SF Rounded text styles scaled by Dynamic Type), and `ArcadeButton` in three `ButtonKind`s (primary, secondary, quiet) with an ink outline and a solid lower edge. Views take sizes from here and colours from `UITheme`. |
| `Scenes/HomeViewController.swift` | Home: mascot (60-frame `UIImageView` animation, still under Reduce Motion), the leaning "Helichopter" wordmark (sized to stay on one line), Play as the one large primary button, and Hangar, Settings, and How to Play as icon tiles in a row (a column at accessibility text sizes). `HomeAction` holds each title, hint, and SF Symbol; scanning order is Play, Hangar, Settings, How to Play. |
| `Scenes/GuideViewController.swift` | First-run guide: three pages, Read this step aloud, Next/Back/Skip/Done. Shown at launch until `onboarding_completed_v1` is set, and from How to Play. |
| `Scenes/ScrollingPanelView.swift` | Shared base for Settings and the Hangar. `ScrollingPanelView`: the Back header and title, the scrolling stack, its own switch scanner over `controls(in:)`, the focus ring, scroll position, `SettingsStyle` (theme-derived colours), `ButtonTarget`, and the shared row helpers (section headings, labels, buttons, `lock(_:)` for the caregiver lock). `PanelScreenViewController<Panel>`: hosts one panel and swaps in a fresh one (0.25 s fade) when the theme, a preset, the lock, Reset, or text size changes, keeping scroll position, scanner focus (`focusedSetting`), and an open adjustment page; Back goes Home. |
| `Scenes/HangarPanelView.swift` | The Hangar (`HangarViewController`, `HangarPanelView`), opened from Home and from the Settings pointer. Menu Theme cards (preview, name, "Chosen", `.selected`; choosing one saves `selectedThemeID`, rebuilds, and keeps focus and VoiceOver on the card), then Helicopters and Pipes, with one card per owned look in `CosmeticsCatalog` (picture, name, "Equipped" in words and as the VoiceOver value, `.selected`, description as the hint; choosing one saves the skin, rebuilds, and keeps focus). Two of each exist: Classic and Two-Tone helicopters, Classic and Striped pipes. Pipe pictures are coloured by the palette as in play (`Cosmetic.pipePreviewImage`). The caregiver lock disables every card and shows "Locked by a caregiver in Settings." Single column at accessibility text sizes. |
| `Scenes/SettingsViewController.swift` | A Settings screen: the menu of categories (`Screen.settings`) or one category's page (`Screen.settingsCategory`). A `PanelScreenViewController<SettingsPanelView>`; a category's Back goes to the menu, which then starts on that category's card. It also opens the Hangar from the pointer button on Colours. |
| `Scenes/SettingsPanelView.swift` | One page of Settings (`SettingsPage`): the menu (six `SettingsCategory` cards, Reset, About) or a category (Difficulty, Comfort, Controls and Switches, Colours, Sound, Caregiver). With the caregiver lock on, categories open but are dimmed, with a note. The menu theme is no longer here: a "Menu Theme: <name>. Change it in the Hangar" button opens the Hangar (disabled when locked). |
| `Scenes/SettingsRows.swift` | The Settings row builders (category card, preset, slider, toggle, list of choices, palette) and `ChoiceButton`. Also `SettingsSlider` and `SettingsSwitch`: their accessibility frame covers the whole row (the row's own text is hidden from VoiceOver), and assistive technology activating a slider (VoiceOver double-tap, Switch Control) opens the adjustment page; a finger tap does not. Time sliders speak seconds; others speak a percentage (`UISlider.spokenValue`). |
| `Scenes/SettingsAdjustmentPanel.swift` | The full-panel page of plain choices for sliders, segmented controls, Reset, Privacy, and Acknowledgements, so one switch press changes one thing. |
| `Scenes/AppLinks.swift` | Privacy URL, support email, privacy summary, and acknowledgements text. |
| `Scenes/GameScene.swift` | Gameplay. `GKStateMachine` (Playing, Paused, GameOver), switch routing, hold-to-pause, VoiceOver flight, flight hint text, and `pauseFromHUD()`. Hides the starfield for plain-backdrop themes. Owns the Pause and Round Over menu items (`GameMenuItem`) that the switch scanner moves through, and acts on them in `perform(_:from:)`. |
| `Scenes/GameMenuView.swift` | Pause and Round Over in UIKit: `MenuAction`, `GameMenuItem` (scanner model owned by the scene), and `GameMenuView`, a `MenuStackView` whose buttons follow their items' focus with no polling. |
| `Adapters/GameSceneAdapter.swift` | Gameplay hub: physics, scoring, best-score saving, sounds, collisions, and the HUD delegate calls. |
| `Game States/*.swift` | `PlayingState` (pipe spawning, first-input start), `PausedState`, `GameOverState`. |
| `Nodes/Playables/HelicopterNode.swift` | Player sprite: atlas animation, physics, all four control schemes, contrast marker, No-Fail pulse. |
| `Nodes/Game Components/PipeNode.swift` | Pipe body and cap, tinted by palette, with a contrast border. Classic's body is a stretched 9-slice; a skin with `repeatsPipeArt` (Striped) is cropped from one tall image so its pattern never stretches. |
| `Nodes/Game Components/InfiniteSpriteScrollNode.swift` | Tiling parallax background. |
| `Factories/PipeFactory.swift` | Spawns pipe pairs from `GameSettings`, in the chosen pipe skin. |
| `Control/FocusScanner.swift` | Timed and manual scanning for every UIKit menu and Settings (`FocusScannable`). |
| `Extensions/SKNode+GameplayBoundary.swift` | `addGameplayBoundary(path:)`: the black/white outline on the helicopter and pipes. |
| `Utils/GameSettings.swift` | Singleton for every setting, preset, palette, theme, and chosen skin (`selectedHelicopterSkin`, `selectedPipeSkin`; unknown or unowned IDs read as Classic; Reset returns them to Classic). Bounded, validated, persisted with `gs_` keys. |
| `Utils/Cosmetics.swift` | `Cosmetic` and `CosmeticsCatalog` (Plan 02): every helicopter and pipe look, with its spoken name and description, art name, and (later) product ID. **The only place art names live**; gameplay, Home, and the Hangar ask the catalog (`artNamesLiveOnlyInTheCatalog` enforces this). Free looks: Classic and Two-Tone helicopters, Classic and Striped pipes. |
| `Utils/UserDefaults.swift` | Legacy `Setting` and `Difficulty` enums, kept for migration and best score. |

Tests live in `HelichopterTests/` (Swift Testing): settings, scanner, lifecycle, onboarding, palette contrast, presentation, Dynamic Type, and window sizes.

`HelichopterUITests/AccessibilityAuditTests.swift` (XCTest UI test) walks Guide → Home → Hangar → Settings (top to bottom, Acknowledgements) → Play → Pause → Round Over and runs `performAccessibilityAudit()` on each, attaching each screen's accessibility tree to the result. VoiceOver and Voice Control do not exist in the simulator; this tree is what they read. `testHangarPassesTheAuditInEveryTheme` chooses each theme card and audits the rebuilt Hangar; it sets no theme launch argument, because an argument would override the saved choice. `HangarTests` (unit) cover the Hangar's order, theme choice, lock, scanning, and text sizes. `AssistiveTechTreeTests` (unit) checks what VoiceOver reads in Settings, Voice Control names, locked controls, and Settings rebuilds. While a UIKit screen is showing, `RootViewController` pauses the empty `SKView` so it stops drawing every frame; without this the app never goes idle and UI tests stall.

### Colour systems (both in `GameSettings.swift`)

- **`ColorPalette`** colours the helicopter and pipes. Pipes use `colorBlendFactor = 1.0`; the detailed helicopter art uses `0.35` so its shading survives. Six palettes: Default, High Contrast, Deuteranopia, Protanopia, Tritanopia, Low Luminance (`gs_selectedPaletteID`).
- **`UITheme`** colours menus and scene backgrounds, with surface levels (page, card, raised), an ink colour for outlines, text and secondary text, an accent with its text colours, and the scanner focus colours; `ThemeSurfaceContrastTests` checks every text-on-surface pair. Three themes: Night Sky, Parchment, Neon Night (`gs_selectedThemeID`), chosen in the Hangar. Light themes (`backgroundSpriteTintColor` set) hide the scrolling starfield, because tinting a dark texture cannot make it light. `helicopterTintColor` overrides the palette colour (Parchment uses `#CC2626`).
- Gameplay contrast does not rely on fill colours: the helicopter has a black/white marker and pipes have black/white borders. `PaletteContrastTests` render all 18 theme/palette combinations, and `renderedGameplayBoundariesAcrossEveryThemeAndPalette` renders every helicopter and pipe skin in all 18.

### Helicopter atlas

`Assets/Assets.xcassets/Playable Characters/Helicopter Player.spriteatlas/`: 60 frames, `r_player1`–`r_player60`, white/greyscale, 1×/2×/3×, played at 60 FPS. The Two-Tone skin is a second atlas, `Helicopter Two-Tone.spriteatlas`, with the same frames and canvas. Regenerate either with `python3 Tools/helicopter-kit/make_frames.py [classic|two-tone]`. **The folder must keep its `.spriteatlas` extension**; without it `SKTextureAtlas` returns an empty atlas and gameplay crashes. The atlas name and frame names live only in `Utils/Cosmetics.swift` (`CosmeticsCatalog.classicHelicopter`, `Cosmetic.helicopterFrameName`); pipes use `pipe-<asset>` and `cap-<asset>` from the same catalog entry.

---

## Known issues and debt

- **Double page during screen changes:** fixed in 2.1 by Plan 01 Stage B (every menu is UIKit, one cross-fade per change): [Plans/01_SINGLE_LAYER_UI.md](Plans/01_SINGLE_LAYER_UI.md). The owner's device screen recordings (Plan 01 "Manual checks") are not recorded as done.
- Narrow iPad windows use the phone layout (larger game, smaller bars) since Plan 01 step 6, but only when Play is pressed: resizing mid-run changes the scale mode only. Not yet checked in a real Split View or Stage Manager window.
- **Not yet verified on a physical device:** VoiceOver, Voice Control, Switch Control, hardware switches, adaptive controllers, the oldest supported device, iPad window resizing, and real transitions.

---

## Releasing an update

Use this list for every version after 2.0. Details of the 2.0 and 2.1 submissions are in the progress log.

1. Bump `MARKETING_VERSION` for user-visible releases and always bump `CURRENT_PROJECT_VERSION` (build number) for each upload.
2. Run the full test suite, then `Tools/release_check.sh` on an unsigned Release build.
3. Archive with an Apple Distribution certificate. Run `Tools/release_check.sh path/to/Helichopter.xcarchive`; it fails on a development-signed build. Bundle ID `com.nathanmayo.helichopter`, team `9HJ5466NL8`.
4. Build with the SDK Apple currently requires (Xcode 26 / iOS 26 SDK since April 2026); check [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/).
5. If anything touches data, networking, SDKs, or purchases, update together: `docs/privacy.html` and its date, `AppLinks.privacySummary`, `PrivacyInfo.xcprivacy`, the App Privacy answers, and `Release/APP_STORE_COPY.md`.
6. If any art, sound, or music is added, record it in `Release/ASSET_RIGHTS.md` first (Guideline 5.2).
7. Update What's New, screenshots if screens changed, and the Accessibility Nutrition Labels if support changed.
8. After approval, tag the release in git (for example `2.0`, `2.1`).

App Store Connect facts for 2.0: category Games → Casual, age rating 4+, EU DSA status **non-trader** (must change before selling anything; see the store plan), App Privacy "Data Not Collected", export compliance "No" (`ITSAppUsesNonExemptEncryption = false`). Accessibility Nutrition Labels are published (2026-10-08): Larger Text, Dark Interface, Sufficient Contrast, Reduced Motion, Differentiate Without Color Alone. VoiceOver and Voice Control are held until device testing.
