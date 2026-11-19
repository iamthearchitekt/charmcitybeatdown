"""Archive editable source; omit build products, caches and visual captures."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

project = Path(__file__).resolve().parents[1]
workspace = project.parent
archive = workspace / "outputs" / "CharmCityBeatdown-Source.zip"
archive.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(archive, "w", ZIP_DEFLATED, compresslevel=6) as bundle:
    for path in project.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(project)
        if relative.parts[0] in (".godot", ".runtime", "build"):
            continue
        if relative.parts[:2] == ("tests", "visual"):
            continue
        bundle.write(path, "charmcitybeatdown/" + relative.as_posix())
    bundle.write(workspace / "CONTINUE_HERE.md", "CONTINUE_HERE.md")
    bundle.writestr("SOURCE-ARCHIVE.txt", "Editable Godot 4.3 source. Import charmcitybeatdown/project.godot in Godot 4.3 and press F5. This archive excludes generated imports, screenshots and executables. The playable Windows build remains beside Play.cmd in the local working project.\n")
with ZipFile(archive) as bundle:
    error = bundle.testzip()
    if error:
        raise RuntimeError("Corrupt archive entry: " + error)
print("Verified source archive:", archive, archive.stat().st_size, "bytes")
