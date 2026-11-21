local book = require("blackbook")
local title = "Graffiti Lab Studio"
local ink, muted, blaze, panel = "#F2EFE9", "#B5B2AC", "#FF5A1F", "#0D0E10F5"
local canvas = {672, 252, 1152, 576}
local perPage = 4

return function(onPlace)
    local mode, doc, file, original = nil, book.new(), nil, nil
    local dirty, rename, pending = false, nil, nil
    local colour, width, redo, stroke = 3, 28, {}, nil
    local tool, lineStart = "Marker", nil
    local files, cards, page = {}, {}, 1
    local note, targets, held = "", {}, {}
    local scale, left, top = 1, 0, 0

    local function save()
        local id, raw = book.save(doc, file, original)
        if not id then note = "Save failed: " .. tostring(raw) return false end
        file, original, dirty = id, raw, false
        note = "Saved to Blackbook"
        reskate.log(string.format("Blackbook saved %s (%d strokes, %d points)", id, #doc.strokes, book.pointCount(doc)))
        return true
    end

    local function gallery(number)
        mode, stroke, lineStart, rename, cards, note = "gallery", nil, nil, nil, {}, ""
        local entries, why = book.list()
        files = entries or {}
        if not entries then note = "Cannot read Blackbook: " .. tostring(why) end
        page = math.clamp(number, 1, math.max(1, math.ceil(#files / perPage)))
        for i = (page - 1) * perPage + 1, math.min(page * perPage, #files) do
            local drawing, raw = book.read(files[i])
            table.insert(cards, {file = files[i], doc = drawing, raw = raw})
        end
    end

    local function edit(card)
        if card and not card.doc then note = "This drawing could not be opened." return end
        local function replace()
            doc = if card then card.doc else book.new()
            file = if card then card.file else nil
            original = if card then card.raw else nil
            dirty, redo, stroke, rename, note, mode = false, {}, nil, nil, "", "editor"
            if card then reskate.log(string.format("Blackbook opened %s (%d strokes, %d points)", file, #doc.strokes, book.pointCount(doc))) end
        end
        if dirty and card and card.file == file then mode = "editor" return end
        if dirty then pending = replace else replace() end
    end

    local function undo()
        local s = table.remove(doc.strokes)
        if s then table.insert(redo, s) dirty, note = true, "" end
    end
    local function redoStroke()
        local s = table.remove(redo)
        if s then table.insert(doc.strokes, s) dirty, note = true, "" end
    end
    local function finishName()
        local name = rename:match("^%s*(.-)%s*$")
        if name ~= "" and name ~= doc.name then doc.name, dirty = name, true end
        rename = nil
    end
    local function nameField()
        if rename then finishName() else reskate.input.text(true) rename = "" end
    end
    local function close()
        if mode then
            mode, stroke, lineStart, pending, rename = nil, nil, nil, nil, nil
            reskate.ui.close()
        end
    end
    local function open(which)
        if not mode then reskate.ui.open(title) end
        pending, rename, stroke, lineStart, held = nil, nil, nil, nil, {mouse = true}
        if which == "gallery" then gallery(1) else mode, note = "editor", "" end
        reskate.log("Opened " .. (if which == "gallery" then "Blackbook" else "Custom Editor"))
    end
    reskate.ui.screen(title, function() end, {panel = false})
    reskate.on("screen_closed", function(name)
        if name == title then mode, stroke, rename, pending = nil, nil, nil, nil end
    end)

    reskate.on("draw", function(d)
        if not mode then return end
        local screen = d:size()
        scale = math.min(screen.x / 1920, screen.y / 1080)
        if scale <= 0 then return end
        left, top = (screen.x - 1920 * scale) / 2, (screen.y - 1080 * scale) / 2
        local function p(x, y) return vector.create(left + x * scale, top + y * scale, 0) end
        local function rect(x, y, w, h, c)
            d:rect(p(x,y), p(x+w,y+h), {colour=c, fill=true})
        end
        local function label(x, y, value, font, size, c)
            d:text(p(x,y), value, {font=font, size=size, colour=c or ink, shadow=false})
        end
        targets = {}
        local function target(x,y,w,h,run)
            table.insert(targets, {x=x,y=y,w=w,h=h,run=run})
        end
        local function button(x,y,w,h,value,run,primary)
            rect(x,y,w,h,if primary then blaze else "#26272A")
            label(x+13,y+(h-24)/2,value,"bold",19,if primary then "#101113" else ink)
            target(x,y,w,h,run)
        end
        local function picture(drawing,x,y,w)
            local zoom = w/book.width
            for _, s in drawing.strokes do
                local xy, c, diameter = s.xy, book.palette[s.colour], s.size * zoom
                local style = {colour=c, thickness=math.max(0.5, diameter * scale * 1080 / screen.y)}
                local prev = p(x+xy[1]*zoom,y+xy[2]*zoom)
                d:circle(prev, math.max(0.5,diameter*scale/2), {colour=c,fill=true})
                for j=3,#xy,2 do
                    local nextPoint = p(x+xy[j]*zoom,y+xy[j+1]*zoom)
                    d:line(prev,nextPoint,style)
                    prev = nextPoint
                end
                if #xy > 2 then d:circle(prev,math.max(0.5,diameter*scale/2),{colour=c,fill=true}) end
            end
        end
        d:rect(vector.zero,screen,{colour=if mode == "editor" then "#080809CC" else "#08080960",fill=true})
        rect(0,0,576,1080,panel)
        label(48,45,"GRAFFITI LAB  /  BLACKBOOK","bold",16,muted)
        label(48,78,if mode == "editor" then "CUSTOM EDITOR" else "SAVED GALLERY","title_large",52)
        d:game_image("brush_bar",p(47,144),p(210,154),{colour=blaze,fit="shape"})
        if mode == "editor" then
            label(48,203,"TOOL","bold",16,muted)
            for i, name in {"Marker","Line"} do
                button(48+(i-1)*246,238,234,60,string.upper(name),function()
                    tool, lineStart, note = name, nil, ""
                end,tool == name)
            end
            label(48,339,"BRUSH SIZE","bold",16,muted)
            button(48,375,64,52,"-",function() width=math.max(4,width-4) end)
            label(136,384,tostring(width).." px","heading",26)
            button(464,375,64,52,"+",function() width=math.min(64,width+4) end)
            label(48,471,"PALETTE","bold",16,muted)
            for i,c in book.palette do
                local x,y=48+(i-1)%8*60,512+math.floor((i-1)/8)*48
                if i == colour then rect(x-3,y-3,60,44,blaze) end
                rect(x,y,54,38,"#101113")
                rect(x+3,y+3,48,32,c)
                target(x,y,54,38,function() colour=i end)
            end
            button(48,666,232,54,"Undo",undo)
            button(296,666,232,54,"Redo",redoStroke)
            button(48,758,480,54,if rename then "Keep name   /   Enter" else "Rename drawing",nameField)
            button(48,831,480,58,"Save to Blackbook   /   Ctrl+S",function()
                if rename then finishName() end
                save()
            end,true)
            button(48,913,480,54,"Open Blackbook",function() if rename then finishName() end gallery(1) end)
            label(48,1004,"Esc   Close","body",18,muted)
            label(672,186,if rename then (if rename == "" then "Type a new name…" else rename .. "|") else doc.name,"heading",38)
            label(672,227,"2048 × 1024   /   TRANSPARENT","bold",15,muted)
            d:image("art/checker.png",p(672,252),p(1824,828))
            picture(doc,672,252,1152)
            if lineStart then
                d:circle(p(672+lineStart[1]*1152/book.width,252+lineStart[2]*576/book.height),
                    5*scale,{colour=book.palette[colour],fill=false})
            end
            label(672,854,string.format("%d strokes    /    %d of %d points",#doc.strokes,book.pointCount(doc),book.maxPoints),"body",20,muted)
            label(672,900,if note ~= "" then note elseif lineStart then "Click the end of the line."
                elseif tool == "Line" then "Click two points to draw a line." elseif dirty then "Unsaved changes" else "","bold",22)
        else
            label(48,199,"DESIGNS   /   "..#files,"bold",18,muted)
            for i,card in cards do
                local x,y=48+(i-1)%2*246,248+math.floor((i-1)/2)*190
                rect(x,y,234,164,"#26272A")
                d:image("art/checker.png",p(x,y),p(x+234,y+117))
                if card.doc then picture(card.doc,x,y,234) end
                local name = if card.doc then card.doc.name else "Unreadable drawing"
                label(x+8,y+126,if #name>18 then name:sub(1,17).."…" else name,"bold",18)
                target(x,y,234,160,function() edit(card) end)
                if card.doc then
                    button(x,y+161,234,28,"Place on wall",function()
                        local ok,why = onPlace(card.file,card.doc)
                        if not ok then note = why end
                    end)
                end
            end
            if #files == 0 then label(48,274,"Your Blackbook is empty.","heading",28) end
            if #files > perPage then
                button(48,642,104,48,"Back",function() gallery(page-1) end)
                label(188,652,string.format("%d / %d",page,math.ceil(#files/perPage)),"body",20)
                button(424,642,104,48,"Next",function() gallery(page+1) end)
            end
            label(48,726,if #cards > 0 then "Click a drawing to edit it." else "Create a drawing to start your collection.","body",19,muted)
            button(48,805,480,58,"New drawing",function() edit(nil) end,true)
            button(48,885,480,54,"Return to editor",function() mode,note="editor","" end)
            label(48,958,note,"body",17)
            label(48,1004,"Esc   Close","body",18,muted)
        end
        if pending then
            table.clear(targets)
            rect(40,616,496,372,"#18191C")
            label(58,642,"Keep your changes?","heading",27)
            button(58,710,452,54,"Save and continue",function()
                if save() then local nextDoc=pending pending=nil nextDoc() else pending=nil end
            end,true)
            button(58,782,452,54,"Discard changes",function() local nextDoc=pending pending=nil nextDoc() end)
            button(58,854,452,54,"Cancel",function() pending=nil end)
        end
    end)

    reskate.on("tick", function()
        if not mode then return end
        local cursor = reskate.input.cursor()
        local down = cursor ~= nil and cursor.left
        local click = down and not held.mouse
        held.mouse = down
        local function key(code)
            local value=reskate.input.key(code)
            local pressed=value and not held[code]
            held[code]=value
            return pressed
        end
        if rename then
            local typed=reskate.input.text(true):gsub("[^ -~]","")
            rename=(rename..typed):sub(1,32)
            if key("Backspace") then rename=rename:sub(1,-2) end
            if key("Enter") then finishName() elseif key("Escape") then rename=nil end
        elseif mode == "editor" and not pending then
            local saveKey, undoKey, redoKey = key("S"),key("Z"),key("Y")
            if reskate.input.key(17) then
                if saveKey then save() elseif undoKey then undo() elseif redoKey then redoStroke() end
            end
        end
        if not down then stroke = nil return end
        if not cursor or scale <= 0 then return end
        local x,y = (cursor.position.x-left)/scale,(cursor.position.y-top)/scale
        if click then
            for _,t in targets do
                if x>=t.x and x<t.x+t.w and y>=t.y and y<t.y+t.h then
                    stroke=nil
                    t.run()
                    return
                end
            end
        end
        if mode ~= "editor" or pending or rename then return end
        local cx,cy,w,h=unpack(canvas)
        if x<cx or x>=cx+w or y<cy or y>=cy+h then stroke=nil return end
        if not stroke and not click then return end
        local margin = width/2
        local px=math.round(math.clamp((x-cx)/w*book.width,margin,book.width-margin))
        local py=math.round(math.clamp((y-cy)/h*book.height,margin,book.height-margin))
        local needed = if tool == "Line" then 2 else 1
        if book.pointCount(doc)+needed>book.maxPoints then note="Point limit reached. Undo a stroke to continue." return end
        if not stroke then
            if #doc.strokes>=book.maxStrokes then note="Stroke limit reached. Undo a stroke to continue." return end
            if tool == "Line" then
                if not lineStart then lineStart,note={px,py},"" return end
                table.insert(doc.strokes,{colour=colour,size=width,xy={lineStart[1],lineStart[2],px,py}})
                lineStart,dirty,note=nil,true,""
                table.clear(redo)
                return
            end
            stroke={colour=colour,size=width,xy={}}
            table.insert(doc.strokes,stroke)
            table.clear(redo)
            dirty,note=true,""
        end
        local xy=stroke.xy
        if #xy>=2 and (px-xy[#xy-1])^2+(py-xy[#xy])^2<16 then return end
        table.insert(xy,px)
        table.insert(xy,py)
    end)
    return {open=open, close=close, active=function() return mode~=nil end}
end
