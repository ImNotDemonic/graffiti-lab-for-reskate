"""Compile one original decal with ReSkate Studio and produce a local mod ZIP."""
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


def build(game, studio, author, destination):
    game, studio, author = (p.resolve(strict=True) for p in (game, studio, author))
    with (game / "Skate.exe").open("rb") as executable:
        if hashlib.file_digest(executable, "sha256").hexdigest() != GAME_HASH:
            raise ValueError("This decal recipe requires Skate build 20260929")
    manifest = json.loads((ROOT / "manifest.json").read_text())
    plugin = json.loads((ROOT / "reskate-plugin.json").read_text())
    declaration = plugin["resident"][0]
    asset, = plugin["effects"]
    build_dir = ROOT / "build"
    build_dir.mkdir(exist_ok=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=build_dir) as temp:
        scratch = Path(temp)
        authored = scratch / "resources"
        authored.mkdir()
        with Image.open(ROOT / "art/switchback.png") as image:
            if image.mode != "RGBA" or image.size != (512, 512):
                raise ValueError("Switchback must be a 512 x 512 RGBA image")
            (scratch / "art.rgba").write_bytes(image.tobytes())
            icon = Image.new("RGBA", image.size, "#e3e9da")
            icon.alpha_composite(image)
            icon.resize((256, 256), Image.Resampling.LANCZOS).save(scratch / "icon.png")
        subprocess.run([author, game, authored, scratch / "art.rgba"], check=True)
        rows = json.loads((authored / "resources.json").read_text())["resources"]
        templates = [r["name"] for r in rows if r.get("root_type") == "EnvironmentDecalVolumeTemplateData"]
        if templates != [asset] or any(r["target"] != declaration["bundle"] for r in rows):
            raise ValueError("Authored template or target bundle differs from the manifest")
        shaders = {r["name"] for r in rows if r["kind"] == 2 and r["added"]}
        if any(d["name"] not in shaders for d in declaration["shaders"]):
            raise ValueError("Declared shader missing from authored resources")
        fbmod = scratch / "graffiti.fbmod"
        package(authored, fbmod, manifest["version_number"])
        subprocess.run([studio, "compile-mod", game, scratch / "compiled", fbmod], cwd=scratch, check=True)
        patch = scratch / "compiled/Patch"
        toc = declaration["bundle"].removeprefix("win32/") + ".toc"
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
            for path in ("manifest.json", "reskate-plugin.json", "plugin/main.lua", "plugin/surface.lua"):
                archive.write(ROOT / path, path)
            archive.writestr("README.md", "# Graffiti Lab 0.1.0\n\n"
                             "Offline Switchback wall-decal prototype for ReSkate 20261116. "
                             "Extract this package into Mods/GraffitiLab beside the managed Skate.exe. "
                             "Start the game and approve the client plugin.\n\n"
                             "Ctrl+G starts or cancels aiming. Aim at a flat wall within 8 metres. "
                             "Ctrl+P places a valid preview. Ctrl+R removes it. One mark lasts for this session "
                             "until removal, a world reset or expiry.\n\n"
                             "The console also accepts graffiti aim, graffiti place, graffiti remove and graffiti status. "
                             "Tested on a Blue Light Beach kiosk panel in San Vansterdam and a solid interior wall "
                             "in Turbo Token Arcade. On a vent, the artwork only appears on the bars.\n")
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
    parser.add_argument("--out", type=Path, default=ROOT / "outputs/GraffitiLab-0.1.0.zip")
    args = parser.parse_args()
    build(args.game, args.studio, args.author, args.out.resolve())
