-- ReSkate 20261116's right arm chain starts the upper arm at joint 47.
-- Aim from that joint so a distant wall never pulls the wrist out of reach.
local visuals = require("spray_fx")
local player=require("playback")
local loopPath, burstPath = "art/spray-loop.wav", "art/spray-burst.wav"
local loopId, burstId, nextAudioTry = nil, nil, 0
reskate.audio.preload(loopPath)
reskate.audio.preload(burstPath)

local function freehandSound(flowing)
    if not flowing or player.volume()==0 then
        if loopId then reskate.audio.stop(loopId) loopId=nil end
        nextAudioTry=0
    elseif not loopId and reskate.time.now()>=nextAudioTry then
        loopId=reskate.audio.play(loopPath,{loop=true,position="skater",volume=0.32*player.volume()/100})
        nextAudioTry=reskate.time.now()+500
    end
end

local upperArm, sweepMs = 47, 360
local wrist, weight, strokeTime = nil, 0, 0
local sweep, sweepTime = nil, 0
local ownsReach = false

local function release()
    if ownsReach then reskate.skater.reach(nil) end
    wrist, weight, strokeTime, sweep, ownsReach = nil, 0, 0, nil, false
end

local function reset()
    freehandSound(false)
    if burstId then reskate.audio.stop(burstId) burstId=nil end
    release()
    visuals.reset()
end

local function tick(dt, hit, brushing, colour)
    freehandSound(brushing and hit~=nil)
    visuals.age(dt)
    local side = -0.09
    local spraying = brushing
    local sweepOffset = 0
    if hit then
        sweep = nil
        if brushing then
            strokeTime += dt
            side = 0.025 * math.sin(strokeTime * 0.012)
        end
    elseif sweep then
        spraying = true
        sweepTime += dt
        local t = math.min(1, sweepTime/sweepMs)
        hit = sweep
        local travel=t*t*(3-2*t)
        side += 0.18*travel
        sweepOffset=(travel-0.5)*0.56
        if t==1 then sweep=nil end
    end
    if not brushing then strokeTime=0 end
    if hit then
        local shoulder = reskate.skater.joint(upperArm)
        if not shoulder then reset() return end
        local wall = vector.create(hit[13],hit[14],hit[15])
        local normal = vector.normalize(vector.create(hit[5],hit[6],hit[7]))
        local across = vector.normalize(vector.create(hit[1],hit[2],hit[3]))
        local delta = wall + normal*0.12 - shoulder.position
        local distance = vector.magnitude(delta)
        if distance<0.01 then reset() return end
        local goal = shoulder.position + delta*(math.min(0.46,distance)/distance) + across*side
        wrist = if wrist then wrist+(goal-wrist)*(1-math.exp(-dt/45)) else goal
        weight = math.min(1,weight+dt/140)
    else
        visuals.hide()
        if not wrist then return end
        weight = math.max(0,weight-dt/140)
        if weight==0 then release() return end
    end
    ownsReach = reskate.skater.reach({hand="right",at=wrist,weight=weight,shown="me"})
    if hit then visuals.update(dt,if ownsReach then hit else nil,spraying,colour,sweepOffset) end
end

return {tick=tick,reset=reset,place=function(hit)
    sweep,sweepTime=hit,0
    if burstId then reskate.audio.stop(burstId) end
    burstId=if player.volume()>0 then reskate.audio.play(burstPath,{position="skater",volume=0.37*player.volume()/100}) else nil
end}
