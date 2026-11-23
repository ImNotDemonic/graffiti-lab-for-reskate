-- Screen-space spans support rotated silhouettes, holes and outlines with the
-- existing overlay rectangles. Wall exports keep their separate decal budget.
local symbols=require("studio_symbols")
local M={}
local cache,order={},{}

function M.bounds(ratio,angle)
    local a=math.rad(angle)
    local c,s=math.cos(a),math.sin(a)
    return math.abs(c)*ratio+math.abs(s),math.abs(s)*ratio+math.abs(c),c,s
end

local function compile(name,ratio,angle,flipX,flipY,outline,size,limit)
    local bw,bh,c,s=M.bounds(ratio,angle)
    local w=math.max(1,math.round(size*math.min(1,bw/bh)))
    local h=math.max(1,math.round(size*math.min(1,bh/bw)))
    local ux,vx=bw*c/(w*ratio),-bw*s/w
    local uy,vy=bh*s/(h*ratio),bh*c/h
    if flipX then ux,uy=-ux,-uy end
    if flipY then vx,vy=-vx,-vy end
    local function ink(x,y)
        local u=.5+(x-w*.5)*ux+(y-h*.5)*uy
        local v=.5+(x-w*.5)*vx+(y-h*.5)*vy
        return symbols.shapeInk(name,u,v,outline,true)
    end
    local function scan(y)
        local row=table.create(w+2,0)
        if y>=0 and y<h then
            for x=0,w-1 do row[x+2]=ink(x+.5,y+.5) end
        end
        return row
    end
    local above,row,below=scan(-1),scan(0),scan(1)
    local parts,previous={},{}
    for y=0,h-1 do
        local current={}
        local start,last=0,0
        for x=0,w do
            local code=0
            if x<w then
                local i=x+2
                local centre=row[i]
                code=centre*4
                if centre~=row[i-1] or centre~=row[i+1] or centre~=above[i] or centre~=below[i] then
                    local fill,border=0,0
                    for _,dy in {.25,.75} do for _,dx in {.25,.75} do
                        local k=ink(x+dx,y+dy)
                        if k==1 then fill+=1 elseif k==2 then border+=1 end
                    end end
                    local alpha=fill+border
                    code=if alpha==0 then 0 elseif border>fill then 4+alpha else alpha
                end
            end
            if code~=last then
                if last~=0 then
                    local key=(last*(w+1)+start)*(w+1)+x
                    local p=previous[key]
                    if p then p.bottom=y+1
                    else
                        if #parts>=limit then return end
                        p={left=start,right=x,top=y,bottom=y+1,code=last}
                        table.insert(parts,p)
                    end
                    current[key]=p
                end
                start,last=x,code
            end
        end
        previous=current
        above,row,below=row,below,scan(y+2)
    end
    return {parts=parts,w=w,h=h}
end

function M.get(name,ratio,angle,flipX,flipY,outline,limit)
    local key=table.concat({name,tostring(ratio),tostring(angle),if flipX then "x" else "",
        if flipY then "y" else "",if outline then "o" else "",tostring(limit)},"/")
    if cache[key] then return cache[key] end
    local sizes=if limit<=180 then {64,48,32,24,16,8} else {192,128,96,64,48,32,16,8}
    for _,size in sizes do
        local shape=compile(name,ratio,angle,flipX,flipY,outline,size,limit)
        if shape then
            if #order>=80 then cache[table.remove(order,1)]=nil end
            table.insert(order,key) cache[key]=shape
            return shape
        end
    end
end

function M.draw(u,shape,x,y,w,h,fill,outline,opacity,clip)
    local colours={}
    for code=1,8 do
        local alpha=math.round(((code-1)%4+1)*opacity*255/400)
        colours[code]=(if code<=4 then fill else outline)..string.format("%02X",alpha)
    end
    for _,p in shape.parts do
        local a,b=x+w*p.left/shape.w,y+h*p.top/shape.h
        local c,d=x+w*p.right/shape.w,y+h*p.bottom/shape.h
        if clip then
            a,b=math.max(a,clip.x),math.max(b,clip.y)
            c,d=math.min(c,clip.x+clip.w),math.min(d,clip.y+clip.h)
        end
        if c>a and d>b then u.rect(a,b,c-a,d-b,colours[p.code]) end
    end
end
return M
