"""Drive the shipping brush and a renderer with delayed release and a finite decal pool."""
import sys
from test_menu import run

FILE_HOST = """
local disk={}
local failWrites=false
reskate.files={
    list=function(folder)
        local names={}
        for path in disk do
            if path:sub(1,#folder)==folder then table.insert(names,path:sub(#folder+1)) end
        end
        return names
    end,
    read=function(path) return disk[path],if disk[path] then nil else "not found" end,
    write=function(path,bytes)
        if failWrites then return nil,"disk full" end
        assert(#bytes<=1048576 and (path:match("^wall%-paint/") or path:match("^placements/") or path=="library/organisation.json" or path:match("^library/collections/c[%x%-]+%.json$")))
        disk[path]=bytes return true
    end,
    remove=function(path) disk[path]=nil return true end,
}
"""

CHECKS = FILE_HOST + """
local maxLive, rendered, retired, samples, strokes, visible = 2048,0,0,0,0,0
local failures, peak=0,0
local fx=reskate.effects
local nativeCreate,nativeRelease,nativeClear=fx.decal,fx.release,fx.clear
fx.decal=function(asset,m)
    if rendered+retired>=maxLive then
        failures+=1
        return nil,"effect asset or renderer unavailable"
    end
    local h=nativeCreate(asset,m)
    rendered+=1
    peak=math.max(peak,rendered)
    return h
end
fx.release=function(h)
    nativeRelease(h) rendered-=1 retired+=1
end
fx.clear=function() nativeClear() rendered,retired=0,0 end
local function tick(ms)
    retired=0
    frame(ms or 16)
    table.clear(labels)
    emit("draw",d)
end
reskate.log=function(msg)
    local a,b,c=string.match(msg,"Wall Paint: (%d+) strokes, (%d+) recorded samples, (%d+) visible decals")
    if a then strokes,samples,visible=tonumber(a),tonumber(b),tonumber(c) end
end
local function status() console.graffiti({"status"}) end
local function settle(n) for _=1,n do tick(32) end end
local function lift() cursor.left=false tick() end
local function openBrush() console.graffiti({"paint"}) tick() lift() end
local function dot()
    cursor.left=true tick() lift()
end
local function drag(n)
    cursor.left=true
    for i=1,n do
        cursor.position=v(865+math.abs(i%40-20)*10,460+(i%2)*160,0)
        tick()
    end
    lift()
end
local function comeBack()
    local screen=active active=nil emit("screen_closed",screen) tick()
end
local function undo()
    keys[17],keys.Z=true,true tick()
    keys[17],keys.Z=false,false tick()
end
local function inkAt(x)
    local n=0
    for _,entry in live do
        if string.find(entry.asset,"/ink_",1,true) and math.abs(entry.m[13]-x)<3 then n+=1 end
    end
    return n
end
online=false tick()
console.graffiti({"aim"}) console.graffiti({"place"})
local art=live[1]
assert(art and rendered==1)
openBrush()
for _=1,24 do dot() end
status() assert(strokes==24 and samples==24 and visible==24,"old mark limit")
drag(900) status()
assert(strokes==25 and samples>768 and visible==samples,"old stroke or handle limit")
local nearSamples=samples
focus=v(66,1,0)
drag(2500) status()
assert(samples>2048 and strokes==26 and live[1]==art,"brush stopped recording at the host ceiling")
local allSamples=samples
settle(150) status()
assert(visible==2047 and rendered==2048 and live[1]==art)
assert(inkAt(66)==2047,"current wall did not receive the full paint pool")
focus=v(2,1,0) settle(380) status()
assert(inkAt(2)==nearSamples and samples==allSamples,"returning to the earlier wall lost recorded ink")
undo() settle(4) status()
assert(strokes==25 and samples==nearSamples and visible==samples and live[1]==art,"undo lost hidden paint or artwork")
-- Start another premade while lots of short strokes are on the map.
comeBack() console.graffiti({"aim"}) tick() console.graffiti({"place"})
assert(live[nextHandle].alpha==1)
local secondArt=nextHandle
-- Other mods can reduce the effective capacity below the per-plugin ceiling.
maxLive=rendered+3
openBrush() focus=v(66,1,0) drag(350) settle(140) status()
assert(strokes==26 and samples>nearSamples+190 and visible<samples and failures>0)
assert(inkAt(66)>190 and live[1]==art and live[secondArt],"shared renderer pressure cut off new paint")
comeBack()
console.graffiti({"aim"}) settle(30) console.graffiti({"place"})
local confirmed=0
for _,entry in live do if entry.alpha==1 then confirmed+=1 end end
assert(confirmed==3,"virtual paint starved an artwork preview: "..confirmed.." confirmed")
console.graffiti({"remove"})
maxLive=2048 settle(200) status()
assert(visible==samples,"freed renderer slots did not restore ink")
openBrush() undo() status()
assert(samples==nearSamples and live[secondArt] and live[1]==art)
-- A continuous stroke can cross the ten-minute boundary while held.
cursor.left=true tick()
tick(580000)
cursor.position=v(989,540,0) tick()
tick(12000)
cursor.position=v(969,540,0) tick()
lift() status()
settle(100) status()
assert(strokes==26 and samples>=nearSamples+3 and visible>nearSamples)
local durableRuns=visible
tick(591000) settle(100) status()
assert(samples>=nearSamples+3 and visible==durableRuns and rendered==durableRuns+2,"persistent paint or premade did not renew")
dot() status() local savedSamples=samples
emit("level_unloading") status()
assert(rendered==0 and samples==0 and strokes==0 and active==nil)
settle(10) assert(rendered==0)
map="levels/game/another" emit("level_loaded",map) settle(3)
-- An unavailable renderer with zero slots must not interrupt a stroke or lose its colour.
maxLive=0 openBrush()
keys[54]=true tick() keys[54]=false tick()
drag(215) status() assert(samples>192 and visible==0 and strokes==1)
maxLive=2048 settle(70) status()
assert(rendered==samples and samples==visible)
for _,entry in live do assert(string.find(entry.asset,"/ink_06_dv",1,true)) end
comeBack()
console.graffiti({"aim"}) console.graffiti({"place"})
local hostArt=nextHandle
maxLive=rendered+5 openBrush() drag(300) settle(10) status()
assert(samples>visible)
online=true tick() status()
assert(strokes==0 and samples==0 and visible==0 and rendered==1 and live[hostArt],
    "joining a session retained private paint or lost the artist's premade")
emit("level_unloading") settle(2) assert(rendered==0)
maxLive=2048 online=false map="levels/game/test" emit("level_loaded",map) settle(150) status()
assert(samples==savedSamples and rendered==durableRuns+3 and strokes==27,string.format("wrong or missing paint on return: %d of %d, %d shown, %d strokes",samples,savedSamples,rendered,strokes))
print(string.format("PASS: %d recorded samples, %d concurrent decals, 26 strokes, return to an older wall, shared-pool recovery, artwork placement, undo, lifetime renewal and per-map restoration",allSamples,peak))
"""
if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "wall_paint")
    run(sys.argv[1], FILE_HOST + """
online=false step()
console.graffiti({"paint"}) step() step()
cursor.position=v(960,540,0) step()
cursor.left=true step()
local picks=0
local nativePick=reskate.world.pick
reskate.world.pick=function(...)
    picks+=1
    now+=11 -- streaming one receiver consumes this tick's brush sampling allowance
    return nativePick(...)
end
cursor.position=v(1000,540,0) step()
assert(picks==1,"brush continued interpolating after a slow native hit")
local function reach()
    local right=-math.huge
    for _,row in live do right=math.max(right,row.m[13]+math.abs(row.m[1])/2) end
    return right
end
local stepsBeforeRelease=reach()
for _=1,8 do step() end
assert(reach()>stepsBeforeRelease,"deferred samples never caught up to the cursor")
local beforeRelease=picks
cursor.left=false step()
assert(picks==beforeRelease,"brush performed a new wall query on the save/release frame")
step() assert(picks==beforeRelease+1,"idle hover did not resume")
print("PASS: slow native wall queries spread across ticks; release and hover recover")
""", "wall_paint_slow_queries")
