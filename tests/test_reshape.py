"""Exercise the real reshape editor, ink exporter and save reader in fresh Luau VMs."""
import sys
from test_menu import run

CREATE = r'''
local disk={}
reskate.files=memoryFiles(disk)
local raw="GLART1 8 8 8 8\n1 1 6 1 3\n1 6 6 1 3\n1 2 1 4 3\n6 2 1 4 6"
disk["imports/Outline.graffiti"]=raw
local shape,imports=require("reshape"),require("imports")
local piece={file="imports/Outline.graffiti",name="Outline"}
assert(imports.load(piece))
local src,original=shape.source(piece)
assert(src.grids[1].w==8 and src.grids[1].h==8)
local untouched=encodeValue(src)
local identity=assert(shape.render(src,original,1))
local outputs={[identity]=true}
for _,mode in shape.modes do
    local settings=shape.identity()
    settings.mode,settings.amount=mode,.8
    if mode=="Corners" then settings=shape.drag(settings,1,.22,-.15) end
    local frame,parts=shape.render(src,settings,1)
    assert(frame and not outputs[frame],mode.." did not produce a distinct shape")
    outputs[frame]=true
    assert(#parts>0 and #parts<=256)
    -- A trapezoid moves the centre of the original towards its shorter vertical edge.
    local centreX=if mode=="Perspective" then -.36*settings.amount else 0
    for _,p in parts do
        assert(p.colour==3 or p.colour==6)
        assert(math.abs(p.x-centreX)>p.w/2 or math.abs(p.y)>p.h/2,mode.." filled the transparent centre")
    end
    local handles=shape.handles(settings)
    assert(#handles==(if mode=="Corners" then 8 else 2))
end
assert(encodeValue(src)==untouched and shape.render(src,original,1)==identity)
local animation={aspect=src.aspect,frameMs=420,grids={src.grids[1],table.clone(src.grids[1])}}
animation.grids[2].pixels=animation.grids[2].pixels:gsub("3","7")
local settings=shape.identity()
settings.mode="Corners" settings=shape.drag(settings,1,.22,-.15)
local frames={}
for i=1,2 do
    local frame,parts=shape.render(animation,settings,i)
    assert(#parts<=128) frames[i]=frame
end
assert(frames[1]~=frames[2])
local file=assert(shape.save("Warp",animation,settings,frames))
assert(file=="Warp.glshape")
assert(shape.save("Warp",animation,settings,frames)=="Warp 2.glshape")
reskate.files.write=function() return nil,"disk full" end
local failed,why=shape.save("Warp",animation,settings,frames)
assert(not failed and why=="disk full" and disk["imports/Outline.graffiti"]==raw)
local bytes=disk["imports/"..file]
print("DOC "..(bytes:gsub(".",function(c) return string.format("%02x",c:byte()) end)))
'''

REOPEN = r'''
local file="imports/Warp.glshape"
reskate.files=memoryFiles({[file]=bytes})
local shape,imports=require("reshape"),require("imports")
local piece=assert(imports.list()[1]) assert(imports.load(piece))
local src,cfg=shape.source(piece)
assert(cfg.mode=="Corners" and cfg.corners[1]==.22 and cfg.corners[2]==-.15)
assert(src.frameMs==420 and #piece.frames==2)
for i=1,2 do assert(shape.render(src,cfg,i)==piece.media.frames[i]) end
local cover,name,asset=require("gallery").prepare({file=file,kind="import",name="Warp"})
assert(cover==piece.rawFrame and name=="Warp" and asset.frames[2]==piece.media.frames[2])
assert(not asset.source and not asset.settings and not asset.sound)
assert(not shape.read(bytes:sub(1,-6)))
'''

EDITOR = r'''
online=false
local read=reskate.package.read_json
reskate.package.read_json=function(path)
    if path:find("art/reshape/",1,true) then return {w=4,h=2,pixels="3333.63."} end
    return read(path)
end
local positions={}
local drawText=d.text
d.text=function(_,pos,label,style)
    positions[label]=pos
    drawText(d,pos,label,style)
end
local function press(label)
    table.clear(positions) step()
    local pos=assert(positions[label],label)
    click(pos.x+2,pos.y+4)
    step()
end
step() console.graffiti({"organise"}) step()
click(270,525) press("Reshape artwork") step()
for _,mode in {"BULGE","BASELINE","PERSPECTIVE","CORNERS"} do press(mode) end
click(1120,310)
press("Reset to original shape") press("Undo reshape edit")
assert(has("HORIZONTAL (%)") and has("Redo reshape edit"))
press("Apply and save copy") step()
local files=reskate.files.list("imports")
local file=assert(files[1])
assert(file:match("%.glshape$"))
local doc=assert(require("reshape").read(assert(reskate.files.read("imports/"..file))))
assert(doc.settings.mode=="Corners" and doc.settings.corners[1]~=0)
press("Reshape artwork")
assert(has("HORIZONTAL (%)") and has("CORNERS"))
print("PASS reshape dock, control hitboxes, corner undo, save and reopen")
'''

TEXTURED = r'''
local imports,shape,world=modules.imports,modules.reshape,modules.placements
local grid={w=4,h=2,pixels="3333.63."}
local read=reskate.package.read_json
reskate.package.read_json=function(path)
    if path=="art/arch/index.json" then return {pack_002={count=8,pad=.12,anchors={-.8,-.4,0,.4,.8}}} end
    if path=="art/reshape/pack_002.json" then return grid end
    return read(path)
end
local disk={}
reskate.files=memoryFiles(disk)
local cfg=shape.identity() cfg.amount=.81
local src={aspect=2,frameMs=250,grids={grid}}
local frame=assert(shape.render(src,cfg,1))
local file=assert(shape.save("Original",src,cfg,{frame}))
local piece={file="imports/"..file,id="import/"..file,name="Original"}
assert(imports.load(piece) and piece.arch.amount==.81 and #piece.textureParts==8)
local base={1,0,0,0,0,0,.04,0,0,-.5,0,0,2,1,-2,1}
world.load("map")
local row=world.new(piece,base,1,0)
local legacy=table.clone(row) legacy.arch=nil
assert(world.handleCount(legacy)==8 and world.design(legacy).textureParts[1].asset=="arch_pack_002_4_0")
local changed=table.clone(legacy)
changed.parts=table.clone(legacy.parts) changed.parts[1]=table.clone(legacy.parts[1])
changed.parts[1].colour=15
assert(not world.design(changed).textureParts)
disk["imports/"..file]=nil
assert(world.design(row).arch.amount==.81 and world.handleCount(row)==8)
local other=table.clone(cfg) other.mode="Corners"
assert(not modules.native_arch.identify(src,other))
print("PASS original-texture arch, verified legacy match and self-contained new placement")
'''

if __name__ == "__main__":
    lua = sys.argv[1]
    log = run(lua, CREATE, "reshape_save", capture=True)
    data = bytes.fromhex(next(line[4:] for line in log.splitlines() if line.startswith("DOC ")))
    escaped = "".join(f"\\{value:03}" for value in data)
    run(lua, f'local bytes="{escaped}"\n' + REOPEN, "reshape_reopen")
    run(lua, EDITOR, "reshape_controls")
    run(lua, TEXTURED, "reshape_original_texture")
    print("PASS five distinct ink transforms, transparency, original retained, two-frame save and independent-process reopen")
