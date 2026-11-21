"""Exercise front-door navigation, real screen callbacks and pointer hitboxes in Luau."""
from pathlib import Path
from tempfile import TemporaryDirectory
import json
import subprocess
import sys

from test_sharing import ADAPTER, ROOT

HOST = """
local screenCount=0
local active, nativePage, typed, lastToast, actionClick
local actions,keys,buttons,labels={}, {},{},{}
local cursor={position=v(0,0,0),left=false}
local saved={}
local defaultCamera=reskate.camera.get
reskate.camera.get=function() local view=defaultCamera() view.fov=60 return view end
local size=v(1920,1080,0)
reskate.package.read_json=function(path)
    if path=="manifest.json" then return {version_number="test"} end
    if path=="art/palette.json" then return table.create(16,"#AA00AA") end
    return testCatalogue
end
reskate.ui={
    screen=function(name)
        assert(screenCount<4,"ReSkate supports four screens per plugin")
        assert(not actions[name]) actions[name]=true screenCount+=1
    end,
    open=function(name) assert(actions[name]) active=name end,
    close=function() active=nil end,
    toast=function(t) lastToast=t end,
}
local storageEncode=reskate.json.encode
reskate.json.encode=function(doc)
    if doc.strokes then saved=table.clone(doc.strokes) end
    return storageEncode(doc)
end
reskate.menu.page=function(_,fn) nativePage=fn end
reskate.input.cursor=function() return cursor end
reskate.input.gamepad=function() return {buttons=buttons} end
reskate.input.key=function(k)
    local vk=tonumber(k)
    if vk then assert(vk>=1 and vk<=254,"a virtual key from 1 to 254") end
    return keys[vk or k]
end
reskate.input.text=function() local result=typed or "" typed=nil return result end
local d={rect=noop,circle=noop,line=noop,image=noop,game_image=noop,gradient=noop,poly=noop,world_image=noop,
    world_to_screen=function() return nil end,size=function() return size end,
    text=function(_,_,t) table.insert(labels,t) end}
local function step() frame(16) table.clear(labels) emit("draw",d) end
local function has(t) return table.find(labels,t)~=nil end
local function click(x,y)
    cursor.position=v(x,y,0) cursor.left=false step()
    cursor.left=true step() cursor.left=false step()
end
local function key(k) keys[k]=true step() keys[k]=false step() end
local function escape()
    local closed=assert(active) active=nil keys.Escape=true emit("screen_closed",closed)
    step() keys.Escape=false step()
end
"""
CHECKS = """
online=false step()
local widgets={button=function() return actionClick end,note=noop}
actionClick=true nativePage(widgets) emit("menu_changed",{reskate=true}) assert(active==nil)
emit("menu_changed",{}) step() assert(active=="Graffiti Lab" and has("C U R R E N T   C A N"))
click(200,420) assert(active=="Premade Art" and has("SWITCHBACK"))
click(212,270) assert(not has("SWITCHBACK") and has("BONEHEAD"))
click(90,188) typed="no match" step() assert(has("No pieces match.")) key("Enter")
escape() assert(active=="Graffiti Lab")
click(200,530) assert(active=="Graffiti Lab Studio" and has("MARKER"))
click(880,400) click(360,186) click(880,400)
click(370,947) assert(#saved==0,"eraser did not remove the clicked stroke")
click(90,947) click(370,947) assert(#saved==1 and saved[1].colour==3,"undo erase lost the stroke")
click(221,947) click(370,947) assert(#saved==0,"redo erase failed")
escape() assert(active=="Graffiti Lab")
click(180,650) assert(active=="Graffiti Lab Studio")
assert(has("40 mm") and has("PAINT SIZE"))
click(104,488) assert(has("65 mm"))
key("E") assert(has("ERASE SIZE") and has("160 mm"))
click(45,488) assert(has("100 mm"))
key("]") assert(has("160 mm"))
key("E") assert(has("65 mm"))
click(72,488) assert(has("40 mm"))
click(100,267) escape() assert(active=="Graffiti Lab" and has("Ink · 40 mm"))
click(200,778) assert(active=="Graffiti Lab Studio" and has("Designs   1"))
click(390,187) assert(has("No local marks on this map yet."))
escape() assert(active=="Graffiti Lab")
click(200,845) assert(has("DEFAULT KEY"))
click(265,188) click(297,340) click(441,539)
assert(has("Acid"))
click(452,185) assert(has("Artwork decals") and has("Visible paint / recorded"))
escape() assert(active=="Graffiti Lab" and has("Acid · 65 mm"))
escape() assert(active==nil)
emit("action","Open Graffiti Lab on pad") step()
buttons.down=true step() buttons.down=false step() -- Public Artworks follows Settings.
buttons.down=true step() buttons.down=false step()
buttons.a=true step() buttons.a=false step()
assert(active=="Premade Art","controller failed to open the first row after wrap")
click(175,966) assert(active==nil and count()==1 and live[1].alpha==0.45)
buttons.a=true step() step()
assert(active=="Premade Art" and live[1].alpha==1 and count()==1,"held A failed to return to the selector")
buttons.a=false step() key("Right") key("Enter")
assert(active==nil and live[2].asset:find("birds_dv",1,true))
key(221) key("E")
assert(math.abs(previewScale-1.05)<0.00001 and previewAngle==5,"Birds preview did not resize and rotate")
key(0x30)
assert(previewScale==1 and previewAngle==0,"top-row 0 did not reset the Birds preview")
cursor.left=true keys[1]=true step() step()
assert(active=="Premade Art" and live[2].alpha==1 and count()==2,"placement click passed through the returned menu")
cursor.left=false keys[1]=false step()
escape() assert(active=="Graffiti Lab") click(200,778)
click(389,185) assert(has("Switchback"),"confirmed mark absent from the gallery map tab")
escape() escape()
local originalFiles=reskate.files
reskate.files={list=function() return {"blackbook-0001.json","blackbook-0002.json","blackbook-0003.json",
    "blackbook-0004.json","blackbook-0005.json"} end,read=function(file) if file:match("^blackbook") then return file end return originalFiles.read(file) end,
    write=originalFiles.write,remove=originalFiles.remove}
reskate.json.decode=function(file)
    if not file:match("^blackbook") then return decodeValue(file) end
    return {version=1,name="Drawing "..file:sub(11,14),strokes={{colour=3,size=28,xy={1024,512}}}}
end
console.graffiti({"blackbook"}) step() click(470,660)
assert(has("Drawing 0001") and has("2 / 2"))
click(120,421) assert(active==nil)
emit("action","Place Switchback") step()
assert(active=="Graffiti Lab Studio" and has("Drawing 0001") and has("2 / 2"),"placement lost the saved gallery page")
escape() assert(active==nil,"a gallery shortcut should return to skating on Back")
reskate.files=originalFiles
online=true step() emit("action","Open Graffiti Lab") step()
click(220,530) assert(active=="Graffiti Lab" and lastToast=="This tool is available offline.")
click(220,420) assert(active=="Premade Art")
click(458,267) click(480,757) step()
assert(has("12 pieces   ·   2 / 2"))
click(200,965) assert(active==nil)
focus=v(2,1,20) emit("action","Place Switchback") step()
assert(active==nil,"a rejected placement should keep aiming")
focus=v(2,1,0) emit("action","Place Switchback") step()
assert(active=="Premade Art" and has("12 pieces   ·   2 / 2") and has("ZINE CUT-UP"),
    "online confirmation lost the category, page or selection")
emit("level_unloading") step() assert(active==nil)
emit("level_loaded",map) step()
console.graffiti({"library"}) step() assert(active=="Premade Art")
escape() assert(active==nil,"direct library shortcut unexpectedly opened the hub")
size=v(1280,720,0) emit("action","Open Graffiti Lab") step()
click(180,560) assert(has("DEFAULT KEY"))
print("PASS: menu navigation, offline and online placement returns, held mouse and controller inputs, Blackbook page, editor erase/undo, can settings, map marks and 720p hitboxes")
"""
def run(luau, checks, name="menu", capture=False, catalogue=None):
    if catalogue is None:
        catalogue = json.loads((ROOT / "art/catalogue.json").read_text(encoding="utf-8"))
    rows = []
    for piece in catalogue:
        fields = [key + "=" + json.dumps(piece[key], ensure_ascii=False)
                  for key in ("id", "name", "category", "number", "lettering", "colourway") if key in piece]
        fields.append("aspect=" + str(piece.get("aspect", 1)))
        fields.append("sheet=" + json.dumps(piece.get("sheet", "art/premades.png")))
        fields.append("thumb={" + ",".join(map(str, piece.get("thumb", [0, 0, 1, 1]))) + "}")
        rows.append("{" + ",".join(fields) + "}")
    with TemporaryDirectory() as directory:
        code = [ADAPTER, "local testCatalogue={" + ",\n".join(rows) + "}", HOST]
        for module in ("dock", "surface", "sharing", "wall_codec", "wall_store", "wall_ink", "media_format", "playback", "pattern", "blackbook", "wall_art", "paint", "studio", "imports", "library", "placements", "map_screen", "photo", "library_screen", "gallery", "gallery_dock", "gallery_screen", "selector", "menu", "spray_fx", "spray_arm"):
            source = (ROOT / "plugin" / (module + ".lua")).read_text(encoding="utf-8")
            code.append(f"modules.{module}=(function()\n{source}\nend)()")
        code.extend([(ROOT / "plugin/main.lua").read_text(encoding="utf-8"), checks])
        script = Path(directory) / f"{name}.luau"
        script.write_text("\n".join(code), encoding="utf-8")
        return subprocess.run([luau, script], check=True, stdout=subprocess.PIPE if capture else None, text=True).stdout


if __name__ == "__main__":
    run(sys.argv[1], CHECKS)
