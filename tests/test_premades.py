"""Check a built mod's catalogue, atlas, page controls and decal choices with Luau.

Run: python tests/test_premades.py PATH_TO_LUAU PATH_TO_MOD_ZIP
"""
import io
import json
from pathlib import Path
import sys
from zipfile import ZipFile

from PIL import Image
from test_menu import ROOT, run

CHECKS = """
online=false step()
local thumbnails={}
d.image=function(_,path,_,_,style)
    if path=="art/premades.png" then table.insert(thumbnails,style.uv) end
end
local function checkPage(first)
    table.clear(thumbnails) step()
    local n=math.min(9,#testCatalogue-first+1)
    assert(#thumbnails==n+1)
    for i=1,n do
        assert(thumbnails[i]==testCatalogue[first+i-1].thumb,"wrong thumbnail on page")
    end
    assert(thumbnails[n+1]==testCatalogue[first].thumb,"wrong detail image")
end
console.graffiti({"library"}) step()
for first=1,#testCatalogue,9 do
    checkPage(first)
    click(475,757)
end
click(86,757) checkPage((math.ceil(#testCatalogue/9)-2)*9+1)
-- The D-pad crosses a page boundary and moving back reveals the previous page.
buttons.left=true step() buttons.left=false step()
local index=(math.ceil(#testCatalogue/9)-2)*9
assert(has(string.upper(testCatalogue[index].name)))
buttons.right=true step() buttons.right=false step()
checkPage(index+1)
local categories={}
for _,piece in testCatalogue do
    if not table.find(categories,piece.category) then table.insert(categories,piece.category) end
end
table.sort(categories)
for i,category in categories do
    click(96+i%4*124,266+math.floor(i/4)*43)
    local matches={}
    for _,piece in testCatalogue do
        if piece.category==category then table.insert(matches,piece) end
    end
    for first=1,#matches,9 do
        table.clear(thumbnails) step()
        local n=math.min(9,#matches-first+1)
        assert(#thumbnails==n+1 and has(string.format("%d pieces   ·   %d / %d",
            #matches,math.ceil(first/9),math.ceil(#matches/9))))
        for slot=1,n do assert(thumbnails[slot]==matches[first+slot-1].thumb) end
        click(475,757)
    end
end
click(90,266)
click(92,188) typed="rSkT" step()
assert(has("CROWN TAG"),"lettering search missed a matching design")
click(506,188) typed="049" step()
assert(has("RAIL SIGIL") and has("1 piece   ·   1 / 1"))
key("Enter") click(200,965) console.graffiti({"place"})
local kept=nextHandle
assert(live[kept].asset:find("pack_049_dv",1,true) and live[kept].alpha==1)
for _,piece in testCatalogue do
    console.graffiti({"library"}) step()
    click(90,188) typed=piece.number or piece.name step()
    assert(has(string.upper(piece.name)))
    key("Enter") click(200,965)
    assert(live[nextHandle].asset=="world/materials/decal/reskate_graffitilab/"..piece.id.."_dv")
    assert(live[kept] and live[kept].alpha==1 and count()==2,"switching lost a confirmed mark")
    console.graffiti({"remove"}) step()
    assert(count()==1 and live[kept])
end
console.graffiti({"remove"}) assert(count()==0)
print("PASS: all category filters, paged thumbnails, D-pad, lettering and number search, every design preview, confirmed placement retained and removed")
"""


def check_package(package):
    source = json.loads((ROOT / "art/catalogue.json").read_text(encoding="utf-8"))
    with ZipFile(package) as archive:
        assert archive.testzip() is None
        runtime = json.loads(archive.read("art/catalogue.json"))
        manifest = json.loads(archive.read("reskate-plugin.json"))
        atlas = Image.open(io.BytesIO(archive.read("art/premades.png"))).convert("RGBA")
        for script in ("plugin/main.lua", "plugin/selector.lua"):
            assert archive.read(script) == (ROOT / script).read_bytes()
    assert [p["id"] for p in source] == [p["id"] for p in runtime]
    assert len({p["id"] for p in runtime}) == len(runtime)
    assert len({p["slot"] for p in runtime}) == len(runtime)
    assert not any(16 <= p["slot"] <= 31 for p in runtime)
    effects = set(manifest["effects"])
    root = "world/materials/decal/reskate_graffitilab/"
    shaders = {s["name"]: s["roots"] for d in manifest["resident"] for s in d["shaders"]}
    for original, entry in zip(source, runtime):
        effect = root + entry["id"] + "_dv"
        assert effect in effects and shaders[root + "shaderblockdepot_" + entry["id"]] == [effect]
        with Image.open(ROOT / original.get("source", f"art/{entry['id']}.png")) as image:
            image.thumbnail((512, 512), Image.Resampling.LANCZOS)
            assert abs(entry["aspect"] - image.width / image.height) < 0.00001
            wall = Image.new("RGBA", (512, 512))
            wall.paste(image, ((512 - image.width) // 2, (512 - image.height) // 2))
            assert wall.getbbox(), entry["id"]
            # Locate the tile via the packaged UVs and compare its pixels to the master.
            l, t, r, b = entry["thumb"]
            assert 0 <= l < r <= 1 and 0 <= t < b <= 1
            cell = 160
            cx, cy = (l + r) / 2 * atlas.width, (t + b) / 2 * atlas.height
            x, y = int(cx // cell) * cell, int(cy // cell) * cell
            expected = wall.resize((cell, cell), Image.Resampling.LANCZOS)
            assert atlas.crop((x, y, x + cell, y + cell)).tobytes() == expected.tobytes(), entry["id"]
    return runtime


if __name__ == "__main__":
    catalogue = check_package(Path(sys.argv[2]))
    run(sys.argv[1], CHECKS, "premades", catalogue=catalogue)
    print(f"Verified the packaged thumbnails and shader declarations for all {len(catalogue)} artworks.")
