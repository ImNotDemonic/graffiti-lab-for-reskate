-- One atomic file per offline instance; records are independent of the artwork library.
local placements={}
local folder,map,pending,offset,records={},nil,{},1,{}
local past,future={},{}
local serial=0
local arch=require("native_arch")
local legacyStyles=setmetatable({},{__mode="k"})

-- Older placements contain only their portable ink. Upgrade the view only if
-- the original local save still matches every stored rectangle and colour.
local function originalStyle(r)
    if arch.valid(r.arch) then return r.arch end
    if legacyStyles[r]~=nil then return legacyStyles[r] or nil end
    legacyStyles[r]=false
    local file=r.art:match("^import/([%w _%-]+%.glshape)$")
    if not file or not r.parts or r.media then return end
    local p={file="imports/"..file}
    if not require("imports").load(p) or not p.arch or #p.parts~=#r.parts then return end
    for i,v in r.parts do
        local expected=p.parts[i]
        if v.colour~=expected.colour then return end
        for _,k in {"x","y","w","h"} do
            if math.abs(v[k]-expected[k])>1e-7 then return end
        end
    end
    legacyStyles[r]=p.arch
    return p.arch
end
local function directory(name)
    local h,k=5381,7
    for i=1,#name do local c=name:byte(i) h=(h*33+c)%4294967296 k=(k*131+c)%4294967296 end
    return string.format("placements/%08x%08x/",h,k)
end
local function valid(rec)
    if type(rec)~="table" or rec.version~=1 or rec.map~=map or type(rec.id)~="string" or
        not rec.id:match("^p%x+%-%x+$") or #rec.id>30 or type(rec.art)~="string" or #rec.art>200
        or type(rec.name)~="string" or #rec.name>256 or type(rec.base)~="table" or #rec.base~=16 then return false end
    for i=1,16 do if type(rec.base[i])~="number" or not (math.abs(rec.base[i])<1000000) then return false end end
    for _,axis in {1,5,9} do
        local length=vector.magnitude(vector.create(rec.base[axis],rec.base[axis+1],rec.base[axis+2]))
        if length<0.00001 or length>64 then return false end
    end
    if type(rec.scale)~="number" or not (rec.scale>=0.1 and rec.scale<=5) or type(rec.angle)~="number" or not (math.abs(rec.angle)<=360) then return false end
    if rec.stretch~=nil and (type(rec.stretch)~="number" or not (rec.stretch>=0.1 and rec.stretch<=5)) then return false end
    if rec.media then
        if not require("media_format").validate(rec.media,require("imports").decode) then return false end
    end
    if rec.parts then
        if type(rec.parts)~="table" or #rec.parts<1 or #rec.parts>256 then return false end
        for _,p in rec.parts do
            if type(p)~="table" or type(p.colour)~="number" or p.colour%1~=0 or p.colour<1 or p.colour>16 then return false end
            for _,k in {"x","y","w","h"} do if type(p[k])~="number" or not (math.abs(p[k])<=1) then return false end end
            if p.w<=0 or p.h<=0 then return false end
        end
    end
    return true
end
function placements.close()
    map=nil records={} pending={} offset=1 table.clear(past) table.clear(future)
end
function placements.load(name)
    if map~=name then
        placements.close()
        local path=directory(name)
        local files,why=reskate.files.list(path)
        if not files and why~="not found" then return nil,why end
        map,folder=name,path
        for _,f in files or {} do if f:match("^p%x+%-%x+%.json$") and #f<=35 then table.insert(pending,f) end end
        table.sort(pending)
    end
    if not pending[offset] then return true end
    local f=pending[offset]
    local raw,why=reskate.files.read(folder..f)
    if not raw and why~="not found" then return nil,why end
    offset+=1
    if not raw then return true end
    local ok,r=pcall(reskate.json.decode,raw)
    if not ok or not valid(r) or r.id..".json"~=f then return nil,"Skipped damaged placement "..f end
    r.sound=nil
    if r.media then r.media=require("media_format").visual(r.media) end
    records[r.id]=r
    return true,r
end
function placements.rows()
    local rows={}
    for _,r in records do table.insert(rows,r) end
    table.sort(rows,function(a,b) return a.id<b.id end)
    return rows
end
function placements.new(piece,base,scale,angle)
    serial+=1
    local id=string.format("p%08x-%08x",math.random(0,0x3fffffff),serial)
    local parts
    if piece.parts then
        parts={}
        for _,p in piece.parts do table.insert(parts,{x=p.x,y=p.y,w=p.w,h=p.h,colour=p.colour}) end
    end
    return {version=1,id=id,map=map,art=piece.id,name=piece.name,parts=parts,arch=piece.arch,media=piece.media,base=table.clone(base),scale=scale,angle=angle}
end
function placements.handleCount(r)
    local style=originalStyle(r)
    return if style then arch.count(style) elseif r.parts then #r.parts else 1
end
function placements.design(r)
    local parts
    if r.parts then
        parts={}
        for _,p in r.parts do local part=table.clone(p) part.asset=string.format("ink_%02d",p.colour) table.insert(parts,part) end
    end
    local m=r.base
    local style=originalStyle(r)
    local textureParts,sheet=arch.parts(style)
    return {id=r.art,name=r.name,parts=parts,arch=style,textureParts=textureParts,textureSheet=sheet,media=r.media,width=vector.magnitude(vector.create(m[1],m[2],m[3])),
        height=vector.magnitude(vector.create(m[9],m[10],m[11]))}
end
function placements.matrix(base,scale,angle,stretch)
    local m=table.clone(base)
    local x=vector.create(m[1],m[2],m[3])
    local z=vector.create(m[9],m[10],m[11])
    local w,h=vector.magnitude(x),vector.magnitude(z)
    local c,s=math.cos(math.rad(angle)),math.sin(math.rad(angle))
    local u,v=x/w,z/h
    x,z=(u*c+v*s)*w*scale*(stretch or 1),(v*c-u*s)*h*scale
    m[1],m[2],m[3],m[9],m[10],m[11]=x.x,x.y,x.z,z.x,z.y,z.z
    return m
end
local function write(before,after)
    local row=after or before
    if not map or row.map~=map or (after and not valid(after)) then return nil,"Invalid placement or map" end
    local path=folder..row.id..".json"
    local raw,why=reskate.files.read(path)
    if not raw and why~="not found" then return nil,why or "Cannot read placement" end
    if raw then
        local ok,disk=pcall(reskate.json.decode,raw)
        if not before or not ok or type(disk)~="table" or disk.id~=before.id or disk.revision~=before.revision then
            return nil,"Placement changed on disk. Reopen the map."
        end
    elseif before then return nil,"Placement no longer exists" end
    local ok,msg
    if after then
        local encoded,data=pcall(reskate.json.encode,after)
        if not encoded then return nil,"Could not encode placement" end
        ok,msg=reskate.files.write(path,data)
    else ok,msg=reskate.files.remove(path) end
    if ok then records[row.id]=after end
    return ok,msg
end
function placements.change(label,before,after)
    if after then after.revision=string.format("%08x-%08x",math.random(0,0x3fffffff),math.floor(reskate.time.now())%4294967296) end
    local ok,why=write(before,after)
    if not ok then return nil,why end
    table.insert(past,{label=label,before=before,after=after})
    if #past>24 then table.remove(past,1) end
    table.clear(future)
    return true
end
function placements.history(forward,apply)
    local src,dest=if forward then future else past,if forward then past else future
    local e=src[#src]
    if not apply or not e then return e and e.label end
    local before,after=if forward then e.before else e.after,if forward then e.after else e.before
    local ok,why=write(before,after)
    if not ok then return nil,why end
    table.remove(src) table.insert(dest,e)
    return true,after,(before or after).id
end
return placements
