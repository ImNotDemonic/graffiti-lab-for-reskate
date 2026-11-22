local dock = require("dock")
local colourNames={"Chalk","Ink","Blaze","Sun","Acid","Cobalt","Pink","Chrome"}
local surface = require("surface")
local palette = require("blackbook").palette
local widths = {0.025, 0.04, 0.065}
local maxSamples = 6 -- Eight world queries per sample, below the host's 64-ray tick limit.

local function position(m)
    return vector.create(m[13], m[14], m[15])
end

local function normal(m)
    return vector.normalize(vector.create(m[5], m[6], m[7]))
end

local function brushHit(view, screen, pixel, focal, width)
    -- Invert ReSkate's vertical-FOV projector using its camera axes.
    local direction = view.forward + view.right * ((pixel.x - screen.x/2) / focal)
        - view.up * ((pixel.y - screen.y/2) / focal)
    return surface(reskate.world, {
        position = view.position, forward = vector.normalize(direction), right = view.right, up = view.up,
    }, width, width)
end

local function inPaintArea(x,y,width,height)
    return x>=0 and y>=0 and x<width and y<height
        and not dock.inside(x,y,28,158,99,660)
        and not dock.inside(x,y,width/2-424,999,848,51)
end

local function segment(first, last, width)
    local a, b, n = position(first), position(last), normal(last)
    local delta = b - a
    -- Never span a depth discontinuity or fold the brush across a corner.
    if vector.dot(normal(first), n) < 0.99 or math.abs(vector.dot(delta, n)) > width/4
        or vector.magnitude(delta) > width*2.25 then return nil end
    local along = delta - n*vector.dot(delta, n)
    local length = vector.magnitude(along)
    if length < width/5 then return nil, true end
    local tangent = along/length
    local x, y, z = tangent*(length+width), n*0.045, vector.cross(tangent, n)*width
    local p = (a+b)/2
    return {x.x,x.y,x.z,0, y.x,y.y,y.z,0, z.x,z.y,z.z,0, p.x,p.y,p.z,1}
end

return function(recordSample, undoMark, onBack, usage, eraseAt, saveState, checkpoint)
    local title=dock.editingScreen()
    local open, previousDown, latched, waitUp = false, false, false, true
    local screen, hover, lastPixel, lastHit, mark
    local colour, size, sampleCount, pathLength = 3, 2, 0, 0
    local keys, message = {}, ""
    local toolDown, erasing = false, false
    local eraseSize=2
    local function toolSize() return if erasing then eraseSize else size end
    local function setSize(index)
        index=math.clamp(index,1,#widths)
        if erasing then eraseSize=index else size=index end
    end

    local function finish()
        if mark then
            reskate.log(string.format("Paint stroke finished: %d samples, %.3f m travel",
                sampleCount, pathLength))
        end
        if mark or (erasing and lastPixel) then checkpoint() end
        lastHit, lastPixel, mark = nil, nil, nil
        sampleCount, pathLength = 0, 0
    end

    local function close()
        if not open then return end
        finish()
        open, latched, hover = false, false, nil
        reskate.ui.close()
    end

    local function add(hit)
        if not hit then lastHit = nil return end
        if erasing then
            eraseAt(hit,widths[eraseSize]*2)
            lastHit=hit
            return
        end
        local matrix = hit
        local connected = false
        if lastHit then
            local between, tooClose = segment(lastHit, hit, widths[size])
            if tooClose then return end
            if between then matrix, connected = between, true end
        end
        local asset=string.format("world/materials/decal/reskate_graffitilab/ink_%02d_dv",colour)
        mark=recordSample(mark,asset,matrix,colour)
        if connected then pathLength += vector.magnitude(position(hit)-position(lastHit)) end
        sampleCount += 1
        lastHit = hit
    end

    local function pressed(key)
        local down = reskate.input.key(key)
        local edge = down and not keys[key]
        keys[key] = down
        return edge
    end

    reskate.on("screen_closed", function(name)
        if name == title and open then
            finish()
            open, latched, hover = false, false, nil
            onBack()
        end
    end)
    reskate.on("draw", function(d)
        if not open then return end
        screen = d:size()
        local scale = math.min(screen.y/1080,screen.x/576)
        if scale <= 0 then return end
        local u=dock.draw(d)
        local mid=screen.x/scale/2
        u.rect(mid-109,12,218,34,"#0D0E10EB")
        d:circle(u.p(mid-97,29),4*scale,{colour=dock.blaze,fill=true})
        u.text(mid+4,19,if erasing then "WALL PAINT   /   ERASER" else "WALL PAINT   /   FREEHAND",14,dock.ink,"bold","centre")
        u.rect(28,158,99,660,"#0D0E10EB")
        u.rect(39,171,77,64,palette[colour])
        for i=1,8 do
            local x,y=39+(i-1)%2*40,250+math.floor((i-1)/2)*39
            u.rect(x,y,36,34,palette[i])
            if i==colour then u.border(x-2,y-2,40,38,dock.blaze) end
            u.text(x+30,y+12,tostring(i),12,if i==2 then dock.ink else dock.dark,"bold","right")
        end
        u.text(39,426,if erasing then "ERASE SIZE" else "PAINT SIZE",13,dock.muted,"bold")
        u.text(39,450,math.round(widths[toolSize()]*(if erasing then 4000 else 1000)).." mm",17,dock.ink,"bold")
        for i=1,#widths do
            local x=39+(i-1)*26
            u.rect(x,479,24,18,if i<=toolSize() then dock.blaze else "#45464A")
            if i==toolSize() then u.border(x-1,478,26,20,dock.ink) end
        end
        u.text(39,501,"[   /   ]",14,dock.muted,"bold")
        u.text(39,543,"FLOW",13,dock.muted,"bold")
        u.rect(35,562,85,32,if latched then dock.blaze else "#333437")
        u.text(39,566,if latched then "Toggle" else "Hold",18,dock.ink,"bold")
        local visible,total,why=usage()
        u.text(39,640,"VISIBLE",13,dock.muted,"bold")
        u.text(39,663,tostring(visible),19,dock.ink,"bold")
        for i,label in {"PAINT","ERASER"} do
            local y=708+(i-1)*46
            local selected=(i==2)==erasing
            u.rect(35,y,85,38,if selected then dock.blaze else "#333437")
            u.text(77,y+9,label,15,if selected then dock.dark else dock.ink,"bold","centre")
        end
        u.rect(mid-424,999,848,51,"#0D0E10EB")
        local ready,warning=saveState()
        local status=if warning then warning elseif not ready then "Loading saved wall paint…" elseif why and total>0 and visible==0 then "Paint recorded · waiting for the renderer" else message
        u.text(mid,1013,if status~="" then status elseif erasing then "Drag to erase wall paint      [ / ]   Size      E   Paint      Esc   Back"
            else "LMB   Spray     E   Eraser     [ / ]   Size     1–8   Colour     Space   Flow     Ctrl+Z   Undo",
            17,dock.ink,"bold","centre")
        local cursor=reskate.input.cursor()
        local pointer=if cursor then cursor.position else screen*0.5
        if not inPaintArea(pointer.x/scale,pointer.y/scale,u.width,u.height) then return end
        local radius=math.max(5,7*scale)
        local colourAtAim=dock.ink
        if hover and cursor then
            local centre=d:world_to_screen(position(hover))
            local edge=d:world_to_screen(position(hover)+vector.create(hover[1],hover[2],hover[3])*(if erasing then 2 else 0.5))
            if centre and edge then radius=math.max(radius,vector.magnitude(edge-centre)) end
            colourAtAim=if erasing then dock.ink else palette[colour]
            d:circle(pointer,2,{colour=colourAtAim,fill=true})
        else
            u.text(mid,61,if cursor then "Aim at a flat wall within 8 m" else "Move the mouse into the game to aim",17,dock.blaze,"bold","centre")
        end
        d:circle(pointer,radius,{colour="#171819",thickness=4})
        d:circle(pointer,radius,{colour=colourAtAim,thickness=2})
    end)

    local function tick()
        if not open or not screen or screen.y<=0 then return end
        local cursor, view = reskate.input.cursor(), reskate.camera.get()
        if not cursor or not view or not view.fov or view.fov<=1 or view.fov>=175 then
            finish()
            previousDown, latched, waitUp, hover = false, false, true, nil
            return
        end
        local pad=dock.buttons()
        if pad.b then
            if not keys.padBack then close() onBack() end
            keys.padBack=true
            return
        end
        keys.padBack=false
        if waitUp then
            if cursor.left then return end
            waitUp,toolDown = false,false
        end
        if pressed("E") then
            finish()
            erasing,latched,waitUp=not erasing,false,cursor.left
            if waitUp then return end
        end
        if pressed("Space") and not erasing then latched = not latched end
        local down = latched or cursor.left
        local released=previousDown and not down
        if released then finish() end
        previousDown = down
        if not down then
            if pressed("Z") and reskate.input.key(17) and not erasing and saveState() then message = undoMark() end
            if pressed("[") then setSize(toolSize()-1) end
            if pressed("]") then setSize(toolSize()+1) end
            for i=1,8 do if pressed(48+i) then colour=i end end
        end
        local pixel = cursor.position
        local scale = math.min(screen.y/1080,screen.x/576)
        local px,py=pixel.x/scale,pixel.y/scale
        local overTools=dock.inside(px,py,28,158,99,660)
        local click=cursor.left and not toolDown
        toolDown=cursor.left
        if click and overTools then
            for i=1,8 do
                if dock.inside(px,py,39+(i-1)%2*40,250+math.floor((i-1)/2)*39,36,34) then colour=i end
            end
            if dock.inside(px,py,39,473,78,30) then setSize(1+math.floor((px-39)/26)) end
            if not erasing and dock.inside(px,py,35,562,85,32) then latched=not latched end
            if dock.inside(px,py,35,708,85,38) or dock.inside(px,py,35,754,85,38) then
                finish()
                erasing,latched,message=py>=754,false,""
            end
            waitUp=true
        end
        if not inPaintArea(px,py,screen.x/scale,screen.y/scale) then
            hover, lastPixel, lastHit = nil, nil, nil
            return
        end
        local focal = screen.y/(2*math.tan(math.rad(view.fov)/2))
        local width = widths[toolSize()]
        if not down then
            -- The previous hit is sufficient for the release frame. Refresh hover next tick.
            if released then return end
            hover = brushHit(view,screen,pixel,focal,width)
            return
        end
        if not saveState() then return end
        message = ""
        local steps = 1
        if lastPixel and lastHit then
            local depth = vector.dot(position(lastHit)-view.position,view.forward)
            local spacing = math.max(2,width*focal/math.max(0.05,depth)*0.75)
            steps = math.max(1,math.ceil(vector.magnitude(pixel-lastPixel)/spacing))
            if steps>maxSamples then lastHit, lastPixel, steps = nil, nil, 1 end
        end
        local started=reskate.time.now()
        for i=1,steps do
            local sample = if lastPixel then lastPixel+(pixel-lastPixel)*(i/steps) else pixel
            hover = brushHit(view,screen,sample,focal,width)
            add(hover)
            if i<steps and reskate.time.now()-started>=8 then
                lastPixel=sample
                if not erasing then return hover,palette[colour] end
                return
            end
        end
        lastPixel = pixel
        if not erasing then return hover,palette[colour] end
    end

    return {
        can=function() return {index=colour,hex=palette[colour],name=colourNames[colour],mm=math.round(widths[size]*1000),
            size=size,widths=widths,palette=palette} end,
        setCan=function(index,brush)
            if index then colour=math.clamp(index,1,8) end
            if brush then size=math.clamp(brush,1,#widths) end
        end,
        open=function()
            if open then return end
            open, previousDown, latched, waitUp = true, false, false, true
            screen, hover, keys, message, toolDown, erasing = nil, nil, {}, "", true, false
            keys.padBack=true
            reskate.ui.open(title)
            reskate.log("Opened Wall Paint")
        end,
        close=close, tick=tick, active=function() return open end,
    }
end
