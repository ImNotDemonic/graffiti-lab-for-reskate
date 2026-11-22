-- Rasterise once per selection. Flat, non-overlapping rectangles preserve stroke
-- order and keep translucent previews from getting darker at intersections.
local art = {width = 1.0, height = 0.5, maxParts = 256}
local book = require("blackbook")
local pattern=require("pattern")

local function paint(grid, w, h, ax, ay, bx, by, radius, colour)
    local dx, dy = bx-ax, by-ay
    local length2 = dx*dx + dy*dy
    local y0 = math.max(0, math.ceil(math.min(ay,by)-radius-0.5))
    local y1 = math.min(h-1, math.floor(math.max(ay,by)+radius-0.5))
    for y=y0,y1 do
        local py = y+0.5
        local first, last = 0, 1
        if dy ~= 0 then
            local a,b = (py-radius-ay)/dy,(py+radius-ay)/dy
            first,last = math.clamp(math.min(a,b),0,1),math.clamp(math.max(a,b),0,1)
        end
        local xa,xb = ax+first*dx,ax+last*dx
        local x0 = math.max(0,math.ceil(math.min(xa,xb)-radius-0.5))
        local x1 = math.min(w-1,math.floor(math.max(xa,xb)+radius-0.5))
        for x=x0,x1 do
            local px=x+0.5
            local t=if length2==0 then 0 else math.clamp(((px-ax)*dx+(py-ay)*dy)/length2,0,1)
            if (px-ax-t*dx)^2 + (py-ay-t*dy)^2 <= radius*radius then grid[y*w+x+1]=colour end
        end
    end
end

local function raster(doc,w)
    local h=w/2
    local grid=table.create(w*h,0)
    local tile=doc.tile
    local count=if tile then tile.count else 1
    local tileW,tileH=if tile then tile.width else book.width,if tile then tile.height else book.height
    local cellW,cellH=w/count,h/count
    for _,stroke in doc.strokes do
        local radius=math.max(0.72,stroke.size*math.min(cellW/tileW,cellH/tileH)/2)
        pattern.segments(stroke,tile,function(ax,ay,bx,by)
            for j=0,count-1 do for i=0,count-1 do
                paint(grid,w,h,(i+ax/tileW)*cellW,(j+ay/tileH)*cellH,(i+bx/tileW)*cellW,(j+by/tileH)*cellH,radius,stroke.colour)
            end end
        end)
    end
    return grid
end

function art.rectangles(grid,w,h)
    local parts,previous={},{}
    for y=0,h-1 do
        local current={}
        local x=0
        while x<w do
            local first,c=x,grid[y*w+x+1]
            repeat x+=1 until x==w or grid[y*w+x+1]~=c
            if c~=0 then
                local key=(c*(w+1)+first)*(w+1)+x
                local part=previous[key]
                if part then
                    part.h+=1
                else
                    if #parts==art.maxParts then return nil end
                    part={x=first,y=y,w=x-first,h=1,colour=c}
                    table.insert(parts,part)
                end
                current[key]=part
            end
        end
        previous=current
    end
    return parts
end

function art.compile(doc, maximumWidth)
    if #doc.strokes==0 then return nil,"Draw and save at least one stroke first." end
    for _,w in {128,64,32,16} do
        if maximumWidth and w>maximumWidth then continue end
        local parts=art.rectangles(raster(doc,w),w,w/2)
        if parts then
            for _,p in parts do
                p.x=(p.x+p.w/2)/w-0.5
                p.y=(p.y+p.h/2)/(w/2)-0.5
                p.w/=w
                p.h/=(w/2)
                p.asset=string.format("ink_%02d",p.colour)
            end
            return parts,w
        end
    end
    error("16 by 8 pixels always fit the rectangle budget")
end

function art.transform(m,p)
    local t=table.clone(m)
    for i=1,3 do
        t[12+i]=m[12+i]+p.x*m[i]+p.y*m[8+i]
        t[i]=m[i]*p.w
        t[8+i]=m[8+i]*p.h
    end
    return t
end

return art
