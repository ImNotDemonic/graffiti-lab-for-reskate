"""Verify the Studio's stencil library at thumbnail and wall resolution."""
import sys
from test_menu import run

CHECKS = r"""
online=false step()
local disk={} reskate.files=memoryFiles(disk)
local shapes=require("studio_symbols")
local model=require("composition")
local preview=require("shape_preview")
local projects=require("studio_projects")
local p=model.new() p.aspect=1
local l=model.add(p,"shape","Circle")
local names,thumbs,exports={},{},{}
local count,newCount=0,0
for category,items in shapes.categories do
    for i=2,#items do
        local name=items[i]
        assert(not names[name],name) names[name]=true count+=1
        l.symbol=name l.w=.92
        l.h=if name=="Ellipse" or name=="Rectangle" or name=="Deck" then .46 else .92
        local thumbnail,tile=model.render(p,16,48)
        assert(thumbnail and #tile<=48,"missing tile: "..name)
        local ratio=shapes.aspect(name)
        local picker=preview.get(name,ratio,0,false,false,false,150)
        assert(picker and #picker.parts>0 and #picker.parts<=150,name)
        assert(preview.get(name,ratio,0,false,false,false,150)==picker)
        local large=preview.get(name,ratio,0,false,false,false,1000)
        assert(large and #large.parts<=1000 and math.max(large.w,large.h)>=64,name.." canvas")
        for _,b in large.parts do
            assert(b.code>=1 and b.code<=4 and b.right<=large.w and b.bottom<=large.h)
        end
        local raw,parts=model.render(p)
        assert(raw and #parts<=256 and model.valid(p),"invalid wall art: "..name)
        if category>3 then
            assert(not thumbs[thumbnail] and not exports[raw],"duplicate silhouette: "..name)
            newCount+=1
        end
        thumbs[thumbnail],exports[raw]=name,name
        assert(projects.save(p,false,raw))
        local restored,saved=projects.open(p.id)
        assert(restored.layers[1].symbol==name and model.render(restored)==raw and saved==raw)
    end
end
assert(count==59 and newCount==40)
local function shade(shape,u,v)
    for _,b in shape.parts do
        if u*shape.w>=b.left and u*shape.w<b.right and v*shape.h>=b.top and v*shape.h<b.bottom then return b.code end
    end
    return 0
end
local wheel=preview.get("Wheel",1,0,false,false,false,1000)
assert(shade(wheel,.5,.5)==0 and shade(wheel,.8,.5)==4)
local crown=preview.get("Crown",1,0,false,false,false,1000)
assert(shade(crown,.5,.8)==0 and shade(crown,.5,.88)==4)
local plain=preview.get("Triangle",1,0,false,false,false,1000)
local turned=preview.get("Triangle",1,180,false,false,false,1000)
assert(shade(plain,.2,.85)==4 and shade(turned,.2,.85)==0)
local outlined=preview.get("Wheel",1,33,true,false,true,1000)
local border,edge=false,false
for _,run in outlined.parts do
    if run.code>4 then border=true end
    if run.code%4~=0 then edge=true end
end
assert(border and edge)
local clip={x=20,y=4,w=30,h=45}
local drawn=0
preview.draw({rect=function(x,y,w,h,colour)
    assert(x>=clip.x and y>=clip.y and x+w<=clip.x+clip.w+.001 and y+h<=clip.y+clip.h+.001)
    assert(#colour==9 and tonumber(colour:sub(-2),16)<=128)
    drawn+=1
end},outlined,0,0,90,90,"#FF5A1F","#121212",50,clip)
assert(drawn>0)
local wide=model.new() wide.aspect=8
local circle=model.add(wide,"shape","Circle")
assert(circle.h<=1 and math.abs(circle.w*wide.aspect-circle.h)<.00001)
assert(model.render(wide):match("^GLART1 96 96 "))
circle.detailed=nil
assert(model.render(wide):match("^GLART1 64 8 "),"earlier wall export changed")
local positions={}
local log=d.text
d.text=function(self,pt,label,...) log(self,pt,label,...) positions[label]=pt end
local function choose(label)
    table.clear(positions) step()
    local pt=assert(positions[label],label)
    click(pt.x+2,pt.y+3)
end
local function swatch(label,n)
    table.clear(positions) step()
    local at=assert(positions[label],label)
    click(at.x+(n-1)*31+14,at.y+34)
end
local palette=require("blackbook").palette
palette[6],palette[7]="#2E6BFF","#FF3D8B"
local rendered={}
local drawRect=d.rect
d.rect=function(self,a,b,style)
    if style.fill and style.colour then
        if a.x<526 and a.y>340 and a.y<810 then rendered["tile"..style.colour]=true end
        if a.x>600 then rendered["canvas"..style.colour]=true end
    end
    drawRect(self,a,b,style)
end
console.graffiti({"studio"}) step() choose("Create new")
choose("SHAPES") swatch("NEW SHAPE COLOUR",6)
table.clear(rendered) step() assert(rendered["tile"..palette[6].."FF"],"blue tile preview")
choose("GEOMETRY") choose("HOURGLASS")
table.clear(rendered) step() assert(rendered["canvas"..palette[6].."FF"],"new shape colour")
swatch("SHAPE COLOUR",7)
table.clear(rendered) step() assert(rendered["canvas"..palette[7].."FF"],"pink layer preview")
choose("SAVE & USE") choose("Undo shape colour")
table.clear(rendered) step() assert(rendered["canvas"..palette[6].."FF"])
choose("Redo shape colour") choose("Save project") choose("Save as premade")
for _,id in projects.list() do
    if id~=p.id then
        local doc,thumb=projects.open(id)
        assert(doc.layers[1].ink==7 and model.render(doc)==thumb)
        local exported=assert(projects.premade(doc,thumb))
        for _,part in exported.parts do assert(part.colour==7 and part.asset=="ink_07") end
    end
end
choose("COMPOSE") choose("Lock") step() assert(not has("SHAPE COLOUR")) choose("Unlock")
for _,pair in {{"NATURE","CACTUS"},{"WEATHER","WAVE"},
        {"STREET","SPRAY CAN"},{"OBJECTS","CASSETTE"}} do
    choose("SHAPES") choose(pair[1]) choose(pair[2])
end
choose("LETTERING") choose("Add text layer") choose("GOTHIC")
choose("SAVE & USE") choose("Save project") choose("Save as premade")
local master,raw
for _,id in projects.list() do if id~=p.id then master,raw=projects.open(id) end end
assert(master and #master.layers==6 and master.layers[5].symbol=="Cassette" and master.layers[6].font=="Gothic")
assert(master.layers[1].ink==7 and master.layers[2].ink==6 and master.layers[5].ink==6)
assert(model.render(master)==raw and projects.premade(master,raw).rawFrame==raw)
print("PASS 59 shape tiles and wall exports, fill swatches, recolouring, undo/redo, locked layers, saved colours and mixed Gothic premade")
"""

if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "studio_shapes")
