"""Run: python3 Tools/pipe-kit/make_pipes.py (requires Pillow).

Draws the Striped Pipes art (Plan 02 Phase 1 step 3) with no outside artwork:

- pipe-striped: light and dark diagonal stripes in greyscale, with the darker edges of the
  Classic pipe. The game multiplies it by the colour palette's pipe colour, so the light
  stripes take the palette colour and the dark stripes a darker shade of it.
- cap-striped: the Classic cap, copied, so both pipe sets share one cap shape.

The body is one tall image, not a 9-slice: a stretched stripe would change angle with the
pipe's height, so `PipeNode` crops this image to the height it needs and repeats it only
for a pipe taller than the image. HEIGHT is a whole number of stripe periods, so repeats
join without a seam.
"""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent
PIPES = ROOT.parents[1] / 'Helichopter/Assets/Assets.xcassets/Pipe'

WIDTH = 60      # points, as the Classic pipe; the game draws it 110 scene units wide
PERIOD = 30     # points from one dark stripe to the next, measured down the pipe
HEIGHT = 840    # points: 28 periods, taller than any pipe in either gameplay layout
LIGHT, DARK = 255, 115
EDGE_LEFT, EDGE_RIGHT = 170, 150   # multiplied over the stripes, like the Classic bevel
SUPERSAMPLE = 4

def body(scale):
    s = scale * SUPERSAMPLE
    w, h, period = WIDTH * s, HEIGHT * s, PERIOD * s
    image = Image.new('L', (w, h), LIGHT)
    draw = ImageDraw.Draw(image)
    # Each dark stripe rises one pipe-width from left to right and is half a period thick.
    for top in range(0, h + w + period, period):
        draw.polygon([(0, top), (w, top - w), (w, top - w + period // 2), (0, top + period // 2)], fill=DARK)
    edges = Image.new('L', (w, h), 255)
    edge = ImageDraw.Draw(edges)
    edge.rectangle((0, 0, 4 * s - 1, h), fill=EDGE_LEFT)
    edge.rectangle((w - 4 * s, 0, w, h), fill=EDGE_RIGHT)
    image = ImageChops.multiply(image, edges).resize((WIDTH * scale, HEIGHT * scale), Image.Resampling.LANCZOS)
    return Image.merge('RGBA', (image, image, image, Image.new('L', image.size, 255)))

def write_imageset(name, files):
    """files: [(scale, filename, save)] where save(path) writes the PNG."""
    folder = PIPES / f'{name}.imageset'
    folder.mkdir(parents=True, exist_ok=True)
    images = []
    for scale, filename, save in files:
        save(folder / filename)
        images.append({'filename': filename, 'idiom': 'universal', 'scale': f'{scale}x'})
    (folder / 'Contents.json').write_text(
        json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')

def suffix(scale):
    return '' if scale == 1 else f'@{scale}x'

def main():
    assert HEIGHT % PERIOD == 0, 'the image must hold a whole number of stripe periods'
    write_imageset('pipe-striped', [
        (scale, f'stripedPipe{suffix(scale)}.png', body(scale).save) for scale in (1, 2, 3)])
    classic_cap = PIPES / 'cap-yellow.imageset'
    write_imageset('cap-striped', [
        (scale, f'stripedPipeCap{suffix(scale)}.png',
         lambda path, source=classic_cap / f'yellowPipeCap{suffix(scale)}.png': shutil.copyfile(source, path))
        for scale in (1, 2, 3)])
    print(f'Created pipe-striped and cap-striped in {PIPES}')

if __name__ == '__main__':
    main()
