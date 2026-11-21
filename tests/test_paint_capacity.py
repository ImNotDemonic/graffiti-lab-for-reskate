"""Measure the Luau paint model and a full flush/restore with a finite decal host."""
import sys
from test_menu import run
from test_wall_paint import FILE_HOST

CHECKS = r'''
local sampleCount=CAPACITY_SAMPLES
local firstX,lastX
local function make()
    local marks={}
    local active=0
    local fx={
        decal=function() if active>=2048 then return nil,"effect limit reached" end active+=1 return active end,
        move=function() end,release=function() active-=1 end
    }
    local ink=require("wall_ink")(fx)
    local store=require("wall_store")(function(id,asset,m,page,slot)
        if not marks[id] then marks[id]={samples={}} end
        local sample=ink.add(marks[id],asset,m,now,true)
        sample.page,sample.slot,sample.matrix=page,slot,nil
        if not firstX then firstX=m[13] end
        lastX=m[13]
    end)
    store.open("levels/test/capacity")
    return ink,store
end
local start=os.clock()
local ink,store=make()
store.load(now)
local memory=gcinfo()
local mark
for i=1,sampleCount do
    if (i-1)%100==0 then mark={samples={}} end
    local x=i*0.04
    local m={0.08,0,0,0,0,0.045,0,0,0,0,0.04,0,x,0,0,1}
    local sample=ink.add(mark,"world/materials/decal/reskate_graffitilab/ink_03_dv",m,now)
    store.add(sample,math.ceil(i/100),3)
end
assert(ink.total==sampleCount and ink.live<=2048)
store.flush(true)
local size,pages=0,0
for _,bytes in disk do size+=#bytes pages+=1 end
local peak=gcinfo()-memory
local paintMs=(os.clock()-start)*1000
ink.reset() ink,store=make()
local calls,maxMs=0,0
local loadStart=os.clock()
while not store.ready and calls<sampleCount do
    local t=os.clock()
    now+=100 store.load(now)
    maxMs=math.max(maxMs,(os.clock()-t)*1000) calls+=1
end
assert(store.ready and ink.total==sampleCount and math.abs(firstX-0.04)<0.0001 and math.abs(lastX-sampleCount*.04)<0.001)
print(string.format("PASS %d samples; %d pages; %d bytes; paint+save %.1f ms; heap growth %.1f KiB; restore %d calls / %.1f ms CPU / %.2f ms worst call",sampleCount,pages,size,paintMs,peak,calls,(os.clock()-loadStart)*1000,maxMs))
'''
if __name__ == "__main__":
    samples=int(sys.argv[2]) if len(sys.argv)>2 else 30000
    run(sys.argv[1], FILE_HOST+CHECKS.replace("CAPACITY_SAMPLES",str(samples)), "paint_capacity")
