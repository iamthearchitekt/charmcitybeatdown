"""Register the eight transparent prop cells; preserve original generated artwork."""
from pathlib import Path
import json
from PIL import Image

project = Path(__file__).resolve().parents[1]
image = Image.open(project / "assets/breakables-atlas.png").convert("RGBA")
width, height = image.size
entries = {}
for row, name in enumerate(("kegs", "boxes")):
    regions = []
    for column in range(4):
        left, top = round(column * width / 4), round(row * height / 2)
        right, bottom = round((column + 1) * width / 4), round((row + 1) * height / 2)
        cell = image.crop((left, top, right, bottom))
        bounds = cell.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
        if bounds is None:
            raise RuntimeError(f"Empty prop cell {name} {column}")
        x, y, x2, y2 = bounds
        regions.append([left + x, top + y, x2 - x, y2 - y])
    entries[name] = {"regions": regions, "source_height": regions[0][3]}
(project / "data/breakables-atlas.json").write_text(json.dumps(entries, indent=2) + "\n")
print("Registered four damage states each for kegs and boxes", image.size)
