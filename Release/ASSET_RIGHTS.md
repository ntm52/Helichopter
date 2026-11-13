# Asset provenance and rights register

Updated November 11, 2026 (2.2 skins added); owner's statements from October 1, 2026. Apple Guideline 5.2 requires rights to every asset in the app. Keep the evidence below current, and update this file whenever an asset is added or replaced.

## Owner statement (October 1, 2026)

All visual assets (helicopter, pipes, background, buttons, launch image, app icon) were made by the owner, either by hand or with AI assistance (Codex). No third-party artwork, stock images, or trademarked characters were used. The sound effects were made by the owner in GarageBand. The original music track's source was unknown, so it was replaced with a documented CC0 track (below).

AI-assisted output made by the owner for this app may be used commercially. Confirm the AI tool's terms permit commercial use of its output; OpenAI's terms assign output to the user.

| Material | Source | Status |
|---|---|---|
| Original project code | Root `LICENSE`: BSD 3-Clause, copyright 2018 Astemir Eleev | Allowed, including commercially and with in-app purchases. The copyright notice and disclaimer must ship with the app (planned Acknowledgements screen). |
| Helicopter (60 frames) | Owner-made; source and converter in `Tools/helicopter-kit/` | Cleared by owner statement |
| Two Tone Helicopter (60 frames, `Helicopter Two-Tone.spriteatlas`), added Nov 11, 2026 for 2.2 | The owner's Classic helicopter art, repainted by `Tools/helicopter-kit/make_frames.py two-tone` (darkens the panels below the waistline). Script written with Claude Code; no outside artwork. | Cleared: derived only from owner-made art |
| Striped Pipes (`pipe-striped`, `cap-striped`), added Nov 11, 2026 for 2.2 | Body drawn entirely by `Tools/pipe-kit/make_pipes.py` (diagonal stripes; script written with Claude Code). The cap is a copy of the owner's Classic cap. No outside artwork. | Cleared: script-drawn plus owner-made art. Confirm the AI tool's terms permit commercial use of its output, as for the other AI-assisted art. |
| Launch screen helicopter (`LaunchHelicopter`), changed Nov 11, 2026 | Frame 1 of the owner's Classic helicopter atlas, copied. Replaces the owner's earlier hand-drawn green helicopter (`LaunchScreen` image set, deleted). | Cleared: owner-made art |
| Pipes, caps, background, launch image, UI buttons | Owner-made (local GIMP files in the sibling `Helichopter Assets/` folder) | Cleared by owner statement |
| App icon, redrawn Nov 12, 2026 for 2.2 | The owner's Classic helicopter body (`Tools/helicopter-kit/helicopter_body.png`) placed by `Tools/icon-kit/make_icon.py` on a script-drawn navy sky and amber circle, with a script-drawn rotor blade (script written with Claude Code). No outside artwork. Replaces the owner's earlier icon. | Cleared: owner-made art plus script-drawn shapes |
| Parchment game background (`BackgroundParchment`), added Nov 12, 2026 for 2.2 | Drawn entirely by `Tools/background-kit/make_parchment.py` (script written with Claude Code): flat colours, circles, lines, and arcs. No outside artwork. | Cleared: script-drawn |
| Helicopter cartoon look, Nov 12, 2026 for 2.2 | The owner's helicopter art with thicker lines, stronger colour, and script-drawn rotor blades, applied by `Tools/helicopter-kit/make_frames.py` (`cartoonify`). It changes both helicopters, the launch picture, and the app icon. No outside artwork. | Cleared: derived only from owner-made art |
| Launch screen sky (`LaunchBackground`), recropped Nov 12, 2026 | The top 512 × 1200 pt of the owner's `Background` starfield (it was the middle), so it lines up with Home. | Cleared: owner-made art |
| Particle sprites (`Assets/Particles/`) | Inherited from the original BSD project | Covered by the BSD licence; remove if unused |
| Effects `Score.caf`, `Dead.caf` | **Made by the owner in GarageBand** (Mar 26, 2021). The original WAVs in `Helichopter Assets/Sounds/` carry GarageBand's file tag and tempo marker. | Cleared. GarageBand's licence allows royalty-free use of its sounds in your own creations. |
| Music `MainTheme.caf` (2 min 5 s) | Replaced Oct 1, 2026 with ["Louswan - Simple Magestic Choir Melody (Soulja Unit Edit)"](https://freesound.org/people/SouljaUnit/sounds/843337/) by SouljaUnit, an edit of ["Simple Majestic Choir Melody"](https://freesound.org/people/Louswan/sounds/843183/) by Louswan. Both are **Creative Commons 0** (licence pages checked on Oct 1, 2026). Converted from Freesound's public HQ preview (196 kbps MP3) to 128 kbps AAC, with gain lowered 6.2 dB to match the old track. | Cleared. CC0 needs no credit, but the app credits both authors in Settings → Acknowledgements. Optionally download the original from Freesound (login required) for a lossless master. |

## Evidence to keep (outside the repo is fine)

- For each sound: the download page URL, licence text or a screenshot of it, and the download date.
- Original working files for the artwork, such as GIMP sources and prompts, as proof of authorship.
