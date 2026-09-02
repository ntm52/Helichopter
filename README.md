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
- Dynamic Type on all text
- Validated contrast palettes including deuteranopia-safe, protanopia-safe, and low-luminance options
- No-fail / practice mode
- Picture-based settings comprehensible without reading

## Tech

- Swift / SpriteKit / GameplayKit
- iOS 17.0+
- iPhone and iPad

## Status

Active development. See `HELICHOPTER_PROJECT.md` for the full phase-by-phase plan and progress log.
