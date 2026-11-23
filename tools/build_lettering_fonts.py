"""Build the Studio's packed 16-row glyphs from verified upstream font files.

Pass a directory containing the files named in SOURCES. Each source is
identified by its upstream URL and SHA-256. Players only need the packaged art.
"""
import argparse
import gzip
import hashlib
import json
import shutil
import unicodedata as ud
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from writing_fonts import build as build_writing

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "art/lettering"
GOOGLE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
GNU = "https://unifoundry.com/pub/unifont/unifont-17.0.03/font-builds/"
SOURCES = {
    "Bangers": (GOOGLE+"bangers/Bangers-Regular.ttf", "4160a7311de9342674cce9160cde9fcbb30f48190397d86ff1b70b455af65824"),
    "Lobster": (GOOGLE+"lobster/Lobster-Regular.ttf", "d6568e697fd50cedc0be04d8aae4127fe95add607e7bff954ca88604be80c205"),
    "Bree": (GOOGLE+"breeserif/BreeSerif-Regular.ttf", "fd080582d70112ef479ba4ddd72407f9a4fcbcec4caa7d29de259b13eeb5f431"),
    "bitmap": (GNU+"unifont-17.0.03.hex.gz", "a331625847ecbb88e1d0e54dcb4871f53ff85c1046b6706b758f3bf6cc4ac7cf"),
    "upper": (GNU+"unifont_upper-17.0.03.hex.gz", "b3cd85e815408dbfbc97563e58d331ee26575096df776175afbaF3301ee319e3".lower()),
    "BangersOFL": (GOOGLE+"bangers/OFL.txt", "630dd5a307c0657b094d324e069b390edf90182fe5003639e06c02a0e5769af7"),
    "LobsterOFL": (GOOGLE+"lobster/OFL.txt", "88aece7d90f2bb7049719f11619a560af22af3451af141f12aa4f46bb157a99b"),
    "BreeOFL": (GOOGLE+"breeserif/OFL.txt", "fbe0442a6b1ce162c95e241df76cab5ef2daf6a5ac84ae1a7a6749f32c051098"),
    "unilicense": ("https://unifoundry.com/LICENSE.txt", "1e74cb82bf476843e97c2596297b04219b1a7e51f7238944a8c031cb9401fa87"),
}
EXTRA_FACES = json.loads((ROOT / "tools/lettering_sources.json").read_text(encoding="utf-8"))
PINNED = "https://raw.githubusercontent.com/google/fonts/06bfe0d62a98375cb09c942fa18e68bd32cff057/ofl/"
DISPLAY_FACES = {"Slab": "Bree", "Poster": "Bangers", "Script": "Lobster"}
for face, info in EXTRA_FACES.items():
    path = info["path"]
    SOURCES[face] = (PINNED + path, info["font_sha256"])
    SOURCES[face + "OFL"] = (PINNED + path.rsplit("/", 1)[0] + "/OFL.txt", info["license_sha256"])
    DISPLAY_FACES[face] = face


def write_face(name, glyphs):
    # Binary-searchable big-endian records: code point (3), advance (1),
    # then sixteen 16-bit scanlines, with the leftmost pixel in the high bit.
    with (DEST / (name + ".glfont")).open("wb") as out:
        for cp, (width, rows) in sorted(glyphs.items()):
            out.write(cp.to_bytes(3, "big") + bytes([width]) + rows)


def display_face(file):
    font = ImageFont.truetype(str(file), 48)
    ascent, descent = font.getmetrics()
    missing = bytes(font.getmask(chr(0x10FFFF)))
    result = {}
    for cp in [*range(32, 0x530), *range(0x1e00, 0x2070), *range(0x20a0, 0x22ff)]:
        ch = chr(cp)
        if not ch.isprintable() or bytes(font.getmask(ch)) == missing:
            continue
        left, _, right, _ = font.getbbox(ch, anchor="ls")
        left = min(0, left)
        w = max(1, max(right, round(font.getlength(ch))) - left)
        im = Image.new("L", (w, ascent + descent))
        ImageDraw.Draw(im).text((-left, ascent), ch, font=font, anchor="ls", fill=255)
        width = max(1, min(16, round(w * 16 / im.height)))
        im = im.resize((width, 16), Image.Resampling.LANCZOS)
        rows = bytearray()
        for y in range(16):
            row = sum((1 << (15-x)) for x in range(width) if im.getpixel((x, y)) >= 76)
            rows.extend(row.to_bytes(2, "big"))
        result[cp] = width, rows
    return result


def build(source):
    for name, (url, digest) in SOURCES.items():
        path = source / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f"Expected {name} from {url}, SHA-256 {digest}")
    DEST.mkdir(exist_ok=True)
    build_writing(DEST, {face: source / file for face, file in DISPLAY_FACES.items()})
    glyphs = {}
    for name in ("bitmap", "upper"):
        for line in gzip.decompress((source / name).read_bytes()).decode("ascii").splitlines():
            key, bitmap = line.split(":")
            cp, data = int(key, 16), bytes.fromhex(bitmap)
            stride = len(data) // 16
            if stride not in (1, 2):
                continue
            rows = data if stride == 2 else b"".join(bytes([byte, 0]) for byte in data)
            glyphs[cp] = stride * 8, rows
    write_face("Pixel", glyphs)
    for face, file in DISPLAY_FACES.items():
        write_face(face, display_face(source / file))
        shutil.copyfile(source / (file+"OFL"), DEST / (face+"-LICENSE.txt"))
    shutil.copyfile(source / "unilicense", DEST / "Pixel-LICENSE.txt")

    # Preserve the player's original string. These tables are only used for display.
    compose, arabic = {}, {}
    for cp in range(0x10000):
        ch = chr(cp)
        decomp = ud.decomposition(ch).split()
        if len(decomp) == 2 and decomp[0] in ("<isolated>", "<initial>", "<medial>", "<final>"):
            base = chr(int(decomp[1], 16))
            arabic.setdefault(base, {})[decomp[0][1:-1]] = cp
        elif len(decomp) == 2 and not decomp[0].startswith("<"):
            pair = "".join(chr(int(k,16)) for k in decomp)
            if ud.normalize("NFC",pair) == ch:
                compose[pair] = cp
    (DEST/"layout.json").write_text(json.dumps({"compose":compose,"arabic":arabic},
        ensure_ascii=True, separators=(",",":")), encoding="ascii")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    build(parser.parse_args().source)
