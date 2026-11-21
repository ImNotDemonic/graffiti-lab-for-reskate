"""Pass only saved file bytes between three independent Luau processes."""
import sys

from test_menu import run
from test_wall_paint import FILE_HOST

DRIVER = """
online=false
local arcade="levels/custom/arcade/test"
local city="levels/city/test"
local function visit(name)
    emit("level_unloading")
    map=name
    emit("level_loaded",name)
    for _=1,80 do step() end
end
local function brush()
    console.graffiti({"paint"}) step() step()
    assert(active=="Wall Paint")
end
local function at(x,y) cursor.position=v(x,y,0) step() end
local function drag(x1,x2,y)
    at(x1,y) cursor.left=true step()
    for x=x1,x2,6 do at(x,y) end
    cursor.left=false step()
end
local function dotAt(x,y)
    at(x,y) cursor.left=true step() cursor.left=false step()
end
local function erase()
    click(75,774) assert(has("WALL PAINT   /   ERASER"),"eraser toolbar button")
end
local function inspect()
    local left,middle,right,other,art=0,0,0,0,0
    for _,row in live do
        if row.asset:find("switchback",1,true) then art+=1
        elseif row.asset:find("ink_06",1,true) then other+=1
        elseif row.m[13]<1.93 then left+=1 elseif row.m[13]>2.07 then right+=1 else middle+=1 end
    end
    return left,middle,right,other,art
end
local function export()
    emit("unload")
    for path,bytes in disk do
        local hex=bytes:gsub(".",function(c) return string.format("%02x",c:byte()) end)
        print("FILE "..path.." "..hex)
    end
end
"""

CREATE = """
visit(arcade) console.graffiti({"aim"}) console.graffiti({"place"})
brush() drag(780,1140,540) key("6") dotAt(960,710)
local l,m,r,o,a=inspect() assert(l>0 and m>0 and r>0 and o==1 and a==1)
erase() dotAt(960,540) step()
l,m,r,o,a=inspect() assert(l>0 and m==0 and r>0 and o==1 and a==1,"partial eraser damaged neighbours or artwork")
key("E") assert(has("WALL PAINT   /   FREEHAND"),"E did not switch back to paint")
visit(city) assert(count()==0,"different maps with the same basename shared paint")
brush() key("6") dotAt(960,710)
visit(arcade)
l,m,r,o,a=inspect() assert(l>0 and m==0 and r>0 and o==1 and a==0,"map return lost the erased gap")
online=true step() assert(count()==0,"private ink was shown online")
online=false for _=1,50 do step() end
l,m,r,o=inspect() assert(l>0 and m==0 and r>0 and o==1,"offline return lost paint")
export()
"""

EDIT = """
visit(arcade)
local l,m,r,o=inspect() assert(l>0 and m==0 and r>0 and o==1,"restart lost edits or colours")
brush() erase() dotAt(960,710)
l,m,r,o=inspect() assert(l>0 and m==0 and r>0 and o==0,"complete erasure failed")
-- Fail one save, then allow the pending erasure to retry while visiting a different map.
failWrites=true at(800,540) cursor.left=true step() emit("unload") cursor.left=false
assert(lastToast and lastToast:find("unsaved",1,true))
failWrites=false visit(city)
for _=1,170 do step() end
local _,_,_,cityInk=inspect() assert(cityInk==1)
visit(arcade) brush()
keys[17]=true key("Z") keys[17]=false step()
assert(count()==0,"undo after restore did not remove the partly erased stroke")
export()
"""

VERIFY = """
visit(arcade) assert(count()==0,"erased or undone strokes reappeared after restart")
visit(city)
local l,m,r,o,a=inspect() assert(l+m+r==0 and o==1 and a==0,"editing arcade changed city ink")
-- Preserve an unknown file version. Painting must not overwrite the file.
local path=next(disk)
local damaged="GLW2"..disk[path]:sub(5)
disk[path]=damaged
visit(city) brush() dotAt(800,420) emit("unload")
assert(disk[path]==damaged and count()==0,"damaged save was overwritten")
"""


GEOMETRY = """
local erased={}
local cache=modules.wall_ink({decal=function() return nil,"unavailable" end,release=noop})
local function stamp(id,x,z,facing)
    local m={0.08,0,0,0,0,0,0.045*facing,0,0,0.04,0,0,x,1,z,1}
    local mark={id=id,samples={}}
    cache.add(mark,"ink",m,now)
    return m
end
local brush=stamp("target",0.49,-2,1)
stamp("overlap in neighbouring bin",0.54,-2,1)
stamp("other side",0.49,-2,-1)
stamp("next parallel wall",0.49,-2.04,1)
stamp("beside disk",0.90,-2,1)
cache.erase(brush,0.07,noop,function(mark) erased[mark.id]=true end)
assert(cache.total==3 and cache.live==0 and erased.target and erased["overlap in neighbouring bin"])
assert(not erased["next parallel wall"] and not erased["other side"] and not erased["beside disk"])
"""

def restart(luau, stage, files):
    preload = []
    for path, raw in files.items():
        literal = "".join(f"\\{byte:03d}" for byte in raw)
        preload.append(f'disk["{path}"]="{literal}"')
    output = run(luau, FILE_HOST + "\n".join(preload) + DRIVER + stage, "wall_save", capture=True)
    return {path: bytes.fromhex(hex_data) for prefix, path, hex_data in
            (line.split(" ", 2) for line in output.splitlines() if line.startswith("FILE "))}


if __name__ == "__main__":
    luau = sys.argv[1]
    run(luau, GEOMETRY, "wall_eraser_faces")
    files = restart(luau, CREATE, {})
    assert len(files) == 2
    edited = restart(luau, EDIT, files)
    assert len(edited) == 1
    restart(luau, VERIFY, edited)
    print("PASS: three fresh Luau processes, per-map paint, partial and full erasure, adjacent ink, premade isolation, undo, failed-save retry and damaged-file protection")
