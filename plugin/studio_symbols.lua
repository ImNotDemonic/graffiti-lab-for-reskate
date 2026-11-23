-- Original geometric masks and five-column lettering for both preview and wall ink.
local stencils=require("studio_stencils")
local symbols={}
symbols.categories={
    {"Basics","Circle","Ellipse","Square","Rectangle","Rounded","Triangle","Line","Curve"},
    {"Signs","Star","Arrow","Chevron","Frame","Speech","Drip","Splatter"},
    {"Skate","Deck","Wheel","Quarterpipe","Truck"},
}
for _,group in stencils.categories do table.insert(symbols.categories,group) end
local abs,sqrt=math.abs,math.sqrt
local function disk(x,y,r) return x*x+y*y<=r*r end
function symbols.mask(name,u,v,detailed)
    if u<0 or v<0 or u>=1 or v>=1 then return false end
    local x,y=2*u-1,2*v-1
    if name=="Circle" or name=="Ellipse" then return disk(x,y,1)
    elseif name=="Square" or name=="Rectangle" then return true
    elseif name=="Rounded" then return disk(math.max(0,abs(x)-.68),math.max(0,abs(y)-.68),.32)
    elseif name=="Triangle" then return abs(x)<=v
    elseif name=="Line" then return abs(y)<.11
    elseif name=="Curve" then return abs(y-.9*x*x+.42)<.13
    elseif name=="Star" then
        local a=math.atan2(y,x)+math.pi/2
        local sector=((a+math.pi/5)%(2*math.pi/5))-math.pi/5
        local limit=.42*math.sin(math.pi/5)/(math.sin(abs(sector))+.42*math.sin(math.pi/5-abs(sector)))
        return x*x+y*y<=limit*limit
    elseif name=="Arrow" then return (u<.55 and abs(y)<.24) or (u>=.55 and abs(y)<(1-u)/.45)
    elseif name=="Chevron" then return abs(x-(.48-abs(y)))<.35
    elseif name=="Frame" then return math.max(abs(x),abs(y))>.78
    elseif name=="Speech" then return disk(x,(y+.2)*1.45,.94) or (u>.18 and u<.39 and v<1-(u-.18)*1.6 and v>.60)
    elseif name=="Drip" then return y<-.52 or disk(x+.48,math.max(0,y-.55)*1.4,.14) or disk(x-.22,math.max(0,y-.15)*1.3,.20)
    elseif name=="Splatter" then return disk(x,y,.46) or disk(x-.6,y+.45,.19) or disk(x+.54,y+.36,.13) or disk(x+.32,y-.59,.16)
    elseif name=="Deck" then return disk(math.max(0,abs(x)-.63),y*.37,.37)
    elseif name=="Wheel" then return disk(x,y,.96) and not disk(x,y,.34)
    elseif name=="Truck" then return (abs(y)<.16 and abs(x)<.9) or (abs(x)<.23 and y>.08 and y<.8) or (abs(x)>.65 and abs(y)<.5)
    elseif name=="Quarterpipe" then return y>.78 or (x>.12 and (x-.05)^2+(y+.84)^2>1.35)
    end
    return stencils.mask(name,u,v,detailed)
end
function symbols.aspect(name)
    return if name=="Rectangle" or name=="Ellipse" or name=="Deck" then 2 else 1
end
-- The preview and wall use the same outline and keep stencil holes transparent.
function symbols.shapeInk(name,u,v,outline,detailed)
    if u<0 or u>=1 or v<0 or v>=1 then return 0 end
    local inside=symbols.mask(name,u,v,detailed)
    if not outline then return if inside then 1 else 0 end
    local a=symbols.mask(name,u-.024,v,detailed)
    local b=symbols.mask(name,u+.024,v,detailed)
    local c=symbols.mask(name,u,v-.045,detailed)
    local d=symbols.mask(name,u,v+.045,detailed)
    if inside and a and b and c and d then return 1 end
    return if inside or a or b or c or d then 2 else 0
end
-- Each row is five bits. These masks are part of the artwork, independent of UI fonts.
local glyphs={
 A={14,17,17,31,17,17,17},B={30,17,17,30,17,17,30},C={14,17,16,16,16,17,14},
 D={28,18,17,17,17,18,28},E={31,16,16,30,16,16,31},F={31,16,16,30,16,16,16},
 G={14,17,16,23,17,17,15},H={17,17,17,31,17,17,17},I={14,4,4,4,4,4,14},
 J={7,2,2,2,2,18,12},K={17,18,20,24,20,18,17},L={16,16,16,16,16,16,31},
 M={17,27,21,21,17,17,17},N={17,25,25,21,19,19,17},O={14,17,17,17,17,17,14},
 P={30,17,17,30,16,16,16},Q={14,17,17,17,21,18,13},R={30,17,17,30,20,18,17},
 S={15,16,16,14,1,1,30},T={31,4,4,4,4,4,4},U={17,17,17,17,17,17,14},
 V={17,17,17,17,17,10,4},W={17,17,17,21,21,27,17},X={17,17,10,4,10,17,17},
 Y={17,17,10,4,4,4,4},Z={31,1,2,4,8,16,31},
 ["0"]={14,17,19,21,25,17,14},["1"]={4,12,4,4,4,4,14},["2"]={14,17,1,2,4,8,31},
 ["3"]={30,1,1,14,1,1,30},["4"]={2,6,10,18,31,2,2},["5"]={31,16,16,30,1,1,30},
 ["6"]={14,16,16,30,17,17,14},["7"]={31,1,2,4,8,8,8},["8"]={14,17,17,14,17,17,14},
 ["9"]={14,17,17,15,1,1,14},["!"]={4,4,4,4,4,0,4},["?"]={14,17,1,2,4,0,4},
 ["-"]={0,0,0,31,0,0,0},["."]={0,0,0,0,0,0,4},["'"]={4,4,0,0,0,0,0},
}
symbols.styles={"Clean","Block","Bubble","Stencil","Marker"}
function symbols.letter(layer,u,v)
    local text=layer.text
    local step=5+layer.spacing
    local actual=math.max(1,#text*step-layer.spacing)
    local span=math.max(actual,12)
    local offset=(span-actual)*layer.align/2
    local x=u*span-offset
    if layer.style=="Marker" then x-=(.5-v)*1.5 end
    local index=math.floor(x/step)+1
    local column=x-(index-1)*step
    local y=v*7
    if column<0 or column>=5 or y<0 or y>=7 or index<1 or index>#text then return false end
    local row=glyphs[text:sub(index,index)]
    if not row then return false end
    local col,ry=math.floor(column),math.floor(y)
    local function has(c) return c>=0 and c<5 and bit32.btest(row[ry+1],2^(4-c)) end
    if layer.style=="Stencil" and ry==3 and column>1.9 and column<2.6 then return false end
    if layer.style=="Bubble" and (column%1-.5)^2+(y%1-.5)^2>.42 then return false end
    return has(col) or (layer.style=="Block" and column%1<.38 and has(col-1))
end
return symbols
