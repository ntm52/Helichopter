# Accessibility audit — 2026-11-15

Audit of the code on `master` (2.2 in progress, after Plan 03 Stage 7), by Claude Code. Thirteen issues were found and fixed on 2026-11-15. Of the ten left open, a second pass on 2026-11-16 and 17 fixed six (A, B, C, D, E, H), part-fixed two (F, G), and left two (I, J). The Open table below is current.

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

## Fixed in the second pass (2026-11-16)

| # | Issue | Fix |
|---|---|---|
| A | A Settings slider could only be dragged by touch. | Every slider row has an "Adjust with buttons" button that opens the page of Decrease and Increase for anyone. Voice Control: "Tap Adjust Gap Size". The scanner still stops once per slider, on the slider. |
| B | The app's scanner could not scroll text. | While a page longer than the screen is scanned, Scroll down and Scroll up buttons sit under it and are scanned first: Privacy Policy, Acknowledgements, "More about this" pages, and the guide. Nobody else sees them. |
| C | The palette row scrolled sideways. | Game Colours is a list of choices like every other, each with its helicopter and pipe colour dots (under the name at accessibility text sizes). `SwatchButton` is gone. |
| E | Scanner speech could not be turned off. | "Speak Menu Items" switch under Menu Scanning (on by default). "Read this step aloud" still speaks when it is off. Still open: its own volume, and the silent switch muting it. |
| F (part) | The unfilled slider track was 1.8:1 on Night Sky and 1.4:1 on Neon Night. | The track uses the theme's secondary text colour, 8:1 or better on a card in every theme; `ThemeSurfaceContrastTests` checks it. |
| G (part) | Button Shapes and Differentiate Without Colour were not followed. | Button Shapes underlines text-only buttons ("More about this", "Adjust with buttons"). Differentiate Without Colour equips Striped Pipes until the player chooses pipes in the Hangar; Reset returns to that. |
| H | Calm Mode left the flap and score vibrations on. | Owner's decision: Calm Mode stays as it is, and a new choice under it, "Vibration in Calm Mode", offers Flap and score (the default, as before), Score only, or No vibration. |

| D | iPhone was portrait only; a phone mounted in landscape showed the app sideways. | Done 2026-11-17. The app turns with the phone. In a window much wider than tall, play uses a wide scene made to the window's shape (owner's choice over a narrow strip between bars): the helicopter and pipes are as large as in portrait, pipes move at their portrait speed and are seen sooner, and there is about half the vertical room. Home drops its mascot on a short screen so all four choices fit. A round keeps the layout it started with: turn the phone, and the round in progress is letterboxed until the next one starts from Home. On that short screen Pause and Round Over show their choices side by side, the HUD is one row at every text size, and the flight hint and the Up and Down labels stop growing at 28 and 22 points so they never cover the helicopter or Pause. On 2026-11-18 Settings went two to a line there (categories, and the rows on each page's cards), read and scanned left to right, then down; one column again at accessibility text sizes. |

New tests in `AccessibilityAuditFixTests` (7 more; the guide scrolling test was rewritten). Five older tests were updated for the new rows and scan order.

**Not looked at or tried:** the Button Shapes underline, the Differentiate Without Colour default, and the vibration choice have unit tests only; the simulator has no haptics. The scroll buttons were not tried in the running app.

## Open

| # | Issue | Why not fixed | What it would take |
|---|---|---|---|
| E (rest) | Scanner speech has no volume of its own, and the silent switch mutes it with the rest of the sound. | Needs an audio-session decision that also affects music. | A volume slider, or speech that ignores the silent switch. |
| F (rest) | With Helicopter Outline off in Parchment, the helicopter is pale pink on cream. | The outline is on by default; turning it off is the player's own choice. | Keep a thin outline in Parchment whatever the switch says, or say so in the switch's description. |
| G (rest) | Increase Contrast changes nothing. | Checked: main and secondary text are already 7:1 or better on the page and on cards in all three themes; only accent text falls short of 7:1 in places (6.2:1 at worst, Parchment headings on the page). | Darker accent text under Increase Contrast, if wanted. |
| I | English only, with no String Catalog. | Roadmap section 4 item 5; a large piece of work. | As the roadmap describes. |
| J | Not verified on a device: everything in roadmap step 2, plus how Full Keyboard Access interacts with the app's own handling of Space, Enter, and the arrow keys. | Needs hardware. | Owner device pass. |

## Checked and found sound

- Every control has a spoken name without symbols, a hint, and the right traits; decorative pictures are hidden from VoiceOver; headings are marked on every screen.
- Each screen is modal for VoiceOver, announces itself once, and moves VoiceOver to a sensible element.
- Text contrast is 4.5:1 or better on every surface in all three themes, and focus and accent marks are 3:1 or better (`ThemeSurfaceContrastTests`). Gameplay shapes have black and white outlines in all 18 theme and palette pairs.
- Dynamic Type reaches the largest accessibility size on every screen, and Apple's audit reports no clipped text; rows become columns where needed. A few long words break across lines at the largest size on a phone (already known).
- Reduce Motion stops the rotor, the background scroll, the bump pulse, button movement, and screen settling.
- Buttons are at least 56 points tall. Nothing is on a timer except the scanner, whose dwell is adjustable from 0.5 to 10 seconds. No-Fail is the default.
- The public pages in `docs/` have a language, headings, a labelled navigation landmark, AA contrast in light and dark, and resizable text.
