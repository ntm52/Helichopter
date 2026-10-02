# Helichopter — Project Reference

**Status (2026-10-01):** Feature-complete for 2.0; working through the [Release Plan](#release-plan--path-to-the-app-store) below. 71 automated tests pass. Remaining blockers are owner inputs (privacy URL, support contact, asset rights), the in-app privacy link, physical-device accessibility testing, and App Store Connect setup. Historical phase notes below are not release certification.

> **Start a new session:** *"Read HELICHOPTER_PROJECT.md and continue from where it left off."* The [Release Plan](#release-plan--path-to-the-app-store) is the active to-do list.
> **Rule:** Update the Progress Log before the session ends. If code and doc disagree, trust the code. Run `Tools/release_check.sh` before any submission.

---

## Current State at a Glance

Helichopter is a Flappy Bird–style iOS/SpriteKit accessibility game. It was broken and unmaintained (2021). Phases 0–6 have brought it to a clean build, full switch access, color palette system, art refresh, and a UIKit settings overlay. The game ships detailed helicopter artwork with a light runtime tint (`colorBlendFactor = 0.35`); pipes retain their solid palette tint.

The project builds. Full gameplay and assistive-technology validation remain outstanding; see the audit report for confirmed issues and coverage.

---

## Known Bugs / Outstanding Issues

- [x] **Two versions of a screen (new loading over old)** — fixed 2026-10-01. The legacy SpriteKit `.sks` menus/HUD were only hidden by the UIKit overlay's 50 ms refresh timer, and `applyUITheme` re-coloured them on every scene load, pause, and round-over. During scene transitions and the first frames of each pause, the archived screen rendered under/beside the UIKit one. Scenes and overlays now call `suppressArchivedPresentation()` at load and after theming (`SceneTextOverlay.swift`).
- [x] **Two Pause buttons** — same root cause: the archived SpriteKit Pause sprite was visible until the first UIKit refresh. Fixed by the change above; covered by `PresentationTests.archivedScenesNeverRenderBeforeUIKitRefresh`.
- [x] **Menu buttons/text at the top instead of centred** — the UIKit menu stack was pinned to the top of its scroll view. Menus now centre vertically and still scroll from the top when text is too large to fit; the gameplay HUD stays at the top. Covered by `PresentationTests.menusAreCentredAndHUDStaysAtTop`.
- [x] **Crash on a fast double-tap in a closing menu** — a UIKit button could outlive its SpriteKit node for up to 50 ms; activating it hit `fatalError` in `ButtonNode.responder`. The responder is now optional and the overlay rebuilds immediately after each tap.
- [ ] Add a “New high score” notification when a run beats the saved record. Announce it once, respect Show Score and Calm Mode, and avoid interrupting flight input.
- [ ] **Verify on device** that the three presentation fixes above hold during real transitions (Title ↔ Settings push, Title → Game fade, Pause/Resume, Round Over → Retry), on iPhone and iPad in both orientations.

VoiceOver flight actions and spoken gap guidance are implemented; sound-only usability remains to be established; Dynamic Type is implemented with device validation pending; gameplay contrast boundaries are implemented, with low-vision device validation pending. Hardware-switch Settings navigation and hold-to-pause are implemented; physical assistive-device validation remains outstanding. See [the current audit](Audit/REVIEW_2026-09-05.md).

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
| `Scenes/SceneTextOverlay.swift` | Scalable UIKit menu/HUD text, scrollable buttons bound to SpriteKit actions, and scanner focus. **UIKit owns everything visible**; `SKNode.suppressArchivedPresentation()` keeps archived `.sks` buttons/labels invisible. Call it after any `applyUITheme`. |
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

**`ColorPalette`** — game sprite colors (helicopter + pipes). Applied at runtime via `color`: pipes use `colorBlendFactor = 1.0`, while the detailed helicopter uses `0.35`. Palette color tests do not certify rendered artwork contrast. 6 palettes: Default, High Contrast, Deuteranopia, Protanopia, Tritanopia, Low Luminance. Selected via `gs_selectedPaletteID`.

**`UITheme`** — menu chrome (background, buttons, labels, helicopter override). 3 themes: Night Sky (default dark navy), Parchment (cream), Neon Night (teal-black). Selected via `gs_selectedThemeID`.

Theme application:
- `backgroundColor` set directly on the SKScene
- For Parchment (and any theme with `backgroundSpriteTintColor != nil`): background sprites whose names start with `"background"` are **hidden** (not tinted — tinting dark textures with colorBlend gives dark result; hiding lets backgroundColor show)
- `helicopterTintColor` on UITheme overrides palette helicopter color (Parchment uses warm red `#CC2626`)
- `SKNode+Theme.swift` extension does recursive traversal; `TitleScene.applyContrastStyling()` also runs `enumerateChildNodes(withName: "//*")` as belt-and-suspenders

---

## Helicopter Sprite Atlas

**Location:** `Assets/Assets.xcassets/Playable Characters/Helicopter Player.spriteatlas/`
**Frames:** 60 × `r_player1`–`r_player60`, white/grayscale PNG, 1×/2×/3× each
**Timing:** 1/60 s/frame = 60 FPS, 1.0 s loop
**Loading:** `SKTextureAtlas(named: "Helicopter Player")` via `SKTextureAtlas+FrameUploader.swift`

⚠️ **Gotcha:** The folder MUST keep the `.spriteatlas` extension. Renaming it to just `Helicopter Player` (no extension) causes `SKTextureAtlas` to return an empty atlas → crash in `PlayingState`. This happened once and was fixed by renaming back.

---

## Design Principles

1. Visible controls independently tune gap size, pipe speed, hitbox size, and background scroll; other model parameters remain preset-controlled in the UI.
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
| 6 — Art + audio | ✅ Done | New helicopter (60 aligned frames), 9-slice pipes, background, icon, audio CAF |
| Post-6 — UI theme system | ✅ Done | Night Sky/Parchment/Neon Night themes, SettingsOverlayView UIKit rewrite |
| **7 — Testing** | ⬜ Next | See Phase 7 section below |
| 8 — App Store | 🔄 In progress | See [Release Plan](#release-plan--path-to-the-app-store) |

---

## Phase 7 — Testing and Validation

- [x] **Gameplay contrast boundaries** — opaque black/white borders separate the flight marker and pipe silhouettes from textured backgrounds. Validate rendered output for every theme/palette, alongside swatch tests. This replaces the unrealized three-way 4.5:1 fill-color target; artwork pixels are not individually certified. Low-vision device testing remains required.
- [x] **GameSettings model tests** — presets, migration, round-trips, validation, reset (`GameSettingsTests.swift`).
- [x] **Scanner timing tests** — dwell advance and activation (`FocusScannerTests.swift`).
- [ ] **Accessibility Inspector audit** — Xcode → Open Developer Tool → Accessibility Inspector → audit every scene. Zero issues target.
- [ ] **Manual assistive-tech matrix** (on hardware, not simulator):
  - VoiceOver with screen curtain on — full session playable by sound alone
  - Switch Control item scanning — every button reachable
  - Keyboard emulation (Space/Enter) — flap and menu navigation
  - GCController — adaptive controller buttons work
  - Reduce Motion — background stops, transitions cross-fade
  - Dynamic Type at max — verify UIKit menu/HUD and Settings layouts on hardware (automated layout coverage added)
- [ ] **Performance check** on oldest target device.
- [ ] **Real-user testing** — via OT/SLP, school, or AT lab. Do this before App Store, not after.

**Exit criteria:** unit suite green, Accessibility Inspector clean, one-switch full session on hardware (launch → settings → game → pause → retry → quit).

---

## Release Plan — path to the App Store

Work top to bottom. **Owner** = needs Nathan's decision or account access; everything else can be done in code. Drafted copy lives in `Release/`; detailed rationale in [Audit/APP_STORE_READINESS.md](Audit/APP_STORE_READINESS.md).

### P0 — Code and repo hygiene (do first)
- [ ] **Commit and push the outstanding work.** As of 2026-10-01 the onboarding guide, Settings reset, settings validation, pipe-geometry fix, presentation fixes, `Release/` docs, and `Tools/release_check.sh` are uncommitted. GitHub (`ntm52/Helichopter`) only has up to `3242563`.
- [x] **Minimum iOS version: 17.6** (owner confirmed 2026-10-01). Dead `#available(iOS 14/17)` branches removed; README and readiness docs updated.
- [x] **Renamed the Xcode scheme** `flappy-fly-bird` → `Helichopter` (2026-10-01) and removed its stale reference to the deleted `flappy-fly-birdTests` target.

### P0 — Apple privacy and security requirements (submission blockers)
Run `Tools/release_check.sh` (unsigned Release build) and `Tools/release_check.sh path/to/Helichopter.xcarchive` (before upload). It verifies the items marked ⚙.
- [x] ⚙ **Privacy manifest** (`PrivacyInfo.xcprivacy`) bundled. Declares no tracking, no collected data, and UserDefaults reason `CA92.1`. No other required-reason APIs (file timestamps, boot time, disk space, keyboards) are referenced by the app binary.
- [x] ⚙ **Export compliance:** `ITSAppUsesNonExemptEncryption = false` (no custom crypto, no networking). Answer "No" to the encryption questions in App Store Connect.
- [x] ⚙ **No App Transport Security exceptions, no networking, no third-party SDKs, no permission prompts.** Keeps the App Privacy answer "Data Not Collected" valid. Re-run the script if any SDK, analytics, or crash reporter is ever added: each needs its own privacy manifest and signature, and the privacy answers must change.
- [x] ⚙ **App Store icon** 1024 px opaque (no alpha).
- [x] **Privacy policy and support pages** written in `docs/` (contact `helichopter.support@gmail.com`), to be served at https://ntm52.github.io/Helichopter/privacy.html and `/support.html`.
- [ ] **Owner: turn on GitHub Pages** (repo Settings → Pages → Deploy from branch `master`, folder `/docs`), then open both URLs to confirm they load before entering them in App Store Connect.
- [x] **In-app privacy policy** (Guideline 5.1.1(i)): Settings → About → Privacy Policy shows a summary plus "Open Full Policy in Safari". Switch-scannable, and reachable while Settings is locked. If the app is placed in the **Kids** category, the Safari link must sit behind a parental gate (Guideline 1.3).
- [ ] **App Privacy questionnaire** in App Store Connect: "Data Not Collected". Tracking: No.
- [ ] ⚙ **Distribution signing:** archive with an Apple Distribution certificate. The script fails if `get-task-allow` is present (development-signed build). Bundle ID `com.nathanmayo.helichopter`, team `9HJ5466NL8`. Owner: confirm the membership and certificates are current.
- [ ] **Current SDK:** uploads must be built with the current required Xcode/iOS SDK (Xcode 26 / iOS 26 SDK since April 2026). The local toolchain already meets this; recheck Apple's [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) at upload time.
- [x] **Content rights (Guideline 5.2).** Artwork is owner-made (by hand or with Codex), the sound effects were made in GarageBand, and the music was replaced with a CC0 Freesound track (2026-10-01). Details in `Release/ASSET_RIGHTS.md`. Optional: download the lossless original from Freesound (login required) to replace the preview-quality encode.
- [x] **Acknowledgements:** Settings → About → Acknowledgements shows the BSD 3-Clause notice (required in binary distributions; it doesn't restrict selling or in-app purchases) and music credits.

### P0 — App Store Connect setup (Owner)
- [ ] **Age rating:** complete Apple's current age-rating questionnaire (the 2025 system with 4+/9+/13+/16+/18+). No violence beyond cartoon collisions, no user-generated content, no ads, no purchases. Answer from the actual content; don't pre-pick a rating.
- [ ] **EU Digital Services Act trader status:** declare trader or non-trader in App Store Connect. Distribution in the EU is blocked without it. Traders must publish contact details.
- [ ] **Category:** Games → Casual (proposed). Choose **Kids** only if you accept its extra rules (parental gate on external links, stricter review).
- [ ] **Listing:** paste in `Release/APP_STORE_COPY.md`. Keep accessibility claims specific (Guideline 2.3: accurate metadata). Add App Review contact and the drafted review notes.
- [ ] **Screenshots:** capture real release-candidate screens on the required iPhone and iPad sizes.
- [ ] **Accessibility Nutrition Labels:** select only features verified on device (VoiceOver, Larger Text, etc.).
- [ ] **Version:** 2.0, build number unique and increasing for each upload. Tag the release in git after approval.

### P1 — Before launch (quality)
- [ ] **Physical-device testing** (Phase 7 matrix): VoiceOver, Switch Control, keyboard switches, adaptive controller, Reduce Motion, largest text, oldest supported device. Include the transition checks under Known Bugs.
- [ ] **TestFlight** with real players (OT/SLP, school, or AT lab) before public release.
- [ ] **iPadOS 26 windowing:** `UIRequiresFullScreen` is deprecated in iPadOS 26 and will be ignored in a future release. Check that the scene and UIKit overlay lay out correctly in resizable windows, not just full-screen portrait/landscape.
- [ ] **Hint wording:** the gameplay hint reads "CLICK ME TO FLY", which is inaccurate for touch, switch, and VoiceOver players. Replace with scheme-aware text (e.g. "Tap or press your switch to fly"). Needs `PlayingState`'s text match updated too.
- [ ] **"New high score" notification** (see Known Bugs).

### P2 — After launch (technical debt)
- [ ] **Replace the 50 ms overlay polling timer** in `GameViewController` with explicit refreshes on scene/state changes. It runs 20×/second even on the home screen (battery), and it's why UIKit and SpriteKit could disagree.
- [ ] **Retire the hidden SpriteKit menu archives.** UIKit now draws every menu; the `.sks` buttons and labels are kept only as invisible action and text models. Moving the actions into Swift would remove the duplication class of bug entirely, along with the iPad `.sks` copies and the legacy `ToggleButtonNode`/`TriggleButtonNode`.
- [ ] Remove `fatalError` from the legacy `ToggleButtonNode`/`TriggleButtonNode` responders, matching the `ButtonNode` fix.
- [ ] Continuous audio guidance, saved profiles, differentiate-without-colour pipe patterns, localization.

---

## Open Items (not blocking Phase 7)

- **Dynamic Type device validation** — UIKit owns visible menu/HUD text; Settings uses UIFontMetrics. Validate largest sizes with VoiceOver, Switch Control, and mounted iPad orientations on hardware.
- **Round-over wording** — runtime already replaces the archive text with “Round Over” or “Well Done!” in Calm Mode.
- **Guided first-run onboarding** — implemented with three replayable steps, spoken instructions, and switch navigation.
- **Differentiate without color** (`UIAccessibility.shouldDifferentiateWithoutColor`) — pattern fills on pipes. Requires art work.
- **Per-profile save/load** — GameSettings supports the pattern; only needs a profile selection UI layer.
- **iPad .sks deduplication** — `*iPad.sks` files exist alongside phone versions. Deferred to Phase 4/5 rebuild.
- **Audio cues** beyond existing Score/Dead — approaching pipe, near-miss, gap cleared.
- **Privacy policy and support** — the root privacy manifest is already bundled. Add a public policy/support page and an accessible in-app policy link before submission.

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

### 2026-09-03 — Pre-Phase-7 deferred items
- **"CLICK ME TO FLY" hint fixed**: replaced path-based search with `enumerateChildNodes(withName: "//*")` scanning for the label by its `text` property. Fades immediately (0.5 s) when PlayingState is entered rather than waiting 3 s. No more "unconfirmed" status.
- **SettingsOverlayView theming**: all hardcoded Night Sky colors removed. Colors now derived from `UITheme` at init time via relative-luminance check. Panel background, section headers, text, subtitles, row backgrounds, hairlines, segmented controls, palette swatch borders, and UISwitch/UISlider accents all follow the active theme. Works correctly for all three themes (Night Sky dark navy, Parchment cream, Neon Night dark teal).
- **Settings screen background**: `SettingsScene.didMove` now sets `backgroundColor` from `selectedTheme.sceneBackgroundColor` instead of hardcoded dark navy.
- **Missing settings rows added**: `scanScheme` (Auto-Advance vs Two-Switch menu navigation) and `isSettingsLocked` (Caregiver section) now have UI rows in the settings panel. Previously they existed in GameSettings but had no UI.
- **FailedScene overlay text**: `GameOverState` now enumerates the overlay for a label with text "Failed" and replaces it with "Round Over" (normal mode) or "Well Done!" (calm mode). Aligns with the "nothing punishes" design principle.
- **PrivacyInfo.xcprivacy**: created at `Helichopter/PrivacyInfo.xcprivacy` with `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`. **Needs to be added to the Xcode target** via File → Add Files to "Helichopter" before App Store submission.
- Zero warnings. Clean build.

### 2026-09-03 — Live settings theming + pipes-on-first-click
- **Settings theme live update**: When the theme segmented control is tapped, the settings panel now rebuilds itself with the new theme colors using a 0.25 s cross-fade. Scroll position is preserved. The SpriteKit background behind the panel also updates immediately.
- **Pipes wait for first click**: `HelicopterNode` now has an `onFirstInput: (() -> Void)?` hook that fires and self-clears on the player's first touch/switch input. `PlayingState.didEnter` sets this hook to (a) start the pipe-spawn action and (b) fade the "CLICK ME TO FLY" hint. Result: helicopter floats with the hint visible, no pipes appear until the player actually taps.
- Resume-from-pause is unaffected — the pipe action resumes automatically via the scene's `isPaused = false` and no hook is set in the pause-resume path.
- Zero warnings. Clean build.

### 2026-09-05 — Independent code audit and regression testing
- Reviewed source, scene archives, assets, build settings, and tests. Preserved existing flight-control edits.
- Fixed pause gravity, stale held inputs, scene retention, background zero-speed persistence, pipe cleanup, hidden-button scanning, paused focus feedback, score visibility/announcement, timer cancellation, Settings lockout, and stale preset controls.
- Added injectable settings storage and lifecycle/migration regression coverage. Original 29 tests passed; expanded 38 tests passed on both iPhone 17 Pro and iPad mini simulators (76 executions, iOS 26.5).
- Unsigned optimized iOS Release build succeeded. Privacy manifest inclusion verified. Actual version is 2.0 (1), app minimum iOS 13.0; earlier notes about version/manifest were stale.
- App Store readiness claim rejected: functional accessibility gaps and device/manual validation remain. Full evidence, limitations, and release gate: `Audit/REVIEW_2026-09-05.md`.

### 2026-09-05 — Gameplay interruption and frame-rate bug fixes
- Continued from the audit, preserving its existing uncommitted fixes.
- App deactivation and controller disconnection now pause active gameplay and clear held flight controls. App reactivation requires explicit gameplay resume; controller callbacks run on the main queue.
- Normalized auto-hover/two-switch damping to elapsed time and reset helicopter timing on pause/new run.
- Added four regression tests. All 42 tests passed on iPhone 17 Pro (iOS 26.5); build succeeded and diff whitespace checks passed.
- Physical-device validation remains outstanding. Next priorities are UIKit Settings switch navigation, a one-switch gameplay Pause route, VoiceOver flight interaction, rendered contrast, and Dynamic Type. See the updated audit for details and test artifacts.

### 2026-09-05 — UIKit Settings switch navigation
- Committed and pushed the earlier work in four sections: settings fixes, scanner fixes, gameplay/lifecycle fixes, and audit documentation.
- Reused FocusScanner through a shared focusable-item protocol for SpriteKit and UIKit. Settings now overrides inherited switch routing and keeps the hidden legacy scanner stopped.
- Added control highlighting, automatic vertical/horizontal scrolling, slider adjustment panels, segmented-choice panels, and focus restoration after theme/preset/lock rebuilds. Back and unlock remain scannable when Settings is locked.
- Added six Settings regression tests: reachability, bounded adjustments, rebuild/lock behavior, palette/scan-mode changes, a timed primary-switch-only session, and rendered small-phone/landscape-tablet layouts. All 48 suite tests passed on iPhone 17 Pro (iOS 26.5).
- Reviewed rendered layouts; made the adjustment panel opaque to eliminate distracting underlying text. Physical switch/controller and system accessibility testing remains outstanding. One-switch Pause during gameplay is still the next functional switch-access gap.

### 2026-09-07 — Helicopter kit integration and complete home-screen loop
- Integrated the supplied source artwork and reproducible Pillow converter into `Tools/helicopter-kit/`; regenerated the existing atlas at 1x/2x/3x with 60 aligned frames, a stationary body, and three rotor cycles per second. Near-transparent export noise is removed before calculating the shared crop.
- Gameplay and title playback share a 1/60-second frame interval. A light theme/palette tint preserves the cockpit and shading. Reduce Motion retains a static frame; rendered contrast validation remains outstanding.
- Fixed the title placeholder lookup: both iPhone and iPad archives name it `Animated Bird`, so the previous lookup for `Animated Helicopter` silently left the archived four-frame action running. Both now replace that placeholder with the complete repeating atlas animation.
- The title mascot has no physics or flight input, and repeated scene presentation does not create another mascot.
- Added a regression covering both title archives, all 60 frames, playback timing, Reduce Motion behavior, and repeat presentation. All 49 tests passed on the iPhone 17 Pro simulator (iOS 26.5), including the new test loading both iPhone and iPad title archives. Build and `git diff --check` passed. Test result: `/tmp/helichopter-title-loop-tests.xcresult`. Physical-device playback remains unverified.

### 2026-09-07 — One-switch gameplay pause and Home navigation
- Added primary-switch hold-to-pause for all four flight schemes. Default delay is 3 seconds; Settings → Switch Access → Hold Switch to Pause adjusts it from 2–10 seconds. Sustained hover users can increase the delay or release/re-press before it expires.
- Switch-triggered Pause starts menu scanning even when automatic menu startup is off. The selected timed/manual scan mode is preserved. Release is required before the next menu activation, and keyboard repeat cannot restart the hold timer or activate a menu/resumed flight accidentally.
- Pending gestures are cancelled on release, gameplay exit, interruption, and scene removal; held flight controls are cleared by pause. Home now stops the outgoing scanner and returns immediately, avoiding a transition that can stall while the game is paused.
- Added five regression tests covering all flight schemes, one-switch Resume/Retry/Home, manual two-switch scanning, cancellation, repeat suppression, and bounded/persisted delay. Existing Settings reachability coverage includes the new control.
- Validation: all **54 tests passed**, zero failures/skips, on iPhone 17 Pro (iOS 26.5 simulator). Build and diff whitespace checks passed. Result: `/tmp/helichopter-switch-pause-complete.xcresult`; log: `/tmp/helichopter-switch-pause-complete.log`.
- Physical keyboard-emulating switches, adaptive controllers, and system Switch Control remain unverified. VoiceOver flight, rendered contrast, and Dynamic Type remain open.

## Follow-up — September 7, 2026: Gameplay contrast boundaries
- Added opaque black/white borders around a stable helicopter flight marker and the combined pipe body/cap silhouettes. Artwork and theme tints remain intact; visibility no longer depends solely on their fill colors.
- No-fail feedback pulses artwork tint instead of fading the player and its boundary. Reduce Motion and Calm Mode still suppress the pulse. Existing collision geometry is unchanged.
- Kept palette swatch tests and added a boundary luminance check plus SpriteKit pixel checks and scene captures for all 18 theme/palette combinations, including both pipe orientations.
- Validation: **56 tests passed**, zero failures/skips, on iPhone 17 Pro (iOS 26.5 simulator). Reviewed the 18 rendered gameplay captures. Results: `/tmp/helichopter-contrast-final.xcresult`; log: `/tmp/helichopter-contrast-final.log`.
- This implements boundary visibility, not certification of every artwork pixel or all vision conditions. Physical-device and low-vision player evaluation remain outstanding.

### 2026-09-08 — VoiceOver flight and Dynamic Type integration
- Preserved and integrated the existing uncommitted Dynamic Type implementation: UIKit menu/HUD text, wrapping Settings labels, scrollable menus/choices, and scanner focus preservation.
- Added a stable VoiceOver flight element to the visible UIKit overlay, with scheme-specific double-tap actions, downward movement, Pause, and accessibility escape. Sustained controls toggle because accessibility activation has no release callback. Changing VoiceOver status pauses and clears held controls.
- Added live altitude/status values and short, rate-limited pipe proximity/gap-alignment announcements. Guidance uses the nearest pipe and collision-radius clearance; automatic speech omits altitude to stay brief. Full sound-only usability is not established by these changes.
- Added regression coverage for all four schemes, first-input spawning, stable accessibility identity, pause/held-state cleanup, and gap direction/clearance. Corrected the inherited Dynamic Type test's trait environment and excluded empty/internal segmented-control labels from its automatic-font assertion. The Settings layout test now hosts the panel in a window and resolves its traits, matching the app view hierarchy. This exposed clipped Calm Mode/Show Score labels at the largest text size; multiline labels now use their resolved width and resist vertical compression.
- Updated README, corrected stale atlas/version/privacy/round-over notes, and added `Audit/APP_STORE_READINESS.md` with the app breakdown and non-testing launch recommendations.
- Final validation: all **60 tests passed**, zero failures/skips, on iPhone 17 Pro (iOS 26.5 simulator). Optimized unsigned iOS Release build and `git diff --check` passed. Reviewed the largest-text 320-point Settings choice capture. Results: `/tmp/helichopter-layout-validated.xcresult`; test log: `/tmp/helichopter-layout-validated.log`; release log: `/tmp/helichopter-release-validated.log`. No physical VoiceOver session or App Store submission is claimed.

### 2026-09-08 — Simple first-run onboarding
- Added a three-step first-run guide with current flight controls, no-fail status, pause, switch scanning, and difficulty guidance. Done/Skip persist completion; How to Play on the home screen replays it.
- Reused scalable, scrollable UIKit menus and switch scanning. Spoken instructions pause the scanner until the next switch press; steps never auto-advance.
- Added completion/replay/switch navigation and phone/tablet large-text layout coverage. Full simulator suite passed; a follow-up onboarding run passed with the largest accessibility text size hosted in a window. Results: `/tmp/helichopter-onboarding-2.xcresult` and `/tmp/helichopter-onboarding-layout.xcresult`. Physical assistive-device verification remains outstanding.
- Updated the App Store readiness document to record the implemented guide.

### 2026-09-08 — Remaining local App Store preparation
- Added bounded numeric settings, safe malformed enum handling, ordered gap bounds, and pipe geometry constrained to the scene. Explicit gap edits retain the newly requested value by adjusting the opposite bound.
- Added Settings reset with Cancel/Restore Defaults and switch scanning; preserves scores and guide completion, resets controls/theme/audio, and respects caregiver lock.
- Prepared release listing/review copy, privacy/support drafts, and an asset-rights register under `Release/`. Updated readiness statuses and narrowed public tuning promises to visible controls.
- Public contact/URLs, asset rights confirmation, final screenshots, supported-OS commitment, distribution signing and App Store Connect remain outstanding. Kept iOS 13 app minimum and the separate iOS 26.5 test target.
- Validation: all **65 discovered tests passed** on iPhone 17 Pro (iOS 26.5 simulator), including reset confirmation, invalid settings recovery, and small-scene gap geometry. Existing timer tests now use the supported 0.5-second minimum instead of out-of-range test values. Result: `/tmp/helichopter-readiness-final.xcresult`; log: `/tmp/helichopter-readiness-final.log`.
- Optimized unsigned iOS Release build passed; bundled manifest and version 2.0 (1), iOS 13 minimum verified. Log: `/tmp/helichopter-readiness-release.log`. Listing field lengths and `git diff --check` passed. This does not establish signing readiness or physical-device accessibility support.

### 2026-09-08 — Unified home screen, gameplay HUD, and pause presentation
- UIKit owns visible menus and HUD controls. Archived SpriteKit buttons remain action/scanner models but no longer render or receive duplicate touch targets; the hidden title mascot stops animating. The home screen retains its themed sky and one visible helicopter.
- Current score, live best score, and a single Pause control share the HUD, with the flight hint below. The HUD stacks vertically at accessibility text sizes. Show Score controls both score displays.
- Pause retains the frozen game behind a light dimming layer. Settings → Comfort → Hide Game While Paused restores a solid background for players who prefer fewer distractions. Pause reads only its own menu labels, excluding the underlying flight hint.
- Added Settings → Comfort → Helicopter Outline to disable the black/white flight marker. It defaults on to preserve the existing contrast aid; collision geometry and pipe boundaries are unchanged.
- Added the “New high score” notification to future work above; it is not implemented in this change.
- Regression coverage includes phone/tablet scene archives, menu action routing, duplicate-control suppression, score visibility, outline preference, pause background modes, and the largest-text HUD layout.
- Validation: initial full simulator suites passed with the earlier local work (68 tests) and in an isolated copy of this change (62 tests). After the pause-label and largest-text refinements, all 7 targeted presentation/Dynamic Type/VoiceOver tests passed both in the working tree and in the final isolated commit, including switch-controlled Resume. Reviewed composite home, HUD, and pause captures. Optimized unsigned iOS Release build passed in the isolated copy. Physical assistive-device validation remains outstanding.
- Final isolated test result: `/tmp/helichopter-ui-commit-final.xcresult`; release log: `/tmp/helichopter-ui-release.log`. Earlier local onboarding/readiness edits remain uncommitted and intact.

### 2026-10-01 — Codebase review, presentation fixes, and release plan (Claude Code)
- Reviewed the codebase, docs, uncommitted Codex work, and GitHub sync. Baseline: 69 tests passed on iPhone 17 (iOS 27 simulator).
- **Fixed duplicate screens and double Pause button.** Root cause: the archived SpriteKit menus/HUD were hidden only by the UIKit overlay's 50 ms timer, and `applyUITheme` re-showed them on every scene load, pause, and round-over. Title/Game scenes, pause/round-over overlays, and Settings now hide archived content at load (`sceneDidLoad`) and after theming. The title-scene SpriteKit mascot is created hidden; UIKit draws the visible one.
- **Fixed menus at top of screen.** Menu stacks centre vertically and scroll from the top when content is too tall. The HUD stays top-pinned. Stack constraints are now tracked and replaced on each rebuild; previously they accumulated.
- **Fixed potential crash:** a tap on a menu that had just closed could reach `fatalError` in `ButtonNode.responder`. The responder is optional and the overlay refreshes immediately after each tap.
- Updated `titleReplacesLegacyFourFrameAnimationOnPhoneAndPad` to the UIKit-mascot contract. Added `archivedScenesNeverRenderBeforeUIKitRefresh` and `menusAreCentredAndHUDStaysAtTop`. **71 tests pass.** Simulator screenshot confirms a single, centred home menu.
- Added `Tools/release_check.sh` (privacy manifest, required-reason APIs, export compliance, ATS, permissions, SDKs, test leftovers, icon alpha, versioning, distribution signing). Unsigned Release build: no blocking failures. Remaining warnings: privacy link/URL and signing.
- Rewrote Phase 8 as the prioritized **Release Plan**, including Apple's privacy/security/account requirements. Added `CLAUDE.md` for future sessions.
- Not done: nothing committed or pushed (awaiting owner); no physical-device verification of the transition fixes.

### 2026-10-01 — Privacy pages, in-app links, and music replacement
- Removed dead pre-iOS 17 availability checks after the owner confirmed iOS 17.6. Committed and pushed earlier work (`6c6faee`, `3e17394`).
- Audio provenance: the original effects' WAVs carry GarageBand tags (owner-made). The music source was unknown, so it was replaced with a CC0 Freesound track by SouljaUnit/Louswan (both licences checked). It was encoded from the public HQ preview to 128 kbps AAC at matched loudness, keeping the same `MainTheme.caf` name.
- Added `docs/` (index, privacy, support) for GitHub Pages with `helichopter.support@gmail.com`. `Release/PRIVACY_AND_SUPPORT.md` now points there instead of duplicating it.
- Added Settings → About (Privacy Policy with summary and Safari link; Acknowledgements with the BSD notice and music credits). Both stay available when Settings is locked. URLs and text live in `AppLinks` (`SettingsScene.swift`).
- Tests: added `privacyAndAcknowledgementsReachableBySwitchWhenLocked`. Updated the locked-Settings item count to 4. Widened the hold-to-pause timing margin, which failed once under full parallel load and passed when re-run alone. **72 tests pass.**
- Owner next: enable GitHub Pages; App Store Connect setup; device testing.
