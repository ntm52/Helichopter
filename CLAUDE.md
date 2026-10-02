# Helichopter — notes for Claude

Accessible SpriteKit/UIKit helicopter game for iPhone/iPad, preparing for App Store release.

**The plan lives in [HELICHOPTER_PROJECT.md](HELICHOPTER_PROJECT.md).** Read its Status, Known Bugs, and **Release Plan** sections before starting. Append a Progress Log entry at the end of each session. Release-specific detail: `Audit/APP_STORE_READINESS.md`; listing/privacy/rights drafts: `Release/`.

## Build and test

```bash
xcodebuild test -project Helichopter.xcodeproj -scheme flappy-fly-bird -destination 'platform=iOS Simulator,name=iPhone 17'
```

- The scheme is still named `flappy-fly-bird` (rename planned). Pick an installed simulator with `xcrun simctl list devices available`.
- `HelichopterTests/` is a file-system-synchronized group, so new test files are picked up without editing the project.
- Tests use Swift Testing (`@Test`, `#expect`). Many touch `GameSettings.shared` and `UserDefaults.standard`, so save and restore values as the existing tests do.
- Run `Tools/release_check.sh` before a submission (it also accepts a `.xcarchive`).

## Architecture rules that bite

- **UIKit draws everything visible** in menus and the HUD (`Scenes/SceneTextOverlay.swift`). The `.sks` archives are kept only as invisible action/text models. Any code that calls `applyUITheme` or adds archived nodes must also call `suppressArchivedPresentation()`. Otherwise the old SpriteKit screen renders alongside the UIKit one (the "two versions / two Pause buttons" bug).
- Settings is a separate UIKit panel (`SettingsOverlayView` in `SettingsScene.swift`); its scene hides all archived children.
- `GameViewController` refreshes the overlay every 50 ms; replacing that timer is planned debt.
- The sprite atlas folder must keep its `.spriteatlas` extension.
- Switch access (FocusScanner), VoiceOver, and Dynamic Type are core features. Every new control must be scannable, labelled, and use scalable text.
