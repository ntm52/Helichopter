# Helichopter: app overview and release preparation

Updated September 8, 2026. This checklist intentionally excludes testing activities.

## What the app contains

- Offline Swift/SpriteKit helicopter obstacle game for iPhone and iPad; app deployment target iOS 13.0, version 2.0 (1).
- Title, gameplay, pause/resume, round-over/retry, saved scores, and persistent Settings. No account, backend, ads, or purchases were found in the reviewed Swift source.
- Four flight schemes: tap-to-flap, hold-to-hover, auto-hover with nudges, and two-switch up/down. Keyboard/controller switch input, timed or manual menu scanning, and hold-to-pause.
- UIKit Settings and scalable menu/HUD text. VoiceOver flight activation, downward actions, Pause/escape, and spoken gap guidance.
- Gentle/Standard/Challenge presets; visible adjustments for gap size, pipe speed, hitbox size, background scrolling, scan timing, and pause delay. The underlying model includes additional tuning values that the UI does not expose independently.
- No-fail mode, Calm Mode, optional score, settings lock, music/effects switches, three themes, six palettes, contrast boundaries, and Reduce Motion handling.
- A 60-frame helicopter animation, pipe artwork, scrolling scenery, music, and event sounds.

## Before submission

1. **Publish privacy and support pages; add the privacy link in Settings.** The bundled manifest declares no tracking/data collection and the UserDefaults CA92.1 reason. A manifest is not a privacy policy. Apple requires a public policy URL in App Store Connect and an easily accessible link inside the app. Include a monitored support contact. [Privacy details](https://developer.apple.com/app-store/app-privacy-details/) · [Review guidelines, section 5.1.1](https://developer.apple.com/app-store/review/guidelines/)
2. **Prepare the distribution package.** Confirm developer membership, bundle identifier, distribution signing, release version/build number, and a signed archive. Set price, availability, age rating, export-compliance answers, and review contact/notes in App Store Connect. Unsigned simulator builds do not establish signing readiness. [Submission properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
3. **Write an accurate listing and accessibility statement.** Prepare iPhone/iPad screenshots, concise gameplay description, keywords, and clear reviewer instructions for switch scanning and VoiceOver actions. Describe specific capabilities; avoid blanket claims about all disabilities or sound-only play at every difficulty. Choose Accessibility Nutrition Labels against Apple's criteria. [Accessibility labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
4. **Document artwork/audio rights.** Keep provenance and license records for the helicopter kit, pipes, background, icon, music, and sound effects, including any required attribution. The repository license alone does not establish rights to every included asset.

## Product and engineering priorities

- **Add a short, replayable first-run guide.** Explain the selected flight control, no-fail mode, pause, switch scanning, and where to change difficulty. Provide accessible text/buttons and avoid requiring timed interaction to finish the guide.
- **Align promises with Settings.** Either expose the remaining independent tuning controls in an advanced section or narrow the documentation's claim. Gravity, flap strength, pipe spacing, and gap variability should not be advertised as separately adjustable in the UI unless they are.
- **Validate values when saving/reading settings.** Clamp nonfinite/out-of-range numbers and enforce ordered, geometrically safe gap bounds before future profiles/imports expand input sources.
- **Prioritize audio navigation if blind players are a launch audience.** Current speech reports gap alignment and altitude, but two-second updates are not continuous guidance. Consider a dedicated audio-guided preset and optional nonverbal pitch/proximity cues with controls for cue volume/frequency.
- **Add a reset-to-defaults control and consider saved profiles later.** Recovery from confusing settings is valuable; profiles would help shared school/therapy devices but need not delay the first release.
- **Choose the supported OS range deliberately.** The app declares iOS 13 while its current test target requires iOS 26.5; document the maintenance commitment instead of letting legacy project settings decide it.

Profiles, more artwork, additional themes, and localization can follow launch unless they are part of the intended initial audience's requirements.
