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

# These cast silhouettes cross the contact sheets' nominal column boundaries.
cast_crops = {
    "7": [[650, 952, 211, 264], [931, 956, 263, 261]],
    "10": [[644, 651, 216, 274], [937, 671, 287, 254]],
    "11": [[653, 974, 207, 263], [934, 981, 290, 256]],
    "12": [[892, 40, 299, 369], [1301, 44, 384, 368]],
}
for fighter, crops in cast_crops.items():
    entry = entries[fighter]
    release_anchor = entry["regions"][3][0] + entry["anchors"][3] - crops[1][0]
    entry["regions"][2:4] = crops
    entry["anchors"][2:4] = [crops[0][2] * .5, release_anchor]

# The six-phase Lamar walk keeps charge and release in the original slots 2 and 3.
lamar_path = "assets/lamar-movement.png"
lamar_alpha = Image.open(project / lamar_path).getchannel("A").point(lambda a: 255 if a >= 128 else 0)
lamar_regions = []
for frame in range(8):
    x, y = (frame % 4) * 450, (frame // 4) * 416
    x0, y0, x1, y1 = lamar_alpha.crop((x, y, x + 450, y + 416)).getbbox()
    lamar_regions.append([x + x0, y + y0, x1 - x0, y1 - y0])
entries["13"].update(path=f"res://{lamar_path}", regions=lamar_regions,
                     anchors=[113, 85, 152, 192, 64, 132, 110, 64], uniform_scale=True)
(project / "data/movement-atlases.json").write_text(json.dumps(entries, indent=2) + "\n")
moves["fighters"][11]["moves"]["special1"]["projectile_skin"] = "violet"
(project / "data/moves.json").write_text(json.dumps(moves, indent=2) + "\n")
print("Registered", sum(len(e["regions"]) for e in entries.values()), "poses for", len(entries), "fighters; Poe uses violet")
