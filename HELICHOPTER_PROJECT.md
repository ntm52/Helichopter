# Helichopter — Accessibility & Modernization Project

**Status:** Phase 0 complete. Phase 1 is next.
**Last updated:** 2026-08-30 — initial audit and plan, written from Windows (read-only).

> **Start a new session with:** *"Read HELICHOPTER_PROJECT.md, check the Progress Log, and
> continue from where it left off."*

---

## ⚠️ How to use this document

**This document is the single source of truth for this project across sessions.** No session
has enough context window to hold this whole project, so it will take many sessions to finish.
That only works if this file stays current.

**Rules for every session working on this project:**

1. **Read this entire file first**, before touching any code. Start with the Progress Log at
   the bottom — it tells you what's actually done versus what's just planned.
2. **Update the Progress Log before the session ends.** Append an entry with the date, what
   phase you worked on, what you completed, what you deliberately deferred, and anything you
   learned that contradicts this plan.
3. **If you learn something that invalidates part of this plan, edit the plan.** The audit
   below was done statically from Windows without ever compiling the project. Some of it will
   turn out to be wrong once there's a working Xcode build. When that happens, correct the
   finding in place and note the correction in the Progress Log — don't leave a known-wrong
   finding sitting in the audit for the next session to trip over.
4. **Check off the exit criteria** as they're met. A phase is done when its exit criteria are
   met and verified on hardware, not when the code is written.
5. **Never mark a phase complete that hasn't been verified on a physical device.** Simulator
   verification does not count for anything in Phases 3, 4, or 7 — assistive technology
   behaves differently on real hardware.

If this file and the code ever disagree, the code is right and this file needs fixing.

---

## Context

Helichopter is a Flappy Bird–style iOS game, built ~2021, designed from the start to be
playable by people across a wide range of disabilities. The intent was: the game slows down
for cognitive load, pipe gaps widen, colors are bright and easy to identify, the helicopter
animates so it's easy to track visually, and the whole app is switch accessible.

**The intent is sound. The implementation is roughly 30% of the way there, and parts of it
work backwards from what was intended.** The app has not been touched since 2021 (last commit
Jan 2021, Xcode 12 era), it cannot be submitted to the App Store in its current form, and the
Xcode project file is currently corrupted on disk.

This project brings the app to current iOS standards, finishes the accessibility work that
was started, replaces the art, and ships it to the App Store.

**Decisions already made:**

| Question | Answer |
|---|---|
| Build environment | Mac with Xcode — stays a native Swift/SpriteKit app |
| Distribution | App Store release |
| Graphics | Full art refresh (new direction, new palette, redrawn) |
| Accessibility scope | All four areas: switch access, granular difficulty, vision & motion, cognitive & sensory |

---

## Current state — audit findings

Everything below was verified by reading the code, the asset binaries, and the git objects on
2026-08-30. **It was not verified by compiling** — no Mac was available. Treat the Blocking
findings as high-confidence (they're plain readings of source and binary data) and re-verify
anything behavioral once there's a build.

### Blocking / correctness

| # | Finding | Evidence |
|---|---|---|
| B1 | **`Helichopter.xcodeproj` is a 0-byte file on disk.** iCloud Drive on Windows collapsed the bundle. The real `project.pbxproj` survives in the git index (blob `e968de6`) and is recoverable. | `ls -la` at repo root; `git ls-files --stage` |
| B2 | **The pipe-gap accessibility toggle is inverted.** `pipeDistance == true` (which is the *registered default*) produces a gap of 240–380pt; `false` produces 300–700pt. The setting labeled to make the game easier makes it harder, and it ships on by default. | `PipeFactory.swift:97-103`, `UserDefaults.swift:65` |
| B3 | **`UIRequiredDeviceCapabilities` is `armv7`** — 32-bit, unsupported. This alone fails App Store validation. | `Info.plist` |
| B4 | **`UIAppFonts` declares `Inter-Black.otf`, which is not in the project.** No `.otf`/`.ttf` file exists anywhere in the tree or the pbxproj. Text silently falls back. | `Info.plist`; `find` + pbxproj grep |
| B5 | Difficulty is dispatched by **exact `Double` equality on floating-point literals** (`case 5.5:`, `case 3.5:`, `case 2.5:`). Fragile; a stored value that round-trips imprecisely silently falls to `default`. | `PipeFactory.swift:35-44` |
| B6 | `SKAction.play()` is called and **discarded** in two places — it constructs an action and throws it away. Music resume is a no-op. | `PlayingState.swift`, `GameOverState.swift` |
| B7 | Pipe height is drawn from a **hardcoded 70–850pt range** with no reference to scene height. On short or unusual viewports, `topHeight = sceneHeight - bottomHeight - gapHeight` can go **negative**. | `PipeFactory.swift:12-14, 117` |
| B8 | `focusRing` is a **force-unwrapped** `childNode(withName:)!` in `ButtonNode.init(coder:)`. Any button in an `.sks` without a `focusRing` child crashes at scene load. Several `fatalError` calls sit on the same path. | `ButtonNode.swift:126`; `ToggleButtonNode.swift`, `TriggleButtonNode.swift` |
| B9 | `CharactersScene.swift` is on disk but **not in the build target, and would not compile** — references `NyancatNode`, `PlayableCharacter.bird/.gamecat/.jazzCat`, `Setting.character`, none of which exist. Dead file. | pbxproj Sources phase; `UserDefaults.swift:76-78` |

### Accessibility — the core gap

| # | Finding |
|---|---|
| A1 | **There is zero accessibility API usage in the entire codebase.** No `isAccessibilityElement`, no `accessibilityLabel`, no `UIAccessibility.is*Enabled` checks, no `GCController`, no `pressesBegan`. Grep returns nothing. |
| A2 | **The switch/focus system is scaffolding only.** `ButtonNode` has `isFocused`, `focusableNeighbors`, `focusRing`, and `performInvalidFocusChangeAnimationForDirection` — all inherited from Apple's DemoBots sample. **Nothing anywhere sets `isFocused` or populates `focusableNeighbors`.** There is no scanner, no timer, no input source. The game is not switch accessible today. |
| A3 | Because SpriteKit nodes are not exposed as accessibility elements, iOS **Switch Control item-scanning cannot reach any button** — it sees the whole `SKView` as one element. Only point-scanning (slow, imprecise) would work. |
| A4 | The only input is `touchesBegan` anywhere on screen → flap. There is no hold-to-hover, no keyboard, no game controller, no adjustable dwell, no scanning. |
| A5 | Difficulty is **3 coupled presets** (easy/medium/hard) that change *both* spawn interval and travel speed together, plus one inverted binary gap toggle. Speed, gap, gravity, and flap strength cannot be tuned independently. |
| A6 | Flap impulse is a hardcoded `dy: 50000`; gravity is a hardcoded `-5.0`. Neither is adjustable. |
| A7 | No practice/no-fail mode. A single pipe contact ends the run immediately and shows a "Failed" scene. |
| A8 | Text is `SKLabelNode` with fixed sizes — **no Dynamic Type support anywhere**. |
| A9 | `UIRequiresFullScreen` + separate `" iPad"` duplicate `.sks` scenes for every screen. This layout approach breaks under iPadOS resizable windows and doubles the maintenance cost of every UI change. |

### Color & motion — measured, not guessed

Dominant colors sampled directly from the PNGs, with WCAG relative luminance:

| Element | Color | Luminance |
|---|---|---|
| Background | `#000000` / `#393B53` | 0.000 / 0.046 |
| Pipes & caps | `#F8FF00` | 0.915 |
| Helicopter | `#37FF00` | 0.723 |
| Button (yellow) | `#F8FF00` | 0.915 |
| Button (green) | `#00FF06` | 0.715 |

- **Helicopter vs. pipe contrast is 1.25:1.** The player and the one thing they must avoid are
  near-identical in luminance, and both are saturated yellow-green — under deuteranopia or
  protanopia they collapse to effectively the same color. *The two most important objects in
  the game are the hardest possible pair to tell apart.* This is the single biggest visual
  defect, and it directly contradicts the "bright colors for easy identification" goal.
  (Contrast against the *background* is excellent — 10.1:1 and 8.1:1. The problem is
  figure-vs-figure, not figure-vs-ground.)
- The two button colors have the **same 1.25:1 problem** and are used to distinguish
  different actions.
- **The rotor "animation" is 2 unique frames alternating at 10 Hz.** `r_player1` and
  `r_player3` are byte-identical, as are `r_player2` and `r_player4` (verified by MD5), so the
  4-frame atlas is really 2 frames looped twice at `timePerFrame: 0.1`. A high-saturation,
  high-luminance sprite strobing at 10 Hz is in the photosensitivity-risk band and reads as
  flicker rather than motion — the opposite of the "easy to track" goal.

### Graphics & audio quality

- **All art is 1x only.** Every `Contents.json` declares 2x and 3x slots and leaves them empty.
- The pipe texture is a **200×20 PNG** tiled into a sprite up to **110×850 points**, rendered
  through `UIGraphicsBeginImageContext` — which is deprecated *and* defaults to scale 1.0, so
  pipes are rasterized at 1x and then displayed on 3x screens. This is the root cause of the
  blurry pipes.
- Buttons are 380×88 at 1x; background is 1920×1080 at 1x scaled up 1.35–1.5×.
- Source art is GIMP `.xcf` at these same small sizes — there is no high-res master to
  re-export from. **New art must be authored, not rescaled.**
- Helicopter frames are named `*-removebg-preview.png` — produced by a background-removal web
  tool, with the edge fringing that implies.
- **`MainTheme.wav` is 25 MB of uncompressed WAV.** Three WAVs total ~26 MB of the bundle.

### Dead weight compiled into the app

All of the following are in the build target and **completely unreferenced** (grep-verified):
`SKSpriteNode+GIF.swift` (132 lines), `SKScene+ShaderTransition.swift` (85),
`SKTexture+Gradient.swift` (44), `SKScene+SpriteUploader.swift` (28),
`Bool+PipeRandom.swift` (9) — plus 4 `.fsh` transition shaders, `SnowParticleEffect.sks`, and
the entire particle sprite atlas (`bokeh`, `spark`). ~300 lines of dead Swift and a pile of
unused assets. `CharactersScene.swift` (105 lines) is dead on disk.

### Language-level staleness

`protocol X: class` (deprecated, → `AnyObject`) in `ButtonNode`, `ToggleButtonNode`,
`TriggleButtonNode`, `Updatable`, `Touchable`. `@UIApplicationMain` (→ `@main`).
`UIGraphicsBeginImageContext` (→ `UIGraphicsImageRenderer`). A stray `print()` in
`SKTextureAtlas+FrameUploader.swift`. `unowned` adapter references in the GK states combined
with `lazy var stateMachine` force-unwrapping `sceneAdapter!` is a lifetime hazard.

---

## Design principles for this rewrite

These are the rules the implementation should be held to, and the thing to re-read when a
tradeoff comes up.

1. **Every difficulty knob is independent and continuous.** No coupled presets. Presets become
   named *starting points* that write to the same independent values, which the user can then
   adjust.
2. **Nothing about the game is unwinnable and nothing punishes.** Failure is a soft reset, not
   a "Failed" screen.
3. **Figure-vs-figure contrast is a hard requirement, not a preference.** Player, obstacle, and
   background must be distinguishable by *luminance and shape*, never by hue alone.
4. **The player never has to read.** Every setting is comprehensible from an icon plus a
   spoken label.
5. **Switch access is a first-class input path, not an overlay.** It gets tested every phase,
   not at the end.
6. **The user's original design intent is preserved.** Bright colors, trackable animated
   helicopter, slow-down for cognitive load, wider gaps — those stay. This project makes them
   *actually work*, it does not replace them.

---

## Phase 0 — Recover the project and get it building

**Goal:** a project that opens in Xcode and runs on a device, unchanged in behavior.
Nothing else can be verified until this is true.

- [ ] Restore the deleted-in-worktree files from the git index:
      `git restore --source=HEAD --staged --worktree .` (or targeted `git checkout-index` for
      the `.xcodeproj` bundle). B1.
- [ ] **Move the repo off iCloud Drive** to a normal local path. iCloud will keep collapsing
      `.xcodeproj` / `.xcassets` / `.spriteatlas` bundles into files. This is non-negotiable for
      a Mac/Windows shared workflow — use the GitHub remote (`ntm52/flappy-fly-bird`) as the
      sync channel instead.
- [ ] Add a proper `.gitignore` (`xcuserdata/`, `.DS_Store`, `*.xcuserstate`, `build/`). The
      repo currently has *four* users' `xcuserdata` and `.DS_Store` files committed.
- [ ] Open in current Xcode, accept the project-format upgrade, resolve the resulting warnings.
- [ ] Confirm it launches and is playable on a simulator and one physical device. **Record a
      baseline video** — this is the reference for "did I break anything" for the rest of the
      project.
- [ ] Rename the repo/remote from `flappy-fly-bird` to `Helichopter`; rewrite `README.md`,
      which is still entirely the upstream project's (badges, gifs, "Flappy Fly-Bird", cat
      characters).

**Exit criteria:** builds, runs, playable, baseline video recorded, committed on a new branch.

---

## Phase 1 — Platform and project modernization

**Goal:** current SDK, current lifecycle, clean build with no warnings. Still no behavior change.

- [ ] Set deployment target (recommend **iOS 17.0**, unless there's a specific older device to
      support — decide against the actual devices these users have; assistive-tech users often
      run older hardware, so confirm this before locking it in).
- [ ] `Info.plist`: `UIRequiredDeviceCapabilities` → `arm64` (B3); remove the `Inter-Black.otf`
      entry or add the actual font file (B4); revisit `UIRequiresFullScreen` and the
      portrait-only lock, which conflicts with the iPad orientation list already in the plist.
- [ ] Migrate `@UIApplicationMain` → `@main`; adopt the **UIScene lifecycle**
      (`AppDelegate.swift`, `GameViewController.swift`). Required for resizable iPad windows and
      increasingly required generally — verify the current requirement at implementation time.
- [ ] **Delete all dead code and assets** listed in the audit. This is the cheapest large win in
      the project and it makes everything after it easier to reason about.
- [ ] `class` → `AnyObject` in all 5 protocols; `UIGraphicsBeginImageContext` →
      `UIGraphicsImageRenderer` in `PipeNode.swift` (this also fixes 1x rasterization); remove
      the stray `print()`.
- [ ] Fix B5 (difficulty `Double` switch), B6 (`SKAction.play()`), B7 (viewport-relative pipe
      heights), B8 (force-unwraps and `fatalError`s on the scene-load path).
- [ ] Replace the two-file `" iPad"` scene duplication (A9) with **one set of scenes laid out
      relative to the safe area**. Do this now, before the art refresh, so new art is only
      integrated once.
- [ ] Enable strict concurrency checking and resolve; adopt Swift 6 language mode if it's not a
      fight.

**Exit criteria:** zero-warning build on current Xcode, behavior identical to the Phase 0 video,
one set of scene files, dead code gone.

---

## Phase 2 — The tuning engine

**Goal:** every gameplay value becomes a named, persisted, independently adjustable parameter.
This phase is the foundation the entire accessibility story sits on.

Introduce a single `GameSettings` model (replacing the scattered `UserDefaults` reads in
`GameSceneAdapter`, `PipeFactory`, and `HelicopterNode`), observable, with sane defaults and
migration from the existing `Setting` keys.

Parameters to expose, each independent:

| Parameter | Currently | Range |
|---|---|---|
| Gap height | binary, **inverted** | continuous, generous → tight |
| Gap horizontal spacing | coupled to difficulty | continuous |
| Scroll speed | coupled to difficulty | continuous, including *very* slow |
| Gravity | hardcoded `-5.0` | continuous |
| Flap strength | hardcoded `50000` | continuous |
| Terminal fall speed | hardcoded `480` | continuous |
| Collision forgiveness | fixed `radius = width/2.5` | shrink the player's physics body relative to its sprite — a "generous hitbox" slider |
| Vertical pipe variance | hardcoded 70–850 | continuous, down to zero (all gaps at the same height) |

Fix B2 here — gap size becomes a real continuous value and the inverted toggle disappears
entirely rather than being patched.

Presets ("Gentle" / "Standard" / "Challenge") become buttons that *write* these values, so any
preset can then be hand-adjusted. Add per-profile save/load, so a therapist or parent can set
up a configuration per player and switch between them.

**Exit criteria:** every value above is live-adjustable and persists; presets write through to
the same model; old `UserDefaults` keys migrate cleanly.

---

## Phase 3 — Switch access, for real

**Goal:** the app is genuinely playable end-to-end by someone using one switch. This is the
phase the whole project exists for.

**Menus — build the scanner the scaffolding was waiting for.** `ButtonNode.isFocused` and
`focusableNeighbors` already exist; write the `FocusScanner` that drives them:

- [ ] Automatic scanning with **adjustable dwell time** (a wide range — 0.5s to 10s; many users
      need far longer than developers assume).
- [ ] Configurable scan order per scene, plus row/column scanning for the settings grid.
- [ ] **Auditory scanning**: speak each item as it's highlighted (`AVSpeechSynthesizer`), so the
      menu is usable without reading. This matters more than almost anything else here.
- [ ] A visible, high-contrast focus indicator that does not rely on color alone — the existing
      `focusRing` plus scale, thickened.
- [ ] One-switch (auto-scan + select) and two-switch (step + select) schemes.

**Input sources — accept switches however they present themselves.** A switch interface reaches
an iPad as one of three things; support all three:

- [ ] **Keyboard emulation** (`pressesBegan`/`pressesEnded`) — Blue2, Jelly Bean via a Bluetooth
      switch interface, and most classroom hardware emulate Space/Enter/1/2/3. *This is the
      single highest-value input to add and it is currently absent.* Make the key bindings
      configurable.
- [ ] **Game controller** (`GCController`) — the Xbox Adaptive Controller and Logitech Adaptive
      Gaming Kit present this way. Map any button to flap; support the d-pad for menu navigation.
- [ ] **Native iOS Switch Control** — expose scene nodes as accessibility elements
      (`isAccessibilityElement`, `accessibilityFrame`, `accessibilityLabel`,
      `accessibilityTraits`) so iOS's own item-scanning can reach the buttons (A3). This is the
      piece that makes the app work with a user's *existing* system-wide setup rather than
      requiring them to learn the app's.

**In-game control schemes** — offer a choice, don't assume flapping:

- [ ] **Tap-to-flap** (current behavior, kept).
- [ ] **Hold-to-hover** — the helicopter climbs while the switch is held and descends when
      released. Dramatically lower motor demand than repeated timed activations, and it's the
      thematically correct control for a helicopter. Recommend this become the *default*.
- [ ] **Auto-hover** — the helicopter holds altitude on its own; the switch only nudges up/down.
- [ ] **Two-switch up/down** — direct altitude control, no physics timing at all.

**Exit criteria:** a full session — launch, change a setting, start a game, play, pause, retry,
quit — completed using only one switch, on hardware, three separate ways (keyboard-emulating
interface, adaptive controller, iOS Switch Control). Video of each.

---

## Phase 4 — Vision, motion, and VoiceOver

- [ ] **VoiceOver** across every scene: labels, hints, traits, and grouping on all buttons, the
      score, and the game-over summary. Announce score changes and state transitions via
      `UIAccessibility.post(notification:)`.
- [ ] **Dynamic Type** on all text. `SKLabelNode` doesn't do this natively — either drive font
      size from `UIFontMetrics` / the current content-size category, or move UI text to a
      `UIKit`/`SwiftUI` overlay above the `SKView`. The overlay route is recommended: it gets
      Dynamic Type, VoiceOver, and Switch Control largely for free, and menus are not the part
      that needs SpriteKit.
- [ ] **Palette system** (feeds directly into Phase 6's art): user-selectable palettes, each
      validated so that player-vs-obstacle, player-vs-background, and obstacle-vs-background all
      clear meaningful luminance-contrast thresholds. Ship at minimum: default, high-contrast,
      deuteranopia-safe, protanopia-safe, tritanopia-safe, and a low-luminance/photophobia-safe
      palette (the current design's 0.915-luminance yellow on black is *painful* for some users
      even though it scores well).
- [ ] **Differentiate without color**: distinct silhouettes and optional pattern fills on pipes,
      so the player/obstacle distinction survives total color loss. Honor
      `UIAccessibility.shouldDifferentiateWithoutColor`.
- [ ] **Honor the system accessibility settings** the app currently ignores entirely:
      `isReduceMotionEnabled` (kill the scrolling parallax and scene-push transitions —
      `RoutingUtilityScene` currently pushes/fades on every navigation),
      `isReduceTransparencyEnabled`, `isBoldTextEnabled`, `isInvertColorsEnabled`,
      `isVideoAutoplayEnabled`, `prefersCrossFadeTransitions`.
- [ ] **Flicker and motion safety**: replace the 10 Hz two-frame strobe with a genuinely smooth
      rotor (Phase 6), cap any flashing well under 3 Hz, and make background scroll speed
      independent of gameplay speed so it can be slowed or stopped without making the game
      easier.
- [ ] **Audio and haptic cues**: distinct sounds for approaching pipe, gap cleared, and
      near-miss; optional continuous sonification where pitch maps to the gap's vertical
      position, which makes the game partially playable by ear. Core Haptics patterns for the
      same events (the app currently uses only the coarse `UIFeedbackGenerator`).
- [ ] **Touch targets**: audit every button against the 44×44pt HIG minimum, with an option to
      scale UI up substantially beyond that.

**Exit criteria:** full VoiceOver pass with the screen curtain on; Accessibility Inspector audit
clean; every palette contrast-validated; Reduce Motion visibly changes behavior.

---

## Phase 5 — Cognitive and sensory design

- [ ] **No-fail / practice mode**: pipes become passable, or the player gets configurable lives,
      or a brief invulnerability window after a hit. Recommend making no-fail the *default first
      experience* with an explicit opt-in to scoring.
- [ ] **Replace the failure screen.** Currently `FailedScene.sks` announces failure and shows two
      scores. Replace with a calm, neutral, one-large-button restart. Score display becomes
      optional — for many players a score is pure discouragement.
- [ ] **Remove all time pressure from the UI.** No countdowns, no auto-advance on any screen
      except the scanner's dwell (which is user-controlled).
- [ ] **Consistent, predictable layout**: the same controls in the same physical positions across
      every scene, so motor patterns transfer.
- [ ] **Picture-based settings**: every setting gets an icon and a live preview. Changing gap
      size should show a gap changing size, not a number changing. This is the part that makes
      the app configurable by the player rather than only by a caregiver.
- [ ] **Calm mode**: gentler audio bed, no sudden loud stingers, no screen shake, muted particles.
- [ ] **A guided first-run** that sets control scheme, switch type, dwell time, and difficulty
      via a few large, spoken, picture-based choices — itself fully switch-navigable.
- [ ] **Session limits / caregiver options** (optional, worth discussing): lock settings behind a
      gesture so a player can't accidentally reconfigure mid-session.

**Exit criteria:** a complete play session with no reading, no failure language, and no
time pressure.

---

## Phase 6 — Art and audio refresh

Full art refresh, authored fresh at high resolution — there is no usable high-res master, so
this is new work, not a re-export.

- [ ] **Author as vector** (SVG/PDF) where possible, exported to `@1x/@2x/@3x`, or use
      `preserves-vector-representation` PDF assets so scaling is lossless. The current
      1x-only-stretched pipeline is the root cause of every blur complaint.
- [ ] **Design the palette first, art second** — build against the Phase 4 palette system so
      swapping to a colorblind-safe or high-contrast palette is a runtime change, not a second
      set of PNGs. The pipe/cap/button art should be authored to be tintable.
- [ ] **Fix the figure-vs-figure contrast defect explicitly.** Player and obstacle must differ
      strongly in *luminance* and *silhouette*, not just hue. This is the acceptance criterion
      for the art, not a nice-to-have.
- [ ] **Redraw the helicopter with 8–12 real frames** of rotor rotation plus body bob, tuned so
      motion reads as smooth rotation rather than flicker. This is what "easy to track" was
      supposed to mean.
- [ ] **9-slice / tiled pipes** so they scale to any height without distortion, replacing the
      `UIGraphicsBeginImageContext` tiling hack.
- [ ] **Background**: a layered design that can be simplified or frozen under Reduce Motion, and
      dimmed under the low-luminance palette. Should never compete visually with the pipes.
- [ ] **New app icon** at all required sizes (the current set is a 2021 export).
- [ ] **Audio**: convert the three WAVs to `.m4a`/`.caf` (**~26 MB → well under 2 MB**), and
      either re-record or license a calmer music bed with independent music / SFX / cue volume
      sliders.

**Exit criteria:** all art crisp on a 3x device; every shipped palette passes contrast
validation for all three pairings; rotor animation reviewed for flicker.

---

## Phase 7 — Testing and validation

- [ ] **Unit tests** for the tuning model, difficulty migration, palette contrast math (a test
      that *fails the build* if any shipped palette drops below threshold on any pairing), and
      the scanner's timing logic.
- [ ] **Snapshot tests** across device sizes, Dynamic Type sizes, and every palette.
- [ ] **Xcode Accessibility Inspector** audit on every scene, zero issues.
- [ ] **Manual assistive-tech matrix**, on hardware, not simulator:
      VoiceOver · Switch Control (item + point scanning) · Voice Control · Full Keyboard Access ·
      AssistiveTouch · Dynamic Type at max · Reduce Motion · Increase Contrast · Color Filters.
- [ ] **Real-user testing.** This is the one that actually matters and the one most likely to get
      skipped. Get the build in front of people with the disabilities it's designed for — via an
      OT/SLP, a school, or an AT lab — before the App Store submission, not after. Budget a full
      round of changes coming out of it.
- [ ] Performance check on the oldest device you intend to support.

---

## Phase 8 — App Store release

- [ ] **Privacy manifest (`PrivacyInfo.xcprivacy`) — required.** The app uses `UserDefaults`,
      which is a required-reason API (category `NSPrivacyAccessedAPICategoryUserDefaults`, reason
      `CA92.1` for app-internal storage). Missing this is a rejection.
- [ ] **Accessibility Nutrition Labels** in App Store Connect — declare VoiceOver, Voice Control,
      Switch Control, larger text, sufficient contrast, reduced motion, captions where
      applicable. For *this* app they're a headline feature, not a checkbox. Verify the current
      requirement and field list at submission time.
- [ ] Bundle ID `com.nathanmayo.helichopter` and team `9HJ5466NL8` are already set — confirm the
      Apple Developer account and certificates are current.
- [ ] Screenshots at current required sizes; App Store description leading with the accessibility
      design; age rating; export compliance.
- [ ] Bump `MARKETING_VERSION` (currently 1.1) and tag the release.
- [ ] Consider **Apple's accessibility editorial channels** and AT communities — this app has a
      genuine story and a real audience that actively looks for titles like it.

---

## Verification

At every phase boundary, on a physical device:

1. `xcodebuild -scheme Helichopter -destination 'generic/platform=iOS' build` — zero warnings.
2. `xcodebuild test` — unit and snapshot suites green.
3. Xcode → Open Developer Tool → **Accessibility Inspector** → audit each scene.
4. **The one-switch run**: launch → change one setting → play a full round → pause → resume →
   quit, using only a single switch. If this can't be done, the phase isn't finished.
5. Compare against the Phase 0 baseline video for unintended regressions.
6. Settings → Accessibility → VoiceOver on, screen curtain on: can a full round be started and
   played by sound alone?

---

## Critical files

| File | Role in this project |
|---|---|
| `Helichopter/Utils/UserDefaults.swift` | Replaced by the Phase 2 `GameSettings` model; owns migration |
| `Helichopter/Factories/PipeFactory.swift` | Gap size (B2), spawn timing, speed, pipe-height math (B7) |
| `Helichopter/Nodes/Playables/HelicopterNode.swift` | Flap strength, gravity response, hitbox forgiveness, control schemes |
| `Helichopter/Adapters/GameSceneAdapter.swift` | Gravity, scoring, audio, collision handling — the game's hub |
| `Helichopter/Nodes/UI Components/ButtonNode.swift` | Existing focus scaffolding — the Phase 3 scanner attaches here |
| `Helichopter/Scenes/RoutingUtilityScene.swift` | Scene transitions — must honor Reduce Motion |
| `Helichopter/Scenes/SettingsScene.swift` | Rebuilt entirely in Phase 5 as the picture-based settings UI |
| `Helichopter/Info.plist` | B3, B4, orientation, scene lifecycle |
| `Helichopter/Assets/Scenes/**/*.sks` | Deduplicated in Phase 1, relaid out in Phase 4/5 |
| `Helichopter/Assets/Assets.xcassets/` | Replaced wholesale in Phase 6 |

Existing utilities worth keeping and reusing rather than rewriting: `PhysicsCategories`
(`Utils/PhysicsCategories.swift`) is a clean `OptionSet` and should stay;
`CGFloat+MathUtils.swift` (`clamp`, `toRadians`, `range`) is fine; `SKTextureAtlas.upload`
(`Extensions/SKTextureAtlas+FrameUploader.swift`) works once the debug `print` is removed;
`Updatable.computeUpdatable` is a sound delta-time helper; the `GameSceneAdapter` /
`GKStateMachine` split is a reasonable architecture and should be repaired rather than replaced.

---

## Sequencing notes

- **Phases 0 and 1 are strictly ordered and gate everything.** Nothing can be verified until
  the project builds.
- **Phase 2 gates Phases 3–5.** The tuning model is the substrate for all the accessibility work.
- **Phase 4's palette system gates Phase 6.** Design the color rules before authoring art
  against them, or the art gets made twice.
- Phase 6 (art) can run in parallel with Phases 3–5 (code) once the palette system exists.
- **Phase 7's real-user testing should start as early as Phase 3 is demonstrable** — don't save
  it for the end. It is the phase most likely to change the plan, so let it change the plan
  while changing the plan is still cheap.

---

## Open questions to settle at kickoff

1. **Minimum iOS version** — decide against the actual devices the intended players use.
   Assistive-tech users frequently run older hardware; iOS 17 may be too aggressive.
2. **iPad orientation** — the plist already permits landscape on iPad while the view controller
   hardcodes portrait. Landscape is arguably better for a side-scroller and for
   mounted/wheelchair setups. Pick one and make the code and plist agree.
3. **Who is doing the art?** Full refresh is real design work. If it's being commissioned, the
   palette system (Phase 4) needs to exist first so the brief can specify it.
4. **Is there an OT/SLP/AT contact** for Phase 7 user testing? Line this up early — it has the
   longest lead time of anything in this plan.

---

## Progress Log

*Append a new entry at the end of every session. Newest at the bottom.*

### 2026-08-30 — Audit and planning (Windows, read-only)

- **Phase:** Pre-Phase 0. No code changed.
- **Done:** Full static audit of the codebase, assets, and git objects. Wrote this document.
  Sampled art colors directly from the PNG binaries and computed WCAG luminance, which is where
  the helicopter-vs-pipe 1.25:1 finding came from. Verified via MD5 that the 4-frame rotor atlas
  is 2 duplicated frames.
- **Decisions:** Stay native Swift/SpriteKit; App Store release; full art refresh; all four
  accessibility areas in scope.
- **Not done / deferred:** Nothing was compiled — no Mac available. Every behavioral claim in
  the audit is inferred from reading source, not from running the app.
- **Notes for the next session:** The repo currently lives in iCloud Drive on Windows, which is
  what corrupted the `.xcodeproj` (B1). Getting it out of iCloud is the first real task, ahead
  of any code change. Do not trust the working tree state — 21 files show as deleted-in-worktree
  but present in the git index; recover from git rather than assuming files are gone.

### 2026-09-01 — Phase 0 complete (Mac, Xcode)

- **Phase:** Phase 0.
- **Done:** Project confirmed building and running on Mac with original gameplay behavior intact
  (B1 resolved — `.xcodeproj` recovered; repo moved off iCloud Drive). `.gitignore` restored
  with correct exclusions (`xcuserdata/`, `*.xcuserstate`, `build/`, `DerivedData/`, `.DS_Store`).
  `README.md` rewritten — old upstream "Flappy Fly-Bird" content replaced with Helichopter
  description and accessibility goals. GitHub remote still points to `ntm52/flappy-fly-bird`
  — rename to `Helichopter` deferred (low priority, does not block Phase 1).
- **Deferred:** Baseline video (user decision to skip). GitHub repo rename.
- **Notes for the next session:** Phase 1 is next. Start with `Info.plist` (B3 arm64, B4 font),
  then dead code deletion, then the five code fixes (B5–B8), then `@UIApplicationMain` → `@main`.
  Do not start Phase 2 until Phase 1 exit criteria (zero-warning build, behavior identical to
  original) are confirmed.
