# Privacy and support page drafts

Prepared September 8, 2026 from the local source. Publication is pending: replace the contact placeholder with a monitored address, approve the support handling statement, and select public URLs. The app's Settings privacy link must use the published URL. This document does not complete that release requirement.

## Privacy policy — publication copy

Helichopter is an offline helicopter game for iPhone and iPad. It does not require an account and does not include advertising, in-app purchases, third-party analytics, or tracking.

The app stores gameplay settings, scores, and whether you have completed the introductory guide on your device. This information is used to remember your preferences and progress. The app does not send it to the developer or an app-operated server. Device backups may include app data according to your Apple device settings.

Reset Settings restores preferences and retains saved scores and guide completion. Removing the app removes its local app data; backup copies are managed through your Apple device and backup settings.

If you contact support, your message and contact details are used to respond to your request. Do not include sensitive personal information in support messages. [OWNER: confirm this support practice and add a monitored contact address before publication.]

Apple's services, including the App Store and device backups, operate under Apple's own privacy policies.

This policy describes the current app. It will be updated if the app's data practices change.

Privacy questions: [MONITORED SUPPORT EMAIL]

## Support — publication copy

### Getting started

Choose Play to begin, or open How to Play for the guide. The helicopter waits for your first flight input before pipes begin appearing. Settings offers Gentle, Standard, and Challenge difficulty presets.

### Making play more comfortable

Turn on No-Fail Mode to keep flying after collisions. Calm Mode removes collision sounds and vibration. Background Scroll can be set to Still; music and sound effects have separate switches. You can hide the score and change colours and themes.

### Switch controls

Space or Enter starts scanning or selects the highlighted item. With timed scanning, wait until the desired item is highlighted and select it. With Two-Switch menu scanning, press 2 to advance and your primary switch to select. Select sliders to open Decrease, Increase, and Done.

Hold the primary keyboard/controller switch for 3 seconds during gameplay to pause, then release before choosing a menu item. Increase Hold Switch to Pause in Settings if you need longer hover holds.

### VoiceOver and larger text

During flight, focus Helicopter flight control and use double-tap and its custom actions. The Pause action or accessibility escape opens the pause menu. Spoken gap guidance is periodic. Larger Text in iOS Accessibility settings changes app menu and Settings text.

### Restoring settings

Open Settings → Reset Settings. Choose Cancel to keep your setup, or Restore Defaults to return to Standard difficulty and default controls, theme, and audio. Scores and guide completion are kept. If settings are locked, turn off Lock Settings first.

### Contact

Contact [MONITORED SUPPORT EMAIL]. Include your device model, iOS version, app version, and a short description of what happened. For accessibility issues, mention the input method or assistive feature you were using if you are comfortable sharing it. No account or password is needed.

## Submission evidence

The reviewed Swift source uses local UserDefaults and Apple frameworks; no networking, advertising, purchase, or third-party analytics implementation was found. The bundled root `PrivacyInfo.xcprivacy` declares no tracking or collected data and the UserDefaults CA92.1 reason. The proposed App Privacy answer is “Data Not Collected” for the current app, subject to confirmation of the final binary and any support service added later. Apple's [privacy detail instructions](https://developer.apple.com/app-store/app-privacy-details/) require a public policy URL; the [review guidelines](https://developer.apple.com/app-store/review/guidelines/) also require accessible in-app policy access and a support contact.
