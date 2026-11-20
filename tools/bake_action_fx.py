"""Register the painted effects at the game's native sprite resolution."""
import json
from pathlib import Path

from PIL import Image, ImageOps


ASSETS = Path(__file__).resolve().parents[1] / "assets"
CELL = 96
FRAME_COUNT = 4
SHEETS = {
    "projectile": [("plasma", (84, 50)), ("shear", (84, 24))],
    "trail": [("streak", (84, 30)), ("sweep", (84, 32)), ("rise", (76, 78))],
    "impact": [("hit", (66, 66)), ("guard", (66, 66)), ("clash", (66, 66))],
}


def crop_row(sheet, row, row_count):
    top = round(row * sheet.height / row_count)
    bottom = round((row + 1) * sheet.height / row_count)
    cell_width = sheet.width // FRAME_COUNT
    cells = []
    boxes = []
    for column in range(FRAME_COUNT):
        left = round(column * sheet.width / FRAME_COUNT)
        cell = sheet.crop((left, top, left + cell_width, bottom))
        alpha = cell.getchannel("A").point(lambda value: 255 if value >= 175 else 0)
        bounds = alpha.getbbox()
        if bounds is None:
            raise ValueError(f"Effect row {row} has an empty frame at column {column}")
        cells.append(cell)
        boxes.append(bounds)

    # Share the crop across a row so the largest frame defines the anchor and
    # smaller buildup and dissipation frames retain their intended scale.
    bounds = (min(box[0] for box in boxes), min(box[1] for box in boxes),
              max(box[2] for box in boxes), max(box[3] for box in boxes))
    return [cell.crop(bounds) for cell in cells]


def main():
    row_count = sum(len(rows) for rows in SHEETS.values())
    atlas = Image.new("RGBA", (CELL * FRAME_COUNT, CELL * row_count))
    regions = {}
    for filename, rows in SHEETS.items():
        with Image.open(ASSETS / "action-fx-sources" / f"{filename}.png") as original:
            sheet = original.convert("RGBA")
        for row, (name, size) in enumerate(rows):
            y = CELL * len(regions)
            regions[name] = [y, *size]
            for column, cell in enumerate(crop_row(sheet, row, len(rows))):
                sprite = cell.resize(size, Image.Resampling.LANCZOS)
                pixels = ImageOps.grayscale(sprite).convert("RGBA")
                pixels.putalpha(sprite.getchannel("A").point(lambda value: 255 if value >= 160 else 0))
                atlas.paste(pixels, (column * CELL, y))
    atlas.save(ASSETS / "action-fx.png", optimize=True)
    metadata = {"cell": CELL, "frames": FRAME_COUNT, "regions": regions}
    (ASSETS.parent / "data" / "action-fx.json").write_text(json.dumps(metadata, indent=2) + "\n")


if __name__ == "__main__":
    main()
