"""Run from the repository root: python3 Tools/icon-kit/make_icon.py (requires Pillow).

Draws the app icon from the Classic helicopter art (Tools/helicopter-kit/helicopter_body.png)
and writes every size listed in AppIcon.appiconset/Contents.json. The colours are the
Night Sky theme's (UITheme in Utils/GameSettings.swift): navy sky, amber accent, ink outline.

    python3 Tools/icon-kit/make_icon.py            writes the icon set
    python3 Tools/icon-kit/make_icon.py preview    also writes Tools/icon-kit/output/preview.png
"""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'helicopter-kit'))
from make_frames import prepared_body  # noqa: E402  (the same cartoon look as the game)

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
BODY = REPO / 'Tools/helicopter-kit/helicopter_body.png'
ICON_SET = REPO / 'Helichopter/Assets/Assets.xcassets/AppIcon.appiconset'

SIZE = 1024
SCALE = 2                      # Drawn at twice the size, then reduced, for smooth edges.
SKY_TOP = (0x0B, 0x14, 0x33)
SKY_BOTTOM = (0x27, 0x48, 0x8A)   # Night Sky raised surface
AMBER = (0xFF, 0xC8, 0x3D)        # Night Sky accent
INK = (0x05, 0x08, 0x14)          # Night Sky ink
BLADE = (0xF2, 0xF5, 0xFB)
# Rotor hub as a fraction of the artwork, as in helicopter-kit/make_frames.py.
HUB = (0.608, 0.435)
ROTOR_RADIUS = 0.36
ROTOR_THICKNESS = 0.030
OUTLINE = 0.006
# How much of the icon's width the helicopter and its rotor span, and its nose-up lean.
SPAN = 0.86
LEAN_DEGREES = 7

def sky(size):
    image = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM)))
    return image

def helicopter():
    """The body with one bold, level rotor blade: a hairline rotor vanishes at small sizes."""
    body = prepared_body()
    w, h = body.size
    cx, cy = HUB[0] * w, HUB[1] * h
    radius, half, line = ROTOR_RADIUS * w, ROTOR_THICKNESS * w / 2, OUTLINE * w
    rotor = Image.new('RGBA', body.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(rotor)
    draw.rounded_rectangle((cx - radius - line, cy - half - line, cx + radius + line, cy + half + line),
                           radius=half + line, fill=INK + (255,))
    draw.rounded_rectangle((cx - radius, cy - half, cx + radius, cy + half), radius=half, fill=BLADE + (255,))
    # The blade goes behind the hub, which is part of the body art.
    art = Image.alpha_composite(rotor, body)
    return art.crop(art.getchannel('A').getbbox())

def master():
    size = SIZE * SCALE
    icon = sky(size).convert('RGBA')
    # An amber moon behind the helicopter, so the white body reads at every size.
    moon = Image.new('RGBA', icon.size, (0, 0, 0, 0))
    r = round(size * 0.335)
    centre = (round(size * 0.5), round(size * 0.5))
    ImageDraw.Draw(moon).ellipse((centre[0] - r, centre[1] - r, centre[0] + r, centre[1] + r), fill=AMBER + (255,))
    icon = Image.alpha_composite(icon, moon)

    art = helicopter()
    width = round(size * SPAN)
    art = art.resize((width, round(art.height * width / art.width)), Image.LANCZOS)
    art = art.rotate(LEAN_DEGREES, resample=Image.BICUBIC, expand=True)
    # A soft shadow under the helicopter separates it from the moon.
    shadow = Image.new('RGBA', icon.size, (0, 0, 0, 0))
    at = ((size - art.width) // 2, (size - art.height) // 2 + round(size * 0.01))
    drop = Image.new('RGBA', art.size, INK + (0,))
    drop.putalpha(art.getchannel('A').point(lambda a: a * 90 // 255))
    shadow.paste(drop, (at[0], at[1] + round(size * 0.018)), drop)
    icon = Image.alpha_composite(icon, shadow.filter(ImageFilter.GaussianBlur(size * 0.008)))
    icon.alpha_composite(art, at)
    # App icons must be opaque.
    return icon.convert('RGB').resize((SIZE, SIZE), Image.LANCZOS)

def main():
    icon = master()
    names = {entry['filename'] for entry in json.loads((ICON_SET / 'Contents.json').read_text())['images']}
    for name in sorted(names, key=lambda n: int(Path(n).stem)):
        pixels = int(Path(name).stem)
        icon.resize((pixels, pixels), Image.LANCZOS).save(ICON_SET / name, optimize=True)
    print(f'Wrote {len(names)} sizes to {ICON_SET.relative_to(REPO)}')
    if 'preview' in sys.argv[1:]:
        out = ROOT / 'output'
        out.mkdir(exist_ok=True)
        sheet = Image.new('RGB', (1024 + 40 + 180, 1024), (40, 40, 40))
        sheet.paste(icon, (0, 0))
        y = 0
        for pixels in (180, 120, 80, 60, 40):
            sheet.paste(icon.resize((pixels, pixels), Image.LANCZOS), (1064, y))
            y += pixels + 20
        sheet.save(out / 'preview.png')

if __name__ == '__main__':
    main()
