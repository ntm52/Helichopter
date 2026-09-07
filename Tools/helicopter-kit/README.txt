HELICOPTER ANIMATION KIT — GAME INTEGRATION

Source artwork and Pillow converter supplied in helicopter-kit.zip.
Run from the repository root with Python 3 and Pillow installed:

    python3 Tools/helicopter-kit/make_frames.py

The converter updates the game's existing Helicopter Player.spriteatlas
(r_player1 through r_player60, each at 1x/2x/3x). Xcode already includes
this atlas, so no target or scene-file changes are needed.

Local output/ contains 200-, 400-, and 600-pixel PNG sets and an animated
preview.png. These intermediate exports are ignored by Git.

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
