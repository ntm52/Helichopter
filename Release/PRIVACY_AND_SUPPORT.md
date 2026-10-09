# Privacy policy and support pages

The published pages live in [`docs/`](../docs/) and are served by GitHub Pages:

- Privacy policy: https://ntm52.github.io/Helichopter/privacy.html
- Support: https://ntm52.github.io/Helichopter/support.html
- Contact: helichopter.support@gmail.com

Edit the HTML in `docs/` directly; there is no separate draft. If the app's data practices ever change (analytics, purchases, crash reporting, or any network access), update `privacy.html` and its effective date, `AppLinks.privacySummary` in `Scenes/AppLinks.swift`, `PrivacyInfo.xcprivacy`, and the App Privacy answers in App Store Connect together.

GitHub Pages must be enabled once: repository Settings → Pages → Build and deployment → Source: "Deploy from a branch", Branch: `master`, folder `/docs`.

## Submission evidence

The reviewed Swift source uses local UserDefaults and Apple frameworks; no networking, advertising, purchase, or third-party analytics implementation was found. The bundled root `PrivacyInfo.xcprivacy` declares no tracking or collected data and the UserDefaults CA92.1 reason. The proposed App Privacy answer is “Data Not Collected” for the current app, subject to confirmation of the final binary and any support service added later. Apple's [privacy detail instructions](https://developer.apple.com/app-store/app-privacy-details/) require a public policy URL; the [review guidelines](https://developer.apple.com/app-store/review/guidelines/) also require accessible in-app policy access and a support contact.
