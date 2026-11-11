HELICOPTER ANIMATION KIT — GAME INTEGRATION

Source artwork and Pillow converter supplied in helicopter-kit.zip.
Run from the repository root with Python 3 and Pillow installed:

    python3 Tools/helicopter-kit/make_frames.py             (every skin)
    python3 Tools/helicopter-kit/make_frames.py two-tone    (one skin)

Each skin in the script's SKINS table is the same helicopter_body.png,
optionally repainted, written to its own atlas of 60 frames at 1x/2x/3x.
Image names must be unique across the asset catalog, so each skin has its
own frame prefix:

    classic    Helicopter Player.spriteatlas     r_player1..60    the art as drawn
    two-tone   Helicopter Two-Tone.spriteatlas   r_twotone1..60   dark underside (2.2)

Atlases live inside Assets.xcassets, so no target or scene-file changes are
needed. To add a helicopter: add a painter and a SKINS entry here, run the
script, then add the atlas name and frame prefix to CosmeticsCatalog (Utils/Cosmetics.swift)
and record the art in Release/ASSET_RIGHTS.md. Alpha is never repainted, so
every skin keeps the same outline, crop, and hitbox.

Local output/ contains 200-, 400-, and 600-pixel PNG sets and an animated
preview.png (other skins: output/<skin>/). These intermediate exports are ignored by Git.

Integration changes from the supplied converter:
- 60 samples per second instead of 20, retaining three rotor cycles/second.
- Alpha values <= 5 are cleared before measuring the common crop; the source
  has nearly invisible pixels far outside the helicopter.
- Output assets use the game's existing atlas and frame naming convention.

Every frame uses the same body, crop, canvas, scale, and anchor. Only the
rotor changes. HelicopterNode.rotorFrameInterval controls playback in both
the title and game scenes. Reduce Motion still shows a stationary frame.
The game's light palette tint preserves the cockpit and shading.

HUB and RADIUS use fractions of the original artwork dimensions. Adjust
these if replacing the source. The blades are stylized, not physical RPM.
