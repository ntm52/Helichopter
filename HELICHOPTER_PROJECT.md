# Helichopter — Project Reference

**Status:** Phases 0–6 complete. UI theme system added post-Phase 6. Phase 7 (testing) is next.

> **Start a new session:** *"Read HELICHOPTER_PROJECT.md and continue from where it left off."*
> **Rule:** Update the Progress Log before the session ends. If code and doc disagree, trust the code.

---

## Current State at a Glance

Helichopter is a Flappy Bird–style iOS/SpriteKit accessibility game. It was broken and unmaintained (2021). Phases 0–6 have brought it to a clean build, full switch access, color palette system, art refresh, and a UIKit settings overlay. The game ships white/grayscale art that gets tinted at runtime via SpriteKit `colorBlendFactor`.

**Immediately playable.** No known crash bugs. One UX bug (see below).

---

## Known Bugs / Outstanding Issues

### "CLICK ME TO FLY" hint does not fade (unconfirmed)
The in-game hint label should fade out ~3 s after game start. The label lives inside the `"world"` node in `GameScene.sks` with the exact name `"CLICK ME TO FLY"` (all caps, confirmed via `strings` on the binary).

Code added to `PlayingState.didEnter` (after the PausedState early-return guard):
```swift
let hint = scene.childNode(withName: "world/CLICK ME TO FLY")
    ?? scene.childNode(withName: "//CLICK ME TO FLY")
if let hint {
    hint.alpha = 1
    hint.run(.sequence([.wait(forDuration: 3.0), .fadeOut(withDuration: 0.5)]))
}
```
The code compiles and runs but the fade has **not been confirmed working on device**. If still broken, try:
- `scene.enumerateChildNodes(withName: "//*") { node, stop in guard let l = node as? SKLabelNode, l.text == "CLICK ME TO FLY" else { return }; /* schedule fade */; stop.pointee = true }`
- Check that `PlayingState.didEnter` actually reaches this code (add a `debugPrint` to verify the node is found)
- The action is scheduled in `sceneDidLoad` timing (before scene is presented) — verify SpriteKit runs it once the scene appears

---

## Architecture

| File | Role |
|---|---|
| `Utils/GameSettings.swift` | Single source of truth for all tunable parameters, palettes, and UI themes. Singleton. |
| `Adapters/GameSceneAdapter.swift` | Game hub: gravity, scoring, audio, collision, HUD, overlay management. |
| `Factories/PipeFactory.swift` | Spawns pipes using `GameSettings` values. |
| `Nodes/Playables/HelicopterNode.swift` | Player sprite: animation, physics, all 4 control schemes, no-fail flash. |
| `Nodes/Game Components/InfiniteSpriteScrollNode.swift` | Tiling parallax background scroll. |
| `Nodes/UI Components/ButtonNode.swift` | Pressable SpriteKit button with focus ring, scanner activation, VoiceOver proxy. |
| `Nodes/UI Components/ToggleButtonNode.swift` | On/off toggle (used in SettingsScene.sks — must keep class even though .sks is hidden). |
| `Nodes/UI Components/TriggleButtonNode.swift` | 3-state button (Easy/Medium/Hard — same, must keep). |
| `Scenes/TitleScene.swift` | Title screen; applies UITheme on load; spawns helicopter from atlas. |
| `Scenes/GameScene.swift` | Main game scene; GKStateMachine; routes input to helicopter or overlay scanner. |
| `Scenes/SettingsScene.swift` | Hides all .sks content; shows `SettingsOverlayView` (UIKit, full settings). |
| `Scenes/RoutingUtilityScene.swift` | Base class for TitleScene/SettingsScene; handles button routing and FocusScanner. |
| `Scenes/SceneOverlay.swift` | Wraps Pause/Failed .sks files as floating overlays over GameScene. |
| `Game States/PlayingState.swift` | Active gameplay; spawns pipes; control-scheme dispatch. |
| `Game States/GameOverState.swift` | Shows FailedScene overlay; updates scores. |
| `Game States/PausedState.swift` | Shows PauseScene overlay; pauses scene. |
| `Extensions/SKNode+Theme.swift` | Recursive UITheme application: tints buttons, sets label colors, hides background nodes. |
| `Control/FocusScanner.swift` | Drives ButtonNode focus ring for switch/keyboard/controller scanning. |
| `Utils/UserDefaults.swift` | Legacy `Setting` enum + `Difficulty` enum. Kept for migration. |
| `Utils/PhysicsCategories.swift` | Physics bitmask constants. |

---

## Color Systems

Two independent systems, both in `GameSettings.swift`:

**`ColorPalette`** — game sprite colors (helicopter + pipes). Applied at runtime via `color` + `colorBlendFactor = 1.0` on white/grayscale art. 6 palettes: Default, High Contrast, Deuteranopia, Protanopia, Tritanopia, Low Luminance. Selected via `gs_selectedPaletteID`.

**`UITheme`** — menu chrome (background, buttons, labels, helicopter override). 3 themes: Night Sky (default dark navy), Parchment (cream), Neon Night (teal-black). Selected via `gs_selectedThemeID`.

Theme application:
- `backgroundColor` set directly on the SKScene
- For Parchment (and any theme with `backgroundSpriteTintColor != nil`): background sprites whose names start with `"background"` are **hidden** (not tinted — tinting dark textures with colorBlend gives dark result; hiding lets backgroundColor show)
- `helicopterTintColor` on UITheme overrides palette helicopter color (Parchment uses warm red `#CC2626`)
- `SKNode+Theme.swift` extension does recursive traversal; `TitleScene.applyContrastStyling()` also runs `enumerateChildNodes(withName: "//*")` as belt-and-suspenders

---

## Helicopter Sprite Atlas

**Location:** `Assets/Assets.xcassets/Playable Characters/Helicopter Player.spriteatlas/`
**Frames:** 20 × `r_player1`–`r_player20`, white/grayscale PNG, 1×/2×/3× each
**Timing:** 0.05 s/frame = 20 FPS, 1.0 s loop
**Loading:** `SKTextureAtlas(named: "Helicopter Player")` via `SKTextureAtlas+FrameUploader.swift`

⚠️ **Gotcha:** The folder MUST keep the `.spriteatlas` extension. Renaming it to just `Helicopter Player` (no extension) causes `SKTextureAtlas` to return an empty atlas → crash in `PlayingState`. This happened once and was fixed by renaming back.

---

## Design Principles

1. Every difficulty knob is independent and continuous — presets are starting points only.
2. Nothing punishes. No-fail is the default first experience.
3. Figure-vs-figure contrast is a hard requirement (player vs obstacle vs background — luminance + silhouette).
4. The player never has to read. Icons + spoken labels.
5. Switch access is first-class, not an afterthought.
6. The original design intent (trackable helicopter, wide gaps, slow-down) is preserved and made to actually work.

---

## Phase Status

| Phase | Status | Summary |
|---|---|---|
| 0 — Project recovery | ✅ Done | Restored .xcodeproj, moved off iCloud, .gitignore, README |
| 1 — Platform modernization | ✅ Done | arm64, dead code removed, B5–B8 fixed, AnyObject protocols |
| 2 — GameSettings tuning engine | ✅ Done | All 10 parameters independent + persisted, 3 presets, migration |
| 3 — Switch access | ✅ Done | FocusScanner, keyboard/GCController/Switch Control, 4 control schemes |
| 4 — Vision/motion/VoiceOver | ✅ Done | Palette system, Reduce Motion, VoiceOver announcements |
| 5 — Cognitive/sensory | ✅ Done | No-fail mode, calm mode, score toggle, settings lock |
| 6 — Art + audio | ✅ Done | New helicopter (20 frames), 9-slice pipes, background, icon, audio CAF |
| Post-6 — UI theme system | ✅ Done | Night Sky/Parchment/Neon Night themes, SettingsOverlayView UIKit rewrite |
| **7 — Testing** | ⬜ Next | See Phase 7 section below |
| 8 — App Store | ⬜ Pending | Privacy manifest, screenshots, submission |

---

## Phase 7 — Testing and Validation

- [ ] **Palette contrast unit tests** — test that fails the build if any palette drops below 4.5:1 on any of the three pairings (helicopter vs pipe, helicopter vs background, pipe vs background). Use the Testing framework.
- [ ] **GameSettings model tests** — verify presets write correct values, migration runs once, UserDefaults round-trips.
- [ ] **Scanner timing tests** — verify dwell fires at the configured interval, primaryActivate triggers the correct button.
- [ ] **Accessibility Inspector audit** — Xcode → Open Developer Tool → Accessibility Inspector → audit every scene. Zero issues target.
- [ ] **Manual assistive-tech matrix** (on hardware, not simulator):
  - VoiceOver with screen curtain on — full session playable by sound alone
  - Switch Control item scanning — every button reachable
  - Keyboard emulation (Space/Enter) — flap and menu navigation
  - GCController — adaptive controller buttons work
  - Reduce Motion — background stops, transitions cross-fade
  - Dynamic Type at max — text doesn't clip (note: Dynamic Type not yet implemented on SKLabelNodes)
- [ ] **Performance check** on oldest target device.
- [ ] **Real-user testing** — via OT/SLP, school, or AT lab. Do this before App Store, not after.

**Exit criteria:** unit suite green, Accessibility Inspector clean, one-switch full session on hardware (launch → settings → game → pause → retry → quit).

---

## Phase 8 — App Store

- [ ] `PrivacyInfo.xcprivacy` — UserDefaults requires `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`
- [ ] Accessibility Nutrition Labels in App Store Connect
- [ ] Bundle ID `com.nathanmayo.helichopter`, Team `9HJ5466NL8` — confirm certificates current
- [ ] Screenshots, description, age rating, export compliance
- [ ] Bump `MARKETING_VERSION` from 1.1 and tag

---

## Open Items (not blocking Phase 7)

- **Dynamic Type on SKLabelNodes** — recommended path is a UIKit overlay for all menu text. Deferred since SettingsScene is already UIKit; TitleScene/GameScene labels are next.
- **FailedScene.sks visual redesign** — still says "Failed" in large text. Backing model for calm restart is in place; only the .sks edit is missing.
- **Guided first-run onboarding** — all backing parameters in GameSettings, no UI yet.
- **Differentiate without color** (`UIAccessibility.shouldDifferentiateWithoutColor`) — pattern fills on pipes. Requires art work.
- **Per-profile save/load** — GameSettings supports the pattern; only needs a profile selection UI layer.
- **iPad .sks deduplication** — `*iPad.sks` files exist alongside phone versions. Deferred to Phase 4/5 rebuild.
- **Audio cues** beyond existing Score/Dead — approaching pipe, near-miss, gap cleared.

---

## Progress Log

*Newest at bottom. Append an entry before ending every session.*

### 2026-08-30 — Audit and planning (Windows, read-only)
Static audit only. No code changed. Wrote original project document.

### 2026-09-01 — Phase 0 complete
Project confirmed building. `.xcodeproj` recovered from git index. Moved off iCloud Drive. `.gitignore` restored. README rewritten.

### 2026-09-01 — Phase 1 complete
arm64, dead code deleted (~300 lines + assets), AnyObject protocols, B5–B8 fixes, PipeNode UIGraphicsImageRenderer (fixes blurry pipes on 3x). Zero warnings.

### 2026-09-01 — Phase 2 complete
`GameSettings.swift` created. 10 independent persisted parameters. 3 presets (Gentle/Standard/Challenge). Migration from legacy `Setting.difficulty`. B2 fix (inverted pipe gap toggle). Zero warnings.

### 2026-09-02 — Phase 3 complete
`FocusScanner.swift`. `SwitchInputReceivable` protocol. Keyboard (`pressesBegan`) + GCController + iOS Switch Control via `ButtonAccessibilityElement`. 4 in-game control schemes (tapFlap, holdHover, autoHover, twoSwitchUD). Zero warnings.

### 2026-09-02 — Phase 4 complete
Palette system (6 palettes, WCAG-validated). VoiceOver labels/hints on all buttons. Score announcements. Reduce Motion (transitions + background scroll + helicopter animation). `backgroundScrollSpeed` independent of pipe speed. Zero warnings.

### 2026-09-02 — Phase 5 complete
No-fail mode (invulnerability flash, default on). Calm mode (suppresses Dead.caf + haptic). Score display toggle. Settings lock. Zero warnings.

### 2026-09-02 — Phase 6 complete
New 20-frame helicopter (white/grayscale, 20 FPS). 9-slice pipes (no more UIGraphicsImageRenderer). New background (dark warm charcoal, tileable). New buttons. New app icon. Audio converted WAV→CAF (~26 MB → ~2.5 MB). Zero warnings.

### 2026-09-02 — Post-Phase-6: UI Theme system + SettingsOverlayView
- **UITheme struct** added to GameSettings.swift with 3 themes (Night Sky, Parchment, Neon Night). `selectedThemeID` persisted under `gs_selectedThemeID`.
- **`SKNode+Theme.swift`** new file — recursive `applyUITheme(_:)` extension tints buttons, colors labels, hides background-named nodes for light themes.
- **Parchment background fix**: uses `isHidden = true` on background-named sprites + `backgroundColor = cream`. Tinting doesn't work because `colorBlend` multiplies dark texture × cream = still dark.
- **`helicopterTintColor: UIColor?`** on UITheme — overrides palette helicopter color per theme. Parchment = warm red `#CC2626` (8:1 contrast vs cream). Night Sky / Neon Night = nil (use palette).
- **`SettingsOverlayView`** (UIKit, inside `SettingsScene.swift`) — full settings panel with sections: Difficulty Preset, Gameplay sliders, Motion, Comfort, Switch Access, Visual Theme (segmented), Colour Accessibility (palette swatches), Audio. The old .sks buttons are hidden in `didMove`; UIKit handles all interaction.
- **Helicopter sprite atlas**: user replaced 10-frame with 20-frame art. Folder was accidentally renamed from `Helicopter Player.spriteatlas` → `Helicopter Player` (no extension) which broke `SKTextureAtlas` loading. Fixed by renaming back. `HelicopterNode.animate(with:)` now guards `!textures.isEmpty`.
- **Dead code removed** from `ButtonNode.swift`: `selectedTextureName` (always nil), `focusableNeighbors` (never used), `performInvalidFocusChangeAnimationForDirection` (never called), macOS `#elseif os(OSX)` block.
- **Known unconfirmed bug**: "CLICK ME TO FLY" label fade — code is in place in `PlayingState.didEnter` but not verified working on device. See Known Bugs section above.
