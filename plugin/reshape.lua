-- The editable source is an ink grid. Every preview and export samples that same grid.
local shape={}
local wall=require("wall_art")
local imports=require("imports")
local media=require("media_format")
local digits=".123456789ABCDEFG"
local inks={}
for i=1,#digits do inks[digits:byte(i)]=i-1 end
shape.modes={"Arch","Bulge","Corners","Baseline","Perspective"}
local corners={0,0,1,0,1,1,0,1}

function shape.identity()
    return {mode="Arch",amount=0,corners=table.clone(corners)}
end
function shape.valid(settings)
    if type(settings)~="table" or not table.find(shape.modes,settings.mode) or type(settings.amount)~="number"
        or not (math.abs(settings.amount)<=1) or type(settings.corners)~="table" or #settings.corners~=8 then return false end
    for i=1,8 do
        local v=settings.corners[i]
        if type(v)~="number" or not (math.abs(v-corners[i])<=.241) then return false end
    end
    return true
end
local function gridOK(g)
    return type(g)=="table" and type(g.w)=="number" and g.w%1==0 and g.w>=1 and g.w<=128
        and type(g.h)=="number" and g.h%1==0 and g.h>=1 and g.h<=128 and type(g.pixels)=="string"
        and #g.pixels==g.w*g.h and not g.pixels:find("[^.1-9A-G]") and g.pixels:find("[^.]",1)~=nil
end
local function fromParts(parts,w,h)
    local pixels=table.create(w*h,".")
    for _,p in parts do
        local x=math.round((p.x+.5-p.w/2)*w)
        local y=math.round((p.y+.5-p.h/2)*h)
        local right=math.clamp(math.round((p.x+.5+p.w/2)*w),x+1,w)
        local bottom=math.clamp(math.round((p.y+.5+p.h/2)*h),y+1,h)
        local c=digits:sub(p.colour+1,p.colour+1)
        for row=y,bottom-1 do for col=x,right-1 do pixels[row*w+col+1]=c end end
    end
    return {w=w,h=h,pixels=table.concat(pixels)}
end
function shape.source(p)
    if p.reshape then return p.reshape.source,p.reshape.settings end
    local grids={}
    if p.sheet and not p.parts then
        if not p.id:match("^[%w_]+$") then return nil,"Unknown packaged artwork." end
        local g=reskate.package.read_json("art/reshape/"..p.id..".json")
        if not gridOK(g) then return nil,"The packaged artwork grid is unavailable." end
        grids[1]=g
    else
        for i,parts in p.frames or {p.parts} do
            local w,h
            local raw=if p.media then p.media.frames[i] else p.rawFrame
            if raw then w,h=raw:match("^GLART1 (%d+) (%d+)") end
            w=tonumber(w) or p.gridWidth or 64
            h=tonumber(h) or math.max(1,math.round(w/(p.aspect or 1)))
            grids[i]=fromParts(parts,w,h)
        end
    end
    if not grids[1] then return nil,"Choose artwork with visible ink." end
    return {aspect=p.aspect or 1,frameMs=if p.media then p.media.frameMs else 250,grids=grids},shape.identity()
end
local function edges(s,x)
    local a=s.amount
    local hump=4*x*(1-x)
    if s.mode=="Arch" then local shift=-.4*a*hump return shift,1+shift end
    if s.mode=="Bulge" then local shift=.38*a*hump return -shift,1+shift end
    if s.mode=="Baseline" then return 0,1+.4*a*math.sin(2*math.pi*x) end
    local shift=.36*a*(2*x-1)
    return -shift,1+shift
end
-- Projective square-to-quad with its inverse. Straight lines remain straight.
local function cornerMap(c)
    local x0,y0,x1,y1,x2,y2,x3,y3=table.unpack(c)
    local ax,ay,bx,by=x1-x2,y1-y2,x3-x2,y3-y2
    local dx,dy=x0-x1+x2-x3,y0-y1+y2-y3
    local det=ax*by-bx*ay
    local g,h=(dx*by-bx*dy)/det,(ax*dy-dx*ay)/det
    local a,b=x1*(1+g)-x0,x3*(1+h)-x0
    local d,e=y1*(1+g)-y0,y3*(1+h)-y0
    return function(x,y)
        local aa,bb,dd,ee=a-g*x,b-h*x,d-g*y,e-h*y
        local inv=aa*ee-bb*dd
        if math.abs(inv)<1e-9 then return -1,-1 end
        return ((x-x0)*ee-bb*(y-y0))/inv,(aa*(y-y0)-(x-x0)*dd)/inv
    end
end
function shape.handles(s)
    if s.mode=="Corners" then return s.corners end
    local x=if s.mode=="Perspective" then 1 elseif s.mode=="Baseline" then .25 else .5
    local top,bottom=edges(s,x)
    return {x,if s.mode=="Baseline" then bottom else top}
end
function shape.drag(s,index,x,y)
    local out=table.clone(s)
    if s.mode=="Corners" then
        out.corners=table.clone(s.corners)
        local i=2*index-1
        out.corners[i]=math.clamp(x,corners[i]-.24,corners[i]+.24)
        out.corners[i+1]=math.clamp(y,corners[i+1]-.24,corners[i+1]+.24)
    else
        local a=if s.mode=="Baseline" then (y-1)/.4 elseif s.mode=="Perspective" then -y/.36
            elseif s.mode=="Bulge" then -y/.38 else -y/.4
        out.amount=math.clamp(a,-1,1)
    end
    return out
end
function shape.bounds(s,aspect)
    local l,t,r,b=0,0,1,1
    if s.mode=="Corners" then
        l,t,r,b=math.huge,math.huge,-math.huge,-math.huge
        for i=1,8,2 do
            local x,y=s.corners[i],s.corners[i+1]
            l,t,r,b=math.min(l,x),math.min(t,y),math.max(r,x),math.max(b,y)
        end
    else
        t,b=math.huge,-math.huge
        for _,x in {0,.25,.5,.75,1} do
            local hi,lo=edges(s,x)
            t,b=math.min(t,hi),math.max(b,lo)
        end
    end
    -- Pad extreme proportions symmetrically to the portable artwork limits.
    local ratio=aspect*(r-l)/(b-t)
    if ratio>16 then local pad=((r-l)*aspect/16-(b-t))/2 t-=pad b+=pad
    elseif ratio<1/16 then local pad=((b-t)/(16*aspect)-(r-l))/2 l-=pad r+=pad end
    return {l=l,t=t,w=r-l,h=b-t,aspect=math.clamp(aspect*(r-l)/(b-t),1/16,16)}
end
-- Map a fitted preview coordinate back into the source using the reshape editor's geometry.
function shape.sampler(s,aspect)
    local box=shape.bounds(s,aspect)
    local inverse
    if s.mode=="Corners" then inverse=cornerMap(s.corners)
    elseif s.mode=="Perspective" then
        local lt,lb=edges(s,0) local rt,rb=edges(s,1)
        inverse=cornerMap({0,lt,1,rt,1,rb,0,lb})
    end
    return function(u,v)
        local x,y=box.l+u*box.w,box.t+v*box.h
        if inverse then return inverse(x,y) end
        local t,b=edges(s,x)
        return x,(y-t)/(b-t)
    end
end
function shape.render(source,s,index)
    local g=source.grids[index]
    local box=shape.bounds(s,source.aspect)
    local inverse=if s.mode=="Corners" then cornerMap(s.corners) else nil
    if s.mode=="Perspective" then
        local lTop,lBottom=edges(s,0)
        local rTop,rBottom=edges(s,1)
        inverse=cornerMap({0,lTop,1,rTop,1,rBottom,0,lBottom})
    end
    -- Eight-frame placements have a smaller overlay budget than static pieces.
    local budget=if #source.grids>1 then 128 else 256
    for _,size in {64,48,32,24,16,12,8} do
        local w=math.max(1,math.round(size*math.min(1,box.aspect)))
        local h=math.max(1,math.round(size/math.max(1,box.aspect)))
        local grid=table.create(w*h,0)
        for col=0,w-1 do
            local x=box.l+(col+.5)*box.w/w
            local top,bottom=edges(s,x)
            for row=0,h-1 do
                local y=box.t+(row+.5)*box.h/h
                local u,v=x,(y-top)/(bottom-top)
                if inverse then u,v=inverse(x,y) end
                if u>=0 and u<1 and v>=0 and v<1 then
                    grid[row*w+col+1]=inks[g.pixels:byte(math.floor(v*g.h)*g.w+math.floor(u*g.w)+1)]
                end
            end
        end
        local rects=wall.rectangles(grid,w,h)
        if rects and #rects>0 and #rects<=budget then
            local lines={string.format("GLART1 %d %d %d 10000",w,h,math.round(box.aspect*10000))}
            for _,p in rects do table.insert(lines,string.format("%d %d %d %d %d",p.x,p.y,p.w,p.h,p.colour)) end
            local raw=table.concat(lines,"\n")
            return raw,imports.decode(raw)
        end
    end
    return nil,"This shape has no visible ink at wall resolution."
end
function shape.read(raw)
    if #raw>240000 then return nil,"Reshaped artwork is too large." end
    local ok,doc=pcall(reskate.json.decode,raw)
    if not ok or type(doc)~="table" or doc.version~=1 or not shape.valid(doc.settings) then return nil,"Damaged reshape settings." end
    local src=doc.source
    if type(src)~="table" or type(src.grids)~="table" or #src.grids<1 or #src.grids>8
        or type(src.aspect)~="number" or not (src.aspect>=1/16 and src.aspect<=16) then return nil,"Damaged reshape source." end
    for i=1,#src.grids do if not gridOK(src.grids[i]) then return nil,"Damaged source frame." end end
    if not media.validate(doc.asset,imports.decode) or #src.grids~=#doc.asset.frames or src.frameMs~=doc.asset.frameMs then
        return nil,"Damaged reshaped frames."
    end
    doc.asset=media.visual(doc.asset)
    return doc
end
function shape.save(name,source,settings,frames)
    local stem=name:gsub("[^%w _%-]",""):match("^%s*(.-)%s*$"):sub(1,54)
    if stem=="" then return nil,"Enter a name for this copy." end
    local files,why=reskate.files.list("imports")
    if not files and why~="not found" then return nil,why end
    local taken={}
    for _,file in files or {} do taken[file:lower()]=true end
    local number,title=1,stem
    while taken[title:lower()..".glshape"] do number+=1 title=stem.." "..number end
    local file=title..".glshape"
    local doc={version=1,source=source,settings=settings,asset={kind="ink",version=1,frameMs=source.frameMs,frames=frames}}
    local ok,data=pcall(reskate.json.encode,doc)
    if not ok then return nil,"Could not encode the reshaped copy." end
    local path="imports/"..file
    local existing,reason=reskate.files.read(path)
    if existing or reason~="not found" then return nil,reason or "Copy name is already in use." end
    local written,msg=reskate.files.write(path,data)
    if not written then return nil,msg end
    return file
end
return shape
