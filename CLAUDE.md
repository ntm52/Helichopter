# Helichopter — notes for Claude

Accessible SpriteKit/UIKit helicopter game for iPhone and iPad. **Version 2.0 is live on the App Store**; work is now post-launch improvement.

## Read first

1. [HELICHOPTER_PROJECT.md](HELICHOPTER_PROJECT.md): current state, architecture, known issues, and the release checklist.
2. [Plans/ROADMAP.md](Plans/ROADMAP.md): what to work on, in order. Each large item links to a detailed plan in `Plans/`.
3. Before ending a session, append an entry to [Audit/PROGRESS_LOG.md](Audit/PROGRESS_LOG.md) and tick off finished roadmap or plan items.

If a document and the code disagree, trust the code and fix the document.

## Build and test

```bash
xcodebuild test -project Helichopter.xcodeproj -scheme Helichopter -destination 'platform=iOS Simulator,name=iPhone 17'
```

- Pick an installed simulator with `xcrun simctl list devices available`.
- Swift Testing filters need the parentheses: `-only-testing:'HelichopterTests/Suite/testName()'`.
- If the full suite hangs, add `-parallel-testing-enabled NO`.
- `HelichopterTests/` is a file-system-synchronized group, so new test files are picked up without editing the project.
- Tests use Swift Testing (`@Test`, `#expect`). Many touch `GameSettings.shared` and `UserDefaults.standard`; save and restore values as the existing tests do.
- Run `Tools/release_check.sh` before any submission (it also accepts a `.xcarchive`).

## Architecture rules that bite

- **UIKit draws everything visible** in menus and the HUD (`Scenes/SceneTextOverlay.swift`). The `.sks` archives are kept only as invisible action and text models. Any code that calls `applyUITheme` or adds archived nodes must then call `suppressArchivedPresentation()`, or the old SpriteKit screen renders alongside the UIKit one.
- Settings is a separate UIKit panel (`SettingsOverlayView` in `SettingsScene.swift`); its scene hides all archived children.
- Change screens only with `GameViewController.present(_:in:)`. Never call `presentScene` elsewhere or use an `SKTransition` (a test enforces this). New code that posts `screenChanged` must use `ScreenChangeAnnouncer.post`, and a scene with its own scanner must list it in `scannersDuringTransition`. Do not add new screens as `.sks` scenes; follow `Plans/01_SINGLE_LAYER_UI.md` Stage B.
- `GameViewController` refreshes the overlay every 50 ms. Replacing that timer is part of the single-layer plan.
- The sprite atlas folder must keep its `.spriteatlas` extension.
- Switch access (`FocusScanner`), VoiceOver, and Dynamic Type are core features. Every new control must be scannable, labelled, and use scalable text.

## Privacy and release rules

- The app currently collects no data and makes no network calls. Anything that changes that (including StoreKit purchases) requires updating `docs/privacy.html`, `AppLinks.privacySummary`, `PrivacyInfo.xcprivacy`, the App Store privacy answers, and `Release/APP_STORE_COPY.md` together.
- New art or audio must be recorded in `Release/ASSET_RIGHTS.md`.
- `docs/` is the live GitHub Pages site; pushing changes there publishes them.
