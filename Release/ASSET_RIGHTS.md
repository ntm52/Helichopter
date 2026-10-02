# Asset provenance and rights register

Updated October 1, 2026 with the owner's statements. Apple Guideline 5.2 requires rights to every asset in the app. Keep the evidence below current, and update this file whenever an asset is added or replaced.

## Owner statement (October 1, 2026)

All visual assets (helicopter, pipes, background, buttons, launch image, app icon) were made by the owner, either by hand or with AI assistance (Codex). No third-party artwork, stock images, or trademarked characters were used. The sound effects were made by the owner in GarageBand. The original music track's source was unknown, so it was replaced with a documented CC0 track (below).

AI-assisted output made by the owner for this app may be used commercially. Confirm the AI tool's terms permit commercial use of its output; OpenAI's terms assign output to the user.

| Material | Source | Status |
|---|---|---|
| Original project code | Root `LICENSE`: BSD 3-Clause, copyright 2018 Astemir Eleev | Allowed, including commercially and with in-app purchases. The copyright notice and disclaimer must ship with the app (planned Acknowledgements screen). |
| Helicopter (60 frames) | Owner-made; source and converter in `Tools/helicopter-kit/` | Cleared by owner statement |
| Pipes, caps, background, launch image, UI buttons | Owner-made (local GIMP files in the sibling `Helichopter Assets/` folder) | Cleared by owner statement |
| App icon | Owner-made | Cleared by owner statement |
| Particle sprites (`Assets/Particles/`) | Inherited from the original BSD project | Covered by the BSD licence; remove if unused |
| Effects `Score.caf`, `Dead.caf` | **Made by the owner in GarageBand** (Mar 26, 2021). The original WAVs in `Helichopter Assets/Sounds/` carry GarageBand's file tag and tempo marker. | Cleared. GarageBand's licence allows royalty-free use of its sounds in your own creations. |
| Music `MainTheme.caf` (2 min 5 s) | Replaced Oct 1, 2026 with ["Louswan - Simple Magestic Choir Melody (Soulja Unit Edit)"](https://freesound.org/people/SouljaUnit/sounds/843337/) by SouljaUnit, an edit of ["Simple Majestic Choir Melody"](https://freesound.org/people/Louswan/sounds/843183/) by Louswan. Both are **Creative Commons 0** (licence pages checked on Oct 1, 2026). Converted from Freesound's public HQ preview (196 kbps MP3) to 128 kbps AAC, with gain lowered 6.2 dB to match the old track. | Cleared. CC0 needs no credit, but the app credits both authors in Settings → Acknowledgements. Optionally download the original from Freesound (login required) for a lossless master. |

## Evidence to keep (outside the repo is fine)

- For each sound: the download page URL, licence text or a screenshot of it, and the download date.
- Original working files for the artwork, such as GIMP sources and prompts, as proof of authorship.
