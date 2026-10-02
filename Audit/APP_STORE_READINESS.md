# Helichopter: app overview and release preparation

Updated September 8, 2026. This checklist intentionally excludes testing activities.

## What the app contains

- Offline Swift/SpriteKit helicopter obstacle game for iPhone and iPad; app deployment target iOS 17.6, version 2.0 (1).
- Title, gameplay, pause/resume, round-over/retry, saved scores, and persistent Settings. No account, backend, ads, or purchases were found in the reviewed Swift source.
- Four flight schemes: tap-to-flap, hold-to-hover, auto-hover with nudges, and two-switch up/down. Keyboard/controller switch input, timed or manual menu scanning, and hold-to-pause.
- UIKit Settings and scalable menu/HUD text. VoiceOver flight activation, downward actions, Pause/escape, and spoken gap guidance.
- Gentle/Standard/Challenge presets; visible adjustments for gap size, pipe speed, hitbox size, background scrolling, scan timing, and pause delay. The underlying model includes additional tuning values that the UI does not expose independently.
- No-fail mode, Calm Mode, optional score, settings lock, music/effects switches, three themes, six palettes, contrast boundaries, and Reduce Motion handling.
- A 60-frame helicopter animation, pipe artwork, scrolling scenery, music, and event sounds.

## Work completed locally — September 8

- Prepared [listing copy, reviewer instructions, accessibility statement, and screenshot brief](../Release/APP_STORE_COPY.md).
- Prepared [privacy policy and support page copy](../Release/PRIVACY_AND_SUPPORT.md), including source-based privacy answers. Contact placeholders are explicit; pages are not published.
- Created an [asset provenance and rights register](../Release/ASSET_RIGHTS.md) identifying source files and missing permissions.
- Added numeric validation on settings reads/writes, safe enum decoding, ordered gap bounds, and scene-size-aware pipe geometry. Invalid values use defaults or bounded values; changing one gap bound adjusts the other if necessary.
- Added Settings → Reset Settings with Cancel/Restore Defaults, scalable text, and switch navigation. Reset restores Standard difficulty and default controls/theme/audio, retaining scores and guide completion. Caregiver lock disables reset until unlocked.
- Narrowed README tuning claims to controls available in Settings. Gravity, flap strength, spawn interval, and gap variability remain preset-controlled in the UI.

## Apple security and privacy checks — October 1, 2026

The prioritized checklist is now the **Release Plan** in [HELICHOPTER_PROJECT.md](../HELICHOPTER_PROJECT.md#release-plan--path-to-the-app-store). Use `Tools/release_check.sh` to verify the local checks: run it on an unsigned Release build during development, then on the signed `.xcarchive` before upload.

| Requirement | Status |
|---|---|
| Privacy manifest + required-reason APIs | Pass. UserDefaults `CA92.1` is the only required-reason API in the app binary. |
| Export compliance (`ITSAppUsesNonExemptEncryption`) | Pass: `false` |
| ATS exceptions / networking / third-party SDKs / permission prompts | None. Supports the "Data Not Collected" answer. |
| App Store icon opaque | Pass |
| Distribution signing (no `get-task-allow`) | Check on the archive |
| Public privacy policy + support URLs | **Open.** Contact address and hosting needed. |
| In-app privacy policy link (5.1.1) | **Open:** not implemented |
| BSD licence notice in distribution | **Open:** no acknowledgements screen |
| Age rating questionnaire, DSA trader status, App Privacy answers | **Open:** App Store Connect |
| Asset rights evidence (5.2) | **Open:** see `Release/ASSET_RIGHTS.md` |

## Before submission

1. **Drafts prepared; publication and in-app privacy URL remain open.** Supply a monitored contact and public hosting destination, then publish the prepared copy and add the real privacy link in Settings. The bundled manifest declares no tracking/data collection and the UserDefaults CA92.1 reason. A manifest is not a privacy policy. Apple requires a public policy URL in App Store Connect and an easily accessible link inside the app. Include a monitored support contact. [Privacy details](https://developer.apple.com/app-store/app-privacy-details/) · [Review guidelines, section 5.1.1](https://developer.apple.com/app-store/review/guidelines/)
2. **Prepare the distribution package.** Confirm developer membership, bundle identifier, distribution signing, release version/build number, and a signed archive. Set price, availability, age rating, export-compliance answers, and review contact/notes in App Store Connect. Unsigned simulator builds do not establish signing readiness. [Submission properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties)
3. **Listing and accessibility copy prepared; screenshots and final labels remain open.** Use the release copy linked above. Capture final iPhone/iPad screenshots and enter the listing in App Store Connect. Describe specific capabilities; avoid blanket claims about all disabilities or sound-only play at every difficulty. Choose Accessibility Nutrition Labels against Apple's criteria. [Accessibility labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
4. **Provenance register prepared; rights confirmation remains open.** Supply authorship statements or license records for the helicopter kit, pipes, background, icon, music, and sound effects, including any required attribution. The repository license alone does not establish rights to every included asset.

## Product and engineering priorities

- **Implemented: short, replayable first-run guide.** Three steps explain the selected flight control, current no-fail mode, pause, switch scanning, and where to change difficulty. The guide uses scalable UIKit text/buttons, spoken instructions, Back/Next/Skip controls, and the existing switch scanner. Finishing or skipping saves completion; How to Play on the home screen reopens it. No timed interaction is required to finish; reading aloud pauses scanning until the next switch press.
- **Completed: align promises with Settings.** Public copy describes the visible controls and identifies the remaining parameters as preset-controlled.
- **Completed: validate values when saving/reading settings.** Numeric settings are bounded, nonfinite values recover, enum conversion is safe, gap bounds stay ordered, and pipe gaps fit the current scene.
- **Prioritize audio navigation if blind players are a launch audience.** Current speech reports gap alignment and altitude, but two-second updates are not continuous guidance. Consider a dedicated audio-guided preset and optional nonverbal pitch/proximity cues with controls for cue volume/frequency.
- **Completed: reset-to-defaults control.** Includes switch-accessible confirmation and preserves scores. Saved profiles remain deferred.
- **OS policy decided (October 1, 2026): iOS 17.6 minimum.** Confirmed by the owner. The test target (iOS 26.5) is a development tool, not the app's compatibility declaration. Validate on the oldest iOS 17 device available.

Profiles, more artwork, additional themes, and localization can follow launch unless they are part of the intended initial audience's requirements.

## Remaining dependencies

- **Owner information:** monitored support contact, public page destination, artwork/audio rights evidence, supported-OS commitment, pricing/regions, and review contact.
- **Apple account:** membership, distribution certificate/provisioning, registered bundle ID, unique upload build number, signed archive, App Store Connect questionnaire answers and submission. Project values remain `com.nathanmayo.helichopter`, team `9HJ5466NL8`, version `2.0 (1)`; configuration is not proof of account readiness.
- **Release work:** publish pages and wire the real in-app URL, include required license notices in distribution materials, capture final product screenshots, and select accessibility labels only when supported by the required assessment.
- **Deferred product direction:** continuous audio navigation and saved profiles are not implemented. Current listing explicitly limits audio guidance to periodic spoken cues.

This checklist remains focused on non-testing preparation. Device and assistive-technology release gates remain in the [audit](REVIEW_2026-09-05.md); completed local work does not certify submission readiness.
