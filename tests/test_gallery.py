"""Exercise the actual screen callbacks, portable artwork and private/offline library copies."""
import sys
from test_menu import run

CHECKS = r'''
online=false
local disk,objects,requests={},{},{}
local function panel(tab,pressed)
    if tab then click(95+(tab-1)*166,185) end
    local points={["profile-1"]={260,350},["profile-2"]={260,394},["source-1"]={255,281},publish={258,960},
        ["pick-1"]={105,343},download={256,958},["stop-wait"]={256,958}}
    if pressed then click(unpack(points[pressed])) end
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
local function reply(data)
    local request=requests[#requests]
    request[2](200,reskate.json.encode(data),nil)
    return request[1]
end
console.graffiti({"public"}) step()
assert(active=="Graffiti Lab Studio" and requests[1][1].url=="https://gallery.example/v1/browse?q=&page=1")
reply({page=1,items={},more=false})
panel(3,"profile-1") panel(2,"source-1") panel(nil,"publish")
local sent=objects[requests[#requests][1].body]
assert(sent.token==string.rep("a",64) and sent.asset.frames[1]==raw and sent.title=="Test")
reply({id=id})
panel(3,"profile-2") panel(1) local second=table.clone(item)
second.id="77777777-0000-4000-8000-0123456789ab" second.title="Wide companion"
second.thumbnail="GLART1 8 4 8 4\n0 0 8 4 6"
reply({page=1,items={item,second},more=false})
local thumbs=0
d.image=function(_,path) if path=="art/checker.png" then thumbs+=1 end end
step() assert(thumbs==3 and has("Wide companion") and has("Artist"),"each public card and the selected detail need a real preview")
-- The service returns up to eight publications. Exercise the largest supported
-- first frames and confirm that each card plus the detail preview is rendered.
local dense="GLART1 16 16 16 16"
for i=0,255 do dense..=string.format("\n%d %d 1 1 %d",i%16,math.floor(i/16),i%16+1) end
local page={}
for i=1,8 do
    local row=table.clone(item)
    row.id=string.format("12345678-0000-4000-8000-%012d",i)
    row.title="Tile "..i row.thumbnail=dense
    table.insert(page,row)
end
panel(1) reply({page=1,items=page,more=true})
local rectangles,drawRect=0,d.rect
d.rect=function(...) rectangles+=1 drawRect(...) end
thumbs=0 step()
assert(thumbs==9 and rectangles>=9*256 and rectangles<3900,"full page exceeds the overlay budget or omits artwork")
d.rect=drawRect
panel(1) reply({page=1,items={item,second},more=false})
panel(nil,"pick-1") panel(nil,"download")
assert(objects[requests[#requests][1].body].token==string.rep("b",64))
panel(nil,"stop-wait") reply(item)
assert(#reskate.files.list("gallery/downloads")==0)
panel(nil,"download") item.downloadedBy="Visitor" reply(item)
assert(#reskate.files.list("gallery/downloads")==1)
local piece
for _,p in require("imports").list() do if p.downloaded then piece=p end end
assert(piece and require("imports").load(piece) and #piece.parts==2)
local ok,note=require("gallery").store(item,id)
assert(ok and note:find("Already",1,true))
item.asset.frames={raw,raw}
assert(require("gallery").store(item,id))
item.asset.frameMs=-1
assert(not require("gallery").store(item,id))
escape() reskate.http=nil
console.graffiti({"library"}) step() click(90,188) typed="Gallery test signal" step() assert(has("GALLERY TEST SIGNAL"))
print("PASS gallery screen, profile switching, selected-art-only publication, cancellation, single download, duplicate protection, unsupported media and offline import")
'''
if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "gallery")
