-- Original stencil paths on a 32-unit artboard. Later parts paint or cut the earlier ones.
local stencils={categories={}}
local definitions={}
local function oval(cx,cy,rx,ry) return {cx=cx,cy=cy,rx=rx,ry=ry or rx} end
local function rect(x1,y1,x2,y2) return {x1,y1, x2,y1, x2,y2, x1,y2} end
local function cut(path) path.cut=true return path end
local function group(title,items)
    local names={title}
    for _,item in items do
        table.insert(names,item[1])
        definitions[item[1]]={paths=item,rows={}}
    end
    table.insert(stencils.categories,names)
end

group("Geometry",{
    {"Diamond",{16,1, 31,16, 16,31, 1,16}},
    {"Pentagon",{16,1, 31,12, 25,30, 7,30, 1,12}},
    {"Hexagon",{8,3, 24,3, 32,16, 24,29, 8,29, 0,16}},
    {"Octagon",{10,1, 22,1, 31,10, 31,22, 22,31, 10,31, 1,22, 1,10}},
    {"Trapezoid",{8,4, 24,4, 32,28, 0,28}},
    {"Parallelogram",{10,4, 32,4, 22,28, 0,28}},
    {"Cross",rect(11,1,21,31),rect(1,11,31,21)},
    {"Hourglass",{1,2, 31,2, 19,16, 31,30, 1,30, 13,16}},
})

group("Nature",{
    {"Heart",oval(9,10,8),oval(23,10,8),{1,11, 31,11, 29,17, 16,31, 3,17}},
    {"Leaf",{2,29, 3,18, 7,10, 16,5, 31,1, 28,15, 23,23, 16,28, 7,29},
        cut({4,28, 13,16, 25,8, 16,18})},
    {"Flower",oval(16,8,6,7),oval(24,13,7,6),oval(22,23,6,7),oval(10,23,6,7),
        oval(8,13,7,6),cut(oval(16,16,4))},
    {"Cactus",rect(12,6,19,31),oval(15.5,6,3.5,5),rect(4,12,9,20),oval(6.5,12,2.5,3),
        {4,17, 9,17, 11,20, 15,20, 15,25, 9,25, 5,22},
        {18,14, 23,14, 24,12, 24,7, 29,7, 29,14, 26,19, 18,20},oval(26.5,7,2.5,3)},
    {"Mushroom",{1,18, 2,12, 6,6, 12,2, 20,2, 26,6, 30,12, 31,18},
        {12,16, 20,16, 21,25, 23,30, 9,30, 11,25},
        cut(oval(9,12,2.5)),cut(oval(18,7,2)),cut(oval(24,13,2.5))},
    {"Pine",{16,0, 25,12, 21,12, 28,21, 23,21, 31,28, 1,28, 9,21, 4,21, 11,12, 7,12},rect(13,26,19,32)},
    {"Butterfly",oval(8,10,7,9),oval(24,10,7,9),oval(10,23,6,7),oval(22,23,6,7),oval(16,16,2.5,12),
        cut(oval(7,9,2.5,3)),cut(oval(25,9,2.5,3))},
    {"Paw",oval(5,12,3.5,5),oval(12,7,3.5,5),oval(20,7,3.5,5),oval(27,12,3.5,5),
        {5,25, 8,21, 12,16, 16,14, 20,16, 24,21, 27,25, 26,29, 22,30, 16,28, 10,30, 6,29}},
})

group("Weather",{
    {"Bolt",{17,0, 30,0, 21,12, 29,12, 8,32, 12,19, 3,19}},
    {"Cloud",oval(8,19,7,6),oval(14,14,8),oval(22,15,6),oval(26,20,5),rect(8,18,27,25)},
    {"Raindrop",{16,0, 25,14, 28,20, 26,26, 22,30, 16,31, 10,30, 6,26, 4,20, 7,14},
        cut({9,18, 10,23, 15,27, 10,26, 7,22})},
    {"Sun",oval(16,16,8), rect(14,0,18,6),rect(14,26,18,32),rect(0,14,6,18),rect(26,14,32,18),
        {3,5, 5,3, 10,8, 8,10},{22,8, 27,3, 29,5, 24,10},
        {3,27, 8,22, 10,24, 5,29},{22,24, 24,22, 29,27, 27,29}},
    {"Crescent",oval(16,16,14.5),cut(oval(22,11,12.5))},
    {"Snowflake",rect(14,1,18,31),{2,6, 30,23, 28,26, 0,9},{30,6, 32,9, 4,26, 2,23},
        {8,3, 16,8, 24,3, 24,7, 16,13, 8,7},{8,25, 16,19, 24,25, 24,29, 16,24, 8,29}},
    {"Flame",{16,0, 21,7, 21,14, 26,9, 30,18, 28,25, 22,30, 16,32, 8,29, 3,24, 2,17, 8,10, 9,16, 14,10},
        cut({16,17, 20,22, 21,26, 18,30, 14,30, 11,26, 12,23})},
    {"Wave",{0,26, 3,24, 6,18, 9,10, 15,5, 23,3, 31,6, 24,7, 20,10, 18,15, 19,21, 23,24, 28,23,
        32,19, 30,26, 26,29, 19,30, 12,27, 8,29, 0,30}},
})

group("Street",{
    {"Crown",{1,7, 9,14, 16,2, 23,14, 31,7, 27,24, 5,24},rect(5,27,27,30)},
    {"Spray can",rect(8,12,24,30),{8,12, 11,7, 21,7, 24,12},rect(13,2,20,6),
        cut(rect(8,16,24,18)),cut(rect(8,24,24,26))},
    {"Brick wall",rect(1,3,14,10),rect(17,3,31,10),rect(1,13,6,20),rect(9,13,23,20),rect(26,13,31,20),
        rect(1,23,14,30),rect(17,23,31,30)},
    {"Traffic cone",{14,2, 18,2, 26,26, 6,26},rect(2,27,30,31),
        cut(rect(8,12,24,15)),cut(rect(8,21,24,23))},
    {"Rail",{1,14, 30,3, 31,7, 2,18},rect(6,14,9,27),rect(24,7,27,21),rect(2,27,12,30),rect(21,21,30,24)},
    {"Stairs",{1,29, 1,22, 8,22, 8,16, 15,16, 15,10, 22,10, 22,4, 31,4, 31,29}},
    {"Kicker",{1,27, 28,5, 31,5, 31,28, 1,30},cut({12,25, 26,14, 26,24})},
    {"Helmet",oval(15,16,14,13),cut(rect(0,21,32,32)),rect(16,17,32,21),
        {7,20, 11,20, 15,27, 21,20, 25,20, 16,31, 13,31},
        cut({8,10, 13,6, 16,6, 10,13}),cut({16,11, 20,7, 23,8, 19,13})},
})

group("Objects",{
    {"Key",oval(9,10,8.5),{12,13, 16,10, 31,25, 28,29, 24,25, 21,28, 18,25, 21,22},cut(oval(8,9,3))},
    {"Camera",rect(1,9,31,28),{8,10, 11,4, 20,4, 23,10},cut(oval(16,18,6)),oval(16,18,3),cut(rect(25,12,29,15))},
    {"Cassette",rect(1,5,31,27),cut(rect(4,9,28,19)),oval(9,14,4),oval(23,14,4),cut(oval(9,14,1.5)),
        cut(oval(23,14,1.5)),cut({7,25, 9,21, 23,21, 25,25})},
    {"Vinyl",oval(16,16,15),cut(oval(16,16,5)),oval(16,16,2),
        cut({4,15, 5,10, 9,6, 14,4, 12,7, 9,9, 7,13}),cut({18,28, 23,25, 26,20, 29,18, 27,24, 23,28})},
    {"Boombox",rect(1,12,31,28),rect(7,5,25,13),cut(rect(10,8,22,12)),
        cut(oval(8,21,4)),cut(oval(24,21,4)),cut(rect(14,17,18,23)),{2,12, 16,1, 18,2, 6,12}},
    {"Padlock",oval(16,12,9,11),cut(oval(16,12,5,7)),rect(4,14,28,31),
        cut(oval(16,20,2.5)),cut(rect(14.5,20,17.5,27))},
    {"Bulb",oval(16,12,11),{7,16, 25,16, 20,25, 12,25},rect(12,27,20,31),
        cut({10,13, 14,16, 16,13, 18,16, 22,13, 18,21, 16,18, 14,21})},
    {"Paper plane",{0,13, 32,1, 24,30, 16,22, 10,29, 9,18},cut({10,18, 27,5, 14,20, 12,25})},
})

-- Keep the original grid for older exports. Detailed layers sample the same
-- paths on a finer grid, and only allocate the rows actually requested.
local function scanline(paths,y,size)
    local cells=table.create(size,0)
    local function span(left,right,ink)
        local a=math.max(1,math.ceil(left*size/32-.5)+1)
        local b=math.min(size,math.ceil(right*size/32-.5))
        for i=a,b do cells[i]=ink end
    end
    for i=2,#paths do
        local part=paths[i]
        local ink=if part.cut then 0 else 1
        if part.rx then
            local dy=(y-part.cy)/part.ry
            if math.abs(dy)<1 then
                local half=part.rx*math.sqrt(1-dy*dy)
                span(part.cx-half,part.cx+half,ink)
            end
        else
            local crossings={}
            local x1,y1=part[#part-1],part[#part]
            for j=1,#part,2 do
                local x2,y2=part[j],part[j+1]
                if (y1>y)~=(y2>y) then table.insert(crossings,x1+(y-y1)*(x2-x1)/(y2-y1)) end
                x1,y1=x2,y2
            end
            table.sort(crossings)
            for j=1,#crossings,2 do span(crossings[j],crossings[j+1],ink) end
        end
    end
    return string.char(table.unpack(cells))
end

function stencils.mask(name,u,v,detailed)
    local shape=definitions[name]
    if not shape then return false end
    local size=if detailed then 256 else 64
    local row=math.floor(v*size)
    local key=if detailed then row+64 else row
    if not shape.rows[key] then shape.rows[key]=scanline(shape.paths,(row+.5)*32/size,size) end
    return shape.rows[key]:byte(math.floor(u*size)+1)==1
end
return stencils
