-- A native strip keeps the original RGBA texture. The portable ink frame stays
-- in the save so other artwork, gallery clients and older builds can read it.
local arch={}
local index
local grids={}
local abs=math.abs

local function entries()
    if not index then index=reskate.package.read_json("art/arch/index.json") or {} end
    return index
end
function arch.valid(style)
    if type(style)~="table" or type(style.id)~="string" or type(style.amount)~="number"
        or not (abs(style.amount)<=1) then return false end
    local entry=entries()[style.id]
    return type(entry)=="table" and type(entry.anchors)=="table" and entry.count~=nil
end
function arch.identify(source,settings)
    if settings.mode~="Arch" or #source.grids~=1 then return end
    local g=source.grids[1]
    for id,entry in entries() do
        if type(id)~="string" or type(entry)~="table" or not entry.anchors then continue end
        if not grids[id] then grids[id]=reskate.package.read_json("art/reshape/"..id..".json") or {} end
        local ref=grids[id]
        if ref.w==g.w and ref.h==g.h and ref.pixels==g.pixels then
            return {id=id,amount=settings.amount}
        end
    end
end
function arch.parts(style)
    if not arch.valid(style) then return end
    local spec=entries()[style.id]
    local bank=1
    for i,a in spec.anchors do
        if abs(a-style.amount)<abs(spec.anchors[bank]-style.amount) then bank=i end
    end
    local parts={}
    local top=math.min(0,-.4*style.amount)
    local height=1+.4*abs(style.amount)
    for i=0,spec.count-1 do
        local x=(i+.5)/spec.count
        local y=.5-1.6*style.amount*x*(1-x)
        parts[i+1]={x=x-.5,y=(y-top)/height-.5,w=1/spec.count,h=(1+2*spec.pad)/height,
            asset=string.format("arch_%s_%d_%d",style.id,bank-1,i)}
    end
    return parts,string.format("art/arch/%s_%d.png",style.id,bank-1)
end
function arch.count(style) return entries()[style.id].count end
function arch.draw(d,u,parts,sheet,x,y,w,h)
    for i,p in parts do
        local l=x+(p.x+.5-p.w/2)*w
        local t=y+(p.y+.5-p.h/2)*h
        d:image(sheet,u.p(l,t),u.p(l+p.w*w,t+p.h*h),{uv={(i-1)/#parts,0,i/#parts,1}})
    end
end
return arch
