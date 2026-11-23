local model=require("composition")
local wall=require("wall_art")
local palette=require("blackbook").palette
local symbols=model.inks
local emotes={}
local function decodeGrid(pixels,w,h)
    if #pixels~=w*h or pixels:find("[^.1-9A-G]") then return end
    local grid={}
    for i=1,#pixels do grid[i]=symbols:find(pixels:sub(i,i),1,true)-1 end
    local parts=wall.rectangles(grid,w,h)
    if not parts or #parts>64 then return end
    for _,p in parts do p.x/=w p.y/=h p.w/=w p.h/=h end
    return parts
end
local function compact(piece)
    local frames=piece.frames or {piece.parts}
    local aspect=piece.aspect or 1
    for _,size in {20,16,12,8} do
        local w=math.max(1,math.round(size*math.min(1,aspect)))
        local h=math.max(1,math.round(size/math.max(1,aspect)))
        local rows={}
        for _,parts in frames do
            local bits=table.create(w*h,".")
            local coverage=table.create(w*h,0)
            for _,p in parts do
                local x,y=(p.x+.5-p.w/2)*w,(p.y+.5-p.h/2)*h
                local right,bottom=x+p.w*w,y+p.h*h
                local colour=symbols:sub(p.colour+1,p.colour+1)
                -- A narrow mark between cell centres still contributes its ink.
                for j=math.max(0,math.floor(y)),math.min(h-1,math.ceil(bottom)-1) do
                    local height=math.min(bottom,j+1)-math.max(y,j)
                    for i=math.max(0,math.floor(x)),math.min(w-1,math.ceil(right)-1) do
                        local area=height*(math.min(right,i+1)-math.max(x,i))
                        local at=j*w+i+1
                        if area>1e-7 and area>=coverage[at] then bits[at],coverage[at]=colour,area end
                    end
                end
            end
            local raw=table.concat(bits)
            if not decodeGrid(raw,w,h) then break end
            table.insert(rows,raw)
        end
        if #rows==#frames and table.concat(rows):find("[^.]") then
            local ms=piece.frameMs or (if piece.media then piece.media.frameMs else 250)
            return string.format("I:%d:%d:%d:%d:",w,h,math.round(aspect*10000),ms)..table.concat(rows,"/")
        end
    end
    return nil,"The emote rendition has no visible ink."
end
function emotes.drawArt(d,art,x,y,w,h,age)
    if art.stock then
        d:image(art.stock.sheet,vector.create(x,y,0),vector.create(x+w,y+h,0),{uv=art.stock.thumb})
    else
        local parts=art.frames[1+math.floor(age/art.ms)%#art.frames]
        for _,p in parts do
            d:rect(vector.create(x+w*p.x,y+h*p.y,0),vector.create(x+w*(p.x+p.w),y+h*(p.y+p.h),0),{colour=palette[p.colour],fill=true})
        end
    end
end
function emotes.create(stock,scope)
    local catalog,cache,order={}, {}, {}
    for _,p in stock do if p.sheet and not p.file then catalog[p.id]=p end end
    local active,last,serial={}, {}, math.floor(reskate.time.now())
    local settings,loadError
    local slotCache={}
    local function load()
        if settings then return settings end
        local raw,why=reskate.files.read("studio/emotes.json")
        if not raw and why~="not found" then loadError=why return end
        local ok,s=true,{version=1,slots={},cooldown=6,others=true}
        if raw then ok,s=pcall(reskate.json.decode,raw) end
        if not ok or type(s)~="table" or s.version~=1 or type(s.slots)~="table" or type(s.cooldown)~="number"
            or not (s.cooldown>=1 and s.cooldown<=30) or type(s.others)~="boolean" then loadError="Invalid emote settings file." return end
        settings=s return s
    end
    local function parse(raw)
        if type(raw)~="string" or #raw>3300 then return end
        local key=model.key(raw)
        if cache[key] then return if cache[key].raw==raw then cache[key] else nil end
        local art={raw=raw,key=key}
        if raw:sub(1,2)=="S:" then
            art.stock=catalog[raw:sub(3)] if not art.stock then return end
            art.aspect=art.stock.aspect or 1
        else
            local w,h,ratio,ms,body=raw:match("^I:(%d+):(%d+):(%d+):(%d+):([%.1-9A-G/]+)$")
            w,h,ratio,ms=tonumber(w),tonumber(h),tonumber(ratio),tonumber(ms)
            if not w or w<1 or w>20 or h<1 or h>20 or ratio<625 or ratio>160000 or ms<100 or ms>5000 then return end
            local frames=string.split(body,"/")
            if #frames>8 then return end
            art.frames,art.aspect,art.ms={},ratio/10000,ms
            for i,f in frames do
                local parts=decodeGrid(f,w,h) if not parts then return end art.frames[i]=parts
            end
        end
        cache[key]=art table.insert(order,key)
        if #order>32 then cache[table.remove(order,1)]=nil end
        return art
    end
    local api={}
    function api.settings() return load(),loadError end
    function api.change(slot,item,cooldown,others)
        local s=load() if not s then return nil,loadError end
        local n=table.clone(s) n.slots=table.clone(s.slots)
        if slot then n.slots[tostring(slot)]=item end
        if cooldown then n.cooldown=math.clamp(math.round(cooldown),1,30) end
        if others~=nil then n.others=others end
        local ok,why=reskate.files.write("studio/emotes.json",reskate.json.encode(n))
        if ok then settings=n if slot then slotCache[slot]=nil end end
        return ok,why
    end
    function api.assign(slot,p)
        local raw,why
        if catalog[p.id] then raw="S:"..p.id
        else
            local ok,msg=require("studio_projects").prepare(p,true)
            if not ok then return nil,msg end
            raw,why=compact(p)
        end
        if not raw or not parse(raw) then return nil,why or "Cannot render this artwork." end
        return api.change(slot,{name=p.name,raw=raw})
    end
    function api.slot(i)
        local s=load() local e=s and s.slots[tostring(i)]
        if type(e)=="table" and type(e.name)=="string" then
            if not slotCache[i] then slotCache[i]=parse(e.raw) end
            return slotCache[i],e.name
        end
    end
    function api.fire(i)
        local art=api.slot(i)
        if not art then return nil,"Choose an occupied emote slot." end
        local now=reskate.time.now()
        if last.me and now-last.me<settings.cooldown*1000 then return nil,"Emote cooling down." end
        local world,map=scope()
        local level=reskate.level.current()
        if not level or not level.name then return nil,"Enter a map first." end
        last.me=now serial+=1
        active.me={art=art,start=now,map=level.name}
        if reskate.session.active() and world and map then
            local wire=table.concat({"GE1",world,map,tostring(serial),art.key,art.raw},"|")
            if #wire>4082 or not reskate.net.send("all",wire) then return true,"Shown locally. Session delivery unavailable." end
        end
        return true
    end
    function api.receive(from,wire)
        if from.me or from.server or type(from.id)~="string" or type(wire)~="string" or #wire>4082 or wire:sub(1,4)~="GE1|" then return end
        local s=load() if not s or not s.others or not reskate.session.active() then return end
        local world,map=scope()
        local level=reskate.level.current()
        if not world or not map or not level or not level.name then return end
        local f=string.split(wire,"|")
        if #f~=6 or f[2]~=world or f[3]~=map then return end
        local seq=tonumber(f[4])
        local now=reskate.time.now()
        local seen=last[from.id]
        if not seq or seq%1~=0 or seq<1 or seq>2^53-1 or (seen and (seq<=seen.seq or now-seen.at<950)) then return end
        if #f[6]>3300 or #f[5]~=16 or model.key(f[6])~=f[5] then return end
        local art=parse(f[6])
        if not art then return end
        last[from.id]={seq=seq,at=now}
        active[from.id]={art=art,start=now,map=level.name}
    end
    function api.drop(id) active[id],last[id]=nil,nil end
    function api.reset() table.clear(active) table.clear(last) end
    function api.draw(d)
        if not next(active) then return end
        local now=reskate.time.now()
        local cam=reskate.camera.get()
        local level=reskate.level.current()
        local rendered,rays=0,0
        local function display(id,e)
            local localPlayer=id=="me"
            if now-e.start>=5000 or not level or level.name~=e.map or (not localPlayer and (not settings.others or not reskate.session.active())) then active[id]=nil return end
            if not cam or rendered>=4 then return end
            local function joint(name)
                if localPlayer then return reskate.skater.joint(name) end
                return reskate.session.joint(id,name)
            end
            local j=joint("head") local offset=.23
            if not j then j=joint("spine") offset=.70 end
            if not j or not j.position then return end
            local at=j.position+vector.create(0,offset,0)
            local delta=at-cam.position
            local dist=vector.magnitude(delta)
            if dist<.1 or dist>25 or vector.dot(delta,cam.forward)<=.05 then return end
            -- Overlay is screen-space. Probe the anchor at 5 Hz, one ray per visible emote.
            if not e.nextRay or now>=e.nextRay then
                if rays>=3 then return end
                rays+=1
                local ray=reskate.world.probe(cam.position,at)
                e.clear=ray.status=="clear" or (ray.status=="hit" and ray.position and vector.magnitude(ray.position-at)<.12)
                e.nextRay=now+200
            end
            if not e.clear then return end
            local pos=d:world_to_screen(at)
            if not pos then return end
            local view=d:size()
            local side=math.clamp(340/math.max(1,dist),32,112)*view.y/1080
            local w=side*math.min(1,e.art.aspect) local h=w/e.art.aspect
            if pos.x+w<0 or pos.x-w>view.x or pos.y<0 or pos.y-h>view.y then return end
            rendered+=1 emotes.drawArt(d,e.art,pos.x-w/2,pos.y-h,w,h,now-e.start)
        end
        if active.me then display("me",active.me) end
        for id,e in active do if id~="me" then display(id,e) end end
    end
    return api
end
return emotes
