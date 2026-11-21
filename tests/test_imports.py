"""Exercise player artwork through the real selector and placement callbacks."""
import sys

from test_menu import run

CHECKS = r'''
online=false step()
local folder={["Signal.graffiti"]="GLART1 96 48 96 48\n16 8 16 32 3\n32 32 48 8 6",
    ["Broken.graffiti"]="GLART1 1 1 1 1\n0 0 2 1 3"}
local revealed=false
reskate.files.list=function(path)
    if path~="imports" then return {} end
    return {"Broken.graffiti","Signal.graffiti","Import Artwork.html","private.txt"}
end
reskate.package.read=function(path) assert(path=="art/Import Artwork.html") return "local helper" end
reskate.files.write=function(path,raw) assert(path=="imports/Import Artwork.html" and raw=="local helper") return true end
reskate.files.reveal=function(path) assert(path=="imports") revealed=true return true end
reskate.files.read=function(path) return folder[path:sub(9)] end
console.graffiti({"library"}) step()
click(360,100) assert(active=="Premade Art" and revealed and has("SIGNAL"))
click(105,400) key("Enter")
assert(active=="Premade Art" and lastToast:find("Invalid artwork",1,true))
click(244,400) key("Enter") assert(active==nil and count()==2)
assert(live[1].asset:find("ink_03_dv",1,true) and live[2].asset:find("ink_06_dv",1,true))
keys[1]=true step() keys[1]=false step()
assert(active=="Premade Art" and lastToast=="Placed Signal" and count()==2)
click(477,100) assert(has("SIGNAL") and count()==2)
escape() online=true step()
console.graffiti({"library"}) step() assert(not has("SIGNAL") and not has("IMPORT ART"))
console.graffiti({"aim"}) step()
for _,entry in live do assert(not entry.asset:find("ink_",1,true),"personal art escaped offline mode") end
print("PASS: file picker hand-off, invalid imports, local preview, placement, refresh and session isolation")
'''
if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "imports")
