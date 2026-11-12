# Plan 03 — UI polish: an open, finished-looking app

**Status:** Written 2026-11-11. Stages 0, 1, and 2 done 2026-11-11 (decisions below; tokens in `Scenes/DesignSystem.swift`). Stages 3, 4, 4b, and 5 done 2026-11-12. **Next: Stage 6 (Guide).**
**Goal:** The owner's words: the app "appears very vibe-coded"; the UI should "feel more open and more polished". Every screen should look designed as one product, with room to breathe, a clear order of importance, and no leftover placeholder art.
**Depends on:** nothing. Plan 01 is done (every menu is UIKit), which is what makes this practical.
**Release:** the 2.2 skins are held and ship together with this plan in one release (owner decision 2026-11-11).

## Owner decisions (Stage 0, 2026-11-11)

Chosen from the mock sheet (private artifact: https://claude.ai/artifact/V4UZAyXFZnbXs4R8tUen5r; it shows directions A "Soft cards" and B "Bold arcade").

1. **Direction: B, Bold arcade.** Where this differs from section 3, this wins:
   - Controls and cards have a 3 pt outline in an "ink" colour and a solid 6 pt lower edge in the same ink (no blur), so they look pressable. Radii 18 (controls) and 20 (cards).
   - Weights are heavy: 800 for buttons and row names, 900 for the wordmark, titles, section headings, and Play.
   - The primary button uses a warm second colour, not the theme blue: amber `#FFC83D` with near-black text on Night Sky; the helicopter red `#CC2626` with white text on Parchment. Neon Night's primary was not drawn; choose it in Stage 1 and check contrast.
   - Mock surfaces. Night Sky: page `#0C1021`, card `#1E3A6E`, raised `#27488A`, ink `#050814`, accent text amber. Parchment: page `#F2ECD8`, card white, ink and text `#1A2A57`, accent text `#A81C1C`. Treat these as starting values; the Stage 1 contrast test decides.
   - Section headings and values (slider percentages, the score) use the accent text colour. The wordmark is tilted about 3 degrees with a solid offset shadow.
   - Home: Play is much larger (about 92 pt tall); Hangar, Settings, and How to Play are a row of three tiles with the icon above the label, falling back to one column of full-width buttons at accessibility text sizes. Scan order is unchanged.
   - HUD: Score and Best are chips with a small label above a large number; Pause has an icon. At accessibility sizes Pause sits on its own row above the chips.
   - Round Over: a centred card with the title, the score very large, Best, then Try Again (primary) and Home.
2. **Release order:** hold 2.2 and ship the skins and the polish together.
3. **Settings as category pages (4b):** decide after seeing Stage 4. **Decided 2026-11-12: yes**, with Reset and About staying on the Settings menu. Built the same day; see Stage 4.
4. **App icon:** redraw it from the Classic helicopter.
5. **Icons beside labels:** yes.

---

## 1. What looks unfinished today

Observed 2026-11-11 from the simulator and `Release/Screenshots/`. Each point names the screen so it can be checked off.

**Everywhere**
- One button look for everything: a dark navy slab the full width of the screen. Play, Skip guide, and Pause all carry the same weight, so nothing reads as the main action.
- The plain system font at near-default sizes, with a thin-weight title. No type scale: sizes 12, 13, 15, 16, and others are chosen per label.
- Spacing and corner radii are chosen per view (radii 6, 8, 12; insets 10, 12, 16, 20). Nothing lines up to a shared grid.
- Colours come straight from the theme with no surface levels. Cards in the Hangar and palette swatches are neutral grey (`#1C1C1C`-like) on a navy page, which looks like a different app pasted in.
- No response to touch beyond the system default: no pressed state on custom buttons, no motion apart from the cross-fade.

**Home**
- A small mascot, a thin title, and four identical slabs, bunched in the middle with the lower third empty.
- Launch → Home: the helicopter jumps in size and position when Home fades in.

**Settings**
- Rows run edge to edge with hairlines, so the page reads as one dense table. Section headings are tiny capitals.
- Too many words on screen. Several rows carry four to six lines of small grey text (Pause by Holding Switch, VoiceOver Direct Touch).
- One list of about 25 controls. It is long to scroll and, for a switch user, long to scan.
- Three unrelated control looks in one screen: red, green, and blue outlined preset buttons; a home-made segmented control; and bare blue text used as buttons ("Reset Settings", "Menu Theme: Night Sky. Change it in the Hangar", which also runs to both screen edges).
- "◀ Back" floats centred above the title rather than sitting in a header.

**Hangar**
- Grey cards on navy, small pictures in large cards, and half the screen empty.

**Play (HUD, Pause, Round Over)**
- "Score 1." and "Best 18" sit in cramped boxes jammed against a very wide Pause slab. The full stop after the score shows.
- Pause and Round Over reuse the Home slabs with no card or title treatment.

**Guide**
- Paragraphs set directly over the starfield, so stars show through the text. Three identical slabs under it.

**App icon**
- Still the hand-drawn green helicopter that was on the launch screen.

---

## 2. Rules that do not bend

These come from `HELICHOPTER_PROJECT.md` and `CLAUDE.md`. Polish that breaks one is a regression.

1. Every control stays reachable by the app's scanner, iOS Switch Control, VoiceOver, and Voice Control. Labels stay speakable words. Scan order stays predictable.
2. Dynamic Type everywhere, up to the largest accessibility size. Any side-by-side layout must fall back to one column at accessibility sizes.
3. Text contrast stays at WCAG AA or better in all three themes; the UI audit must keep passing on every screen.
4. Touch targets get bigger or stay the same, never smaller. Players with motor disabilities rely on the large buttons. "Open" means more space around things, not smaller things.
5. Reduce Motion and Calm Mode are honoured by anything that moves or vibrates.
6. UIKit menus, SpriteKit gameplay only, no refresh timers, screen changes only through `RootViewController.present(_:)`.
7. No new fonts or art without an entry in `Release/ASSET_RIGHTS.md`. The plan uses only system fonts (SF Rounded) and SF Symbols, which need no entry.
8. Existing spoken labels and the order of controls stay as they are unless a stage says otherwise, so the 137 unit tests keep their meaning.

---

## 3. Design direction (to confirm in Stage 0)

- **Type:** SF Rounded (`UIFontDescriptor.withDesign(.rounded)`), which is friendlier and still the system font, so Dynamic Type and every language keep working. A scale of five text styles: display (title), heading, body, label, caption. Body no smaller than 17 pt.
- **Space:** one spacing scale (4, 8, 12, 16, 24, 32, 48) and two radii (14 for controls, 20 for cards). Content has a maximum width (about 560 pt) and is centred, so iPad stops looking stretched.
- **Surfaces:** each theme defines page, card, and raised-card colours, plus one accent. Nothing uses a colour outside the theme.
- **Buttons:** three kinds. Primary (filled accent, one per screen), secondary (card-coloured with a border), quiet (text with an icon). All at least 56 pt tall.
- **Icons:** an SF Symbol beside each main label (play, wrench, paintbrush, question mark). This also serves principle 3, "the player never has to read". Icons are decorative to VoiceOver; the label stays the spoken name.
- **Fewer words:** one short line under a setting's name. Longer explanations move to a "More about this" page, reusing the adjustment-page pattern that switch users already have.
- **Feedback:** a pressed state on every button; a light haptic on choose (off in Calm Mode); nothing that loops.

---

## 4. Stages

Each stage leaves `master` releasable with the full suite green. Do them in order; 1 is the foundation for the rest.

### Stage 0 — Agree the look (done 2026-11-11)

- Build a mock sheet before touching app code: Home, Settings, Hangar, and Play in the proposed style, in Night Sky and Parchment, at default and largest text size. Static images or an HTML page are enough.
- Offer two directions if the first is not clearly right (for example "soft cards" and "bold arcade").
- The owner picks one and answers "Decisions needed". Record the choice at the top of this file.

### Stage 1 — Design tokens (done 2026-11-11)

What was built, and what later stages should know:
- `Scenes/DesignSystem.swift`: `Spacing`, `Radius`, `Stroke`, `Layout`, `TypeStyle` (display, heading, body, label, caption; SF Rounded through `UIFontMetrics`), `ButtonKind`, and `ArcadeButton` (primary, secondary, quiet). `MenuButton` is an `ArcadeButton`; `addButton(for:kind:)` takes the kind, and every caller still uses secondary, so **no screen has a primary button yet** (Stages 2 and 5 choose them).
- `UITheme` now holds page, card, raised, ink, text, secondary text, accent, on-accent, accent text, focus, and on-focus colours. `buttonTintColor` and `buttonTextColor` are gone. Neon Night's accent is pink `#FF8ADF`.
- Scanner focus on a menu button is still the 4 pt border the tests pin, and the face also turns to the theme's focus colour with contrasting text, because a border alone is hard to see on a button that already has an outline.
- Layouts were not redesigned, but the look changed: rounded heavy type, section headings in the heading style (no longer small capitals), outlined buttons with a lower edge, theme-coloured cards, presets as secondary buttons (their green, blue, and red are gone), and content capped at 560 pt wide.
- Left for later stages: the "◀  Back" header (4), Home layout and icons (2), HUD chips (5), pressed states beyond a dimmed title (7). A few sizes that are not spacing remain in views (picture sizes, palette dots).

Original scope:

- New `Scenes/DesignSystem.swift`: spacing, radii, the type scale (`scaledFont` gains the rounded design), and the three button kinds as small `UIButton` subclasses built on the existing `DynamicTextButton` and `MenuButton` (focus border by callback stays).
- `UITheme` gains the surface levels and accent. `SettingsStyle` reads them instead of deriving its own.
- Replace per-view numbers and colours with tokens across `MenuStackView`, `ScrollingPanelView`, `SettingsRows`, `SettingsAdjustmentPanel`, `HangarPanelView`, `SceneTextOverlay`, `GameMenuView`.
- Tests: a contrast test for every text-on-surface pair in every theme; `DynamicTypeTests` still pass.

### Stage 2 — Home (done 2026-11-11)

What was built:
- Mascot 170 pt tall (110 at accessibility text sizes). **Stage 3 must match the launch screen to this size and position.**
- The wordmark: `TypeStyle.wordmark` (46 pt black rounded) in the theme's text colour with a solid accent shadow, leaning 3 degrees on a holder view. `fitWordmark()` limits its size to one line of the screen, so it grows with Dynamic Type only until it fills the width. The UI audit's Dynamic Type check is excused for this one label (see `AccessibilityAuditTests.audit`); **Owner decision 2026-11-12: keep the one-line limit.** The name is treated as a logo; the cost is that at the largest text size on iPhone it stops at about 50 pt, slightly smaller than the button labels.
- Play is the one primary button, large (`ButtonSize.large`, at least 86 pt plus the edge), with a play icon. Hangar, Settings, and How to Play are a row of tiles with the icon above the title (`MenuStackView.addTileRow`); at accessibility sizes they are a column with the icon before the title. `ArcadeButton.setIcon(systemName:placement:)` is available to later stages.
- Not done: moving the content into the upper two-thirds. With the larger mascot and Play the column fills most of the screen, so it is still centred.

Original scope:

- Larger animated mascot, a bold rounded wordmark, Play as the one primary button, then Hangar, Settings, and How to Play as secondary buttons with icons. Content sits in the upper two-thirds with even spacing rather than bunched in the middle.
- Scanner order and labels unchanged (Play, Hangar, Settings, How to Play).

### Stage 3 — Launch screen and app icon (done 2026-11-12)

- [x] Launch screen shows the Classic helicopter instead of the hand-drawn green one. Done 2026-11-11: new `LaunchHelicopter` image set (frame 1 of the Classic atlas); the old `LaunchScreen` image set is deleted.
- [x] Place and size the launch helicopter to match the Home mascot from Stage 2, so launch flows into Home without a jump. Done 2026-11-12: the helicopter is 170 pt and sits 155 pt above the centre of the safe area (144.67 pt on full-screen iPad), which is where Home's centred column puts the mascot at the default text size. The launch sky is now the top of Home's sky, drawn from the top at the screen's width, so the stars do not move either. A launch storyboard cannot read Home's layout, so these numbers are copied by hand; `LaunchMatchesHomeTests` fails when Home moves and the storyboard has not followed. **Later stages that change Home's height must update the storyboard.** Does not match, and cannot: a first launch (it opens the guide), a text size other than the default, a theme other than Night Sky, a helicopter other than Classic, and an iPad window narrower than full screen (about 10 pt off).
- [x] App icon redrawn from the Classic helicopter art (decision 3). Done 2026-11-12: `Tools/icon-kit/make_icon.py` draws it (the Classic body with one bold rotor blade, leaning nose-up over an amber moon on the Night Sky navy) and writes all 19 sizes; recorded in `ASSET_RIGHTS.md`. App Store Connect takes the icon from the uploaded build, so nothing is uploaded by hand. **Owner approved the icon 2026-11-12.**

### Stage 4 — Settings and Hangar panels (done 2026-11-12, except 4b)

What was built:
- **Page and cards.** `ScrollingPanelView` is a page with 16 pt margins. `sectionHeader` starts a section; `appendRow` puts rows on that section's card (`SurfaceView` in `DesignSystem.swift`: card colour, 3 pt ink outline, 6 pt lower edge, 1 pt dividers between rows); `appendToPage` puts a button or a row of cards straight on the page.
- **Header.** Back is a secondary button with a chevron picture, titled and spoken "Back", before the title; at accessibility text sizes the title goes below it. It lines up with the 560 pt column on iPad.
- **Fewer words.** Rows show one short line. Two switches (VoiceOver Direct Touch, Pause by Holding Switch) have a "More about this" text button that opens a page with the full text; VoiceOver still hears the full text as the switch's hint, and Voice Control can say "More about this" or "More about Pause by Holding Switch". This adds two stops to the scan. Long text for a slider or a list of choices is on its page of larger buttons instead, which adds no stops.
- **One button look.** Presets, the Hangar pointer, Reset, Privacy Policy, Acknowledgements, and every choice on an adjustment page are secondary `ArcadeButton`s. The only text-only buttons left are the two "More about this".
- **Values.** Each slider shows its value in the accent colour beside its name ("37%", "2.0 s"); below the name at accessibility sizes.
- **Choices.** Replaced by lists in 4b (below).
- **Hangar.** Cards are `CardButton`s on the page: card colour, ink outline and lower edge, accent outline when chosen, "Chosen" or "Equipped" in the accent colour. Themes are a column of full-width cards with the preview before the name (three across broke "Parchment" inside the word). Look pictures are 112 pt (were 64), centred, cards equal in height.
- **Checking by eye.** `ScreenSheetTests` (skipped unless `TEST_RUNNER_SCREEN_SHEET=<folder>` is set) draws Home, Settings, and the Hangar in three themes, at the default and largest text sizes, at phone and iPad widths.
- **4b, built 2026-11-12 (owner said yes).** Settings is a menu of six category cards (Difficulty, Comfort, Controls and Switches, Colours, Sound, Caregiver; each with a picture, its name, what is inside, and a chevron), then Reset Settings, Privacy Policy, and Acknowledgements. Each category is its own screen (`Screen.settingsCategory`, shown by `RootViewController.present` like any other): Back returns to the menu, and the menu then starts the scanner and VoiceOver on the category just left. Controls and Switches has three sections (Menu Scanning, Flying, Pausing) in the old order. Comfort, Sound, and Caregiver are one card with no section heading.
  - **Choices are lists.** Menu Scan Mode and In-Game Control are one button per choice (`ChoiceButton`: a ring, or a filled tick when chosen, plus the selected trait). One press chooses; nothing scrolls sideways; the old page of choices and every `UISegmentedControl` are gone. This adds stops on that page (two and four, where each list was one), in exchange for no second page.
  - **Lock.** With Lock Settings on, every category still opens. Its controls are dimmed and unreachable, with a note saying where to unlock. On the menu only Reset is dimmed. The lock itself is on the Caregiver page.
  - **Scan length.** The menu is 10 stops. The longest page is Controls and Switches at 14; Difficulty is 8; the rest are 2 to 7. Before, one page had about 30.
  - **The guide** now says "Settings → Controls and Switches" and "Settings → Difficulty". **Stage 8 must update** `docs/support.html` and the review notes in `Release/APP_STORE_COPY.md`, which still say "Settings → Switch Access", and choose the store screenshots: `StoreScreenshotTests` now captures the menu and four pages (`4-settings` to `8-colours`, then `9-how-to-play`) with no scrolling.
- **Left over.** At the largest text size on a phone, "Generous", "Acknowledgements", and the Hangar pointer still break inside a word (they are wider than the screen). Scanner focus on the new cards was not looked at on screen.


- Rows become inset rounded cards grouped by section, with margins at the screen edges. Headings use the heading style.
- A real header: Back at the leading edge with a chevron symbol (spoken label still "Back"), title beside or below it.
- One short description line per row; long text moves behind "More about this".
- Presets, segmented choices, Reset, and the Hangar pointer use the shared button kinds.
- Hangar: cards use theme surfaces, larger pictures, equal heights.
- [x] **4b (larger, optional), done 2026-11-12:** split Settings into category pages (Difficulty, Comfort, Controls and Switches, Colours, Sound, Caregiver). This is the biggest gain in openness and cuts the scan length for switch users, but it changes navigation and many tests. Decide after 4 (decision 2).

### Stage 5 — Play: HUD, Pause, Round Over (done 2026-11-12)

What was built:
- **HUD.** Score and Best are `ScoreChip`s at the leading edge (a small name over a large number in the accent colour; one VoiceOver element, "Score 12"). Pause is a secondary button with a pause picture at the trailing edge, at its own width instead of filling the row. At accessibility text sizes Pause has its own row above the chips. The flight hint, the new-high-score banner, and the Up and Down markers are `ChipLabel`s (card colour, ink outline, padding). Only Pause takes touches; everything else passes to the flight area.
- **Pause and Round Over.** `GameMenuView` sits on a card (`MenuStackView(onCard:)`, a `SurfaceView` behind the column) in the middle of the screen. Round Over shows the round's score in the largest type under a small "Score", then "Best 12"; VoiceOver still hears "Current Score: 4" and "Best Score: 10". Resume and Try Again are the primary buttons, Home is secondary, and each has a picture.
- **Kept as it was:** `GameSceneHUDDelegate`, what the overlay is told, every spoken name, and the order of choices. **Round Over still lists Home before Try Again**, as the scene's scanning order does; the Stage 0 mock drew Try Again first. Swapping them changes what a switch user reaches first. **Owner decision 2026-11-12: keep Home first.**
- **The stray full stop** after the score could not be found in the code ("Score \(score)" had none); the chips replace that label either way.
- **Known:** at the largest text size the flight hint is tall enough to run under the Up and Down markers until it fades on the first flap. This is believed to predate this stage (the hint sat lower still before), but that was not checked.


- Score and Best as two clear chips; Pause as a button with an icon, still large, at the trailing edge. Remove the stray full stop.
- Pause and Round Over as a centred card with a title, the score shown large on Round Over, one primary button (Resume or Play Again) and secondary ones.
- No change to `GameSceneHUDDelegate` or to what the overlay is told.

### Stage 6 — Guide

- Text on a card so stars never show through it. One picture per step. Next is primary; Read aloud and Skip are secondary.

### Stage 7 — Feedback and motion

- Pressed states, the choose haptic, and a short spring on screen content after the cross-fade (plain fade under Reduce Motion).

### Stage 8 — Release

- All three screenshot sets, What's New, the support page if any wording changed, `Tools/release_check.sh`.
- Owner: a full device pass (roadmap step 2), because every screen will have changed again.

---

## 5. How to check each stage

- Full unit suite and `HelichopterUITests` (the accessibility audit on every screen).
- A screenshot sheet of the changed screens: three themes × default and largest text size × iPhone 17 and iPad Pro 13-inch. Look at it; do not rely on tests for looks. (On 2026-11-11 the tests passed while "Helicopter" was breaking mid-word in the Hangar.)
- Scan each changed screen with the app's scanner in Timed and Step modes.
- Stop the app on the simulator afterwards.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| Polish shrinks targets or adds reading | Rule 4 and "Fewer words"; check at the largest text size every stage. |
| Tests pin exact labels, order, and some frames | Keep labels and order; update only layout assertions, one stage at a time. |
| `StoreScreenshotTests` frames shots from the Settings layout | Re-tune it in Stage 4; re-capture in Stage 8. |
| A full redesign delays the finished 2.2 skins | Accepted by the owner (decision 2): they ship together. |
| Taste: the result still feels generic | Stage 0 mock sheet and owner sign-off before code. |

---

## 7. Decisions needed from the owner

All answered 2026-11-11; see "Owner decisions" at the top. The original questions:

1. **Release order.** Recommended: finish 2.2 release prep and ship the skins, then do this plan as 2.3. Alternative: hold 2.2 and ship both together.
2. **Settings as category pages (Stage 4b):** yes, no, or decide after seeing Stage 4.
3. **App icon:** redraw it from the Classic helicopter, or keep the green one as the app's recognisable mark.
4. **Icons beside labels on Home and in menus:** yes (recommended) or text only.
5. **Direction:** chosen from the Stage 0 mock sheet.

## 8. Done when

- [ ] Every screen uses the shared tokens, button kinds, and theme surfaces; no per-view colours or sizes remain.
- [ ] The owner has looked at every screen on a device and agrees it no longer looks vibe-coded.
- [ ] Full suite and UI audit green; device accessibility pass done.
- [ ] Docs updated (`HELICHOPTER_PROJECT.md` architecture table, roadmap, progress log).
