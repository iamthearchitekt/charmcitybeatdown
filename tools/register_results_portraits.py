"""Register result portrait cells from alpha. Does not modify artwork."""
import json
from pathlib import Path
from PIL import Image

project = Path(__file__).resolve().parents[1]
groups = [
    ("a", ["marcus", "brook-lynne", "alex", "lauren"]),
    ("b", ["chelsea", "vivian", "spike", None]),
    ("c", ["eric", "stan", None]),
    ("d", ["rachel", "jeff"]),
    ("e", ["edgar-allan-poe"]),
    ("f", ["orioles-mascot"]),
    ("g", ["lamar-jackson"]),
]
fighters = json.loads((project / "data/moves.json").read_text())["fighters"]
indices = {fighter["id"]: str(i) for i, fighter in enumerate(fighters)}
registered = {}
for group, names in groups:
    filename = f"results-portraits-{group}.png"
    image = Image.open(project / "assets" / filename).convert("RGBA")
    for col, identity in enumerate(names):
        if identity is None:
            continue
        entry = {"path": "res://assets/" + filename}
        for row, state in enumerate(["victory", "defeat"]):
            left = round(col * image.width / len(names))
            right = round((col + 1) * image.width / len(names))
            top = round(row * image.height / 2)
            bottom = round((row + 1) * image.height / 2)
            alpha = image.getchannel("A").crop((left, top, right, bottom))
            bounds = alpha.point(lambda a: 255 if a >= 160 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"Empty portrait: {identity} {state}")
            x0, y0, x1, y1 = bounds
            x0, y0 = max(0, x0-2), max(0, y0-2)
            x1, y1 = min(right-left, x1+2), min(bottom-top, y1+2)
            entry[state] = [left+x0, top+y0, x1-x0, y1-y0]
        registered[indices[identity]] = entry
assert len(registered) == len(fighters), "Every playable fighter needs both portraits"
(project / "data/results-portraits.json").write_text(json.dumps(registered, indent=2)+"\n")
print(f"Registered {len(registered)*2} victory/defeat portraits")
