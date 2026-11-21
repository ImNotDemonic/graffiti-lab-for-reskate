-- Resource handles belong to each local instance. Far pieces show their original first frame.
local player={}
local running={}
local used,voices=0,0
local fx=reskate.effects
local audio=reskate.audio
local assetRoot="world/materials/decal/reskate_graffitilab/"
local gain,readGain=nil,false
function player.volume()
    if not readGain then
        readGain=true
        local raw=reskate.files.read("library/audio.txt")
        gain=math.clamp(tonumber(raw) or 100,0,100)
    end
    return gain or 100
end
function player.setVolume(pct)
    local ok,why=reskate.files.write("library/audio.txt",tostring(pct))
    if ok then gain,readGain=pct,true end
    return ok,why
end
local function silence(s)
    if s.voice then audio.stop(s.voice) s.voice=nil voices-=1 end
end
local function first(s)
    for _,h in s.overlay do fx.release(h) end
    used-=#s.overlay table.clear(s.overlay)
    if s.frame~=1 then for _,h in s.mark.handles do fx.opacity(h,1) end end
    s.frame=1
end
function player.remove(mark)
    local s=running[mark]
    if s then first(s) silence(s) running[mark]=nil end
end
function player.clear()
    for mark in running do player.remove(mark) end
end
function player.attach(mark,frames,asset)
    player.remove(mark)
    if not asset or (#frames==1 and not asset.sound) then return end
    running[mark]={mark=mark,frames=frames,asset=asset,frame=1,elapsed=0,overlay={},last=-math.huge,near=false}
end
function player.handles() return used end
local function show(s,index,wall,budget)
    if index==s.frame then return end
    if index==1 then first(s) return end
    local frame=s.frames[index]
    if #frame+used>math.min(160,budget) then first(s) return end
    local nextHandles={}
    for _,part in frame do
        local h=fx.decal(assetRoot..part.asset.."_dv",wall.transform(s.mark.transform,part))
        if not h then for _,new in nextHandles do fx.release(new) end first(s) return end
        table.insert(nextHandles,h)
    end
    first(s)
    for _,h in s.mark.handles do fx.opacity(h,0) end
    s.overlay,s.frame=nextHandles,index used+=#nextHandles
end
local function soundAt(s,p,inside,interact,now,g)
    local cfg=s.asset.sound
    if not cfg then return end
    local loop=cfg.trigger=="nearby-loop"
    if s.voice and not audio.playing(s.voice) then s.voice=nil voices-=1 end
    if s.voice and (not inside or g<=0) then silence(s)
    elseif s.voice then audio.set(s.voice,{position=p,volume=g*cfg.volume/10000}) end
    local start=(loop or (cfg.trigger=="approach" and not s.near) or (cfg.trigger=="interact" and interact))
    if inside and start and not s.voice and voices<6 and g>0 and now-s.last>=(if loop then 500 else cfg.cooldown*1000) then
        s.last=now
        s.voice=audio.play("art/"..cfg.id..".wav",{position=p,range=cfg.radius,volume=g*cfg.volume/10000,loop=loop})
        if s.voice then voices+=1 end
    end
    s.near=inside
end
function player.tick(dt,wall,budget,interact)
    if not next(running) then return end
    local cam=reskate.camera.get()
    if not cam then for _,s in running do first(s) silence(s) s.near=false end return end
    local closest,nearest=nil,math.huge
    if interact then
        for _,s in running do
            local m=s.mark.transform
            local dist=vector.magnitude(cam.position-vector.create(m[13],m[14],m[15]))
            local cfg=s.asset.sound
            if cfg and cfg.trigger=="interact" and dist<=cfg.radius and dist<nearest then closest,nearest=s,dist end
        end
    end
    for _,s in running do
        local m=s.mark.transform
        local p=vector.create(m[13],m[14],m[15])
        local dist=vector.magnitude(cam.position-p)
        if #s.frames>1 then
            if dist<=18 then
                s.elapsed=(s.elapsed+dt)%(#s.frames*s.asset.frameMs)
                show(s,1+math.floor(s.elapsed/s.asset.frameMs),wall,budget)
            else s.elapsed=0 first(s) end
        end
        if s.asset.sound then soundAt(s,p,dist<=s.asset.sound.radius,s==closest,reskate.time.now(),player.volume()) end
    end
end
return player
