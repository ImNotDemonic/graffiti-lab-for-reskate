-- Strokes keep just the user's points. The same segment expansion drives preview, picking and wall rasterisation.
local pattern={modes={"Off","Mirror","Four-way","Radial mirror","Rotational"}}
local function whole(x,a,b) return type(x)=="number" and x%1==0 and x>=a and x<=b end
function pattern.validBrush(s)
    return s==nil or (type(s)=="table" and table.find(pattern.modes,s.mode)~=nil and whole(s.x,0,100) and whole(s.y,0,100)
        and whole(s.angle,0,359) and whole(s.sectors,2,8))
end
function pattern.validTile(t)
    return t==nil or (type(t)=="table" and whole(t.width,128,2048) and whole(t.height,64,1024) and whole(t.count,1,4))
end
function pattern.segments(stroke,tile,emit)
    local w,h=if tile then tile.width else 2048,if tile then tile.height else 1024
    local s=stroke.symmetry
    local mode=if s then s.mode else "Off"
    local ox,oy=if s then w*s.x/100 else 0,if s then h*s.y/100 else 0
    local angle=if s then math.rad(s.angle) else 0
    local radial=mode=="Radial mirror" or mode=="Rotational"
    local rotations=if radial then s.sectors elseif mode=="Four-way" then 2 else 1
    local mirrors=if mode=="Mirror" or mode=="Four-way" or mode=="Radial mirror" then 2 else 1
    local function segment(ax,ay,bx,by)
        local seen={}
        for n=0,rotations-1 do
            for flip=1,mirrors do
                local function point(x,y)
                    x,y=x-ox,y-oy
                    if flip==2 then
                        local c,d=math.cos(2*angle),math.sin(2*angle)
                        x,y=x*c+y*d,x*d-y*c
                    end
                    local a=2*math.pi*n/rotations
                    return ox+math.cos(a)*x-math.sin(a)*y,oy+math.sin(a)*x+math.cos(a)*y
                end
                local x1,y1=point(ax,ay)
                local x2,y2=point(bx,by)
                local dx,dy=x2-x1,y2-y1
                if tile then
                    x1,y1=x1%w,y1%h
                    dx,dy=(dx+w/2)%w-w/2,(dy+h/2)%h-h/2
                    x2,y2=x1+dx,y1+dy
                end
                local key=string.format("%.1f,%.1f,%.1f,%.1f",x1,y1,x2,y2)
                if seen[key] then continue end
                seen[key]=true
                local radius=stroke.size/2
                local wrap=if tile then 1 else 0
                for iy=-wrap,wrap do for ix=-wrap,wrap do
                    local a,b,c,d=x1+ix*w,y1+iy*h,x2+ix*w,y2+iy*h
                    if math.max(a,c)>=-radius and math.min(a,c)<=w+radius and math.max(b,d)>=-radius and math.min(b,d)<=h+radius then emit(a,b,c,d) end
                end end
            end
        end
    end
    local xy=stroke.xy
    if #xy==2 then segment(xy[1],xy[2],xy[1],xy[2]) end
    for i=3,#xy,2 do segment(xy[i-2],xy[i-1],xy[i],xy[i+1]) end
end
return pattern
