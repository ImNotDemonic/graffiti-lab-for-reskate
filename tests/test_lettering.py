"""Run packed glyphs through the actual Studio input, save, wall and emote routes."""
import sys
from test_menu import run

EXTRA = "éèΩ東京Жבשלוםسلام 😀中\u0301\u05b0"

CHECKS = r"""
online=false step()
local disk={} reskate.files=memoryFiles(disk)
local model=require("composition")
local lettering=require("lettering")
local projects=require("studio_projects")
local p=model.new()
local l=model.add(p,"text","Proof")
assert(l.font=="Flow" and l.spacing==0 and l.natural)
for _,phrase in {"I","Writing","Wavy letters","Café","One\nTwo"} do
    l.text=phrase
    local face=lettering.layout(l)
    assert(face.smooth and #face.characters>0,phrase)
    local w,h=model.dimensions(l,p.aspect)
    assert(math.abs(w*p.aspect/h-face.width/face.height)<.0001,"distorted lettering")
    assert(w<=l.w and h<=l.h)
    for _,g in face.characters do
        if g.metric[4]>0 then assert(g.metric[7]>=1 and g.metric[7]<=18) end
    end
end
l.text="Tag"
assert(model.render(p):match("^GLART1 96 96 "), "short wall tag lost detail")
local phrase="Café @ 2:30! #42 / 東京"
assert(#lettering.fonts==20)
l.text=phrase
for _,font in lettering.fonts do
    l.font=font
    assert(not lettering.layout(l).missing,font.." coverage")
end
local masks={}
l.text="Skate!"
for _,font in lettering.fonts do
    l.font=font
    local raw,parts=model.render(p)
    assert(raw and #parts<=256 and not masks[raw],font.." indistinct or empty")
    assert(projects.save(p,false,raw))
    local restored,thumbnail=projects.open(p.id)
    assert(restored.layers[1].font==font and model.render(restored)==thumbnail and thumbnail==raw)
    masks[raw]=true
end
-- The one-pixel upright of a Pixel K falls between output-cell centres at this width.
l.font="Pixel" l.text="Kick 24/7!"
l.natural=nil l.w=.82 l.h=.42 l.spacing=1
local _,pixelParts=model.render(p)
local function covered(x,y)
    for _,b in pixelParts do
        if math.abs(x-.5-b.x)<b.w/2 and math.abs(y-.5-b.y)<b.h/2 then return true end
    end
    return false
end
for y=20,30 do
    assert(covered(9.5/96,(y+.5)/48) or covered(10.5/96,(y+.5)/48),"Pixel K lost its upright")
end
l.font="Slab" l.text="a"
l.natural=true l.spacing=0
local small=model.render(p) l.text="A" assert(model.render(p)~=small)
local function painted(word)
    l.text=word local layout=lettering.layout(l)
    assert(not layout.missing and model.valid(p))
    return assert(model.render(p))
end
assert(painted("é")==painted("e"..utf8.char(0x301)))
assert(painted("東")~=painted("京") and painted("@")~=painted("&"))
assert(painted("ב")~=painted("ש"))
l.text="سلام" local arabic=lettering.layout(l)
assert(not arabic.missing and arabic.characters[1].text=="م" and arabic.characters[4].text=="س")
l.text="😀" assert(not lettering.layout(l).missing)
l.text=string.rep("é",256)
assert(model.valid(p) and lettering.limitText(l.text.."!") == l.text)
assert(not lettering.limitText(string.char(255)))
l.text="A"..utf8.char(0x10ffff) assert(lettering.layout(l).missing)
l.text="Hi\nSkate!" assert(#lettering.layout(l).lines==2)
l.text=string.rep("Hello ",12) assert(#lettering.layout(l).lines>1)
-- Saved uppercase versions retain their old five-column output.
l.text="AZ-9!" l.font=nil l.w=.6 l.h=.32
local old=model.render(p)
assert(projects.save(p,false,old))
local oldProject=projects.open(p.id)
assert(model.render(oldProject)==old)

local positions={}
local log=d.text
d.text=function(self,position,label,...) log(self,position,label,...) positions[label]=position end
local function choose(label)
    table.clear(positions) step()
    local pt=assert(positions[label],label)
    click(pt.x+2,pt.y+3)
end
console.graffiti({"studio"}) step()
local glyphDraws=0
local image=d.image
d.image=function(self,path,tl,br,style)
    if path:match("^art/lettering/writing%-%d+%.png$") then
        glyphDraws+=1
        assert(tl.x<br.x and tl.y<br.y and #style.uv==4)
        for _,uv in style.uv do assert(uv>=0 and uv<=1) end
    end
    return image(self,path,tl,br,style)
end
choose("Create new") choose("LETTERING") choose("Add text layer")
glyphDraws=0 step() assert(glyphDraws==3,"default tag needs three high-resolution glyphs")
choose("Preview wall detail") glyphDraws=0 step() assert(glyphDraws==0)
choose("Show Studio lettering") glyphDraws=0 step() assert(glyphDraws==3)
choose("Tag")
typed="trash" step() step()
keys[0x11]=true key(0x41) keys[0x11]=false
typed=phrase.."中" step() step()
key("Backspace")
keys[0x10]=true key("Enter") keys[0x10]=false
typed="Go!" step() step() key("Enter")
choose("SCRIPT") choose("DECO") choose("SAVE & USE") choose("Save project") choose("Save as premade")
local master,thumb
for _,id in projects.list() do
    if id~=p.id then master,thumb=projects.open(id) end
end
assert(master and master.layers[1].text==phrase.."\nGo!",master and master.layers[1].text)
assert(master.layers[1].font=="Deco" and model.render(master)==thumb)
local export=assert(projects.premade(master,thumb))
local onWall=assert(require("imports").decode(export.rawFrame))
assert(#onWall>0 and export.rawFrame==thumb)
choose("Place in World") emit("action","Place Switchback") step()
assert(active and has("Save project"))
local service=require("graffiti_emotes").create(testCatalogue,function() return nil end)
assert(service.assign(1,export) and service.slot(1).frames)
choose("LETTERING") choose("Separate letters and keep original")
choose("SAVE & USE") choose("Save project")
local split=projects.open(master.id)
assert(split.layers[1].hidden and split.layers[1].text==phrase.."\nGo!")
local jp=false
for _,char in split.layers do
    assert(model.valid(split) and utf8.len(char.text))
    if char.text=="東" then jp=true end
end
assert(jp)
print("PASS 20 distinct and reopenable fonts, all picker rows, Unicode input, split, legacy output, wall and emote export")
"""

if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "lettering", font_characters=EXTRA)
