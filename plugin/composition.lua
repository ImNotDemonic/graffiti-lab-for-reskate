local symbols=require("studio_symbols")
local lettering=require("lettering")
local wall=require("wall_art")
local imports=require("imports")
local M={inks=".123456789ABCDEFG", paintW=96,paintH=48}
local kinds={shape=true,text=true,paint=true,image=true}
local warps=setmetatable({},{__mode="k"})
M.deformations={"Arch","Baseline","Perspective"}
local function finite(n,lo,hi) return type(n)=="number" and n>=lo and n<=hi end
local function integer(n,lo,hi) return finite(n,lo,hi) and n%1==0 end
local function validGrid(g)
    return type(g)=="table" and integer(g.w,1,128) and integer(g.h,1,128) and type(g.pixels)=="string"
        and #g.pixels==g.w*g.h and not g.pixels:find("[^.1-9A-G]")
end
local shapeNames={}
for _,group in symbols.categories do for i=2,#group do shapeNames[group[i]]=true end end
function M.valid(p)
    if type(p)~="table" or p.version~=1 or type(p.id)~="string" or not p.id:match("^p%d+%-%d+$")
        or #p.id>45 or type(p.name)~="string" or #p.name>60 or not finite(p.aspect,1/16,16)
        or not integer(p.serial,0,2^40) or type(p.layers)~="table" then return false end
    local ids={}
    for i,l in p.layers do
        if not integer(i,1,#p.layers) or type(l)~="table" or not kinds[l.kind] or not integer(l.id,1,p.serial) or ids[l.id]
            or type(l.name)~="string" or #l.name>64 or not finite(l.x,-4,5) or not finite(l.y,-4,5)
            or not finite(l.w,.001,10) or not finite(l.h,.001,10) or not finite(l.angle,-360,360)
            or not integer(l.ink,1,16) or not integer(l.opacity,0,100) or (l.group and not integer(l.group,1,p.serial)) then return false end
        ids[l.id]=true
        if l.kind=="shape" and (not shapeNames[l.symbol] or (l.detailed~=nil and type(l.detailed)~="boolean")) then return false end
        if l.kind=="text" and (type(l.text)~="string" or #l.text>lettering.limit*4 or not utf8.len(l.text)
            or utf8.len(l.text)>lettering.limit or not table.find(symbols.styles,l.style)
            or (l.font~=nil and not table.find(lettering.fonts,l.font))
            or (l.natural~=nil and type(l.natural)~="boolean")
            or not integer(l.spacing,0,5) or not integer(l.align,0,2) or not finite(l.arch,-1,1)
            or (l.deform~=nil and not table.find(M.deformations,l.deform))) then return false end
        if l.kind=="paint" or l.kind=="image" then
            if not validGrid(l.grid) then return false end
            if l.kind=="paint" and (l.grid.w~=M.paintW or l.grid.h~=M.paintH) then return false end
        end
    end
    return true
end
function M.new()
    return {version=1,id=string.format("p%d-%d",math.floor(reskate.time.now()),math.random(1,999999999)),name="Untitled",aspect=2,serial=0,layers={}}
end
-- Past states share immutable layers and pixel strings. A pointer gesture replaces one layer once.
function M.edit(p)
    local n=table.clone(p) n.layers=table.clone(p.layers) return n
end
function M.add(p,kind,name)
    p.serial+=1
    local l={kind=kind,id=p.serial,name=name,x=.5,y=.5,w=.35,h=.35*p.aspect,angle=0,ink=3,opacity=100}
    if kind=="shape" then
        l.symbol=name
        l.detailed=true
        local ratio=symbols.aspect(name)
        l.h=math.min(.7,l.h/ratio) l.w=l.h*ratio/p.aspect
    elseif kind=="text" then
        l.text="Tag" l.font="Flow" l.style="Clean" l.align=1 l.spacing=0 l.arch=0 l.w=.84 l.h=.72 l.natural=true
    elseif kind=="paint" then
        l.w,l.h=1,1 l.grid={w=M.paintW,h=M.paintH,pixels=string.rep(".",M.paintW*M.paintH)}
    end
    table.insert(p.layers,l)
    return l
end
function M.dimensions(l,aspect)
    if l.kind=="text" and l.font and l.natural then
        local layout=lettering.layout(l)
        local ratio=layout.width/layout.height/aspect
        return math.min(l.w,l.h*ratio),math.min(l.h,l.w/ratio)
    end
    return l.w,l.h
end
function M.localPoint(l,aspect,x,y)
    local a=math.rad(l.angle)
    local w,h=M.dimensions(l,aspect)
    local dx,dy=(x-l.x)*aspect,y-l.y
    local u=(dx*math.cos(a)+dy*math.sin(a))/(w*aspect)
    local v=(-dx*math.sin(a)+dy*math.cos(a))/h
    return .5+(if l.flipX then -u else u),.5+(if l.flipY then -v else v)
end
function M.worldPoint(l,aspect,u,v)
    local a=math.rad(l.angle)
    local w,h=M.dimensions(l,aspect)
    local x=(u-.5)*w*aspect*(if l.flipX then -1 else 1)
    local y=(v-.5)*h*(if l.flipY then -1 else 1)
    return l.x+(x*math.cos(a)-y*math.sin(a))/aspect,l.y+x*math.sin(a)+y*math.cos(a)
end
local function mask(l,u,v)
    if u<0 or u>=1 or v<0 or v>=1 then return false end
    if l.kind=="text" then
        if l.arch~=0 then
            if not warps[l] then warps[l]=require("reshape").sampler({mode=l.deform or "Arch",amount=l.arch},1) end
            u,v=warps[l](u,v)
        end
        return if l.font then lettering.sample(l,u,v) else symbols.letter(l,u,v)
    end
    return false
end
local function sample(l,u,v)
    if u<0 or u>=1 or v<0 or v>=1 then return 0 end
    if l.kind=="shape" then
        local ink=symbols.shapeInk(l.symbol,u,v,l.outline,l.detailed)
        return if ink==1 then l.ink else ink
    end
    if l.grid then
        local g=l.grid
        local i=1+math.floor(v*g.h)*g.w+math.floor(u*g.w)
        return M.inks:find(g.pixels:sub(i,i),1,true)-1
    end
    local inside=mask(l,u,v)
    if l.outline and not inside then
        if mask(l,u-.024,v) or mask(l,u+.024,v) or mask(l,u,v-.045) or mask(l,u,v+.045) then return 2 end
    elseif inside then
        if l.outline and (not mask(l,u-.024,v) or not mask(l,u+.024,v) or not mask(l,u,v-.045) or not mask(l,u,v+.045)) then return 2 end
        return l.ink
    end
    return 0
end
local bayer={0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5}
function M.pick(p,x,y)
    for i=#p.layers,1,-1 do
        local l=p.layers[i]
        if not l.hidden and l.opacity>0 then
            local ink=sample(l,M.localPoint(l,p.aspect,x,y))
            if ink>0 then return i,ink end
        end
    end
end
local function raster(p,w,h)
    local grid=table.create(w*h,0)
    for _,l in p.layers do
        if l.hidden or l.opacity==0 then continue end
        local lx,ly,hx,hy=1,1,0,0
        for _,u in {0,1} do for _,v in {0,1} do
            local x,y=M.worldPoint(l,p.aspect,u,v)
            lx,ly,hx,hy=math.min(lx,x),math.min(ly,y),math.max(hx,x),math.max(hy,y)
        end end
        local u0,v0=M.localPoint(l,p.aspect,0,0)
        local ux,vx=M.localPoint(l,p.aspect,1/w,0)
        local uy,vy=M.localPoint(l,p.aspect,0,1/h)
        ux,vx,uy,vy=ux-u0,vx-v0,uy-u0,vy-v0
        local du,dv=0,0
        if l.kind=="text" and l.font then
            local layout=lettering.layout(l)
            local spanU,spanV=math.abs(ux)+math.abs(uy),math.abs(vx)+math.abs(vy)
            -- When a cell spans several font pixels its centre can miss an entire stem.
            if spanU*layout.width>1 then du=if layout.smooth then spanU*.27 else math.min(spanU*.25,.5/layout.width) end
            if spanV*layout.height>1 then dv=if layout.smooth then spanV*.27 else math.min(spanV*.25,.5/layout.height) end
        end
        for y=math.max(0,math.floor(ly*h)),math.min(h-1,math.floor(hy*h)) do
            for x=math.max(0,math.floor(lx*w)),math.min(w-1,math.floor(hx*w)) do
                if l.opacity*16<=bayer[(y%4)*4+x%4+1]*100 then continue end
                local u,v=u0+(x+.5)*ux+(y+.5)*uy,v0+(x+.5)*vx+(y+.5)*vy
                local ink=sample(l,u,v)
                if ink==0 and du>0 then ink=math.max(sample(l,u-du,v),sample(l,u+du,v)) end
                if ink==0 and dv>0 then ink=math.max(sample(l,u,v-dv),sample(l,u,v+dv)) end
                if ink>0 then grid[y*w+x+1]=ink end
            end
        end
    end
    return grid
end
function M.render(p,maxWidth,budget)
    local detailed=false
    for _,l in p.layers do
        if not l.hidden and ((l.kind=="shape" and l.detailed) or
            (l.kind=="text" and l.font and l.natural and lettering.layout(l).smooth)) then detailed=true break end
    end
    if not maxWidth then
        maxWidth=if detailed then 96 else 64
        for _,l in p.layers do
            if l.kind=="text" and l.font and not l.hidden then maxWidth=96 break end
        end
    end
    for _,size in {96,64,48,32,24,16,12,8} do
        if size>maxWidth then continue end
        local w=math.max(1,math.round(size*math.min(1,p.aspect)))
        local h=math.max(1,math.round(size/math.max(1,p.aspect)))
        -- GLART stores the physical aspect separately. Both grid axes can retain
        -- detail in a wide or tall word without distorting its wall dimensions.
        if detailed then w,h=size,size end
        local parts=wall.rectangles(raster(p,w,h),w,h)
        if parts and #parts>0 and #parts<=(budget or 256) then
            local rows={string.format("GLART1 %d %d %d 10000",w,h,math.round(p.aspect*10000))}
            for _,b in parts do table.insert(rows,string.format("%d %d %d %d %d",b.x,b.y,b.w,b.h,b.colour)) end
            local raw=table.concat(rows,"\n")
            return raw,imports.decode(raw)
        end
    end
    return nil,"No visible ink."
end
function M.stamp(pixels,ax,ay,bx,by,r,ink,opacity)
    local w,h=M.paintW,M.paintH
    ax,ay,bx,by=ax*w,ay*h,bx*w,by*h
    local dx,dy=bx-ax,by-ay
    local length=dx*dx+dy*dy
    for y=math.max(0,math.floor(math.min(ay,by)-r)),math.min(h-1,math.ceil(math.max(ay,by)+r)) do
        for x=math.max(0,math.floor(math.min(ax,bx)-r)),math.min(w-1,math.ceil(math.max(ax,bx)+r)) do
            local t=if length==0 then 0 else math.clamp(((x+.5-ax)*dx+(y+.5-ay)*dy)/length,0,1)
            if (x+.5-ax-t*dx)^2+(y+.5-ay-t*dy)^2<=r*r and opacity*16>bayer[(y%4)*4+x%4+1]*100 then
                pixels[y*w+x+1]=M.inks:sub(ink+1,ink+1)
            end
        end
    end
end
function M.key(s)
    local a,b=5381,7
    for i=1,#s do a=(a*33+s:byte(i))%4294967296 b=(b*131+s:byte(i))%4294967296 end
    return string.format("%08x%08x",a,b)
end
return M
