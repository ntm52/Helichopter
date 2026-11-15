# Accessibility audit — 2026-11-15

Audit of the code on `master` (2.2 in progress, after Plan 03 Stage 7), by Claude Code. Thirteen issues were found and fixed; ten are open and listed with what each would take.

## How it was tested

- Read every UIKit screen, the scanner, the HUD, the game scene, and the input code.
- Ran the full suite before and after the fixes on the iPhone 17 simulator: **180 unit tests and the 4 UI tests pass** (the UI tests run Apple's accessibility audit on every screen).
- Looked at the picture sheet (`ScreenSheetTests`) for every menu in three themes at the default and largest text sizes, phone and iPad.
- Ran the app in the simulator: Home and play in Parchment at the default and largest text sizes, and switch input from the keyboard.

**Not tested, because the simulator cannot:** VoiceOver, Voice Control, and iOS Switch Control running for real; hardware switches and controllers; haptics; speech output. The VoiceOver, Voice Control, and controller fixes below are checked by unit tests only. The device checks in roadmap step 2 are still needed, and now cover these fixes too.

## Fixed

| # | Issue | Who it affected | Fix |
|---|---|---|---|
| 1 | Opening Privacy Policy, Acknowledgements, Reset, "More about this", or a slider's page always started the switch scanner: a moving highlight and a synthetic voice. After Done it kept scanning the Settings list. | Touch, VoiceOver, and Voice Control users who never use a switch | The scanner runs on these pages only for a player who was already scanning. A first switch press on an open page scans that page only. |
| 2 | The scanner's own voice spoke while VoiceOver was on, so two voices talked at once. | VoiceOver users with a switch or keyboard | With VoiceOver on, the scanner hands its words to VoiceOver as announcements. |
| 3 | Scanner speech named each choice but never said which was chosen. | Switch users who rely on the spoken scan | It now says "Hold to Hover, selected" and "Striped Pipes, Equipped", in Settings and the Hangar. |
| 4 | Scanning down the guide's choices scrolled its words off the top, and they never came back. A switch user cannot scroll. | Switch users, most of all deaf ones, who cannot use "Read this step aloud" | Coming round to the first choice scrolls back up as far as keeps that choice on screen. Partly fixed: see open issue B. |
| 5 | At accessibility text sizes the flight hint covered the waiting helicopter, and in Auto Hover and Up/Down Switches it overlapped the Up and Down labels. | Low-vision players | At those sizes the hint sits at the bottom of the screen. A label the hint would still cover waits until the hint fades. |
| 6 | A Settings switch was a 51 by 31 point target. | Touch users with limited dexterity | Tapping the row's name or description flips the switch too. |
| 7 | The slider page's buttons were named "Decrease. Value: 37%", which cannot be said to Voice Control. | Voice Control users | "Tap Decrease" and "Tap Increase" work. VoiceOver still hears the value. |
| 8 | VoiceOver's escape gesture (two-finger scrub) did nothing in any menu, and Magic Tap did nothing. | VoiceOver users | Escape goes Back in Settings and the Hangar, closes an open page, and resumes from Pause. Magic Tap pauses and resumes the game. |
| 9 | The chosen colour palette was marked only by its border's colour and width. | Colour-blind players, on the colour-blindness screen | A tick in the card's corner. |
| 10 | The No-Fail bump pulsed 3.3 times a second, over the limit of three. Under Reduce Motion a bump showed nothing at all. | Photosensitive players; deaf players on iPad, which has no haptics | 2.5 pulses a second. Under Reduce Motion the helicopter holds a steady stronger tint until the bump ends. Calm Mode still shows nothing, as before. |
| 11 | With Reduce Transparency on, the pause menu was still see-through over the game. | Low-vision and cognitive | Reduce Transparency gives the solid background that Hide Game While Paused gives. |
| 12 | VoiceOver announced "Game over" even in Calm Mode, where the screen says "Well Done!". | VoiceOver users in Calm Mode | The announcement uses the screen's words: "Round over" or "Well done". |
| 13 | A game controller's Menu button did nothing. | Adaptive controller users | Menu pauses and resumes, and starts menu scanning as a switch pause does. |

New tests: `HelichopterTests/AccessibilityAuditFixTests.swift` (12) and `magicTapPausesAndResumesTheGame` in `ScreenTransitionTests`. Two `HangarTests` now compare names without ", selected".

**Two of these change how the app behaves for everyone, so the owner may want to veto them:** row taps flip switches (6), and the large-text hint moves to the bottom (5).

## Open

Ordered by how much they matter.

| # | Issue | Why not fixed | What it would take |
|---|---|---|---|
| A | A Settings slider can only be dragged by touch. The page of Decrease and Increase buttons opens for VoiceOver, Switch Control, and the scanner, not for a finger. | A new visible control on every slider row is a design decision. | A small "Adjust" button on each slider row that opens the existing page. |
| B | The app's scanner cannot scroll text. Privacy Policy, Acknowledgements, and the guide at large text sizes run past one screen, and a switch-only user sees only what is near the focused button. | Needs a new scanning item or paged text. | "Scroll down" and "Scroll up" scan items on long pages, or split long text into pages with Next. |
| C | The palette row scrolls sideways; at the largest text size one palette is visible at a time. `CLAUDE.md` says a short list of choices should be a `choiceRow`. | Layout redesign of the Colours page. | A column of palette choices, each with its two colour dots. |
| D | iPhone is portrait only. A phone mounted in landscape on a wheelchair shows the game sideways. iPad rotates. | Needs a landscape phone layout and testing. | Allow landscape on iPhone using the existing letterboxed fit. |
| E | Scanner speech cannot be turned off or have its volume set, and the silent switch mutes it with the rest of the sound. | A new setting; changes scan order tests. | A "Speak Menu Items" switch under Menu Scanning. |
| F | Two low-contrast spots. With Helicopter Outline off in Parchment, the helicopter is pale pink on cream. The unfilled part of a slider track is 1.8:1 on Night Sky cards and 1.4:1 on Neon Night (the thumb and the value text do pass). | The first is the player's own choice of setting; the second needs a new theme colour. | Keep a thin outline in Parchment; add a track colour to `UITheme` with a contrast test. |
| G | Three iOS settings are not followed: Differentiate Without Colour (roadmap section 4 item 2: equip Striped Pipes), Increase Contrast, and Button Shapes (the "More about this" text button has no shape). | Each is a small feature. | As the roadmap describes for the first; an underline for quiet buttons under Button Shapes. |
| H | Calm Mode silences menu haptics and bump haptics but not the flap and score haptics. | Unclear which the owner intends; flap haptics may be wanted feedback. | Owner decision, then one `guard`. |
| I | English only, with no String Catalog. | Roadmap section 4 item 5. | As the roadmap describes. |
| J | Not verified on a device: everything in roadmap step 2, plus how Full Keyboard Access interacts with the app's own handling of Space, Enter, and the arrow keys. | Needs hardware. | Owner device pass. |

## Checked and found sound

- Every control has a spoken name without symbols, a hint, and the right traits; decorative pictures are hidden from VoiceOver; headings are marked on every screen.
- Each screen is modal for VoiceOver, announces itself once, and moves VoiceOver to a sensible element.
- Text contrast is 4.5:1 or better on every surface in all three themes, and focus and accent marks are 3:1 or better (`ThemeSurfaceContrastTests`). Gameplay shapes have black and white outlines in all 18 theme and palette pairs.
- Dynamic Type reaches the largest accessibility size on every screen, and Apple's audit reports no clipped text; rows become columns where needed. A few long words break across lines at the largest size on a phone (already known).
- Reduce Motion stops the rotor, the background scroll, the bump pulse, button movement, and screen settling.
- Buttons are at least 56 points tall. Nothing is on a timer except the scanner, whose dwell is adjustable from 0.5 to 10 seconds. No-Fail is the default.
- The public pages in `docs/` have a language, headings, a labelled navigation landmark, AA contrast in light and dark, and resizable text.
