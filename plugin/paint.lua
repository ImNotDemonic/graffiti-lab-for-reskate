local surface = require("surface")
local palette = require("blackbook").palette
local title = "Wall Paint"
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
    }, reskate.level.current, width, width)
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

return function(canStamp, startMark, undoMark)
    local open, previousDown, latched, waitUp = false, false, false, true
    local screen, hover, lastPixel, lastHit, mark
    local colour, size, sampleCount, pathLength = 3, 2, 0, 0
    local keys, message = {}, ""
    local stopped = false

    local function finish()
        if mark then
            reskate.log(string.format("Paint stroke finished: %d decals, %d samples, %.3f m travel",
                #mark.handles, sampleCount, pathLength))
        end
        lastHit, lastPixel, mark = nil, nil, nil
        sampleCount, pathLength, stopped = 0, 0, false
    end

    local function close()
        if not open then return end
        finish()
        open, latched, hover = false, false, nil
        reskate.ui.close()
    end

    local function add(hit)
        if not hit then lastHit = nil return end
        local matrix = hit
        local connected = false
        if lastHit then
            local between, tooClose = segment(lastHit, hit, widths[size])
            if tooClose then return end
            if between then matrix, connected = between, true end
        end
        if not canStamp(mark) then
            stopped, message = true, "Paint limit reached. Undo a stroke to free space."
            return
        end
        local asset = string.format("world/materials/decal/reskate_graffitilab/ink_%02d_dv", colour)
        local handle, why = reskate.effects.decal(asset, matrix)
        if not handle then
            stopped, message = true, "Brush unavailable: " .. tostring(why)
            return
        end
        if mark then table.insert(mark.handles, handle) else mark = startMark(handle) end
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

    reskate.ui.screen(title, function() end, {panel=false})
    reskate.on("screen_closed", function(name)
        if name == title and open then
            finish()
            open, latched, hover = false, false, nil
        end
    end)
    reskate.on("draw", function(d)
        if not open then return end
        screen = d:size()
        local scale = screen.y/1080
        if scale <= 0 then return end
        local function p(x,y) return vector.create(x*scale,y*scale,0) end
        d:rect(p(32,168),p(292,356),{colour="#0D0E10F0",fill=true})
        d:text(p(48,181),"WALL PAINT",{font="heading",size=27,colour="#F2EFE9"})
        d:rect(p(49,226),p(81,258),{colour=palette[colour],fill=true})
        d:text(p(94,229),string.format("%d mm",math.round(widths[size]*1000)),{size=21,colour="#F2EFE9"})
        d:text(p(48,273),"1–8  Colour     [ / ]  Width",{size=16,colour="#C9C6BF"})
        d:text(p(48,313),if previousDown then "Painting" elseif hover then "Wall in range" else "Aim at a nearby wall",
            {font="bold",size=17,colour=if hover then "#F2EFE9" else "#FF936B"})
        local hint = if message~="" then message else "Drag to paint   /   Space toggles flow   /   Ctrl+Z undo   /   Esc close"
        d:text(p(screen.x/scale/2,1008),hint,{align="centre",font="bold",size=18,colour="#F2EFE9",shadow=true})
        if hover then
            local centre = d:world_to_screen(position(hover))
            if centre then
                local edge = d:world_to_screen(position(hover)+vector.create(hover[1],hover[2],hover[3])/2)
                if edge then d:circle(centre,math.clamp(vector.magnitude(edge-centre),3,75),{colour=palette[colour],thickness=2}) end
            end
        end
    end)

    local function tick()
        if not open or not screen or screen.y<=0 then return end
        local cursor, view = reskate.input.cursor(), reskate.camera.get()
        if not cursor or not view or not view.fov or view.fov<=1 or view.fov>=175 then
            finish()
            previousDown, latched, waitUp, hover = false, false, true, nil
            return
        end
        if waitUp then
            if cursor.left then return end
            waitUp = false
        end
        if pressed("Space") then latched = not latched end
        local down = latched or cursor.left
        if previousDown and not down then finish() end
        previousDown = down
        if not down then
            if pressed("Z") and reskate.input.key(17) then message = undoMark() end
            if pressed("[") then size = math.max(1,size-1) end
            if pressed("]") then size = math.min(#widths,size+1) end
            for i=1,8 do if pressed(tostring(i)) then colour=i end end
        end
        local pixel = cursor.position
        local scale = screen.y/1080
        local overTools = pixel.x>=32*scale and pixel.x<=292*scale and pixel.y>=168*scale and pixel.y<=356*scale
        if overTools or pixel.x<0 or pixel.y<0 or pixel.x>=screen.x or pixel.y>=screen.y then
            hover, lastPixel, lastHit = nil, nil, nil
            return
        end
        local focal = screen.y/(2*math.tan(math.rad(view.fov)/2))
        local width = widths[size]
        if not down then
            hover = brushHit(view,screen,pixel,focal,width)
            return
        end
        if stopped then return end
        message = ""
        local steps = 1
        if lastPixel and lastHit then
            local depth = vector.dot(position(lastHit)-view.position,view.forward)
            local spacing = math.max(2,width*focal/math.max(0.05,depth)*0.75)
            steps = math.max(1,math.ceil(vector.magnitude(pixel-lastPixel)/spacing))
            if steps>maxSamples then lastHit, lastPixel, steps = nil, nil, 1 end
        end
        for i=1,steps do
            local sample = if lastPixel then lastPixel+(pixel-lastPixel)*(i/steps) else pixel
            hover = brushHit(view,screen,sample,focal,width)
            add(hover)
            if stopped then break end
        end
        lastPixel = pixel
    end

    return {
        open=function()
            if open then return end
            open, previousDown, latched, waitUp = true, false, false, true
            screen, hover, keys, message = nil, nil, {}, ""
            reskate.ui.open(title)
            reskate.log("Opened Wall Paint")
        end,
        close=close, tick=tick, active=function() return open end,
        expiring=function(entry)
            if entry == mark then finish() latched, waitUp = false, true end
        end,
    }
end
