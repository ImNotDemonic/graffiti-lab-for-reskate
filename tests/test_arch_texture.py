"""Compare packaged arch previews to a continuous warp of the original RGBA master."""
from io import BytesIO
import json
from pathlib import Path
import sys
from zipfile import ZipFile

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]


def check(package):
    catalogue = {p["id"]: p for p in json.loads((ROOT / "art/catalogue.json").read_text())}
    with ZipFile(package) as z:
        index = json.loads(z.read("art/arch/index.json"))
        manifest = json.loads(z.read("reskate-plugin.json"))
        assert len(manifest["effects"]) == len(set(manifest["effects"])) <= 128
        for key, spec in index.items():
            with Image.open(ROOT / catalogue[key]["source"]) as master:
                w = 512
                h = round(w * master.height / master.width)
                source = master.resize((w, h), Image.Resampling.LANCZOS).convert("RGBA")
            for amount in (-1, -.72, 0, .33, .81, 1):
                bank = min(range(len(spec["anchors"])), key=lambda i: abs(spec["anchors"][i]-amount))
                sheet = Image.open(BytesIO(z.read(f"art/arch/{key}_{bank}.png"))).convert("RGBA")
                size = (w, round(h * (1 + .4 * abs(amount))))
                top = min(0, -.4 * amount)
                expected, actual = (Image.new("RGBA", size) for _ in range(2))
                def shift(x):
                    return h * (-1.6 * amount * x * (1 - x) - top)
                for x in range(w):
                    expected.paste(source.crop((x, 0, x+1, h)), (x, round(shift((x+.5)/w))))
                n = spec["count"]
                for i in range(n):
                    name = f"world/materials/decal/reskate_graffitilab/arch_{key}_{bank}_{i}_dv"
                    assert name in manifest["effects"]
                    strip = sheet.crop((i*sheet.width//n, 0, (i+1)*sheet.width//n, sheet.height))
                    strip = strip.resize((w//n, round(h*(1+2*spec["pad"]))), Image.Resampling.LANCZOS)
                    actual.paste(strip, (i*w//n, round(shift((i+.5)/n)-spec["pad"]*h)))
                a, b = [im.getchannel("A").point(lambda v: 255 if v>=128 else 0) for im in (expected, actual)]
                overlap = ImageChops.darker(a,b).histogram()[255] / ImageChops.lighter(a,b).histogram()[255]
                bg = Image.new("RGBA", size, "#A69885")
                rgb = [Image.alpha_composite(bg,im).convert("RGB") for im in (expected,actual)]
                error = max(ImageStat.Stat(ImageChops.difference(*rgb)).mean)
                assert overlap > .96 and error / 255 < .03, (key, amount, overlap, error)
                print(f"{key} {amount:+.0%} silhouette overlap {overlap:.1%}, max channel mean error {error:.2f}/255")


if __name__ == "__main__":
    check(sys.argv[1])
