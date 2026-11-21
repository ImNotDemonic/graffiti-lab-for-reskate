"""Render the fixed dock headings and print texture into a single ReSkate UI image."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
font = ImageFont.truetype("impact.ttf", 90)
atlas = Image.new("RGBA", (512, 512))
labels = ["GRAFFITI", "LAB", "PREMADE ART", "CUSTOM EDITOR", "WALL PAINTING",
          "SAVED GALLERY", "SETTINGS", "PLACE ON WALL", "SAVE TO BLACKBOOK"]
for i, label in enumerate(labels):
    l, t, r, b = font.getbbox(label)
    mask = Image.new("L", (r-l, b-t))
    ImageDraw.Draw(mask).text((-l, -t), label, font=font, fill=255)
    mask = mask.resize((300, 50), Image.Resampling.LANCZOS)
    atlas.paste((255, 255, 255, 255), (2, 2 + i*56, 302, 52 + i*56), mask)
draw = ImageDraw.Draw(atlas)
for y in range(3, 200, 7):
    for x in range(3, 200, 7):
        alpha = round(max(0, (x - y + 30) / 230) * 150)
        draw.ellipse((310+x-1, y-1, 310+x+2, y+2), fill=(255, 90, 31, alpha))
draw.polygon([(311,216), (323,213), (423,215), (509,213),
              (505,222), (389,220), (316,222)], fill=(255,90,31,255))
atlas.save(root / "art/menu-type.png", optimize=True)
