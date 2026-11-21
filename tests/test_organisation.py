"""Round-trip independent placement and library records across fresh Luau VMs."""
import sys
from test_wall_save import restart

CREATE = """
visit("levels/city/test")
local lib,world=modules.library,modules.placements
local rows={{id="switchback",search="switchback built in"},{id="import/tag.graffiti",search="tag guest artist street"},
    {id="blackbook-0001.json",search="my tag blackbook"}}
assert(lib.change("create folder",nil,"Crew"))
for i=2,3 do assert(lib.change("move artwork",rows[i].id,"Crew")) end
assert(lib.change("favourite",rows[2].id))
for _,i in {2,3,2} do assert(lib.used(rows[i].id)) end
local matches=lib.filter(rows,"guest","Crew",true,true)
assert(#matches==1 and matches[1]==rows[2])
assert(lib.change("rename folder","Crew","Wall"))
assert(lib.history(false,true) and lib.get().folders.Crew)
assert(lib.history(true,true) and not lib.get().folders.Crew)
assert(lib.change("remove folder","Wall"))
assert(lib.history(false,true) and lib.get().items[rows[3].id].folder=="Wall")
local m={1,0,0,0,0,0,.04,0,0,-.5,0,0,1,1,-2,1}
local a=world.new({id="switchback",name="First"},m,1,0)
assert(world.change("placement",nil,a))
local b=world.new({id="switchback",name="Second"},m,1,0)
assert(world.change("placement duplication",nil,b) and a.id~=b.id)
local edited=table.clone(b)
edited.base=table.clone(b.base) edited.base[13]=4 edited.scale=2 edited.angle=45
assert(world.change("placement move",b,edited))
assert(a.scale==1 and a.base[13]==1)
assert(world.change("placement deletion",a,nil))
assert(world.history(false,true))
assert(world.history(true,true))
assert(world.history(false,true))
failWrites=true
local invalid=table.clone(edited) invalid.scale=3
assert(not world.change("resize",edited,invalid))
assert(not lib.change("rename folder","Wall","Broken"))
failWrites=false
assert(#world.rows()==2 and #lib.get().recent==2)
local raw="GLART1 8 8 8 8\\n0 0 3 2 3"
local inputs={version=1,items={{name="Mark A",frame=raw},{name="Mark B",frame=raw}}}
disk["imports/Crew.collection"]=reskate.json.encode(inputs)
assert(modules.imports.addCollection("Crew.collection"))
local group=modules.imports.list()
assert(#group==2 and modules.imports.load(group[1]) and modules.imports.load(group[2]))
local snapshot=group[1].file
assert(lib.history(false,false)=="collection import")
assert(lib.history(false,true) and #modules.imports.list()==0)
assert(disk[snapshot] and #world.rows()==2 and lib.get().items[rows[2].id].favourite)
assert(lib.history(true,true) and #modules.imports.list()==2)
assert(modules.imports.addCollection("Crew.collection") and #modules.imports.list()==2)
export()
"""
VERIFY = """
visit("levels/city/test")
local state=assert(modules.library.get())
local group=modules.imports.list()
assert(#group==2 and modules.imports.load(group[1]) and modules.imports.load(group[2]))
assert(state.folders.Wall and state.items["import/tag.graffiti"].favourite)
assert(state.recent[1]=="import/tag.graffiti" and state.recent[2]=="blackbook-0001.json")
local world=modules.placements
local rows=world.rows()
assert(#rows==2 and not world.history(false))
for _,r in rows do
    if r.name=="Second" then assert(r.scale==2 and r.angle==45 and r.base[13]==4)
    else assert(r.name=="First" and r.scale==1 and r.angle==0 and r.base[13]==1) end
end
local path
for p in disk do if p:find(rows[1].id,1,true) then path=p end end
disk[path]="damaged"
visit("elsewhere") assert(#world.rows()==0)
visit("levels/city/test") assert(#world.rows()==1 and disk[path]=="damaged")
"""
if __name__ == "__main__":
    restart(sys.argv[1], VERIFY, restart(sys.argv[1], CREATE, {}))
    print("PASS: combined folder, favourite, creator search and recency; grouped collection import, undo, redo and restart; independent copies, move, scale, rotation, delete, undo, redo, failed writes, restart and isolated damage")
