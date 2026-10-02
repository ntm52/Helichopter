# Asset provenance and rights register

Updated October 1, 2026 with the owner's statements. Apple Guideline 5.2 requires rights to every asset in the app. Keep the evidence below current, and update this file whenever an asset is added or replaced.

## Owner statement (October 1, 2026)

All visual assets (helicopter, pipes, background, buttons, launch image, app icon) were made by the owner, either by hand or with AI assistance (Codex). No third-party artwork, stock images, or trademarked characters were used. All sound and music comes from an open-source, royalty-free sound website.

AI-assisted output made by the owner for this app may be used commercially. Confirm the AI tool's terms permit commercial use of its output; OpenAI's terms assign output to the user.

| Material | Source | Status |
|---|---|---|
| Original project code | Root `LICENSE`: BSD 3-Clause, copyright 2018 Astemir Eleev | Allowed, including commercially and with in-app purchases. The copyright notice and disclaimer must ship with the app (planned Acknowledgements screen). |
| Helicopter (60 frames) | Owner-made; source and converter in `Tools/helicopter-kit/` | Cleared by owner statement |
| Pipes, caps, background, launch image, UI buttons | Owner-made (local GIMP files in the sibling `Helichopter Assets/` folder) | Cleared by owner statement |
| App icon | Owner-made | Cleared by owner statement |
| Particle sprites (`Assets/Particles/`) | Inherited from the original BSD project | Covered by the BSD licence; remove if unused |
| Music `MainTheme.caf`, effects `Score.caf`, `Dead.caf` | Open-source royalty-free sound website | **To record:** site name, page URL for each sound, and the licence name. "Royalty-free" licences differ: CC0 needs nothing; CC-BY requires a credit line; some site licences forbid redistribution of the raw file. Add any required credits to the Acknowledgements screen. |

## Evidence to keep (outside the repo is fine)

- For each sound: the download page URL, licence text or a screenshot of it, and the download date.
- Original working files for the artwork, such as GIMP sources and prompts, as proof of authorship.
