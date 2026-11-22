"""Bake original-colour strips for the native, continuously adjustable arch."""
import hashlib
import json

from PIL import Image


def prepare(root, catalogue, scratch):
    slots = json.loads((root / "art/arch-sources.json").read_text())
    by_id = {p["id"]: p for p in catalogue}
    used = {p["slot"] for p in catalogue} | set(range(16, 32))
    dest = scratch / "arch"
    dest.mkdir()
    index, args, digest = {}, [], hashlib.sha256()
    count, pad = 8, 0.12
    # Use the midpoint of each equal slider interval to minimise the largest
    # correction (and visible steps at strip boundaries) over the full range.
    anchors = [-0.8, -0.4, 0, 0.4, 0.8]
    for key, first in slots.items():
        piece = by_id[key]
        with Image.open(root / piece["source"]) as source:
            # Premultiplied-alpha resampling retains dark outlines at transparent edges.
            image = source.convert("RGBa")
        w, h = image.size
        index[key] = dict(count=count, pad=pad, anchors=anchors)
        for bank, amount in enumerate(anchors):
            sheet = Image.new("RGBA", (512, 256))
            for i in range(count):
                mid = (i + 0.5) / count
                # Pixels inside a strip already follow this bank's smooth curve.
                # Luau translates each strip for the exact strength on the slider.
                mesh = []
                def offset(x):
                    u = (i + x / 512) / count
                    return 1.6 * amount * (u * (1 - u) - mid * (1 - mid))
                for left in range(0, 512, 32):
                    right = left + 32
                    x0, x1 = (i + left / 512) * w / count, (i + right / 512) * w / count
                    y0, y1 = (offset(left) - pad) * h, (offset(right) - pad) * h
                    span = (1 + 2 * pad) * h
                    mesh.append(((left, 0, right, 512),
                                 (x0, y0, x0, y0 + span, x1, y1 + span, x1, y1)))
                strip = image.transform((512, 512), Image.Transform.MESH, mesh,
                                        Image.Resampling.BICUBIC).convert("RGBA")
                name = f"arch_{key}_{bank}_{i}"
                slot = first + bank * count + i
                if slot in used or slot > 127:
                    raise ValueError(f"Native decal slot collision or overflow: {slot}")
                used.add(slot)
                path = scratch / f"{name}.rgba"
                data = strip.tobytes()
                path.write_bytes(data)
                digest.update(name.encode() + bytes([slot]) + data)
                args.extend([str(slot), name, path])
                sheet.paste(strip.resize((64, 256), Image.Resampling.LANCZOS), (i * 64, 0))
            sheet.save(dest / f"{key}_{bank}.png")
    (dest / "index.json").write_text(json.dumps(index), encoding="utf-8")
    (dest / "materials.sha256").write_text(digest.hexdigest(), encoding="ascii")
    return args
