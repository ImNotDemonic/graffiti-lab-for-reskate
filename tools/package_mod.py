"""Compile the premade decal catalogue with ReSkate Studio and package the client."""
import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image
from fbmod import package
from arch_textures import prepare as prepare_arch
from build_lettering_fonts import DISPLAY_FACES

ROOT = Path(__file__).resolve().parents[1]
GAME_HASH = "fbce74d5e28ef525dbba2cb4adbebc13405bdbd88f31bc940bca45e4ae88b8f9"


def mist_texture(path):
    """A small, feathered aerosol puff, tinted by the brush at draw time."""
    lobes = [(0, 0, 0.44), (-0.24, 0.13, 0.28), (0.20, -0.16, 0.32), (0.24, 0.17, 0.22)]
    image = Image.new("RGBA", (64, 64))
    alpha = []
    for y in range(64):
        for x in range(64):
            u, v = (x - 31.5) / 32, (y - 31.5) / 32
            density = sum(math.exp(-2 * ((u-a)**2 + (v-b)**2) / radius**2) for a, b, radius in lobes)
            alpha.append(round(170 * (1 - math.exp(-density))))
    image.putdata([(255, 255, 255, a) for a in alpha])
    image.save(path)


def reshape_grid(image, palette):
    """An editable source in the same 16 resident inks used by wall artwork."""
    grid = image.convert("RGBA")
    grid.thumbnail((64, 64), Image.Resampling.LANCZOS)
    colours = [bytes.fromhex(value[1:]) for value in palette]
    symbols = "123456789ABCDEFG"
    pixels = []
    for r, g, b, alpha in grid.get_flattened_data() if hasattr(grid, "get_flattened_data") else grid.getdata():
        if alpha < 96:
            pixels.append(".")
        else:
            ink = min(range(len(colours)), key=lambda i: (
                2 * (r-colours[i][0])**2 + 4 * (g-colours[i][1])**2 + (b-colours[i][2])**2))
            pixels.append(symbols[ink])
    return {"w": grid.width, "h": grid.height, "pixels": "".join(pixels)}


def prepare_art(catalogue, scratch):
    """Build wall textures and 480 px overlay sheets from the same fitted artwork."""
    columns = rows = 3
    cell = 160
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
        sheet, tile = divmod(index, columns * rows)
        if tile == 0:
            atlas = Image.new("RGBA", (columns * cell, rows * cell))
        filename = "premades.png" if sheet == 0 else f"premades-{sheet+1}.png"
        x, y = tile % columns, tile // columns
        atlas.paste(image.resize((cell, cell), Image.Resampling.LANCZOS), (x * cell, y * cell))
        if tile == columns * rows - 1 or index == len(catalogue) - 1:
            atlas.save(scratch / filename)
        left, top = (512 - master.width) // 2, (512 - master.height) // 2
        uv = [(x + left / 512) / columns, (y + top / 512) / rows,
              (x + (left + master.width) / 512) / columns, (y + (top + master.height) / 512) / rows]
        entry = {k: v for k, v in piece.items() if k != "source"}
        runtime.append({**entry, "sheet": "art/" + filename, "thumb": uv, "aspect": master.width / master.height})
    (scratch / "catalogue.json").write_text(json.dumps(runtime), encoding="utf-8")
    return args


def build(game, studio, author, destination, native_from=None):
    with Image.open(ROOT / "icon.png") as icon:
        if icon.format != "PNG" or icon.size != (256, 256):
            raise ValueError("The package icon must be a 256 x 256 PNG")
        icon.verify()
    if native_from is None:
        if not game or not studio:
            raise ValueError("Provide --game and --studio for a native build")
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
        images = prepare_art(catalogue, scratch)
        arches = prepare_arch(ROOT, catalogue, scratch)
        if native_from:
            patch = scratch / "verified-native"
            toc = bundle.removeprefix("win32/") + ".toc"
            # Studio gives some native resources new IDs on every compile.
            # Reuse the complete tested bundle for a script-only release.
            with ZipFile(native_from) as previous:
                if ("art/arch/materials.sha256" not in previous.namelist() or
                        previous.read("art/arch/materials.sha256") != (scratch / "arch/materials.sha256").read_bytes()):
                    raise ValueError("Original-texture arch materials changed. Rebuild with Studio.")
                old_plugin = json.loads(previous.read("reskate-plugin.json"))
                if any(old_plugin[key] != plugin[key] for key in ("resident", "effects")):
                    raise ValueError("The native resource declarations changed. Rebuild with Studio.")
                if json.loads(previous.read("art/catalogue.json")) != json.loads((scratch / "catalogue.json").read_text(encoding="utf-8")):
                    raise ValueError("The artwork catalogue changed. Rebuild with Studio.")
                if json.loads(previous.read("art/palette.json")) != json.loads((ROOT / "art/palette.json").read_text()):
                    raise ValueError("The wall palette changed. Rebuild with Studio.")
                for name in ("layout.toc", ".reskate-studio-patch", "Win32/" + toc,
                             "Win32/configurations/layout/initialinstallpackage/cas_01.cas"):
                    file = patch / name
                    file.parent.mkdir(parents=True, exist_ok=True)
                    with previous.open(name) as src, file.open("wb") as dst:
                        shutil.copyfileobj(src, dst)
        else:
            authored = scratch / "resources"
            authored.mkdir()
            scene = scratch / "graffitilab_can"
            shutil.copytree(ROOT / "art/spray-can", scene)
            can_build = scratch / "can-output"
            subprocess.run([studio, "compile-map", game, scene, can_build, "--no-stream", "--no-lods",
                            "--no-gi", "--no-auto-reflection", "--no-bam-lighting", "--no-live-tod"], check=True)
            args = [author, game, authored, can_build / "Patch", *images]
            # Keep slots 16 through 31 reserved for the Blackbook palette.
            palette = json.loads((ROOT / "art/palette.json").read_text())
            for index, colour in enumerate(palette, start=1):
                name = f"ink_{index:02}"
                pixels = scratch / f"{name}.rgba"
                pixels.write_bytes(Image.new("RGBA", (512, 512), colour).tobytes())
                args.extend([str(15 + index), name, pixels])
            args.extend(arches)
            subprocess.run(args, check=True)
            rows = json.loads((authored / "resources.json").read_text())["resources"]
            templates = [r["name"] for r in rows if r.get("root_type") == "EnvironmentDecalVolumeTemplateData"]
            if templates != plugin["effects"] or any(r["target"] != bundle for r in rows):
                raise ValueError("Authored template or target bundle differs from the manifest")
            resources = {r["name"] for r in rows if r["kind"] == 2 and r["added"]}
            shaders = [s for d in declarations for s in d["shaders"]]
            expected = {t: t.rsplit("/", 1)[0] + "/shaderblockdepot_" + t.rsplit("/", 1)[1][:-3] for t in templates}
            expected['world/custom/dingolevel_reskate_graffitilab_can/meshes/graffitilab_can_0_0_bp'] = 'levels/game/dingolevel_reskate_graffitilab_can/dingolevel_reskate_graffitilab_can_win32_shaderstate/shaderblockdepot_6748045137296043854'
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
            for path in ("manifest.json", "icon.png", "reskate-plugin.json", "plugin/main.lua", "plugin/surface.lua",
                         "plugin/dock.lua", "plugin/menu.lua", "plugin/selector.lua", "plugin/blackbook.lua", "plugin/studio.lua",
                         "plugin/wall_art.lua", "plugin/wall_codec.lua", "plugin/wall_store.lua", "plugin/wall_ink.lua", "plugin/paint.lua", "plugin/sharing.lua",
                         "plugin/spray_arm.lua", "plugin/spray_fx.lua", "art/spray-loop.wav", "art/spray-burst.wav",
                         "plugin/media_format.lua", "plugin/playback.lua", "plugin/pattern.lua", "plugin/reshape.lua", "plugin/reshape_screen.lua", "plugin/library_dock.lua", "plugin/library.lua", "plugin/library_screen.lua", "plugin/placements.lua", "plugin/map_screen.lua",
                         "plugin/imports.lua", "plugin/gallery.lua", "plugin/gallery_dock.lua", "plugin/gallery_screen.lua",
                         "art/palette.json", "art/checker.png", "LICENSE", "art/NOTICE.md"):
                archive.write(ROOT / path, path)
            # ReSkate caches overlay textures by path across plugin reloads.
            archive.write(ROOT / "art/menu-type.png", "art/menu-headings-081.png")
            archive.write(scratch / "catalogue.json", "art/catalogue.json")
            archive.write(ROOT / "plugin/native_arch.lua", "plugin/native_arch.lua")
            for module in ("studio_stencils", "studio_symbols", "shape_preview", "lettering", "composition", "studio_projects", "composition_screen",
                           "graffiti_emotes", "emote_wheel"):
                archive.write(ROOT / f"plugin/{module}.lua", f"plugin/{module}.lua")
            font_files = [face + suffix for face in (*DISPLAY_FACES, "Pixel")
                          for suffix in (".glfont", "-LICENSE.txt")]
            for name in (*font_files, "layout.json", "README.md"):
                archive.write(ROOT / "art/lettering" / name, "art/lettering/" + name)
            directory = ROOT / "art/lettering"
            for name in DISPLAY_FACES:
                for suffix in (".metrics.json", ".ink"):
                    path = directory / (name + suffix)
                    archive.write(path, "art/lettering/" + path.name)
            for path in sorted(directory.glob("writing-*.png")):
                archive.write(path, "art/lettering/" + path.name)
            for file in sorted((scratch / "arch").iterdir()):
                archive.write(file, "art/arch/" + file.name)
            for sheet in sorted(scratch.glob("premades*.png")):
                archive.write(sheet, "art/" + sheet.name)
            importer = (ROOT / "art/Import Artwork.html").read_text(encoding="utf-8")
            palette = json.loads((ROOT / "art/palette.json").read_text(encoding="utf-8"))
            importer = importer.replace("__WALL_INKS__", json.dumps(palette))
            for token, script in [("__PREPARE_JS__", "prepare.js"), ("__PREPARE_UI_JS__", "prepare-ui.js")]:
                importer = importer.replace(token, (ROOT / "art" / script).read_text(encoding="utf-8"))
            archive.writestr("art/Import Artwork.html", importer)
            for piece in catalogue:
                with Image.open(ROOT / piece.get("source", f"art/{piece['id']}.png")) as original:
                    grid = reshape_grid(original, palette)
                    archive.writestr(f"art/reshape/{piece['id']}.json", json.dumps(grid))
                    original.thumbnail((384, 384), Image.Resampling.LANCZOS)
                    path = scratch / "edit-source.png"
                    original.save(path)
                    archive.write(path, f"art/edit/{piece['id']}.png")
            mist_texture(scratch / "spray-mist.png")
            archive.write(scratch / "spray-mist.png", "art/spray-mist.png")
            archive.write(ROOT / "docs/THUNDERSTORE_README.md", "README.md")
            archive.write(ROOT / "CHANGELOG.md", "CHANGELOG.md")
            archive.write(ROOT / "docs/LAYERED_STUDIO.md", "docs/LAYERED_STUDIO.md")
        with ZipFile(scratch / "GraffitiLab.zip") as archive:
            if archive.testzip():
                raise ValueError("ZIP CRC verification failed")
        (scratch / "GraffitiLab.zip").replace(destination)
    print(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path)
    parser.add_argument("--studio", type=Path)
    parser.add_argument("--native-from", type=Path, help="Reuse native assets from a verified Graffiti Lab ZIP for a script-only update")
    parser.add_argument("--author", type=Path, default=ROOT / "build/native/decal-author.exe")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    version = json.loads((ROOT / "manifest.json").read_text())["version_number"]
    build(args.game, args.studio, args.author, (args.out or ROOT / f"outputs/GraffitiLab-{version}.zip").resolve(), args.native_from)
