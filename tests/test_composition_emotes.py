"""Exercise mixed projects and a cold emote recipient in separate Luau processes."""
import json
import sys

from test_menu import run

AUTHOR = r"""
online=false
local disk={} reskate.files=memoryFiles(disk)
local m=require("composition")
local files=require("studio_projects")
local project=m.new() project.name="Sidewalk Signal"
local body=m.add(project,"shape","Rounded") body.x=.31 body.ink=9
local wheel=m.add(project,"shape","Wheel") wheel.x=.18 wheel.y=.7 wheel.ink=2
local word=m.add(project,"text","Title") word.text="GO!" word.x=.67 word.y=.28
local brush=m.add(project,"paint","Highlights")
local pixels=string.split(brush.grid.pixels,"")
m.stamp(pixels,.08,.85,.8,.62,2.2,4,100) brush.grid.pixels=table.concat(pixels)
local source="GLART1 4 4 4 4\n0 0 3 2 7\n2 2 2 2 4"
disk["imports/New art.graffiti"]=source
local imported={id="import/New art.graffiti",name="New art",file="imports/New art.graffiti"}
local g,aspect=files.image(imported) assert(g and aspect==1)
local im=m.add(project,"image","Imported corner") im.grid=g im.source=imported.id im.x=.85 im.y=.76 im.w=.17 im.h=.34
assert(m.valid(project))
local raw,parts=m.render(project) assert(raw and #parts>4)
assert(files.save(project,false,raw) and files.save(project,true,raw))
local master,thumb=files.open(project.id)
assert(master.layers[3].text=="GO!" and master.layers[4].grid.pixels==brush.grid.pixels and master.layers[5].source==imported.id)
assert(m.render(master)==raw and thumb==raw and files.draft().id==master.id)
local pie=assert(files.premade(master,raw)) assert(pie.rawFrame==raw and pie.aspect==2 and disk[imported.file]==source)
master.layers[3].angle=40 assert(m.render(master)~=raw and disk[pie.file]==raw)
local broken=table.clone(project) broken.version=2
assert(not files.save(broken,false,raw) and files.open(project.id).name==project.name)
local registry=require("graffiti_emotes")
local function scope() return "12345",map end
local service=registry.create(testCatalogue,scope)
assert(service.assign(1,testCatalogue[1]) and service.assign(2,imported) and service.assign(3,pie))
local drawing={version=1,name="Dot",strokes={{colour=4,size=96,xy={256,256,1024,620}}}}
local media=assert(require("media_format").fromDrawing(drawing,require("wall_art")))
local drawPiece={id="freehand-test",name="Dot",media=media,frames=require("media_format").validate(media,require("imports").decode),aspect=2}
drawPiece.parts=drawPiece.frames[1]
assert(service.assign(4,drawPiece))
local which=assert(service.slot(3)).raw
assert(service.slot(1).stock and service.slot(2).frames and service.slot(4).frames)
service=registry.create(testCatalogue,scope) assert(service.slot(3).raw==which)
online=true
assert(service.fire(3)) assert(not service.fire(3))
local wire=messages[#messages]
assert(#wire<=4082 and wire:sub(1,4)=="GE1|" and not wire:find(project.name,1,true))
local draws={}
local where=v(2,1,-2)
reskate.skater.joint=function(name) assert(name=="head") return {position=where} end
reskate.world.probe=function() return {status="clear"} end
local overlay={size=function() return size end,world_to_screen=function(_,pt) return v(pt.x*150,500-pt.y*70,0) end,
    image=function(_,path) draws.image=path end,rect=function(_,a,b) table.insert(draws,a.x) end}
for _,slot in {3,1,2,4} do
    if slot~=3 then now+=6500 assert(service.fire(slot)) end
    table.clear(draws) service.draw(overlay)
    if slot==1 then assert(draws.image==testCatalogue[1].sheet) else
        assert(#draws>0)
        local prev=draws[1] where+=v(1,0,0) table.clear(draws) now+=250 service.draw(overlay)
        assert(draws[1]~=prev)
    end
end
now+=5001 table.clear(draws) service.draw(overlay) assert(not next(draws))
print("WIRE "..wire)
print("SOURCE "..which)
print("PASS mixed master, separate image source, flat export, editable reopen, draft, private loadout and cooldown")
"""

VISITOR = r"""
local disk={} reskate.files=memoryFiles(disk)
local service=require("graffiti_emotes").create(testCatalogue,function() return "12345",map end)
assert(not service.slot(3))
local head=v(2,1,-2) local sampled={} local quads={}
reskate.camera.get=function() return {position=v(0,1,1),forward=v(0,0,-1)} end
reskate.world.probe=function() return {status="clear"} end
reskate.session.joint=function(id,joint) assert(id=="4421") table.insert(sampled,joint) return if head then {position=head} else nil end
local z={size=function() return v(1920,1080,0) end,world_to_screen=function(_,pos) return v(100+pos.x*50,500-pos.y*50,0) end,
    rect=function(_,a,b,style) table.insert(quads,{a.x,a.y,b.x,b.y,style.colour}) end}
local artist={id="4421"}
local function draw() table.clear(quads) service.draw(z) return #quads end
service.receive(artist,wire:sub(1,-4)) assert(draw()==0)
service.receive(artist,wire) assert(draw()>0 and sampled[1]=="head")
local start=quads[1][1] head=v(3,.6,-2) now+=201
assert(draw()>0 and quads[1][1]~=start)
head=nil now+=22 assert(draw()==0 and sampled[#sampled]=="spine")
head=v(3,1,4) now+=220 assert(draw()==0)
head=v(2,1,-2) reskate.world.probe=function() return {status="hit",position=v(0,1,0)} end
now+=220 assert(draw()==0)
reskate.world.probe=function() return {status="clear"} end now+=5200 assert(draw()==0)
service.receive(artist,wire) assert(draw()==0,"old activation replayed")
local replay=wire:gsub("^(GE1|[^|]+|[^|]+|)(%d+)",function(prefix,seq) return prefix..tostring(tonumber(seq)+1) end)
service.receive(artist,replay) assert(draw()>0) service.drop(artist.id) assert(draw()==0)
assert(not next(disk),"session display published or stored something on the visitor")
print("PASS cold recipient, transport sender, moving joint, absent player, behind camera, occlusion, expiry, replay and departure")
"""

EDITOR = r"""
online=false step()
local disk={} reskate.files=memoryFiles(disk)
local projects=require("studio_projects")
-- Address the dock by its rendered labels so this test also covers its real hitboxes.
local points={}
local logText=d.text
d.text=function(self,position,label,...)
    logText(self,position,label,...)
    points[label]=position
end
local function choose(label)
    table.clear(points) step()
    local pt=assert(points[label],"Missing control: "..label)
    click(pt.x+2,pt.y+3)
end
console.graffiti({"studio"}) step()
choose("Create new")
choose("SHAPES") choose("CIRCLE")
choose("SHAPES") choose("SQUARE")
choose("Hide") choose("Show") choose("Lock") choose("Unlock")
choose("Lower")
choose("Adjustment: fine")
cursor.wheel=-1 step() cursor.wheel=0
choose("Move →")
cursor.wheel=1 step() cursor.wheel=0
choose("LETTERING") choose("Add text layer")
choose("FREEHAND") choose("Add paint layer")
click(820,450)
choose("SAVE & USE") choose("Undo brush stroke") choose("Redo brush stroke")
choose("Save project") choose("Save as premade")
local ids=projects.list() assert(#ids==1)
local master,thumb=projects.open(ids[1])
assert(master.layers[1].symbol=="Square" and master.layers[1].x>.51)
assert(master.layers[2].symbol=="Circle" and master.layers[3].text=="Tag")
assert(master.layers[4].grid.pixels:find("[^.]",1) and thumb)
choose("My Artwork") choose("UNTITLED")
choose("SAVE & USE") choose("Place in World")
assert(active==nil and count()>0 and live[1].alpha==.45)
emit("action","Place Switchback") step()
assert(active and has("Save project") and live[1].alpha==1)
choose("Assign as Emote")
local equip
for label in points do if label:sub(1,6)=="Equip " then equip=label end end
if not equip then table.clear(points) step() for label in points do if label:sub(1,6)=="Equip " then equip=label end end end
choose(assert(equip)) choose("Display above my head")
assert(active==nil)
print("PASS project UI, two shapes, hide/show, lock/unlock, reorder, nudge, freehand undo/redo, editable reopen, wall placement and emote loadout")

-- Pick the visible lower ink through a dithered top layer, then paint with it.
local m=require("composition")
local proof=m.new() proof.name="Picker Proof"
for index,colour in {6,7} do
    local shape=m.add(proof,"shape","Square")
    shape.w,shape.h,shape.ink,shape.opacity=1,1,colour,if index==1 then 100 else 50
end
m.add(proof,"paint","Sample")
local raw,rendered=m.render(proof)
assert(projects.save(proof,false,raw))
console.graffiti({"studio"}) step()
if has("My Artwork") then choose("My Artwork") end
choose("PICKER PROOF") choose("FREEHAND")
local first,last
local oldImage=d.image
d.image=function(self,path,a,b,...)
    if path=="art/checker.png" then first,last=a,b end
    oldImage(self,path,a,b,...)
end
choose("PICKER")
local lower
for _,part in rendered do if part.colour==6 then lower=part break end end
assert(lower and first and last)
click(first.x+(lower.x+.5)*(last.x-first.x),first.y+(lower.y+.5)*(last.y-first.y))
choose("BRUSH")
click((first.x+last.x)/2,(first.y+last.y)/2)
choose("SAVE & USE") choose("Save project")
assert(projects.open(proof.id).layers[3].grid.pixels:find(m.inks:sub(7,7),1,true))
print("PASS colour picker samples the visible lower ink through partial opacity")
"""

SOURCES = r"""
local disk={} reskate.files=memoryFiles(disk)
local function registry() return require("graffiti_emotes").create(testCatalogue,function() return "12345",map end) end
local service=registry()
for _,piece in testCatalogue do
    assert(service.assign(1,piece) and service.slot(1).raw=="S:"..piece.id)
end
local imports=require("imports")
local dot="GLART1 96 96 1 1\n0 0 1 1 6"
local line="GLART1 96 96 1 1\n95 0 1 96 4"
disk["imports/Pinpoint.graffiti"]=dot
local id="01234567-89ab-4cde-abcd-112233445566"
disk["gallery/downloads/Blink~"..id..".json"]=encodeValue({version=1,id=id,title="Blink",frame=dot,
    media={version=1,kind="ink",frames={dot,line},frameMs=410}})
disk["imports/Pairs.collection"]=encodeValue({version=1,items={{name="Sliver",frame=line}}})
assert(imports.addCollection("Pairs.collection"))
local shape=require("reshape")
local sparse=assert(shape.source({rawFrame=line,parts=imports.decode(line),aspect=1}))
local settings=shape.identity()
assert(shape.save("Bent",sparse,settings,{line}))
local sources={}
for _,piece in imports.list() do sources[piece.name]=piece end
for i,name in {"Pinpoint","Blink","Sliver","Bent"} do
    local slot=i+1
    assert(service.assign(slot,assert(sources[name])))
    local art=assert(service.slot(slot))
    assert(#art.frames[1]==1)
    if name=="Blink" then assert(#art.frames==2 and art.ms==410 and art.frames[2][1].colour==4) end
end
local held=assert(service.slot(2)).raw
disk["imports/Damaged.graffiti"]="invalid"
assert(not service.assign(2,{id="import/Damaged.graffiti",file="imports/Damaged.graffiti",name="Damaged"}))
assert(registry().slot(2).raw==held)
local projects,m=require("studio_projects"),require("composition")
local master=m.new() master.name="Night Star"
m.add(master,"shape","Star")
assert(projects.save(master,false))
local book=require("blackbook")
local drawing=book.new() drawing.name="Flash"
drawing.animation={frameMs=350,frames={{strokes={}},{strokes={{size=8,colour=7,xy={500,412}}}}}}
assert(book.save(drawing))
local points={}
local old=d.text
d.text=function(self,pt,label,...) old(self,pt,label,...) points[label]=pt end
local function choose(label)
    table.clear(points) step()
    local pt=assert(points[label],"Missing control: "..label)
    click(pt.x+2,pt.y+2)
end
local function saved(slot) return decodeValue(disk["studio/emotes.json"]).slots[tostring(slot)] end
online=true step()
console.graffiti({"library"}) step()
choose("Use as emote") key(55) choose("Equip Switchback here")
assert(saved(7).raw=="S:switchback")
console.graffiti({"library"}) step()
click(65,187) typed="Pinpoint" step() key("Enter")
assert(has("Offline only")) click(175,966) assert(active=="Premade Art")
buttons.y=true step() buttons.y=false step()
key(50) choose("Equip Pinpoint here")
assert(saved(2).name=="Pinpoint" and #registry().slot(2).frames[1]==1)
choose("Display above my head")
assert(not active and messages[#messages]:find(saved(2).raw,1,true))

-- Pick a saved layered master straight from the online loadout.
local importsBefore=table.concat(reskate.files.list("imports"),"|")
console.graffiti({"emotes"}) step() key(53)
choose("Choose artwork for this slot")
choose("Name, creator or tag") typed="Night Star" step() key("Enter")
choose("NIGHT STAR") choose("Equip in selected slot")
assert(saved(5).name==master.name and #registry().slot(5).frames[1]>0)
assert(table.concat(reskate.files.list("imports"),"|")==importsBefore,"Equipping a Studio master exported a premade")
assert(saved(7).raw=="S:switchback")

online=false frame(1100)
console.graffiti({"blackbook"}) step() choose("Emote") key(56)
choose("Equip Flash here")
local ani=assert(registry().slot(8))
assert(saved(8).name=="Flash" and #ani.frames==2 and #ani.frames[1]==0 and #ani.frames[2]>0 and ani.ms==350)
console.graffiti({"organise"}) step()
choose("SWITCHBACK") choose("Use as emote") key(54) choose("Equip Switchback here")
assert(saved(6).raw=="S:switchback")
print("PASS bundled catalogue, imports, gallery animation, collection, reshaped copy, sparse ink, Studio master and animated Blackbook; online/offline picker, quick action and persisted slots")
"""

if __name__ == "__main__":
    author = run(sys.argv[1], AUTHOR, "studio_author", capture=True)
    wire = next(line[5:] for line in author.splitlines() if line.startswith("WIRE "))
    print(author.splitlines()[-1])
    print(run(sys.argv[1], "local wire=" + json.dumps(wire) + "\n" + VISITOR, "studio_visitor", capture=True).strip())
    print(run(sys.argv[1], EDITOR, "studio_ui", capture=True).strip())
    print(run(sys.argv[1], SOURCES, "emote_sources", capture=True).strip())
