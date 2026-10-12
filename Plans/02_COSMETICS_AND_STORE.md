# Plan 02 — Cosmetic skins, Hangar screen, and in-app purchases

**Status:** Phase 1 step 1 done 2026-10-12. Written 2026-10-08; Phase 1 revised 2026-10-12 (themes move to the Hangar; three steps; steps 1–2 ship in 2.1; no "more on the way" sentences).
**Goal:** Players can change how the helicopter and pipes look. Some skins are free; others are one-time purchases. Purchases are **cosmetic only**.
**Depends on:** [Plan 01](01_SINGLE_LAYER_UI.md) Stage B (or at least Stage A). The Hangar must be a UIKit screen built on the new pattern, not another `.sks`-backed scene.

---

## 1. Ground rules (non-negotiable)

1. **Cosmetic only.** No skin changes hitbox, speed, physics, score, or difficulty.
2. **Accessibility is never paid.** Every accessibility feature, palette, theme, and control scheme stays free in every version. State this in the listing.
3. **Skins never reduce accessibility.** Colour palettes, the helicopter contrast marker, pipe borders, Reduce Motion, and Calm Mode work with every skin.
4. **No pressure.** No pop-ups, countdowns, "limited time" offers, currencies, loot boxes, or consumables. The store is only reachable from the Home screen, never during play or on Round Over.
5. **Fully operable** with the app's switch scanner, iOS Switch Control, VoiceOver, and Dynamic Type, like every other screen.
6. **Respects caregivers.** When Settings is locked, buying and restoring are locked too. iOS Ask to Buy and Screen Time restrictions are honoured.

---

## 2. Phases

### Phase 1 — Hangar with themes and free skins (no StoreKit) → steps 1–2 in 2.1, step 3 in 2.2

Revised 2026-10-12: the Hangar also takes over the **menu theme** from Settings. Phase 1 is split into three steps; each leaves `master` releasable.

**Owner decision (2026-10-12): steps 1 and 2 ship in 2.1**, which has not been submitted yet (version 2.1, build 3, is already set). Step 3 (new pipes and helicopters) ships later, in 2.2. Consequences:

- The Hangar must pass everything the rest of 2.1 passes: the `HelichopterUITests` accessibility audit, the switch scanner in Timed and Step modes, VoiceOver, Voice Control, Dynamic Type up to the largest accessibility size, Reduce Motion, every theme and palette, and the caregiver lock. The owner's 2.1 device checks (roadmap step 2) now include the Hangar.
- 2.1 release preparation must be redone after step 2: What's New in `Release/APP_STORE_COPY.md` (mention the Hangar and that the menu theme moved there), all three screenshot sets (Home has four buttons; the theme shot moves to the Hangar), the unpushed `docs-support-2.1` branch (where to change the menu theme), and `Tools/release_check.sh`.
- With only Classic in Helicopters and Pipes, those sections are thin. Show only the real Classic item, with nothing that looks like a locked item and no "more are on the way" sentence (owner decision, 2026-10-12: it reads as placeholder content and is unnecessary).

**What moves and what stays**

- **Moves to the Hangar:** Menu Theme (Night Sky, Parchment, Neon Night). It is a personal look, and every theme already meets WCAG AA, so it fits with the helicopter and pipe skins.
- **Stays in Settings:** Colour Accessibility palettes (High Contrast, the colour-vision palettes, Low Luminance), Helicopter Outline, and every other comfort option. These are accessibility features, not looks, and caregivers expect to find them in Settings. Ground rule 2 still applies: themes stay free forever.
- **Settings keeps a pointer:** where the Visual Theme section was, one button, **"Menu Theme: Night Sky. Change it in the Hangar"**, opens the Hangar. Players and caregivers who learned the old place are not stranded.
- **Caregiver lock covers the Hangar.** When Settings is locked, Hangar items are disabled (dimmed, as in Settings) with the line "Locked by a caregiver in Settings." A light theme can be a vision need, so a locked device must not let it change by accident.
- **Reset Settings** resets the theme (as today) and, from step 2, the chosen helicopter and pipe skins to Classic (owner decision, 2026-10-12). It never removes or restores purchases: in Phase 2, ownership comes from StoreKit entitlements, not from `GameSettings`, so Reset cannot touch it. Update the Reset confirmation text to say the look is reset too.

**No "coming soon" tiles or sentences.** App Review Guideline 2.1 rejects placeholder content, and for switch and VoiceOver users a locked tile is a scan stop that does nothing. Each section shows only what really exists (at first only **Classic**, equipped).

#### Step 1 — Hangar screen, themes moved (one session, no new art) — done 2026-10-12

- Add `Screen.hangar` and `HangarViewController` (a `ScreenViewController`, presented only through `RootViewController.present(_:)`; list its scanner in `scannersDuringTransition`).
- Home order: **Play, Hangar, Settings, How to Play** (`HomeAction.hangar`, hint "Changes how the game looks").
- **Reuse the Settings panel machinery, don't copy it.** Pull the generic half of `SettingsPanelView` (Back header, scrolling stack, focus ring, control scanner, `controls(in:)`, rebuild that keeps scroll and focus) into a shared base, for example `ScrollingPanelView`, with `SettingsPanelView` and `HangarPanelView` as subclasses. `SettingsStyle` becomes the shared style. This keeps switch, VoiceOver, Voice Control, and Dynamic Type behaviour identical and gives the Hangar the tested rebuild-on-theme-change path for free. Do this extraction as its own commit first, with the full test suite green, before adding the Hangar.
- **Theme cards:** one button per theme, like the palette swatches: a small preview (background, a button chip, title text in the theme's colours) and the name. Label "Night Sky", trait `.selected` on the chosen one; VoiceOver hint "Menu theme". Choosing one saves `selectedThemeID` and rebuilds the panel, keeping focus on the card.
- Sections, in order: **Menu Theme**, **Helicopters** (Classic, Equipped), **Pipes** (the same). The Classic cards in step 1 are static (not buttons, so not scanned); they become buttons in step 2.
- Settings: remove the Visual Theme section and add the pointer button. Update the Colour Accessibility description ("Independent of the menu theme above" → "Independent of the menu theme in the Hangar").
- Tests to update: `GameLifecycleTests` uses "Menu Theme" in the Settings label list, `settingsSwitchPreservesFocusAcrossThemePresetAndLockRebuilds`, and the segmented-scanner test near line 880; move the theme parts to new Hangar tests. Add: Home item order; theme card selection persists and rebuilds with focus kept; the lock disables Hangar items; the scanner reaches every Hangar control in Timed and Step modes; Back returns Home. Add the Hangar to the `HelichopterUITests` audit walk.
- Store screenshots: Home now has four buttons, and screenshot 4 shows themes in Settings. Re-capture all three sets for 2.1 after step 2 (move the theme shot to the Hangar).

#### Step 2 — Skin plumbing with only Classic (one session, no new art)

- `Utils/Cosmetics.swift` with the data model below. `CosmeticsCatalog.all` holds `heli.classic` and `pipe.classic`.
- `GameSettings.selectedHelicopterSkinID` / `selectedPipeSkinID` (`gs_` keys, unknown or unowned IDs fall back to Classic).
- Replace the hard-coded art names (six places today): `"Helicopter Player"` in `HomeViewController.swift` (twice), `UserDefaults.swift`, and `HangarPanelView.swift` (the Classic card picture), and `pipe-yellow` / `cap-yellow` in `PipeFactory.swift` (twice) and `pipe-yellow` in `HangarPanelView.swift`.
- Classic cards become real buttons ("Classic Helicopter. Equipped."), so step 3 only adds catalog entries and art.
- A Hangar preview at the top (the equipped helicopter between two equipped pipes in the current theme and palette, static under Reduce Motion) is optional here; add it once there is more than one item to compare.

#### Step 3 — First real new items, then release 2.2 (after 2.1)

- **A patterned pipe set, free** (stripes or dots). It is the roadmap's "Differentiate without colour" item, can be drawn by `Tools/` scripts with no outside art rights, and gives the Pipes section a real second choice. Consider also turning it on automatically when iOS Differentiate Without Color is on.
- **One extra free helicopter** made with `Tools/helicopter-kit/make_frames.py` (extend it to take an input image and output name).
- Contrast tests: run every skin through all 18 theme/palette combinations (extend `renderedGameplayBoundariesAcrossEveryThemeAndPalette`).
- Record new art in `Release/ASSET_RIGHTS.md`. Bump to 2.2 (build 1) at the start of this step. Device check with a switch and VoiceOver, then ship 2.2.

Phase 2 (purchases) then adds paid items to the same catalog with no screen redesign.

**Data model** (step 2)

```swift
enum CosmeticKind { case helicopter, pipe }

struct Cosmetic: Identifiable {
    let id: String              // "heli.classic", "pipe.brick"
    let kind: CosmeticKind
    let name: String            // shown and spoken: "Rescue Helicopter"
    let spokenDescription: String // "Red and white, with a winch"
    let assetName: String       // atlas name, or pipe texture prefix
    let productID: String?      // nil = free
}
```

**Art rules for every skin** (enforced by tests where possible)

- Same canvas size and similar silhouette size as the current helicopter, so the contrast marker and hitbox stay correct.
- Provide colour art for the Default palette **and** a greyscale version for the accessibility palettes. Recommended: the converter generates the greyscale version automatically, so artists draw only once. When any non-Default palette or the Parchment theme tint is active, the greyscale version is used and tinted, exactly as today.
- Pipe skins are 9-slice textures with the same slice proportions (top and bottom sixth fixed) and cap ratio as the current pipe.
- No flashing or strobing. Animated details stop under Reduce Motion.
- Every new image is recorded in `Release/ASSET_RIGHTS.md` before it ships.

**Hangar accessibility** (all steps)

- Grid of cards at normal text sizes; a single-column list at accessibility text sizes.
- Scanner order: Back, then each item in order (preview and static cards skipped). Focus is restored after an item is chosen.
- VoiceOver: "Rescue Helicopter. Red and white, with a winch. Equipped." Choosing posts an announcement. Section titles are headings for the rotor.
- First-run guide: unchanged. Optionally mention the Hangar on the last page.

### Phase 2 — In-app purchases (StoreKit 2)

**Product design (owner decides the details)**

- Non-consumable products only, one per skin, plus optional bundles. Suggested starting point: individual skins at the lowest tier ($0.99), a bundle of all launch skins at about $2.99.
- Product IDs: `com.nathanmayo.helichopter.skin.heli.<name>`, `com.nathanmayo.helichopter.skin.pipe.<name>`, `com.nathanmayo.helichopter.bundle.<name>`.
- Turn on **Family Sharing** for each product. Many players share an iPad with family or carers.
- Prices are always read from `Product.displayPrice`; never hard-code a price string.

**Code** (new file, for example `Store/StoreManager.swift`)

- Load products with `Product.products(for:)` when the Hangar opens.
- Buy with `product.purchase()`. Handle all results: success (verify the transaction, then `finish()` it), `.userCancelled` (do nothing), `.pending` (Ask to Buy: show "Waiting for approval"), and errors (plain message, no technical codes).
- At app launch, start a listener on `Transaction.updates` so approvals, purchases on other devices, and refunds arrive while the app is running.
- Owned items = `Transaction.currentEntitlements`, ignoring revoked transactions. A refunded skin stops being owned; if it was equipped, switch back to the default without fuss.
- **Restore Purchases** calls `AppStore.sync()`. Apple requires a restore mechanism for non-consumables (Guideline 3.1.1).
- Offline: owned skins still work (StoreKit caches entitlements). If products cannot load, the Hangar shows owned and free skins plus "The store is unavailable right now" with a Retry button.
- Keep the store code out of `GameSettings`; `GameSettings` only stores the selected IDs.

**Accessibility of buying**

- The purchase confirmation is Apple's system sheet. The app's own switch scanner cannot operate it; iOS Switch Control, VoiceOver, and AssistiveTouch can. Before the system sheet opens, speak and show: "Apple will ask you to confirm. Use your device's Switch Control or Face ID / Touch ID / passcode." Document this in support pages and review notes.
- The Buy and Restore buttons are scannable, labelled with the localised price ("Buy Rescue Helicopter for 99 cents"), and disabled while a purchase is in progress.

**Local testing**

- Add a StoreKit configuration file (`Helichopter.storekit`) to the scheme for simulator testing.
- Unit tests with `SKTestSession` (StoreKitTest): purchase, cancel, Ask to Buy (pending then approved and declined), refund/revocation, restore, and offline product load failure.
- Sandbox purchases on a physical device, including with Switch Control turned on.

### Phase 3 — Optional later additions

- New skin sets added in updates (each needs its art rights recorded and contrast tests).
- Pipe skins with patterns (stripes, dots). These double as the long-planned "differentiate without colour" feature; consider shipping a patterned pipe set free for that reason.
- A "Supporter" non-consumable that unlocks nothing extra but thanks the player, if the owner wants a simple way to support the app.

---

## 3. App Store Connect, legal, and privacy checklist (owner tasks marked)

Do these before submitting the first version with purchases.

- [ ] **Owner:** Accept the **Paid Applications Agreement** and complete tax and banking in App Store Connect → Business.
- [ ] **Owner:** Enrol in the **App Store Small Business Program** (15% commission instead of 30%).
- [ ] **Owner:** Change the **EU Digital Services Act status to trader.** Selling in-app purchases makes the developer a trader. Apple then shows the trader's address, phone number, and email on EU storefronts. Decide which contact details to publish before this step; EU distribution is blocked until it is complete.
- [ ] **Owner:** Create each in-app purchase product (reference name, product ID, price, display name and description, review screenshot), and enable Family Sharing. The first purchases must be submitted together with an app version.
- [ ] Review the **age-rating questionnaire** again with purchases included.
- [ ] Update the **privacy policy** (`docs/privacy.html` and its date). Today it says the app never connects to the internet; with purchases, the app contacts Apple to process them. Apple handles payment; the developer receives no personal information. Update `AppLinks.privacySummary` to match.
- [ ] Recheck the **App Privacy answers**. If the app itself stores and sends nothing (StoreKit only, no server, no analytics), "Data Not Collected" should still apply, because data Apple collects for its own payment processing is not the developer's to declare. Confirm against Apple's [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/) at the time.
- [ ] `PrivacyInfo.xcprivacy`: no change expected unless new required-reason APIs are used. Re-run `Tools/release_check.sh`, and update it to expect StoreKit instead of warning about it.
- [ ] Update `Release/APP_STORE_COPY.md` and the listing: remove "without … in-app purchases" from the description, add "All accessibility features are free; optional purchases change only how the helicopter and pipes look", and add sandbox instructions to the review notes.
- [ ] Add each new skin to `Release/ASSET_RIGHTS.md` (author, tool, date, AI tool terms if used).
- [ ] Update `docs/support.html` with how to restore purchases and request refunds (refunds go through Apple at reportaproblem.apple.com).

---

## 4. Decisions needed from the owner

1. Name of the screen: **Hangar** (recommended: friendly, not salesy) or **Store**.
2. Launch skins: how many helicopters and pipe styles, and which are free. Recommended: 1 free + 3 paid helicopters, 1 free + 2 paid pipe styles.
3. Prices and whether to offer a bundle.
4. Colour skins with automatic greyscale versions (recommended), or greyscale-only skins that take colour from the palette.
5. ~~Whether Reset Settings also resets the chosen skins.~~ Decided 2026-10-12: yes, theme and skins return to the defaults; purchases are never affected.
6. Which public contact details to use for EU trader status.

## 5. Done when

- [ ] Phase 1 shipped: Hangar with free skins, all tests green, contrast tests cover every skin, device-checked with a switch and VoiceOver.
- [ ] Phase 2 shipped: purchases, restore, Ask to Buy, and refunds verified in sandbox on a device, App Store Connect and legal checklist complete, privacy text updated.
- [ ] Docs updated (`HELICHOPTER_PROJECT.md` architecture table, `CLAUDE.md` privacy note, progress log).
