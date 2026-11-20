"""Crop the painted wordmarks and numbers into one transparent game atlas."""
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SOURCES = ASSETS / "round-callout-sources"
GUTTER = 2


def keyed_sprite(cell, height):
    alpha = cell.getchannel("A").point(lambda value: 255 if value >= 165 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("Round callout source cell is empty")
    crop = cell.crop(bounds)
    width = round(crop.width * height / crop.height)
    sprite = crop.resize((width, height), Image.Resampling.LANCZOS)
    sprite.putalpha(sprite.getchannel("A").point(lambda value: 255 if value >= 160 else 0))
    return sprite


def main():
    words = Image.open(SOURCES / "callouts.png").convert("RGBA")
    numerals = Image.open(SOURCES / "digits.png").convert("RGBA")
    results = Image.open(SOURCES / "results.png").convert("RGBA")
    hits = Image.open(SOURCES / "hits.png").convert("RGBA")
    sprites = {}
    for label, top, bottom, height in [("fight", 0, 380, 80), ("round", 380, 646, 54), ("final", 646, 887, 52)]:
        sprites[label] = keyed_sprite(words.crop((0, top, words.width, bottom)), height)
    for index, digit in enumerate("1234567890"):
        row, column = divmod(index, 5)
        left = round(column * numerals.width / 5)
        right = round((column + 1) * numerals.width / 5)
        top = round(row * numerals.height / 2)
        bottom = round((row + 1) * numerals.height / 2)
        sprites[digit] = keyed_sprite(numerals.crop((left, top, right, bottom)), 54)

    result_rows = [("ko", 0.0, .36, 72), ("win", .36, .68, 54), ("lose", .68, 1.0, 54)]
    for label, top, bottom, height in result_rows:
        region = (0, round(top * results.height), results.width, round(bottom * results.height))
        sprites[label] = keyed_sprite(results.crop(region), height)
    sprites["hits"] = keyed_sprite(hits, 31)
    sprites["won"] = keyed_sprite(Image.open(SOURCES / "won.png").convert("RGBA"), 116)

    rows = [["fight"], ["round"], ["final"], list("12345"), list("67890"),
            ["ko", "hits"], ["win"], ["lose"], ["won"]]
    width = max(sum(sprites[key].width + GUTTER for key in row) for row in rows)
    height = sum(max(sprites[key].height for key in row) + GUTTER for row in rows)
    atlas = Image.new("RGBA", (width, height))
    regions = {}
    y = 0
    for row in rows:
        x = 0
        for key in row:
            sprite = sprites[key]
            atlas.paste(sprite, (x, y))
            regions[key] = [x, y, sprite.width, sprite.height]
            x += sprite.width + GUTTER
        y += max(sprites[key].height for key in row) + GUTTER
    atlas.save(ASSETS / "round-callouts.png", optimize=True)
    (ROOT / "data" / "round-callouts.json").write_text(json.dumps(regions, indent=2) + "\n")


if __name__ == "__main__":
    main()
