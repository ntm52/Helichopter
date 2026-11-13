"""Run: python3 make_frames.py [skin ...] (requires Pillow).

With no arguments every skin in SKINS is rebuilt; name one or more to rebuild only those,
for example `python3 make_frames.py two-tone`. Every skin is painted from the same
helicopter_body.png, so the outline, crop, canvas, and hitbox are identical.
"""
from pathlib import Path
import json
import math
import sys
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'output'
FRAMES = 60
# Normalized coordinates measured from the supplied source artwork.
HUB = (0.608, 0.435)
RADIUS = 0.32
TILT = 0.13

# The cartoon look (Plan 03, 2026-11-12): every dark line is LINE_GROWTH pixels thicker
# and colours are a little stronger, to match the app's bold outlines. Change these two
# numbers to make it stronger or weaker; 1 and 1.0 give the art exactly as drawn.
LINE_GROWTH = 7
COLOUR_BOOST = 1.25
INK = (0x1B, 0x1F, 0x2A)
BLADE_FILL = '#E8EDF5'
# Half-widths of a rotor blade at the hub and at the tip, and its outline, in source pixels.
BLADE_ROOT, BLADE_TIP, BLADE_OUTLINE = 44, 66, 5

def cartoonify(body):
    """Thicken the outline and inner lines and strengthen colour. Alpha is untouched, so
    the silhouette, crop, and hitbox stay exactly as drawn: the outer line grows inward."""
    alpha = body.getchannel('A')
    flat = Image.new('RGB', body.size, INK)
    flat.paste(body.convert('RGB'), mask=alpha)
    # Each pixel takes the darkest colour near it, which widens every dark line.
    bold = flat.filter(ImageFilter.MinFilter(LINE_GROWTH)).filter(ImageFilter.GaussianBlur(0.8))
    bold = ImageEnhance.Color(bold).enhance(COLOUR_BOOST).convert('RGBA')
    bold.putalpha(alpha)
    return bold

def prepared_body(painter=None):
    """The source art, cleaned, repainted for a skin if asked, then given the cartoon look.
    The app icon (Tools/icon-kit) uses this too, so it always matches the game."""
    body = Image.open(ROOT / 'helicopter_body.png').convert('RGBA')
    # Ignore near-transparent export noise so it cannot change the shared crop.
    body.putalpha(body.getchannel('A').point(lambda alpha: 0 if alpha <= 5 else alpha))
    if painter is not None:
        body = painter(body)
    return cartoonify(body)

def paint_two_tone(body):
    """Darken the body panels below the waistline. Glass, outlines, and alpha are untouched."""
    w, h = body.size
    rgb = body.convert('RGB')
    _, saturation, value = rgb.convert('HSV').split()
    # Paint only bright, unsaturated pixels (the white panels), fading out toward the dark
    # outline and the blue glass so edges stay smooth.
    bright = value.point(lambda v: max(0, min(255, round((v - 120) * 255 / 60))))
    grey = saturation.point(lambda s: max(0, min(255, round((40 - s) * 255 / 20))))
    below = Image.new('L', (w, h), 0)
    ImageDraw.Draw(below).rectangle((0, round(h * TWO_TONE_WAIST), w, h), fill=255)
    weight = ImageChops.multiply(ImageChops.multiply(bright, grey), below)
    dark = rgb.point(lambda c: round(c * TWO_TONE_SHADE))
    painted = Image.composite(dark, rgb, weight)
    painted.putalpha(body.getchannel('A'))
    return painted

# Fraction of the artwork height where the dark underside starts, and how dark it is.
TWO_TONE_WAIST = 0.665
TWO_TONE_SHADE = 0.43

# Skin key -> (texture atlas name, frame name prefix, painter applied to the body, or None
# for the art as drawn). An asset catalog needs every image name to be unique, so each skin
# has its own prefix. Both names must match `CosmeticsCatalog` in Utils/Cosmetics.swift.
SKINS = {
    'classic': ('Helicopter Player', 'r_player', None),
    'two-tone': ('Helicopter Two-Tone', 'r_twotone', paint_two_tone),
}

def main():
    keys = sys.argv[1:] or list(SKINS)
    unknown = [key for key in keys if key not in SKINS]
    if unknown:
        raise SystemExit(f'Unknown skin {unknown}; choose from {list(SKINS)}')
    for key in keys:
        build(key)

def build(key):
    global OUT
    atlas_name, prefix, painter = SKINS[key]
    OUT = ROOT / 'output' if painter is None else ROOT / 'output' / key
    body = prepared_body(painter)
    w, h = body.size
    cx, cy = HUB[0] * w, HUB[1] * h
    radius = RADIUS * w
    box = body.getchannel('A').getbbox()
    if box is None:
        raise ValueError('Source image is empty')
    # One common crop for every frame; never center frames independently.
    left = math.floor(min(box[0], cx - radius - 8))
    top = math.floor(min(box[1], cy - (radius + BLADE_TIP) * TILT - 8))
    right = math.ceil(max(box[2], cx + radius + 8))
    bottom = math.ceil(box[3])
    crop = (left, top, right, bottom)
    atlas = ROOT.parents[1] / f'Helichopter/Assets/Assets.xcassets/Playable Characters/{atlas_name}.spriteatlas'
    atlas.mkdir(parents=True, exist_ok=True)
    (atlas / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2))
    previews = []
    for i in range(FRAMES):
        frame = body.copy()
        draw = ImageDraw.Draw(frame)
        # Identical opposing blades repeat after half a revolution.
        # 3 visual cycles per second gives a lively, seamlessly looping rotor.
        angle = 3 * math.pi * i / FRAMES
        for offset in (0, math.pi):
            a = angle + offset
            def project(radial, transverse):
                return (cx + radial * math.cos(a) - transverse * math.sin(a),
                        cy + (radial * math.sin(a) + transverse * math.cos(a)) * TILT)
            # Wide, light blades with an ink outline: the old hairline blades vanished
            # against the night sky.
            points = [project(7, -BLADE_ROOT), project(radius, -BLADE_TIP),
                      project(radius, BLADE_TIP), project(7, BLADE_ROOT)]
            draw.polygon(points, fill=BLADE_FILL, outline=INK, width=BLADE_OUTLINE)
        draw.ellipse((cx-22, cy-15, cx+22, cy+15), fill='#515965', outline=INK, width=8)
        cropped = frame.crop(crop)
        images = []
        imageset = atlas / f'{prefix}{i + 1}.imageset'
        imageset.mkdir(exist_ok=True)
        for scale, size in enumerate((200, 400, 600), 1):
            ratio = (size * 0.90) / max(cropped.size)
            resized = cropped.resize(tuple(round(d * ratio) for d in cropped.size), Image.Resampling.LANCZOS)
            canvas = Image.new('RGBA', (size, size))
            canvas.alpha_composite(resized, ((size-resized.width)//2, (size-resized.height)//2))
            folder = OUT / f'{size}x{size}'
            folder.mkdir(parents=True, exist_ok=True)
            name = f'helicopter_{i:02d}.png'
            canvas.save(folder / name)
            assetname = f'{prefix}{i + 1}' + ('' if scale == 1 else f'@{scale}x') + '.png'
            canvas.save(imageset / assetname)
            images.append({'idiom': 'universal', 'scale': f'{scale}x', 'filename': assetname})
            if size == 400:
                previews.append(canvas)
        (imageset / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2))
    # APNG preserves smooth transparent edges; each frame lasts 1/60 second.
    previews[0].save(OUT / 'preview.png', save_all=True, append_images=previews[1:], duration=1000 / FRAMES, loop=0, disposal=0, blend=0)
    for size in (200, 400, 600):
        files = list((OUT / f'{size}x{size}').glob('helicopter_*.png'))
        assert len(files) == FRAMES
        for path in files:
            with Image.open(path) as im:
                assert im.size == (size, size) and im.mode == 'RGBA'
    print(f'{key}: created 180 PNG frames, the {atlas_name} atlas, and a 1-second APNG preview in {OUT}')

if __name__ == '__main__':
    main()
