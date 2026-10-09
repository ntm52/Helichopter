# Helichopter — Roadmap after 2.0

Written 2026-10-08, after version 2.0 went live. Work top to bottom unless the owner reprioritises. Tick items off and note them in [Audit/PROGRESS_LOG.md](../Audit/PROGRESS_LOG.md). **Owner** marks tasks that need Nathan's account, device, or decision.

---

## Now — wrap up the 2.0 release (small)

- [x] Commit the build-number change in `project.pbxproj` (`CURRENT_PROJECT_VERSION` 1 → 2, the uploaded build) and tag the release `2.0` in git. Done 2026-10-08 (commit `1edfa21`, tag `2.0`).
- [x] **Owner:** Publish the Accessibility Nutrition Label drafts in App Store Connect now that 2.0 is live (Larger Text, Dark Interface, Sufficient Contrast, Reduced Motion, Differentiate Without Color Alone). Published 2026-10-08.
- [ ] **Owner:** Check Xcode → Window → Organizer → Crashes, Hangs, and Feedback weekly for the first month (until about 2026-11-08). Ongoing; does not block step 1. This needs no SDK and does not change the privacy answers.

## 1. Remove the "double page" effect — [Plan 01](01_SINGLE_LAYER_UI.md)

Version numbering: bug fixes with no new features ship as `2.0.x`; anything that changes screens or adds features ships as `2.x`. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` at the start of the release's work so test builds are never confused with the live 2.0 (2).

- [x] **Stage A (quick fix):** route every screen change through one helper that animates SpriteKit and UIKit together as a single snapshot. Done 2026-10-08 (`0bb33a1`). **Not released as 2.0.1** (owner decision: no partial hotfix); it ships inside 2.1.
- [ ] **Stage B (proper fix, several sessions) → release 2.1, build 3 (version already set):** start at "Start here" in Plan 01 Stage B. Release only after steps 1–5 are all done. Steps 1 (event-driven HUD), 2 (Pause and Round Over in UIKit), 3 (Home and guide in UIKit; 50 ms timer deleted), 4 (Settings in UIKit; `SettingsScene.swift` split), and 5 (clean-up; HUD built in Swift; `RootViewController`) done 2026-10-08. **Next: Owner** device screen recordings (Plan 01 "Manual checks"), then submit 2.1. Step 6 (narrow iPad windows get the larger phone layout) also done 2026-10-08. Make Home, Guide, Settings, Pause, and Round Over plain UIKit screens; SpriteKit only for gameplay and the backdrop. Deletes the hidden `.sks` menus, the 50 ms timer, the legacy toggle classes, and the iPad archive copies. Splits the 1,160-line `SettingsScene.swift`.

## 2. Device accessibility testing (can run alongside step 1)

These were never done on hardware and they gate two more Accessibility Nutrition Labels.

- [ ] **Owner:** VoiceOver with Screen Curtain: full session from launch to Round Over. If it passes, add the VoiceOver label.
- [ ] **Owner:** Voice Control: every button reachable by name or number. If it passes, add the Voice Control label.
- [ ] **Owner:** iOS Switch Control item scanning; a keyboard-emulating switch; an adaptive game controller.
- [ ] **Owner:** Reduce Motion, largest text size, iPad in a resized window, and the oldest iOS 17.6 device available (performance and frame rate).
- [ ] Run Xcode's Accessibility Inspector audit on every screen and fix what it reports.
- [ ] **Owner:** TestFlight or in-person sessions with real players (occupational or speech therapists, a school, or an assistive-technology lab).

Do a second pass of this list after Plan 01 Stage B, since every menu will have been rebuilt.

## 3. Cosmetic skins, Hangar screen, and in-app purchases — [Plan 02](02_COSMETICS_AND_STORE.md)

- [ ] **Phase 1:** skin system, Hangar screen, free skins only. No purchases yet.
- [ ] **Phase 2:** StoreKit 2 one-time purchases, Restore, Ask to Buy, refunds. Includes App Store Connect business setup, EU trader status, and privacy text updates.
- [ ] **Phase 3 (optional):** more skin sets; patterned pipes that also serve players who cannot rely on colour.

## 4. Further improvements (suggested; pick by audience need)

Ordered by value to players, highest first.

1. **Continuous audio guidance for blind players.** Today VoiceOver speaks gap guidance at most every 2 seconds. Add optional non-speech cues: a tone whose pitch follows the helicopter's height relative to the next gap, and a soft tick as a pipe approaches. Give it its own volume and an on/off switch. This is the biggest remaining step toward sound-only play. Write a dedicated plan first.
2. **Differentiate without colour.** Pattern fills on pipes (stripes or dots) when iOS "Differentiate Without Color" is on. Can share art work with pipe skins in Plan 02.
3. **Player profiles.** Shared iPads in schools and therapy rooms need per-player settings and scores. `GameSettings` already uses injectable storage; this needs a profile picker on Home and a profile key prefix. Profiles must be switch-accessible and lockable by the caregiver lock.
4. **More sound cues.** Gap cleared, near miss, and pipe approaching, each with its own toggle. Respect Calm Mode.
5. **Localisation.** Move UI strings into a String Catalog (`Localizable.xcstrings`). Start with Spanish. Listing copy and screenshots need translation too. Easier after Plan 01, when strings live in Swift instead of `.sks` files.
6. **A gentle "Rate Helichopter" link** in Settings → About, opening the App Store review page. No automatic review pop-ups, which interrupt switch and VoiceOver users.
7. **Optional Game Center** personal-best leaderboards. Keep scores optional and hidden when Show Score is off. Only if players ask for it; it adds sign-in prompts.

## 5. Engineering clean-up

- [ ] Fix the full test suite hanging with parallel simulator clones, then remove the `-parallel-testing-enabled NO` advice from `CLAUDE.md`.
- [ ] Review timing-sensitive tests (hold-to-pause, scanner dwell) so they cannot fail under load.
- [x] Remove `fatalError` from `ToggleButtonNode`/`TriggleButtonNode` responders, unless Plan 01 Stage B deletes them first. (Both classes deleted in Stage B step 4, 2026-10-08.)
- [ ] Rename the `Nodes/Game Componens/` folder to `Game Components` (update the Xcode project group at the same time).
- [ ] Remove the inherited particle sprites in `Assets/Particles/` if unused (see `Release/ASSET_RIGHTS.md`).
- [ ] **Owner (optional):** download the lossless music original from Freesound to replace the preview-quality encode.
