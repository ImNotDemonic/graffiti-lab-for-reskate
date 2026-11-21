local dock = require("dock")
local book = require("blackbook")
local title = "Graffiti Lab Studio"
local ink, muted, blaze, panel = "#F2EFE9", "#B5B2AC", "#FF5A1F", "#0D0E10F5"
local canvas = {672, 252, 1152, 576}
local perPage = 4

return function(onPlace,onBack,mapMarks)
    local mode, doc, file, original = nil, book.new(), nil, nil
    local dirty, rename, pending = false, nil, nil
    local colour, width, redo, stroke = 3, 28, {}, nil
    local tool, lineStart = "Marker", nil
    local history, mapTab, galleryBack, mapPage = {},false,false,1
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
        mapTab, galleryBack = false,false
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
            history,galleryBack={},true
            if card then reskate.log(string.format("Blackbook opened %s (%d strokes, %d points)", file, #doc.strokes, book.pointCount(doc))) end
        end
        if dirty and card and card.file == file then mode,galleryBack="editor",true return end
        if dirty then pending = replace else replace() end
    end

    local function record(s,index,erased)
        table.insert(history,{s=s,index=index,erased=erased})
        table.clear(redo)
        dirty,note=true,""
    end
    local function undo()
        local change=table.remove(history)
        if not change and #doc.strokes>0 then change={index=#doc.strokes,s=doc.strokes[#doc.strokes]} end
        if not change then return end
        if change.erased then table.insert(doc.strokes,change.index,change.s) else table.remove(doc.strokes,change.index) end
        table.insert(redo,change)
        dirty,note=true,""
    end
    local function redoStroke()
        local change=table.remove(redo)
        if not change then return end
        if change.erased then table.remove(doc.strokes,change.index) else table.insert(doc.strokes,change.index,change.s) end
        table.insert(history,change)
        dirty,note=true,""
    end
    local function strokeAt(x,y)
        for i=#doc.strokes,1,-1 do
            local s=doc.strokes[i]
            local ax,ay=s.xy[1],s.xy[2]
            for j=1,#s.xy,2 do
                local bx,by=s.xy[j],s.xy[j+1]
                local dx,dy=bx-ax,by-ay
                local t=math.clamp(((x-ax)*dx+(y-ay)*dy)/math.max(1,dx*dx+dy*dy),0,1)
                if (x-ax-dx*t)^2+(y-ay-dy*t)^2<=(s.size/2+3)^2 then return i end
                ax,ay=bx,by
            end
        end
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
        pending, rename, stroke, lineStart, held = nil, nil, nil, nil, {mouse = true,padBack=true}
        galleryBack=false
        if which == "gallery" then gallery(1) else mode, note = "editor", "" end
        reskate.log("Opened " .. (if which == "gallery" then "Blackbook" else "Custom Editor"))
    end
    local function back(native)
        if pending then
            pending=nil
        elseif rename then
            rename=nil
        elseif mode=="editor" and galleryBack then
            gallery(page)
        else
            if native then mode=nil else close() end
            onBack()
            return
        end
        held={mouse=true,padBack=true}
        if native then reskate.ui.open(title) end
    end
    reskate.ui.screen(title, function() end, {panel = false})
    reskate.on("screen_closed", function(name)
        if name == title and mode then stroke,lineStart=nil,nil back(true) end
    end)

    reskate.on("draw", function(d)
        if not mode then return end
        local screen = d:size()
        scale = math.min(screen.x / 1920, screen.y / 1080)
        if scale <= 0 then return end
        left, top = 0, (screen.y - 1080 * scale) / 2
        if mode=="gallery" then scale=math.min(screen.y/1080,screen.x/576) top=0 end
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
        if mode=="editor" then d:rect(vector.zero,screen,{colour="#080809CC",fill=true}) end
        rect(0,-top/scale,576,screen.y/scale,panel)
        local heading=if mode=="editor" then "Custom Editor" else "Saved Gallery"
        local u=dock.draw(d)
        if mode=="editor" then
            -- The editor and its drawing surface share the same letterboxed coordinates.
            u.p=p
        end
        rect(48,40,64,24,"#292A2D")
        label(53,42,"← Esc","bold",14,ink)
        target(42,30,76,44,function() back(false) end)
        label(123,42,"GRAFFITI LAB   /   "..string.upper(heading),"bold",14,muted)
        u.heading(48,84,heading,43)
        if mode == "editor" then
            for i,name in {"Marker","Line","Eraser","Picker"} do
                button(48+(i-1)*122,154,115,65,string.upper(name),function()
                    tool,lineStart,note=name,nil,""
                end,tool==name)
            end
            label(48,242,"BRUSH SIZE","bold",15,muted)
            label(414,242,width.." px","bold",17,ink)
            rect(48,270,480,6,"#38393B")
            rect(48,270,480*(width-4)/60,6,blaze)
            rect(48+470*(width-4)/60,264,10,18,ink)
            for i=0,15 do target(48+i*30,253,30,45,function() width=4+i*4 end) end
            label(48,342,"PALETTE","bold",15,muted)
            for i,c in book.palette do
                local x,y=48+(i-1)%8*60,377+math.floor((i-1)/8)*44
                if i==colour then rect(x-2,y-2,60,43,blaze) end
                rect(x+1,y+1,55,37,c)
                target(x,y,58,40,function() colour=i end)
            end
            label(48,510,"DRAWING","bold",15,muted)
            button(48,549,480,49,if rename then "Keep name   /   Enter" else "Rename drawing",nameField)
            button(48,607,480,49,"Open Blackbook",function() if rename then finishName() end gallery(1) end)
            button(48,920,112,53,"Undo",undo)
            button(168,920,112,53,"Redo",redoStroke)
            rect(291,920,237,53,blaze)
            u.heading(304,937,"Save to Blackbook",22,dock.dark)
            target(291,920,237,53,function() if rename then finishName() end save() end)
            label(48,1004,"Ctrl+S   Save       Ctrl+Z / Y   Undo / Redo       Esc   Back","body",16,muted)
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
            u.rule(48,138,151)
            local markCount=mapMarks()
            button(48,168,232,43,"Designs   "..#files,function() mapTab=false end,not mapTab)
            button(288,168,236,43,"On this map   "..markCount,function() mapTab,mapPage=true,1 end,mapTab)
            if mapTab then
                mapPage=math.clamp(mapPage,1,math.max(1,math.ceil(markCount/8)))
                for i=(mapPage-1)*8+1,math.min(mapPage*8,markCount) do
                    local y=245+((i-1)%8)*58
                    rect(48,y,476,51,"#222326")
                    label(62,y+10,mapMarks(i),"bold",19,ink)
                end
                if markCount==0 then label(48,256,"No local marks on this map yet.","body",21,muted) end
                if markCount>8 then
                    button(48,738,104,48,"Previous",function() mapPage-=1 end)
                    button(420,738,104,48,"Next",function() mapPage+=1 end)
                end
                label(48,1004,"Esc / B   Back","body",18,muted)
            else
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
            label(48,1004,"Esc / B   Back","body",18,muted)
            end
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
        local pad=dock.buttons()
        local goBack=pad.b and not held.padBack
        held.padBack=pad.b
        if goBack then back(false) return end
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
        if tool=="Eraser" or tool=="Picker" then
            if not click then return end
            local i=strokeAt((x-cx)/w*book.width,(y-cy)/h*book.height)
            if i then
                if tool=="Picker" then colour=doc.strokes[i].colour else record(table.remove(doc.strokes,i),i,true) end
            end
            return
        end
        local needed = if tool == "Line" then 2 else 1
        if book.pointCount(doc)+needed>book.maxPoints then note="Point limit reached. Undo a stroke to continue." return end
        if not stroke then
            if #doc.strokes>=book.maxStrokes then note="Stroke limit reached. Undo a stroke to continue." return end
            if tool == "Line" then
                if not lineStart then lineStart,note={px,py},"" return end
                table.insert(doc.strokes,{colour=colour,size=width,xy={lineStart[1],lineStart[2],px,py}})
                lineStart,dirty,note=nil,true,""
                record(doc.strokes[#doc.strokes],#doc.strokes,false)
                return
            end
            stroke={colour=colour,size=width,xy={}}
            table.insert(doc.strokes,stroke)
            record(stroke,#doc.strokes,false)
        end
        local xy=stroke.xy
        if #xy>=2 and (px-xy[#xy-1])^2+(py-xy[#xy])^2<16 then return end
        table.insert(xy,px)
        table.insert(xy,py)
    end)
    return {open=open, close=close, active=function() return mode~=nil end}
end
