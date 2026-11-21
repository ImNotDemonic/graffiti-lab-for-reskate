"""Run premade placement and late-join reconciliation in separate Luau processes.

Usage: python tests/test_sharing.py /path/to/luau
The adapter supplies the wall, session transport, clock and decal handles.
"""
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = """
local modules, events, console, live, messages = {}, {}, {}, {}, {}
local v = vector.create
local now, nextHandle, world, online, available = 900000, 0, "12345", true, true
local map = "levels/game/test"
local focus = v(2,1,0)
local failNext = false
local function noop() end
local function count()
    local n=0
    for _ in live do n+=1 end
    return n
end
local function emit(name,...)
    for _,f in events[name] or {} do f(...) end
end
local function frame(ms)
    now+=ms
    emit("tick",ms)
end
local function wall(a,b)
    if b.z>=-2 or a.z<=-2 then return {status="clear"} end
    return {status="hit",position=a+(b-a)*((-2-a.z)/(b.z-a.z))}
end
local reskate = {
    skater={joint=function(id) if id==47 then return {position=v(0,1.4,0)} end end,reach=function() return true end},
    entities={bounds=noop,set=noop,remove=noop,status=noop},
    package={read_json=function() return {{id="switchback",name="Switchback"}} end},
    effects={
        state=function() return available,1 end, clear=function() table.clear(live) end,
        decal=function(asset,m)
            if failNext then failNext=false return nil,"unavailable" end
            nextHandle+=1 live[nextHandle]={asset=asset,m=m} return nextHandle
        end,
        opacity=function(id,a) assert(live[id]) live[id].alpha=a end,
        release=function(id) assert(live[id]) live[id]=nil end,
        move=function(id,m) live[id].m=m end,
    },
    files={list=function() return {} end},
    net={send=function(to,data)
        assert(online and to=="all" and #data<=4082)
        table.insert(messages,data)
        return true
    end},
    time={now=function() return now end},
    camera={get=function() return {position=focus,forward=v(0,0,-1),right=v(1,0,0),up=v(0,1,0)} end},
    level={current=function() return {name=map} end}, world={probe=wall,pick=wall},
    session={active=function() return online end,world=function() return {world=world,map=map} end},
    on=function(n,f) events[n]=events[n] or {} table.insert(events[n],f) end,
    menu={page=noop},ui={toast=noop},
    input={bind=noop,allowed=function() return true end,key=noop,gamepad=noop},
    console={command=function(n,_,f) console[n]=f end},log=noop
}
reskate.audio={preload=function() end,play=function() return 1 end,stop=function() end}
local function require(name) return assert(modules[name],name) end
local function panel() return {close=noop,open=noop,active=function() return false end,tick=noop,expiring=noop} end
modules.paint,modules.selector,modules.studio,modules.menu,modules.wall_art=panel,panel,panel,panel,{}
"""

ADAPTER += (ROOT / "tests/storage_fixture.luau").read_text(encoding="utf-8")

ARTIST = """
-- A real lobby already has its own world, but active() is false until its first handshake.
online=false
frame(1)
console.graffiti({"aim"})
frame(3100)
assert(#messages==0,"unconnected host sent a preview")
console.graffiti({"place"})
assert(count()==1 and live[1].alpha==1)
frame(401) assert(#messages==0)
online=true frame(1)
assert(count()==1 and live[1] and string.find(messages[#messages],"switchback",1,true),"lost the host's first mark")
-- The visitor has not launched. Drop all traffic so far.
table.clear(messages)
frame(3100)
assert(#messages==1)
print("LATE "..messages[1])
console.graffiti({"remove"})
frame(401)
assert(count()==0)
print("EMPTY "..messages[#messages])
for i=1,16 do
    focus=v(i,1,0)
    console.graffiti({"aim"}) console.graffiti({"place"})
end
frame(401)
assert(count()==16)
print("FULL "..messages[#messages])
online=false frame(1)
assert(count()==16,"last peer leaving the lobby cleared the artist's work")
online=true frame(1)
assert(count()==16 and string.find(messages[#messages],"switchback",1,true))
online=false frame(1) world="unrelated-lobby" online=true frame(1)
assert(count()==0 and not string.find(messages[#messages],"switchback",1,true),"unrelated world imported old work")
online=false frame(1)
console.graffiti({"aim"}) console.graffiti({"place"})
world="offline-world" frame(300)
world="unrelated-lobby" online=true frame(1)
assert(count()==0,"a later lobby reused a world id and inherited an old mark")
"""

VISITOR = """
local artist={id="101",me=false,server=false}
local function arrive(msg,who) emit("message",who or artist,msg) end
frame(1)
assert(count()==0)
available=false arrive(late)
assert(count()==0)
available=true
arrive(late,{id="101",me=true}) arrive(late,{id="101",server=true})
assert(count()==0)
failNext=true arrive(late)
assert(count()==0)
local function stamp(s,sequence)
    local parts=string.split(s,"|")
    parts[4]=tostring(sequence)
    return table.concat(parts,"|")
end
local serial=tonumber(string.split(late,"|")[4])
local newer=stamp(late,serial+1)
arrive(newer)
assert(count()==1)
local received=assert(live[1])
assert(received.asset=="world/materials/decal/reskate_graffitilab/switchback_dv")
local m=received.m
assert(math.abs(m[13]-2)<0.0001 and math.abs(m[14]-1)<0.0001 and math.abs(m[15]+1.994)<0.0001)
assert(math.abs(m[1]-0.65)<0.00001 and math.abs(m[7]-0.045)<0.00001 and math.abs(m[10]+0.65)<0.00001)
arrive(newer) arrive(late)
assert(count()==1 and nextHandle==1)
local invalid=stamp(late,serial+2)
arrive((string.gsub(invalid,"switchback","other")))
arrive((string.gsub(invalid,",2.0000,",",1e99,")))
assert(count()==1 and nextHandle==1)
-- The visitor can draw their own copy at the same position.
console.graffiti({"aim"}) console.graffiti({"place"})
assert(count()==2)
arrive(empty)
assert(count()==1 and live[2],"owner removal touched visitor's own decal")
arrive(late)
assert(count()==1)
arrive(full)
assert(count()==17)
emit("player_left",artist)
assert(count()==1 and live[2])
world="new-world" frame(1) arrive(full)
assert(count()==0)
world="12345" map="levels/elsewhere" frame(1) arrive(late)
assert(count()==0)
map="levels/game/test" frame(1) arrive(full)
assert(count()==16)
for i=1,6 do arrive(full,{id=tostring(200+i)}) end
assert(count()==64)
frame(12010)
assert(count()==0)
online=false frame(1) arrive(late)
assert(count()==0)
print("PASS: late render, asset and transform, duplicate and stale delivery, retry, ownership, map and world filters, remote budget, expiry, disconnect and offline isolation")
"""

PLACEMENT_INPUT = """
online=false
local allowed, mouseDown = true, true
local pad = {buttons={a=true,b=false}}
reskate.input.allowed=function() return allowed end
reskate.input.key=function(code) return code==1 and mouseDown end
reskate.input.gamepad=function() return pad end
local labels={}
local draw={size=function() return v(1920,1080,0) end,rect=noop,circle=noop,
    text=function(_,_,label) table.insert(labels,label) end}
local function status()
    table.clear(labels)
    emit("draw",draw)
    return labels[1]
end
frame(1)
focus=v(2,1,20)
console.graffiti({"aim"}) frame(101)
assert(status()=="Aim at a flat wall within 8 m" and count()==0)
focus=v(2,1,0) frame(101)
assert(status()=="Wall ready" and live[1].alpha==0.45,"selecting with a held button confirmed immediately")
mouseDown=false pad.buttons.a=false frame(1)
allowed=false mouseDown=true frame(1)
assert(status()==nil and live[1].alpha==0.45)
allowed=true frame(1)
assert(live[1].alpha==0.45,"menu click leaked into placement")
mouseDown=false frame(1)
focus=v(2,1,20) mouseDown=true frame(1)
assert(count()==0,"placed from stale wall preview")
focus=v(2,1,0) mouseDown=false frame(101)
mouseDown=true frame(1) frame(101)
assert(count()==1 and live[2].alpha==1 and status()==nil,"left click failed to place once")
console.graffiti({"aim"}) mouseDown=false frame(1)
pad.buttons.b=true frame(1)
assert(count()==1 and live[2].alpha==1 and status()==nil,"cancelling removed an older mark")
pad.buttons.b=false
console.graffiti({"aim"}) frame(1)
pad.buttons.a=true frame(1)
assert(count()==2 and live[4].alpha==1 and status()==nil)
local camera=reskate.camera.get
reskate.camera.get=function() local view=camera() view.fov=60 return view end
console.graffiti({"aim"}) frame(101)
local expectedY=focus.y + 2*(1-2*0.35)*math.tan(math.rad(60)/2)
assert(math.abs(live[5].m[14]-expectedY)<0.001,"wall ray missed the raised aiming ring")
print("PASS: aim prompt, invalid wall, held controls, menu input, mouse placement, controller confirm and cancel")
"""

def run(luau, directory, name, script):
    modules = []
    for module in ("playback", "media_format", "library", "placements", "surface", "sharing", "wall_codec", "wall_store", "wall_ink", "spray_fx", "spray_arm"):
        code = (ROOT / "plugin" / (module + ".lua")).read_text(encoding="utf-8")
        modules.append(f"modules.{module}=(function()\n{code}\nend)()")
    main = (ROOT / "plugin/main.lua").read_text(encoding="utf-8")
    path = directory / (name + ".luau")
    path.write_text("\n".join([ADAPTER, *modules, main, script]), encoding="utf-8")
    return subprocess.check_output([luau, path], text=True)

if __name__ == "__main__":
    with TemporaryDirectory() as tmp:
        directory = Path(tmp)
        print(run(sys.argv[1],directory,"placement",PLACEMENT_INPUT).strip())
        snapshots = dict(line.split(" ",1) for line in run(sys.argv[1],directory,"artist",ARTIST).splitlines())
        # Only wire data crosses into the new visitor process.
        inputs = "\n".join(f"local {key.lower()}={json.dumps(value)}" for key,value in snapshots.items())
        print(run(sys.argv[1],directory,"visitor",inputs+"\n"+VISITOR).strip())
