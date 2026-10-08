# Plan 02 — Cosmetic skins, Hangar screen, and in-app purchases

**Status:** Not started. Written 2026-10-08.
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

### Phase 1 — Skin system and Hangar, free skins only (no StoreKit)

Build and ship the whole cosmetic system with 1–2 free skins per type. This proves the art pipeline, contrast, and the screen before money is involved, and gives every player something new.

**Data model** (new file, for example `Utils/Cosmetics.swift`)

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

- A static `CosmeticsCatalog.all` list. The current art becomes `heli.classic` and `pipe.classic`, the defaults.
- `GameSettings` gains `selectedHelicopterSkinID` and `selectedPipeSkinID` (`gs_` keys, validated like other settings). If a saved ID is unknown or not owned, fall back to the default. **Reset Settings keeps the chosen skin** (it is not a setting that harms play), or resets it; owner to decide.

**Rendering changes**

- Replace the hard-coded `"Helicopter Player"` (in `TitleScene`/Home, `SceneTextOverlay`, `UserDefaults.swift`) with the selected skin's atlas name.
- Replace the hard-coded `pipe-yellow`/`cap-yellow` in `PipeFactory` with the selected pipe skin's textures.
- Each helicopter skin is a new 60-frame atlas (`Helicopter <Name>.spriteatlas`) produced by `Tools/helicopter-kit/make_frames.py`. Extend the script to take an input image and output name.

**Art rules for every skin** (enforced by tests where possible)

- Same canvas size and similar silhouette size as the current helicopter, so the contrast marker and hitbox stay correct.
- Provide colour art for the Default palette **and** a greyscale version for the accessibility palettes. Recommended: the converter generates the greyscale version automatically, so artists draw only once. When any non-Default palette or the Parchment theme tint is active, the greyscale version is used and tinted, exactly as today.
- Pipe skins are 9-slice textures with the same slice proportions (top and bottom sixth fixed) and cap ratio as the current pipe.
- No flashing or strobing. Animated details stop under Reduce Motion.
- Every new image is recorded in `Release/ASSET_RIGHTS.md` before it ships.

**Hangar screen** (`HangarViewController`, opened from a new Home button)

- Top: a live preview of the selected helicopter between two of the selected pipes, using the current theme and palette. Static under Reduce Motion.
- Two sections: **Helicopters** and **Pipes**. Each item is a card with a preview, name, and one action: **Equipped**, **Equip**, or (Phase 2) **Buy – price**.
- Bottom: **Back** (and in Phase 2 **Restore Purchases**).
- Grid at normal text sizes; a single-column list at accessibility text sizes.
- Scanner order: Back, then preview (skipped), then each item in order. Scanning works in timed and two-switch modes, and focus is restored after an item is equipped.
- VoiceOver: "Rescue Helicopter. Red and white, with a winch. Equipped." Equipping posts an announcement.
- First-run guide: unchanged. Optionally mention the Hangar on the last page.

**Tests**

- Every catalog entry has its assets: 60 frames at 1×/2×/3× for helicopters; body and cap textures for pipes.
- Extend `PaletteContrastTests` to run every skin through all 18 theme/palette combinations.
- Selection falls back to the default for unknown or unowned IDs.
- The scanner reaches every Hangar control; Dynamic Type layout at the largest size; VoiceOver labels exist for each card.

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
5. Whether Reset Settings also resets the chosen skins.
6. Which public contact details to use for EU trader status.

## 5. Done when

- [ ] Phase 1 shipped: Hangar with free skins, all tests green, contrast tests cover every skin, device-checked with a switch and VoiceOver.
- [ ] Phase 2 shipped: purchases, restore, Ask to Buy, and refunds verified in sandbox on a device, App Store Connect and legal checklist complete, privacy text updated.
- [ ] Docs updated (`HELICHOPTER_PROJECT.md` architecture table, `CLAUDE.md` privacy note, progress log).
