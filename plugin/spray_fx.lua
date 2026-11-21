local v = vector.create
local up = v(0,1,0)
local asset = "world/custom/dingolevel_reskate_graffitilab_can/meshes/graffitilab_can_0_0_bp"
-- The authored can is centred in X/Z and stands 0.186 m from base to nozzle.
-- entities.set queues the attachment; a synchronous bounds lookup scans asset domains.
local canScale = 1
local nozzleHeight = 0.186*canScale
local previousOffset
local canId = 1
-- The skeleton's right_middle is the middle knuckle; right_hand itself is the wrist.
local gripJoint = 54
local requested, nextLookup = false, 0
local puffs, emissionMs, serial = {}, 0, 0
local neutral = "#E0DED8"

local function hide()
    if requested then
        reskate.entities.remove(canId)
        nextLookup=0
    end
    requested, emissionMs, previousOffset = false, 0, nil
end

local function reset()
    hide()
    table.clear(puffs)
    nextLookup = 0
end

local function age(dt)
    for i=#puffs,1,-1 do
        local p=puffs[i]
        p.age+=dt
        if p.age>=p.life then table.remove(puffs,i) end
    end
end

local function puff(at,velocity,diameter,life,colour)
    if #puffs>=28 then table.remove(puffs,1) end
    table.insert(puffs,{at=at,velocity=velocity,diameter=diameter,life=life,age=0,colour=colour})
end

local function update(dt,hit,spraying,colour,sweepOffset)
    if not hit then hide() return end
    local hand=reskate.skater.joint(gripJoint)
    local wrist=reskate.skater.joint(49)
    if not hand or not wrist then hide() return end
    -- Carry the barrel just beyond the knuckle, along the fingers. Wrist roll
    -- does not turn the long axis sideways through the back of the hand.
    local finger=hand.position-wrist.position
    local reach=vector.magnitude(finger)
    if reach<0.001 then hide() return end
    local offset=finger*(0.042/reach)-up*0.115
    local now=reskate.time.now()
    if now>=nextLookup and (not requested or vector.magnitude(offset-previousOffset)>0.003) then
        requested=reskate.entities.set(canId,asset,{position=offset,scale=canScale},false,{joint=gripJoint,turn=false},{solid=false})
        previousOffset=offset
        nextLookup=now+(if requested then 50 else 1200)
    end
    if not spraying then emissionMs=0 return end
    emissionMs-=dt
    if emissionMs>0 then return end
    emissionMs=55
    local across=v(hit[1],hit[2],hit[3])
    local wall=v(hit[13],hit[14],hit[15])+across*sweepOffset
    local normal=vector.normalize(v(hit[5],hit[6],hit[7]))
    local side=vector.normalize(across)
    local nozzle=hand.position+(previousOffset or offset)+up*nozzleHeight
    local delta=wall-nozzle
    local distance=vector.magnitude(delta)
    if distance<0.025 then return end
    serial+=1
    local drift=side*(0.09*math.sin(serial*2.4))+up*0.14
    puff(nozzle+delta/distance*0.035,delta/distance*math.min(1.6,distance/0.24)+drift,
        0.28,470,colour or neutral)
    puff(wall+normal*0.035,normal*0.09+drift,0.34,580,neutral)
end

reskate.on("draw",function(d)
    for _,p in puffs do
        local t=p.age/p.life
        local colour=p.colour..string.format("%02X",math.round(220*(1-t)^1.45))
        d:world_image("art/spray-mist.png",p.at+p.velocity*(p.age/1000),p.diameter*(0.65+1.9*t),{colour=colour})
    end
end)

return {age=age,update=update,hide=hide,reset=reset}
