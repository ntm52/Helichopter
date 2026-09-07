"""Run: python3 make_frames.py (requires Pillow)."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'output'
FRAMES = 60
# Normalized coordinates measured from the supplied source artwork.
HUB = (0.608, 0.435)
RADIUS = 0.32
TILT = 0.13

def main():
    body = Image.open(ROOT / 'helicopter_body.png').convert('RGBA')
    # Ignore near-transparent export noise so it cannot change the shared crop.
    body.putalpha(body.getchannel('A').point(lambda alpha: 0 if alpha <= 5 else alpha))
    w, h = body.size
    cx, cy = HUB[0] * w, HUB[1] * h
    radius = RADIUS * w
    box = body.getchannel('A').getbbox()
    if box is None:
        raise ValueError('Source image is empty')
    # One common crop for every frame; never center frames independently.
    left = math.floor(min(box[0], cx - radius - 8))
    top = math.floor(min(box[1], cy - radius * TILT - 8))
    right = math.ceil(max(box[2], cx + radius + 8))
    bottom = math.ceil(box[3])
    crop = (left, top, right, bottom)
    atlas = ROOT.parents[1] / 'Helichopter/Assets/Assets.xcassets/Playable Characters/Helicopter Player.spriteatlas'
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
            points = [project(7, -11), project(radius, -16),
                      project(radius, 16), project(7, 11)]
            draw.polygon(points, fill='#697380', outline='#303641', width=3)
        draw.ellipse((cx-15, cy-10, cx+15, cy+10), fill='#515965', outline='#303641', width=3)
        cropped = frame.crop(crop)
        images = []
        imageset = atlas / f'r_player{i + 1}.imageset'
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
            assetname = f'r_player{i + 1}' + ('' if scale == 1 else f'@{scale}x') + '.png'
            canvas.save(imageset / assetname)
            images.append({'idiom': 'universal', 'scale': f'{scale}x', 'filename': assetname})
            if size == 400:
                previews.append(canvas)
        (imageset / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2))
    # APNG preserves smooth transparent edges; each frame lasts 1/60 second.
    previews[0].save(OUT / 'preview.png', save_all=True, append_images=previews[1:], duration=1000 / FRAMES, loop=0, disposal=0, blend=0)
    for size in (200, 400, 600):
        files = list((OUT / f'{size}x{size}').glob('*.png'))
        assert len(files) == FRAMES
        for path in files:
            with Image.open(path) as im:
                assert im.size == (size, size) and im.mode == 'RGBA'
    print(f'Created 180 PNG frames, Xcode assets, and a 1-second APNG preview in {OUT}')

if __name__ == '__main__':
    main()
