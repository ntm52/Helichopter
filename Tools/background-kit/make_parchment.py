"""Run from the repository root: python3 Tools/background-kit/make_parchment.py (requires Pillow).

Draws the Parchment theme's game background: the theme's cream page with faint sketched
clouds, dashed flight paths, and birds, like a drawing on old paper. It is the same size
as the starfield (`Background`, 512 x 1500 pt) and repeats sideways without a seam, so the
game scrolls it exactly as it scrolls the stars.

Every mark is kept faint on purpose: pipes and the helicopter must stand out as clearly
as they did on the plain page. MARK and CLOUD are the darkest and lightest colours used.

    python3 Tools/background-kit/make_parchment.py            writes the image set
    python3 Tools/background-kit/make_parchment.py preview    also writes output/preview.png
"""
from pathlib import Path
import json
import math
import random
import sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
IMAGE_SET = REPO / 'Helichopter/Assets/Assets.xcassets/BackgroundParchment.imageset'
NAME = 'BackgroundParchment'

W, H, SCALE = 512, 1500, 3           # Points, drawn at 3x and reduced for 2x and 1x.
PAGE = (0xF2, 0xEC, 0xD8)            # UITheme.themeParchment.sceneBackgroundColor
STAIN = (0xEC, 0xE4, 0xCB)           # Soft patches, as on aged paper.
CLOUD = (0xF8, 0xF4, 0xE6)           # Inside a cloud: a little lighter than the page.
MARK = (0xD3, 0xC5, 0x9E)            # Ink for outlines, paths, and birds.
SEED = 2026

def wrapped(x):
    """An element near an edge is drawn on both sides, so the tile has no seam."""
    return (x - W, x, x + W)

def cloud(draw, x, y, size, rng):
    """A row of overlapping puffs on a flat base: outline first, then the lighter inside."""
    puffs = []
    count = rng.randint(3, 5)
    for i in range(count):
        t = i / (count - 1)
        r = size * (0.55 + 0.45 * math.sin(math.pi * t)) * rng.uniform(0.85, 1.1)
        puffs.append((x + (t - 0.5) * size * 2.6, y - r * 0.55, r))
    line = 2.2
    for grow, colour in ((line, MARK), (0, CLOUD)):
        for px, py, r in puffs:
            for ox in wrapped(px):
                box = [(ox - r - grow) * SCALE, (py - r - grow) * SCALE, (ox + r + grow) * SCALE, (py + r + grow) * SCALE]
                draw.ellipse(box, fill=colour)
        left, right = puffs[0][0] - puffs[0][2], puffs[-1][0] + puffs[-1][2]
        for shift in (-W, 0, W):
            draw.rounded_rectangle([(left + shift - grow) * SCALE, (y - size * 0.5 - grow) * SCALE,
                                    (right + shift + grow) * SCALE, (y + size * 0.28 + grow) * SCALE],
                                   radius=(size * 0.39 + grow) * SCALE, fill=colour)

def flight_path(draw, x, y, length, rng):
    """A dashed, gently curving line, like a route drawn on a map."""
    bend, tilt = rng.uniform(-28, 28), rng.uniform(-0.25, 0.25)
    steps = int(length / 4)
    for i in range(steps):
        if i % 5 >= 3:
            continue
        def at(k):
            t = k / steps
            return (x + t * length, y + tilt * t * length + bend * math.sin(math.pi * t))
        (x0, y0), (x1, y1) = at(i), at(i + 1)
        for shift in (-W, 0, W):
            draw.line([((x0 + shift) * SCALE, y0 * SCALE), ((x1 + shift) * SCALE, y1 * SCALE)],
                      fill=MARK, width=round(1.6 * SCALE))

def bird(draw, x, y, span):
    """Two shallow arcs, the way a child draws a bird."""
    for ox in wrapped(x):
        for side in (-1, 0):
            box = [(ox + side * span) * SCALE, (y - span * 0.45) * SCALE, (ox + (side + 1) * span) * SCALE, (y + span * 0.45) * SCALE]
            draw.arc(box, start=200, end=340, fill=MARK, width=round(1.6 * SCALE))

def tile():
    rng = random.Random(SEED)
    # Stains are blurred on a canvas three tiles wide, then the middle is kept, so the
    # blur runs across the seam.
    wide = Image.new('RGB', (W * 3 * SCALE // 4, H * SCALE // 4), PAGE)
    stains = ImageDraw.Draw(wide)
    for _ in range(9):
        x, y, rx, ry = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(70, 150), rng.uniform(60, 130)
        for ox in wrapped(x):
            stains.ellipse([(ox + W - rx) * SCALE / 4, (y - ry) * SCALE / 4, (ox + W + rx) * SCALE / 4, (y + ry) * SCALE / 4], fill=STAIN)
    wide = wide.filter(ImageFilter.GaussianBlur(26 * SCALE / 4))
    page = wide.crop((W * SCALE // 4, 0, 2 * W * SCALE // 4, H * SCALE // 4)).resize((W * SCALE, H * SCALE), Image.BICUBIC)

    draw = ImageDraw.Draw(page)
    # Rows from top to bottom, each with its own kind of mark, so nothing bunches up.
    y = 70
    while y < H - 60:
        kind = rng.choice(['cloud', 'cloud', 'cloud', 'path', 'birds'])
        x = rng.uniform(0, W)
        if kind == 'cloud':
            cloud(draw, x, y, rng.uniform(26, 44), rng)
            if rng.random() < 0.5:
                cloud(draw, (x + rng.uniform(190, 300)) % W, y + rng.uniform(-30, 40), rng.uniform(18, 28), rng)
        elif kind == 'path':
            flight_path(draw, x, y, rng.uniform(170, 300), rng)
        else:
            for i in range(rng.randint(2, 3)):
                bird(draw, (x + i * rng.uniform(34, 50)) % W, y + rng.uniform(-14, 14), rng.uniform(11, 16))
        y += rng.uniform(70, 115)
    return page

def main():
    full = tile()
    IMAGE_SET.mkdir(parents=True, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        name = NAME + ('' if scale == 1 else f'@{scale}x') + '.png'
        image = full if scale == SCALE else full.resize((W * scale, H * scale), Image.LANCZOS)
        image.save(IMAGE_SET / name, optimize=True)
        images.append({'filename': name, 'idiom': 'universal', 'scale': f'{scale}x'})
    (IMAGE_SET / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
    print(f'Wrote {IMAGE_SET.relative_to(REPO)}')
    if 'preview' in sys.argv[1:]:
        out = ROOT / 'output'
        out.mkdir(exist_ok=True)
        one = full.resize((W, H), Image.LANCZOS)
        # Two tiles side by side show whether the seam is visible.
        sheet = Image.new('RGB', (W * 2, 900), PAGE)
        sheet.paste(one.crop((0, 0, W, 900)), (0, 0))
        sheet.paste(one.crop((0, 0, W, 900)), (W, 0))
        sheet.save(out / 'preview.png')

if __name__ == '__main__':
    main()
