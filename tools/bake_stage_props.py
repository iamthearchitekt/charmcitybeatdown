from pathlib import Path
import json

from PIL import Image
import numpy as np


PROJECT = Path(__file__).resolve().parents[1]
ATLAS_CELL = 112
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])


def painted_frames(filename):
    sheet = Image.open(PROJECT / 'assets' / filename).convert('RGBA')
    frames = []
    for col in range(4):
        left = col * sheet.width // 4
        right = (col + 1) * sheet.width // 4
        cell = sheet.crop((left, 0, right, sheet.height))
        bounds = cell.getchannel('A').point(lambda alpha: 255 if alpha >= 128 else 0).getbbox()
        if bounds is None:
            raise ValueError(f'{filename} frame {col + 1} is empty')
        frames.append(cell.crop(bounds))
    return frames


def main():
    metadata = json.loads((PROJECT / 'data/breakables-atlas.json').read_text())
    original = Image.open(PROJECT / 'assets/breakables-atlas.png').convert('RGBA')
    atlas = Image.new('RGBA', (ATLAS_CELL * 4, ATLAS_CELL * 4))

    def bake(region, size, row, col):
        region = region.resize(size, Image.Resampling.LANCZOS)
        pixels = np.array(region)
        y, x = np.indices(pixels.shape[:2])
        dither = ((BAYER[y % 4, x % 4] + .5) / 16 - .5) * .85
        pixels[:, :, :3] = np.clip(np.round(pixels[:, :, :3] * (23 / 255) + dither[:, :, None]) * (255 / 23), 0, 255)
        pixels[:, :, 3] = (pixels[:, :, 3] >= 128) * 255
        region = Image.fromarray(pixels)
        region = region.crop(region.getbbox())
        atlas.alpha_composite(region, (col * ATLAS_CELL + (ATLAS_CELL - region.width) // 2, (row + 1) * ATLAS_CELL - 1 - region.height))

    for row, name, height in [(0, 'kegs', 82), (1, 'boxes', 88)]:
        info = metadata[name]
        for col, (x, y, w, h) in enumerate(info['regions']):
            region = original.crop((x, y, x + w, y + h))
            bake(region, (round(w * height / info['source_height']), round(h * height / info['source_height'])), row, col)
    # Register each intact prop to its gameplay footprint. Keep that scale
    # through the damage frames so dents and the crushed silhouette read.
    artwork = [(2, 'stage-oil-drum-source.png', 72, 89), (3, 'stage-trash-can-source.png', 74, 96)]
    for row, filename, intact_width, intact_height in artwork:
        frames = painted_frames(filename)
        width_scale = intact_width / frames[0].width
        height_scale = intact_height / frames[0].height
        for col, region in enumerate(frames):
            width = min(ATLAS_CELL - 2, round(region.width * width_scale))
            height = round(region.height * height_scale)
            bake(region, (width, height), row, col)
    atlas.save(PROJECT / 'assets/stage-breakables.png', optimize=True)


if __name__ == '__main__':
    main()
