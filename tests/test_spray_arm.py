"""Exercise the local skater reach through the shipping brush and premade selector."""
import sys

from test_menu import run


CHECKS = """
local shoulder=v(2,1.35,0)
local pose,updates,releases=nil,0,0
local tracked,hasJoint=true,true
local entity,nativeAvailable,quads={},false,0
local clouds={}
local loops, bursts, activeLoop, stops=0,0,nil,0
reskate.audio.play=function(path,options)
    assert(options.position=="skater" and options.volume>0 and options.volume<=1)
    if options.loop then
        assert(path=="art/spray-loop.wav" and options.volume==0.32 and not activeLoop)
        loops+=1 activeLoop=1000+loops return activeLoop
    end
    assert(path=="art/spray-burst.wav" and options.volume==0.37) bursts+=1 return bursts
end
reskate.audio.stop=function(id)
    if id==activeLoop then activeLoop=nil stops+=1 end
end
local stock="world/custom/dingolevel_reskate_graffitilab_can/meshes/graffitilab_can_0_0_bp"
reskate.entities.bounds=function() error("interactive paint scanned the game's asset domains") end
reskate.entities.set=function(id,asset,transform,hidden,attach,options)
    assert(id==1 and asset==stock and not hidden)
    assert(attach.joint==54 and attach.turn==false and options.solid==false)
    assert(math.abs(transform.position.y+0.115)<0.001 and transform.position.z < -0.04 and transform.scale==1)
    entity[id]=true return true
end
reskate.entities.remove=function(id) assert(entity[id]) entity[id]=nil end
reskate.entities.status=function(id) return if not entity[id] then nil elseif nativeAvailable then "ready" else "missing" end
d.poly=function(_,vertices,style) assert(#vertices==4 and style.fill) quads+=1 end
d.world_image=function(_,asset,at,height,style)
    assert(asset=="art/spray-mist.png" and height>0 and height<0.88 and #style.colour==9)
    table.insert(clouds,{at=at,height=height,colour=style.colour})
end
local function drawFX()
    table.clear(clouds) quads=0 emit("draw",d)
    assert(#clouds<=28,"unbounded mist")
end
reskate.skater.joint=function(id)
    if id==49 then return if pose then {position=pose.at} else nil end
    if id==54 then return if pose then {position=pose.at+v(0,0,-0.055),rotation={0,0,0,1}} else nil end
    assert(id==47)
    if hasJoint then return {position=shoulder} end
end
reskate.skater.reach=function(goal)
    if goal then
        assert(goal.hand=="right" and goal.shown=="me")
        assert(goal.weight>0 and goal.weight<=1 and vector.magnitude(goal.at-shoulder)<0.56)
        if not tracked then return nil,"arm in use" end
        pose=goal updates+=1
    else
        assert(pose,"released an arm this plugin did not own")
        pose=nil releases+=1
    end
    return true
end
local function steps(n) for _=1,n do step() end end
local function testWall(level,blueprint)
    map=level emit("level_loaded",map)
    reskate.world.pick=function(a,b)
        local result=wall(a,b)
        if result.position then result.object={blueprint=blueprint} end
        return result
    end
    online=false step()
    console.graffiti({"paint"}) step()
    cursor.position=v(960,540,0) step()
    assert(not pose,"hover moved the arm")
    local before=updates
    local loopsBefore, burstsBefore=loops,bursts
    cursor.left=true steps(12)
    assert(pose and pose.weight==1 and updates>before)
    assert(activeLoop and loops==loopsBefore+1 and bursts==burstsBefore)
    drawFX()
    assert(#clouds>1 and entity[1])
    assert(quads==0,"paint can was drawn as a HUD shape")
    assert(clouds[1].height>0.20,"spray cloud too small")
    local nearHand,nearWall=false,false
    for _,p in clouds do
        nearHand=nearHand or vector.magnitude(p.at-pose.at)<0.6
        nearWall=nearWall or math.abs(p.at.z+2)<0.15
    end
    assert(nearHand and nearWall,"mist did not originate at the hand and wall")
    local start=pose.at
    cursor.position=v(1260,480,0) steps(12)
    assert(pose.at.x>start.x+0.10 and pose.at.y>start.y)
    cursor.left=false step()
    assert(pose and pose.weight<1 and not activeLoop and loops==loopsBefore+1)
    steps(10) assert(not pose)
    key("Space") steps(10) assert(pose and pose.weight==1,"latched brush")
    key("Space") steps(10) assert(not pose)
    key("E") cursor.left=true steps(24) drawFX()
    assert(not activeLoop and loops==loopsBefore+2 and not pose and not entity[1] and #clouds==0 and quads==0,"eraser kept spray effects")
    cursor.left=false step() key("E")
    focus=v(2,1,20) cursor.left=true steps(12) assert(not pose,"invalid wall")
    cursor.left=false step() focus=v(2,1,0)
    escape()
    console.graffiti({"library"}) step()
    key("Right") key("Enter") steps(12) drawFX()
    assert(not active and pose and pose.weight==1)
    assert(bursts==burstsBefore and not activeLoop)
    assert(#clouds==0,"aiming consumed paint or emitted mist")
    local aimingX=pose.at.x
    local liveBefore=count()
    local art=live[nextHandle]
    keys[1]=true step() assert(active=="Premade Art" and art.alpha==1)
    steps(18) drawFX()
    assert(bursts==burstsBefore+1 and not activeLoop)
    assert(#clouds>0 and entity[1] and quads==0,"missing premade spray")
    assert(active=="Premade Art" and has("BIRDS") and pose.at.x>aimingX+0.09,"premade sweep or selection lost")
    steps(16) assert(active=="Premade Art" and count()==liveBefore and not pose)
    keys[1]=false steps(40) drawFX()
    assert(#clouds==0 and not entity[1] and quads==0)
    key("Enter") steps(10) assert(pose)
    buttons.b=true step() buttons.b=false steps(12)
    assert(not pose and count()==liveBefore,"cancel left a reach or an extra decal")
    console.graffiti({"aim"}) steps(10) assert(pose)
    hasJoint=false step() assert(not pose)
    hasJoint=true tracked=false step()
    local lastReleases=releases
    emit("unload") assert(releases==lastReleases,"cleared another plugin's reach")
    tracked=true
    console.graffiti({"aim"}) steps(12) assert(pose)
    emit("level_unloading") drawFX()
    assert(not pose and not entity[1] and quads==0 and #clouds==0,"map unload left spray effects")
end
nativeAvailable=true
testWall("levels/game/bam_levelroot/bam_levelroot","Levels/Game/BAM_LevelRoot/generated/StairsLitePG_AGAsset_B8E7EE88")
nativeAvailable=false
testWall("levels/game/dingolevel_reskate_turbo_token_arcade/dingolevel_reskate_turbo_token_arcade",
    "world/custom/dingolevel_reskate_turbo_token_arcade/collision/0562_str_roof_281_0.physics_bp")
print("PASS: arm, attached can, native mesh, bounded nozzle and wall mist, premade selector, release and unload on both receiver fixtures")
"""


if __name__ == "__main__":
    run(sys.argv[1], CHECKS, "spray_arm")
