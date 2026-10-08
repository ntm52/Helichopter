# Plan 01 — One drawing layer per screen (remove the "double page" effect)

**Status:** Stage A code merged on `master` 2026-10-08 but **will not ship on its own** (owner decision: no 2.0.1 hotfix). Stage B is next and ships as **2.1** only when complete. Written 2026-10-08.
**Goal:** Every screen change looks like one page replacing another. No screen ever shows two menus, two backgrounds, or a menu sitting still while the page behind it slides.
**Order:** Do this before the cosmetics store ([Plan 02](02_COSMETICS_AND_STORE.md)), so the Hangar/Store screen is built on the new pattern instead of adding another screen with the same problem.

---

## 1. What the player sees

When moving between Home and Settings (and, to a lesser degree, Home → Play and Settings → Home), two pages are visible at once for about a second. One page appears instantly while another slides or fades underneath it.

## 2. Why it happens

Each screen is drawn by two separate systems that are not synchronised.

| Layer | What it draws | How it changes screens |
|---|---|---|
| SpriteKit (`SKView`) | Scene background, starfield, gameplay | `SKTransition.push` (1.0 s) or `.fade` (0.4–1.0 s) in `RoutingUtilityScene.buttonTriggered` and `SettingsScene.navigateBack` |
| UIKit (`SceneTextOverlay`, `SettingsOverlayView`) | Every visible menu, button, label, and the Settings panel | Swaps instantly when `SKView.scene` changes, which happens at the **start** of a SpriteKit transition |

So, for example:

- **Home → Settings:** `SettingsScene.didMove` adds the UIKit Settings panel at once, while the SpriteKit layer is still pushing the Home background downward behind it.
- **Settings → Home:** the panel fades out in 0.15 s, then a 1-second SpriteKit fade starts. The UIKit Home menu appears immediately on top of a background that is still fading from the Settings colour.
- **Home → Play:** the HUD appears at once over a 1-second fade from the title scene.

The 50 ms polling timer in `GameViewController` adds jitter: the UIKit layer can be up to one tick behind SpriteKit.

This is the same root cause as the earlier "two versions of a screen" and "two Pause buttons" bugs (fixed 2026-10-01 by hiding archived nodes). The `.sks` menus still exist as invisible models, so any new code path that forgets `suppressArchivedPresentation()` can bring those bugs back.

**Step 0 of the work is to confirm this on a device:** record the screen (Control Centre → Screen Recording) during Home → Settings → Home → Play → Pause → Home on an iPhone and an iPad, and step through the frames. Save the findings in the progress log.

---

## 3. The fix, in two stages

### Stage A — Quick fix: move both layers together (done; not released separately)

> **Done 2026-10-08 (commit `0bb33a1`). Not shipping as 2.0.1:** the owner accepted the double page in 2.0 and does not want a partial fix released. The code stays as the transition foundation for Stage B, and Stage B's 2.1 release includes it. Built: `GameViewController.present(_:transition:)`, `ScreenTransition`, `ScreenChangeAnnouncer`, and `FocusScanner.suspend()/resume()`. Snapshot check: `snapshotView(afterScreenUpdates: false)` included the Metal layer on the iPhone 17 simulator (8-second probe fade showed starfield and menu together), so it is used. The fallback `GameViewController.compositeSnapshot(of:)` is built and tested; it is used when the system snapshot returns nil, and should replace it outright if a device recording shows a blank or black first frame. Tests: `ScreenTransitionTests`. The device recording moves to Stage B's manual testing.

Replace the SpriteKit transitions with one UIKit transition of the whole screen.

1. Add a single helper on `GameViewController`, for example `present(_ scene: SKScene, style: ScreenTransition)`, and route **every** scene change through it (`RoutingUtilityScene.buttonTriggered`, `SettingsScene.navigateBack`, `GameScene` Home). No other code calls `presentScene`.
2. The helper:
   - takes a snapshot image of the current screen (SpriteKit and UIKit together) and places it on top;
   - disables input and stops all scanners for the duration;
   - presents the new scene **without** an `SKTransition`, then refreshes the UIKit overlay synchronously (no waiting for the timer);
   - animates the snapshot away (cross-fade, or a slide if you want to keep the push feel), then removes it and re-enables input;
   - posts `UIAccessibility.screenChanged` once, after the animation.
3. Transition style: cross-fade of about 0.3 s by default. With Reduce Motion or Prefer Cross-Fade Transitions, use a short cross-fade with no movement. Remove the `lastPushTransitionDirection` logic.
4. **Risk to check first:** snapshots of Metal-backed `SKView`s can come out blank with `snapshotView(afterScreenUpdates:)`. If so, build the image from `SKView.texture(from: scene)` plus `drawHierarchy(in:afterScreenUpdates:)` of the UIKit overlay. Test on a real device, not only the simulator.
5. Tests:
   - A test that fails if any code other than the helper calls `presentScene` (scan the source, or inject a spy `SKView`).
   - A test that, immediately after each navigation, exactly one menu is visible and the overlay's host scene equals `SKView.scene` (no stale tick).
   - Input during the transition is ignored (guards the old double-tap crash class).
   - Reduce Motion selects the no-movement style.

Stage A removes the visible problem with little risk. It does not remove the hidden `.sks` menus or the timer, so the bug class remains for future screens.

### Stage B — The real fix: UIKit menus, SpriteKit only for gameplay (several sessions)

**Release:** 2.1, build 3 (`MARKETING_VERSION` already set to 2.1). Ship only when steps 1–5 are all done and the manual recordings pass. Raise the build number only if a build is uploaded and rejected or replaced.

#### Start here (state on 2026-10-08)

What Stage A left in place, to reuse rather than rebuild:

- **`GameViewController.present(_:transition:)`** is the single screen-change path. It snapshots the whole screen, swaps, refreshes the UIKit overlay at once, holds input, cross-fades (`ScreenTransition.preferred()`: 0.3 s, 0.2 s with Reduce Motion), and then releases. As screens become view controllers, keep one equivalent entry point on the new `RootViewController` (child view-controller swap under the same snapshot cross-fade), so there is still exactly one way to change screens.
- **`ScreenChangeAnnouncer`** carries every `screenChanged` post and sends one per transition. New UIKit screens must post through it.
- **`FocusScanner.suspend()/resume()`** and the `ScreenTransitionScanning` protocol freeze the incoming screen's scanner during the fade. New view controllers that own a scanner should adopt the protocol.
- **Input gate:** `GameViewController.acceptsInput(in:)` is checked in `ButtonNode.buttonTriggered`, key and controller forwarding, and `ButtonAccessibilityElement`. UIKit buttons on new screens are already blocked because the root view has interaction disabled during the fade.
- **Tests to keep green or port:** `ScreenTransitionTests` (5 tests). It loads the real storyboard controller into a `UIWindow` and waits 150 ms for a first draw, because `snapshotView` returns nil before that. The source-scan test expects `presentScene` only in `GameViewController.swift` (2 calls); update the expected list when the root controller changes. 87 tests pass at the start of Stage B.

Step 1 (event-driven HUD) touch points: `GameSceneAdapter.score` and `scoreLabel` (`Adapters/GameSceneAdapter.swift`), `isShowingNewHighScore`, the flight hint set and faded in `PlayingState`, Round Over text in `GameOverState`, and `SceneTextOverlay.refresh(in:)`, which polls all of these. The 50 ms timer and `refreshSceneText()` live in `GameViewController`. After step 1, nothing on the HUD may depend on the timer; it can only be deleted once Home, Guide, and Settings no longer use `SceneTextOverlay` (step 3–4), so delete it no later than step 5.

Manual checks before 2.1 is submitted (owner, on an iPhone and an iPad): screen-record Home → Settings → Home → Play → Pause → Home and step through the frames. Expect one fade per change, no black or empty first frame, and never two menus. Repeat with Reduce Motion on, with VoiceOver (each screen spoken once), and with switch scanning (scanning resumes on the new screen after the fade). If a fade starts on a black or empty frame, make `makeTransitionSnapshot` use `compositeSnapshot` only.

Make each menu screen a plain UIKit view controller. SpriteKit is used only for gameplay and, optionally, an animated backdrop.

**Target structure**

```
RootViewController (owns navigation and transitions)
├── BackdropView          one shared SKView with a light "sky" scene (or a static image under Reduce Motion)
├── HomeViewController    title, mascot, Play / Settings / How to Play / Hangar
├── GuideViewController   first-run guide (moved out of SceneTextOverlay)
├── SettingsViewController hosts the existing SettingsOverlayView, nearly unchanged
├── HangarViewController  added by Plan 02
└── GameViewController    SKView with GameScene + UIKit HUD, Pause, and Round Over views
```

**Rules for the new structure**

- Menu buttons are defined in Swift (a `MenuAction` enum), not read from archives.
- UIKit buttons join the scanner through the existing `FocusScannable` protocol, as Settings already does.
- `GameScene` reports changes to its owner through a small delegate (`scoreDidChange`, `bestScoreDidChange`, `stateDidChange(playing/paused/roundOver)`, `flightHintDidChange`, `newHighScore`). The HUD updates only on those calls. **The 50 ms timer is deleted.**
- Screen transitions are UIKit view-controller transitions: the whole screen moves as one unit.
- One place builds themed colours and fonts for UIKit (a small `Theme` helper reused by every screen), replacing `SKNode+Theme`.

**Migration steps (each step keeps the app working and the tests green; commit after each)**

1. **Event-driven HUD.** Add the `GameScene` delegate and make the HUD use it. Keep the timer temporarily, then delete it once tests show nothing depends on it.
2. **Pause and Round Over in UIKit.** Build both menus in Swift (Resume, Retry, Home; "Round Over" / "Well Done!" text, scores). Delete `SceneOverlay`, `PauseScene*.sks`, and `FailedScene*.sks`. Keep the existing pause background options (dim or solid) and hold-to-pause behaviour.
3. **Home screen.** Create `HomeViewController` with the mascot (already a `UIImageView`) and the backdrop. Move the first-run guide into `GuideViewController`. Delete `TitleScene`, `TitleScene*.sks`, and the hidden placeholder mascot.
4. **Settings.** Move `SettingsOverlayView` into `SettingsViewController`. Delete `SettingsScene`, `SettingsScene*.sks`, `ToggleButtonNode`, and `TriggleButtonNode`. While here, split `SettingsScene.swift` (about 1,160 lines) into the panel, rows, adjustment panel, and `AppLinks`.
5. **Clean-up.** Delete `RoutingUtilityScene`, `ButtonAccessibilityElement`, `suppressArchivedPresentation()`, `SKNode+Theme`, unused `ButtonNode` code, and the iPad `.sks` copies that are no longer needed. `GameScene.sks` stays for gameplay nodes. Update `CLAUDE.md`, `HELICHOPTER_PROJECT.md`, and the README.
6. **Narrow iPad windows** (optional): with menus in UIKit, layout adapts naturally. Revisit the gameplay scale mode so narrow windows get a larger game instead of wide bars.

**Things that must not change**

- Saved keys in `UserDefaults` (`gs_*`, best score, `onboarding_completed_v1`). Players keep their settings and scores.
- Scanner behaviour: timed and two-switch modes, focus order, hold-to-pause, release-before-select, focus restoration after rebuilds.
- VoiceOver: labels, hints, flight element, `screenChanged` on every screen, modal Settings.
- Dynamic Type at every size, Reduce Motion, Calm Mode, the caregiver lock.

**Testing**

- Rewrite `PresentationTests` and the archive-loading parts of `GameLifecycleTests`, `WindowSizeTests`, `DynamicTypeTests`, and `OnboardingTests` to load view controllers instead of `.sks` files. Expect this to be the largest part of the work: about 40 test references to archives exist today.
- New tests: one visible menu per screen; no `presentScene` outside gameplay; HUD updates without any timer; the scanner reaches every control on every screen; the locked-Settings item list is unchanged.
- Manual: screen-record every transition on iPhone and iPad (portrait, landscape, resized window) with Reduce Motion on and off, with VoiceOver, and with a keyboard switch.

---

## 4. Risks

| Risk | Mitigation |
|---|---|
| Test suite is tightly coupled to archives | Migrate one screen per step and rewrite its tests in the same commit. |
| Switch or VoiceOver regressions | Keep `FocusScanner` unchanged; reuse the Settings scanning pattern that is already tested. Manual switch session after each step. |
| Snapshot blank on Metal (Stage A) | Use `SKView.texture(from:)` fallback; verify on a device. |
| Players lose settings | Do not rename any key; add a test that loads a saved 2.0 settings set. |
| Large change, long branch | Do Stage B steps as separate commits on `master`, each keeping the app working and tests green. Release 2.1 only after all of steps 1–5 (owner decision 2026-10-08: no partial releases). |

## 5. Done when

- [ ] Device screen recordings show one page at a time for every transition.
- [ ] No `.sks` menu archives, `SceneOverlay`, `RoutingUtilityScene`, or 50 ms timer remain.
- [ ] All tests pass; new presentation tests cover each screen.
- [ ] Docs updated, and the "UIKit draws everything visible" trap removed from `CLAUDE.md` because it no longer applies.
