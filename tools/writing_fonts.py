"""Pack proportional lettering for the Studio overlay and the portable wall sampler."""
import json

from PIL import Image, ImageDraw, ImageFont


def build(dest, files):
    # The plugin already draws 14 other pictures. Pages are shared between faces
    # and padded with transparent white so linear filtering preserves edge colour.
    side = 512
    faces, tiles = {}, []
    for face, path in files.items():
        font = ImageFont.truetype(str(path), 48, layout_engine=ImageFont.Layout.BASIC)
        ascent, descent = font.getmetrics()
        missing = bytes(font.getmask(chr(0x10FFFF)))
        metrics = {"line": ascent + descent, "base": ascent, "glyphs": {}}
        faces[face] = metrics
        bits = bytearray()
        for cp in [*range(32, 127), *range(160, 256), *range(0x2010, 0x2027)]:
            ch = chr(cp)
            if not ch.isprintable() or (ch!=" " and bytes(font.getmask(ch)) == missing):
                continue
            left, top, right, bottom = font.getbbox(ch, anchor="ls")
            advance = round(font.getlength(ch), 3)
            mask = Image.new("L", (max(1, right-left), max(1, bottom-top)))
            ImageDraw.Draw(mask).text((-left, -top), ch, font=font, anchor="ls", fill=255)
            bounds = mask.getbbox()
            if bounds:
                left += bounds[0]
                top += bounds[1]
                mask = mask.crop(bounds)
            width, height = mask.size if bounds else (0, 0)
            record = [advance, left, top, width, height, len(bits), 0, 0, 0]
            metrics["glyphs"][ch] = record
            if bounds:
                bits.extend(mask.point(lambda value: 255 if value >= 96 else 0).convert("1").tobytes())
                tiles.append((mask, record))
        (dest / (face + ".ink")).write_bytes(bits)

    pages = []
    x, y, row = side, side, 0
    for mask, record in sorted(tiles, key=lambda item: -item[0].height):
        width, height = mask.size
        if x + width + 2 > side:
            x, y, row = 0, y + row, 0
        if y + height + 2 > side:
            pages.append(Image.new("L", (side, side)))
            x, y, row = 0, 0, 0
        pages[-1].paste(mask, (x+1, y+1))
        record[6:] = [len(pages), x+1, y+1]
        x += width + 2
        row = max(row, height + 2)
    if len(pages) + 14 > 32:
        raise ValueError("Font pages exceed the host's shared package image count")
    for i, alpha in enumerate(pages, 1):
        rgba = Image.new("RGBA", alpha.size, "white")
        rgba.putalpha(alpha)
        rgba.save(dest / f"writing-{i}.png", optimize=True)
    for face, metrics in faces.items():
        (dest / (face + ".metrics.json")).write_text(
            json.dumps(metrics, ensure_ascii=True, separators=(",", ":")), encoding="ascii")
