"""Exercise the actual screen callbacks, portable artwork and private/offline library copies."""
import sys
from test_menu import run

CHECKS = r'''
online=false
local frames,widgets,disk,objects,requests={},{},{},{},{}
local tickPanel
local function panel(tab,pressed)
    local ui={tabs=function() return tab end,note=function(_,text) table.insert(frames,text) end,
        button=function(_,id) table.insert(widgets,id) return id==pressed end,
        info=noop,text=function(_,_,_,value) return value end}
    tickPanel(ui)
end
local title="Gallery test signal"
local id="12345678-0000-4000-8000-0123456789ab"
local raw="GLART1 8 8 8 8\n2 0 3 2 3\n2 2 2 3 6"
local item={id=id,title=title,creator="Artist",description="Two inks",tags={"qa"},thumbnail=raw,
    asset={version=1,kind="ink",frames={raw},frameMs=250}}
reskate.json.encode=function(t) local k="json"..(#objects+1) table.insert(objects,t) objects[k]=t return k end
reskate.json.decode=function(raw) return assert(objects[raw]) end
local pack=reskate.package.read_json
reskate.package.read_json=function(path)
    if path=="reskate-plugin.json" then return {domains={"gallery.example"}} end
    return pack(path)
end
reskate.files.list=function(dir)
    local files={}
    if not dir then return files end
    for path in disk do
        local name=path:match("^"..dir.."/([^/]+)$")
        if name then table.insert(files,name) end
    end
    return files
end
reskate.files.read=function(p) if disk[p] then return disk[p] end return nil,"not found" end
reskate.files.write=function(p,bytes) disk[p]=bytes return true end
disk["imports/Test.graffiti"]=raw
disk["gallery/accounts/Artist.key"]=string.rep("a",64)
disk["gallery/accounts/Visitor.key"]=string.rep("b",64)
reskate.http={request=function(opts,fn) requests[#requests+1]={opts,fn} return #requests end}
local screenRegister=reskate.ui.screen
reskate.ui.screen=function(name,fn) assert(name=="Public Artworks") tickPanel=fn screenRegister(name,fn) end
local function reply(data)
    local request=requests[#requests]
    request[2](200,reskate.json.encode(data),nil)
    return request[1]
end
console.graffiti({"public"}) step()
assert(active=="Public Artworks" and requests[1][1].url=="https://gallery.example/v1/browse?q=&page=1")
reply({page=1,items={},more=false})
panel(3,"profile-1") panel(2,"source-1") panel(2,"publish")
local sent=objects[requests[#requests][1].body]
assert(sent.token==string.rep("a",64) and sent.asset.frames[1]==raw and sent.title=="Test")
reply({id=id})
panel(3,"profile-2") panel(1) reply({page=1,items={item},more=false})
panel(1,"pick-1") panel(1,"download")
assert(objects[requests[#requests][1].body].token==string.rep("b",64))
panel(1,"stop-wait") reply(item)
assert(#reskate.files.list("gallery/downloads")==0)
panel(1,"download") item.downloadedBy="Visitor" reply(item)
assert(#reskate.files.list("gallery/downloads")==1)
local piece
for _,p in require("imports").list() do if p.downloaded then piece=p end end
assert(piece and require("imports").load(piece) and #piece.parts==2)
local ok,note=require("gallery").store(item,id)
assert(ok and note:find("Already",1,true))
item.asset.frames={raw,raw}
assert(not require("gallery").store(item,id))
escape() reskate.http=nil
console.graffiti({"library"}) step() click(90,188) typed="Gallery test signal" step() assert(has("GALLERY TEST SIGNAL"))
print("PASS gallery screen, profile switching, selected-art-only publication, cancellation, single download, duplicate protection, unsupported media and offline import")
'''
if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "gallery")
