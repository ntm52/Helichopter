# Helichopter — Progress Log

One entry per working session, newest at the bottom. Append a short entry before ending a session: the date, what changed, the test count, and what is still open. The current plan is in [HELICHOPTER_PROJECT.md](../HELICHOPTER_PROJECT.md).

## Phase history (2026-08 to 2026-10, before 2.0 shipped)

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
| 7 — Testing | Partly done | Automated suite done; device matrix moved to the roadmap |
| 8 — App Store | ✅ Done | Version 2.0 released (October 2026) |

## Phase 7 testing checklist (as it stood at release; open items now live in the roadmap)

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

## Entries

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

### 2026-09-07 — Gameplay contrast boundaries
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

### 2026-10-01 — Scheme rename, flight hint, new high score, window sizes
- Renamed the scheme to `Helichopter` and removed its stale `flappy-fly-birdTests` reference.
- Replaced "CLICK ME TO FLY" with scheme- and VoiceOver-aware hint text, refreshed each run.
- Added the "New high score!" banner and VoiceOver announcement. Best scores now save as soon as they are beaten (previously lost in No-Fail runs that ended via Home).
- Made scene scaling window-shape aware for iPadOS resizable windows; added `WindowSizeTests`.
- Each item was committed and pushed separately. **78 tests pass.**

### 2026-10-07 — Store screenshots, accessibility label checks, release bug fixes (Claude Code)
- **Fixed Auto Hover** (owner-confirmed broken): each nudge applied a quarter flap impulse with no speed cap, reaching ~56,000 pt/s in a 1,434-unit scene, so the helicopter slammed into the floor. A nudge now sets ±`terminalVelocity` (≈100 units of travel at Standard), and damping settles it. Test: `autoHoverNudgesAreBoundedAndGravityStaysOff`.
- **Fixed missing iPad title:** `TitleScene iPad.sks` nests the "Helichopter" label inside the Play button, so the UIKit overlay skipped it as button text. `TitleScene.sceneDidLoad` now moves it to the scene. Test: `titleTextShowsOnPhoneAndPad` (fails without the fix).
- **Fixed bare band in the scrolling background:** the scroller used exactly 2 tiles (768 units wide on iPad), leaving a flat navy band over up to a quarter of the screen as it scrolled. iPhone was affected at the edges too. The tile count now covers the scene width. Test: `scrollingBackgroundCoversPhoneAndPadScenes` (failed on both devices without the fix).
- **Fixed Parchment contrast:** preset buttons measured 1.7–2.0:1 (white text on a pale tint), and detail and segment text 3.4–3.5:1. They now use the theme text colour and 75% opacity (≥4.9:1). Test: `settingsTextMeetsAAInEveryTheme` checks every Settings label and segment in all themes against the colours actually behind it.
- HUD "Best" label is now centred like the score.
- **Accessibility checks (simulator):** Larger Text at AX5. Home, guide, Settings, and HUD all scale; segmented rows scroll sideways, and switch users get a choice list. Reduce Motion: the home rotor and starfield go fully static (47 vs 15,172 pixels changed per second), and pipes still move. Contrast: all themes ≥4.5:1 after the fix. VoiceOver/Voice Control still need a physical device.
- Screenshots in `Release/Screenshots/` (6 iPhone, 5 iPad). Gameplay shots used Auto Hover with No-Fail on. **82 tests pass** (`-parallel-testing-enabled NO`; a parallel-clone run hung once).
- App Store Connect: screenshots uploaded (6.3" required, 6.9", iPad 13"); old v1.3 shots removed from 2.0; accessibility labels saved as drafts, not published.
- Still open: publish the accessibility drafts after 2.0 releases; on-device VoiceOver test; distribution archive **including these fixes**.


### 2026-10-08 — Post-launch documentation clean-up and roadmap (Claude Code)
- Version 2.0 is live on the App Store (owner confirmed).
- Rewrote `HELICHOPTER_PROJECT.md` for the post-launch state: fixed architecture paths (`Nodes/Game Componens/`), added a document map, known issues, and a reusable release checklist. Moved this log and the phase history here from that file, unchanged apart from the phase table.
- Rewrote `CLAUDE.md`. Marked the two `Audit/` reviews as historical. Updated stale status lines in `README.md` and `Release/APP_STORE_COPY.md`.
- Added `Plans/ROADMAP.md`, `Plans/01_SINGLE_LAYER_UI.md` (the "double page" effect: SpriteKit transitions animate scenes while UIKit menus swap instantly), and `Plans/02_COSMETICS_AND_STORE.md` (skins, Hangar screen, StoreKit 2).
- No code changed; tests not re-run (82 at last run). The `project.pbxproj` build-number change (1 → 2) is still uncommitted.

### 2026-10-08 — Roadmap step 0: 2.0 release wrap-up (Claude Code)
- Committed the build-number change (`CURRENT_PROJECT_VERSION` 1 → 2) as `1edfa21` and tagged it `2.0` (lightweight, like the `1.4.x` tags). Not pushed yet.
- Owner published the Accessibility Nutrition Labels in App Store Connect: Larger Text, Dark Interface, Sufficient Contrast, Reduced Motion, Differentiate Without Color Alone. VoiceOver and Voice Control still wait on device testing (roadmap step 2).
- Updated `Plans/ROADMAP.md`, `HELICHOPTER_PROJECT.md`, and `Release/APP_STORE_COPY.md` to match. Committed the post-launch document rewrite and `Plans/` from the previous entry.
- Still open from step 0: weekly Organizer crash/hang check until about 2026-11-08. Next: Plan 01 Stage A.
- Owner confirmed 2.0 (build 2) is the official release. Pushed `master` and tag `2.0`. Decided: Plan 01 Stage A ships as 2.0.1 (build 3); Stage B ships as 2.1.
