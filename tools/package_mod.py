"""Compile the premade decal catalogue with ReSkate Studio and package the client."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image
from fbmod import package

ROOT = Path(__file__).resolve().parents[1]
GAME_HASH = "fbce74d5e28ef525dbba2cb4adbebc13405bdbd88f31bc940bca45e4ae88b8f9"


def prepare_art(catalogue, scratch):
    """Build wall textures and one overlay image from the same fitted artwork."""
    columns = min(8, len(catalogue))
    rows = (len(catalogue) + columns - 1) // columns
    cell = 160
    atlas = Image.new("RGBA", (columns * cell, rows * cell))
    runtime = []
    args = []
    for index, piece in enumerate(catalogue):
        name = piece["id"]
        if not name.isascii() or not name.isidentifier():
            raise ValueError(f"Invalid artwork ID: {name}")
        source = ROOT / piece.get("source", f"art/{name}.png")
        with Image.open(source) as master:
            if master.mode != "RGBA":
                raise ValueError(f"{source} must be RGBA")
            master.thumbnail((512, 512), Image.Resampling.LANCZOS)
            image = Image.new("RGBA", (512, 512))
            image.paste(master, ((512 - master.width) // 2, (512 - master.height) // 2))
        pixels = scratch / f"{name}.rgba"
        pixels.write_bytes(image.tobytes())
        args.extend([str(piece["slot"]), name, pixels])
        x, y = index % columns, index // columns
        atlas.paste(image.resize((cell, cell), Image.Resampling.LANCZOS), (x * cell, y * cell))
        left, top = (512 - master.width) // 2, (512 - master.height) // 2
        uv = [(x + left / 512) / columns, (y + top / 512) / rows,
              (x + (left + master.width) / 512) / columns, (y + (top + master.height) / 512) / rows]
        entry = {k: v for k, v in piece.items() if k != "source"}
        runtime.append({**entry, "thumb": uv, "aspect": master.width / master.height})
        if name == "switchback":
            icon = Image.new("RGBA", image.size, "#e3e9da")
            icon.alpha_composite(image)
            icon.resize((256, 256), Image.Resampling.LANCZOS).save(scratch / "icon.png")
    atlas.save(scratch / "premades.png")
    (scratch / "catalogue.json").write_text(json.dumps(runtime), encoding="utf-8")
    return args


def build(game, studio, author, destination):
    game, studio, author = (p.resolve(strict=True) for p in (game, studio, author))
    with (game / "Skate.exe").open("rb") as executable:
        if hashlib.file_digest(executable, "sha256").hexdigest() != GAME_HASH:
            raise ValueError("This decal recipe requires Skate build 20260929")
    manifest = json.loads((ROOT / "manifest.json").read_text())
    plugin = json.loads((ROOT / "reskate-plugin.json").read_text())
    declarations = plugin["resident"]
    bundle = declarations[0]["bundle"]
    if len(declarations) > 16 or len(plugin["effects"]) > 128 or any(
        d["bundle"] != bundle or len(d["shaders"]) > 32 for d in declarations
    ):
        raise ValueError("Resident declarations exceed the supported ReSkate layout")
    catalogue = json.loads((ROOT / "art/catalogue.json").read_text(encoding="utf-8"))
    build_dir = ROOT / "build"
    build_dir.mkdir(exist_ok=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=build_dir) as temp:
        scratch = Path(temp)
        authored = scratch / "resources"
        authored.mkdir()
        args = [author, game, authored, *prepare_art(catalogue, scratch)]
        # Keep slots 16 through 31 reserved for the Blackbook palette.
        palette = json.loads((ROOT / "art/palette.json").read_text())
        for index, colour in enumerate(palette, start=1):
            name = f"ink_{index:02}"
            pixels = scratch / f"{name}.rgba"
            pixels.write_bytes(Image.new("RGBA", (512, 512), colour).tobytes())
            args.extend([str(15 + index), name, pixels])
        subprocess.run(args, check=True)
        rows = json.loads((authored / "resources.json").read_text())["resources"]
        templates = [r["name"] for r in rows if r.get("root_type") == "EnvironmentDecalVolumeTemplateData"]
        if templates != plugin["effects"] or any(r["target"] != bundle for r in rows):
            raise ValueError("Authored template or target bundle differs from the manifest")
        resources = {r["name"] for r in rows if r["kind"] == 2 and r["added"]}
        shaders = [s for d in declarations for s in d["shaders"]]
        expected = {t: t.rsplit("/", 1)[0] + "/shaderblockdepot_" + t.rsplit("/", 1)[1][:-3] for t in templates}
        if len(shaders) != len(expected) or any(s["name"] not in resources for s in shaders) or {
            root: s["name"] for s in shaders for root in s["roots"]
        } != expected:
            raise ValueError("Resident shader bindings differ from the authored decals")
        fbmod = scratch / "graffiti.fbmod"
        package(authored, fbmod, manifest["version_number"])
        subprocess.run([studio, "compile-mod", game, scratch / "compiled", fbmod], cwd=scratch, check=True)
        patch = scratch / "compiled/Patch"
        toc = bundle.removeprefix("win32/") + ".toc"
        for path in (patch / "layout.toc", patch / ".reskate-studio-patch", patch / "Win32" / toc):
            if not path.is_file():
                raise ValueError(f"Missing compiled output: {path.name}")
        if GAME_HASH not in (patch / ".reskate-studio-patch").read_text():
            raise ValueError("Unexpected compiler game-build stamp")
        payload = [p for p in (patch / "Win32").rglob("*") if p.suffix.lower() in (".toc", ".cas")]
        if not any(p.suffix.lower() == ".cas" for p in payload):
            raise ValueError("Missing compiled CAS payload")
        with ZipFile(scratch / "GraffitiLab.zip", "w", ZIP_DEFLATED) as archive:
            for path in sorted([*payload, patch / ".reskate-studio-patch", patch / "layout.toc"]):
                archive.write(path, path.relative_to(patch))
            for path in ("manifest.json", "reskate-plugin.json", "plugin/main.lua", "plugin/surface.lua",
                         "plugin/dock.lua", "plugin/menu.lua", "art/menu-type.png", "plugin/selector.lua", "plugin/blackbook.lua", "plugin/studio.lua",
                         "plugin/wall_art.lua", "plugin/wall_store.lua", "plugin/wall_ink.lua", "plugin/paint.lua", "plugin/sharing.lua",
                         "art/palette.json", "art/checker.png"):
                archive.write(ROOT / path, path)
            archive.write(scratch / "catalogue.json", "art/catalogue.json")
            archive.write(scratch / "premades.png", "art/premades.png")
            archive.writestr("README.md", "# Graffiti Lab " + manifest["version_number"] + "\n\n"
                             "Premade graffiti for ReSkate 20261116. With the game closed, extract into "
                             "Mods/GraffitiLab beside Skate.exe, then launch and approve the plugin. For multiplayer, "
                             "each player needs this version under the same mod folder name. While in the same session and map, "
                             "confirmed premade marks are shared, including with late joiners while the artist remains online. "
                             "Custom artwork and freehand painting are available offline.\n\n"
                             "Open Insert > Plugins > Graffiti Lab > Open Graffiti Lab, then press Insert again. "
                             "Ctrl+L opens the Graffiti Lab main menu. In Premade Art, filter by category or search by name, lettering or pack number. Use the page arrows to browse. Select a tile and choose Place on Wall "
                             "or press Enter to aim. Centre the ring on a flat wall within 8 m. When Wall ready appears, "
                             "left-click, press Ctrl+P or tap A to place and return to your selection. Ctrl+G toggles aiming. Ctrl+R cancels a "
                             "preview or removes the last mark. Esc returns to the main menu.\n\n"
                             "Ctrl+E opens the drawing editor. Drag on the canvas, choose a colour and size, or rename "
                             "the drawing. Ctrl+S saves to Blackbook. Ctrl+B opens the gallery. Click a saved piece "
                             "to edit it, or choose Place on wall below its thumbnail. Aim at a suitable wall, press "
                             "Ctrl+P to confirm and return to the same gallery page. After leaving the menus, Ctrl+R removes the latest mark.\n\n"
                             "Ctrl+I opens Wall Paint. Hold the left mouse button and move over a wall, or press Space "
                             "to toggle continuous flow. Use 1-8 for colour, [ and ] for width, Ctrl+Z to undo a stroke "
                             "and Esc to put the brush away. Keep drawing across the wall with no stroke or stamp count limit. "
                             "Wall Paint saves automatically for each map. Select Eraser or press E and drag to erase ink. "
                             "When the renderer fills, the brush prioritises nearby and recent ink.\n")
            archive.write(scratch / "icon.png", "icon.png")
        with ZipFile(scratch / "GraffitiLab.zip") as archive:
            if archive.testzip():
                raise ValueError("ZIP CRC verification failed")
        (scratch / "GraffitiLab.zip").replace(destination)
    print(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--studio", type=Path, required=True)
    parser.add_argument("--author", type=Path, default=ROOT / "build/native/decal-author.exe")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    version = json.loads((ROOT / "manifest.json").read_text())["version_number"]
    build(args.game, args.studio, args.author, (args.out or ROOT / f"outputs/GraffitiLab-{version}.zip").resolve())
