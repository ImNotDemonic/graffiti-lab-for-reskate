"""Execute the production Blackbook reader and writer against a legacy save and write failures."""
import sys
from test_menu import run

CHECKS = r'''
local book = require("blackbook")
local file = "blackbook-0001.json"
local backup = "recovery/blackbook-v1/"..file
local disk = {[file]="v1-original", ["blackbook-0002.json"]="broken"}
local decoded = {["v1-original"]={version=1,name="Original",strokes={{colour=1,size=4,xy={0,0,2,2}}}}}
reskate.json.decode=function(raw)
    local doc=decoded[raw]
    if not doc then error("bad json") end
    return table.clone(doc)
end
local serial=0
reskate.json.encode=function(doc)
    serial+=1
    local raw="encoded-"..serial
    decoded[raw]=table.clone(doc)
    return raw
end
local failPath=nil
reskate.files.read=function(path)
    if disk[path] then return disk[path] end
    return nil,"not found"
end
reskate.files.write=function(path,bytes)
    if path==failPath then return nil,"disk full" end
    disk[path]=bytes return true
end
local old,original=book.read(file)
assert(old and old.artworkId==file and disk[backup]==nil)
assert(not book.read("blackbook-0002.json"))
old.name="Edited"
failPath=backup
assert(not book.save(old,file,original) and disk[file]==original and not disk[backup])
failPath=file
assert(not book.save(old,file,original) and disk[file]==original and disk[backup]==original)
failPath=nil
assert(book.save(old,file,original)==file and disk[backup]==original)
local reopened,raw=book.read(file)
assert(reopened.version==2 and reopened.artworkId==file and reopened.name=="Edited")
assert(reopened.strokes[1].xy[3]==2 and disk["blackbook-0002.json"]=="broken")
assert(not book.save(old,file,original) and disk[file]==raw)
print("PASS legacy drawing migration, recoverable original, stable ID, round trip, corrupt neighbour, failed writes and stale writers")
'''
if __name__ == "__main__":
    run(sys.argv[1],CHECKS,"artwork_migration")
