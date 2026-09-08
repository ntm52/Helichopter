# Helichopter

An iOS side-scrolling game built with Swift and SpriteKit, designed from the ground up to be playable by people across a wide range of disabilities.

## About

Helichopter is a Flappy Bird–style game where you pilot a helicopter through an obstacle course of pipes. The core design goal is genuine accessibility: the game slows down for cognitive load, pipe gaps widen, colors are designed for contrast and colorblind safety, and the entire app is intended to be navigable with a single switch.

This project is an active remodel of the original 2021 build, bringing it to current iOS standards and finishing the accessibility work that was started.

## Accessibility goals

- Switch access as a first-class input (keyboard emulation, game controller, iOS Switch Control)
- Independent, continuous difficulty tuning — gap size, speed, gravity, flap strength, hitbox forgiveness, all separately adjustable
- Hold-to-hover and auto-hover control schemes alongside tap-to-flap
- VoiceOver support across every scene
- Dynamic Type for menus, gameplay text, and Settings
- Validated contrast palettes including deuteranopia-safe, protanopia-safe, and low-luminance options
- No-fail / practice mode
- Picture-based settings comprehensible without reading

## Tech

- Swift / SpriteKit / GameplayKit
- iOS 13.0+ (current project deployment target; oldest-device validation pending)
- iPhone and iPad

## Switch controls in Settings

Press Space, Enter, 1, Up Arrow, or the controller's primary button to start scanning or select the highlighted control. Auto-Advance moves focus on a timer; in Two-Switch mode, use 2, an arrow mapped to secondary input, or the secondary controller button to advance.

Select a slider to open Decrease, Increase, and Done; each adjustment changes 5% of its range. Select a segmented control to scan its choices. Settings scrolls focused controls into view and preserves focus after theme, preset, or lock changes. When locked, Back and Lock Settings remain reachable.

## Switch controls during gameplay

Hold the primary keyboard/controller switch for **3 seconds** to pause in any flight mode. Release it, then press again to select a highlighted menu button. The pause menu starts scanning even when Auto-Scan Menus is off; Menu Scan Mode still chooses timed one-switch or manual two-switch navigation.

Settings → Switch Access → **Hold Switch to Pause** adjusts the delay from 2–10 seconds. In Hold to Hover and Two-Switch flight, release and press again before the delay to keep flying without pausing, or increase the delay for longer holds. Touch flight is unchanged. Physical switch/controller validation is still pending.

## VoiceOver flight

During play, focus **Helicopter flight control**. Double-tap to flap (Tap to Flap),
toggle rising/falling (Hold to Hover), nudge up (Auto Hover), or toggle rising/stopping
(Two-Switch). The **Move down** action releases hover, nudges down, or toggles
descending/stopping for the corresponding scheme. **Pause** and the two-finger
scrub open the pause menu. Switching VoiceOver on or off pauses the run.

VoiceOver reads altitude, approaching pipes, and whether to move up, move down,
or stay aligned with the next gap. Automatic guidance is limited to one update
per two seconds and is separate from the game's sound-effects setting. These
are spoken spatial cues, not continuous audio navigation; sound-only playability
at every difficulty is not yet established.

## Text size

Text follows iOS Settings → Accessibility → Display & Text Size → Larger Text,
including accessibility sizes and changes while the app is open. Title, pause,
and round-over menus scroll vertically; gameplay score and instructions use
UIKit text independent of the SpriteKit scene scale. Settings labels wrap,
presets stack vertically, and choice controls and palette cards scroll horizontally.
The switch scanner scrolls the selected menu button into view. Changing text size
in Settings preserves the selected setting and an open adjustment panel.

## Status

Active development; not yet ready for App Store submission. See [app overview and release preparation](Audit/APP_STORE_READINESS.md) for non-testing launch work. See [the September 5 audit](Audit/REVIEW_2026-09-05.md) for tested fixes and remaining release blockers. See `HELICHOPTER_PROJECT.md` for the full phase-by-phase plan and progress log.

## Helicopter artwork and animation

The title screen and gameplay use the supplied helicopter kit: 60 aligned frames
at 60 FPS, with a stationary body and a looping rotor. Reduce Motion shows a static
frame. The title mascot has no flight input or physics.

Source artwork and the Pillow converter live in `Tools/helicopter-kit/`. Run
`python3 Tools/helicopter-kit/make_frames.py` to regenerate the bundled 1x/2x/3x
atlas and local animated preview. See [the kit notes](Tools/helicopter-kit/README.txt)
for details. The helicopter uses a light palette/theme tint to retain its shading.

Gameplay uses an opaque black-and-white flight marker and matching pipe borders to
keep object boundaries visible across palettes and textured backgrounds. No-fail
feedback pulses the artwork tint without fading the marker. These borders preserve
the existing hitboxes; they are visual guides, not collision outlines. Rendered
regression tests cover all 18 theme/palette combinations. This does not certify
all artwork pixels or replace testing with players who have low vision.
