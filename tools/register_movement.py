"""Register dedicated walking and two-handed projectile poses without changing source art."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

project = Path(__file__).resolve().parents[1]
groups = [("movement-a", [0, 1, 2, 3]), ("movement-b", [4, 5, 6, 7]),
          ("movement-c", [8, 9, 10, 11]), ("movement-d", [12, 13])]
moves = json.loads((project / "data/moves.json").read_text())
entries = {}
for stem, kinds in groups:
    image = Image.open(project / f"assets/{stem}.png").convert("RGBA")
    alpha = np.asarray(image)[:, :, 3]
    for row, kind in enumerate(kinds):
        projectile = bool(moves["fighters"][kind]["moves"]["special1"].get("projectile"))
        regions = []
        anchors = []
        for column in range(4 if projectile else 2):
            left, right = round(column * image.width / 4), round((column + 1) * image.width / 4)
            top, bottom = round(row * image.height / len(kinds)), round((row + 1) * image.height / len(kinds))
            mask = alpha[top:bottom, left:right] >= 128
            ys, xs = np.where(mask)
            if not len(xs):
                raise RuntimeError(f"Empty movement cell: {kind}/{column}")
            x, y, w, h = left + int(xs.min()), top + int(ys.min()), int(xs.max()-xs.min()+1), int(ys.max()-ys.min()+1)
            regions.append([x, y, w, h])
            anchors.append(w * (.38 if column == 3 else .5))
        entries[str(kind)] = {"path": f"res://assets/{stem}.png", "regions": regions,
                              "anchors": anchors, "height": regions[0][3], "projectile": projectile}
(project / "data/movement-atlases.json").write_text(json.dumps(entries, indent=2) + "\n")
moves["fighters"][11]["moves"]["special1"]["projectile_skin"] = "violet"
(project / "data/moves.json").write_text(json.dumps(moves, indent=2) + "\n")
print("Registered", sum(len(e["regions"]) for e in entries.values()), "poses for", len(entries), "fighters; Poe uses violet")
