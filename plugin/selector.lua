local dock=require("dock")
local imports=require("imports")
local palette=require("blackbook").palette
local title="Premade Art"
local columns, pageSize=3,9
local tileWidth,tileHeight=154,116
local function tilePosition(slot)
    return 36+(slot-1)%columns*166, 355+math.floor((slot-1)/columns)*125
end

return function(pieces,onChoose,onBack)
    local stockCount=#pieces
    local importMessage,nextRead=nil,0
    local categories,searchText={},{}
    for i,piece in pieces do
        if not table.find(categories,piece.category) then table.insert(categories,piece.category) end
        searchText[i]=string.lower(table.concat({piece.name,piece.category,piece.number or "",piece.lettering or ""}," "))
    end
    table.sort(categories)
    table.insert(categories,1,"All")
    table.insert(categories,"My imports")
    local open,focus,category,query,typing=false,1,1,"",false
    local held,visible,scale={}, {}, nil
    -- Focus is a position in the filtered list; every way to move it reveals its page.
    local function filter(keep)
        table.clear(visible)
        local needle=string.lower(query)
        for i,piece in pieces do
            if (category==1 or piece.category==categories[category]) and searchText[i]:find(needle,1,true) then
                table.insert(visible,i)
            end
        end
        focus=table.find(visible,keep) or 1
    end
    local function refresh(importsOnly,keep)
        local id=pieces[keep or 0] and pieces[keep].id
        for i=#pieces,stockCount+1,-1 do pieces[i],searchText[i]=nil,nil end
        if not reskate.session.active() then
            local designs=imports.list()
            for _,piece in designs do
                table.insert(pieces,piece)
                table.insert(searchText,string.lower(piece.name.." My imports"))
            end
        end
        if importsOnly then category,query=#categories,"" end
        for i,piece in pieces do if piece.id==id then keep=i break end end
        filter(keep)
    end
    local function openImporter()
        if reskate.session.active() then return end
        local ok,why=imports.reveal()
        importMessage=if ok then "Open Import Artwork.html in the folder, then refresh." else tostring(why)
        refresh(true)
    end
    local function selectCategory(index)
        category=index
        filter(visible[focus])
    end
    local function page() return math.floor((focus-1)/pageSize) end
    local function pageCount() return math.ceil(#visible/pageSize) end
    local function turnPage(delta)
        local target=page()+delta
        if target>=0 and target<pageCount() then focus=target*pageSize+1 end
    end
    local function close()
        if open then open=false reskate.ui.close() end
    end
    local function back() close() onBack() end
    reskate.ui.screen(title,function() end,{panel=false})
    reskate.on("screen_closed",function(name)
        if name==title and open then open=false onBack() end
    end)
    reskate.on("draw",function(d)
        if not open then return end
        local u=dock.draw(d)
        scale=u.scale
        local function thumbnail(piece,x,y,width,height)
            local w=math.min(width,height*piece.aspect)
            local h=w/piece.aspect
            local left,top=x+(width-w)/2,y+(height-h)/2
            if piece.file then
                if piece.parts then
                    for _,part in piece.parts do
                        u.rect(left+(part.x+0.5-part.w/2)*w,top+(part.y+0.5-part.h/2)*h,
                            part.w*w,part.h*h,palette[part.colour])
                    end
                else
                    u.text(x+4,y+24,if piece.problem then "Invalid file" else "Loading…",15,dock.muted)
                end
                return
            end
            d:image(piece.sheet,u.p(left,top),u.p(left+w,top+h),{uv=piece.thumb})
        end
        u.header(title)
        if not reskate.session.active() then
            u.rect(309,82,112,38,"#38393B")
            u.text(365,92,"IMPORT ART",14,dock.ink,"bold","centre")
            u.rect(426,82,102,38,"#38393B")
            u.text(477,92,"REFRESH",14,dock.ink,"bold","centre")
        end
        if category==#categories then
            u.text(36,330,if reskate.session.active() then "Personal art is available offline."
                else importMessage or "Import Art opens your local artwork folder.",15,dock.muted)
        end
        u.rect(36,164,492,46,"#18191C")
        u.border(36,164,492,46,if typing then dock.blaze else "#393A3D")
        u.text(50,177,if typing then query.."|" elseif query~="" then query else "Search name, lettering or number",17,
            if typing or query~="" then dock.ink else dock.muted)
        u.text(506,178,if query~="" then "×" else "/",16,dock.muted,"bold","right")
        u.text(36,223,"C A T E G O R Y",13,dock.muted,"bold")
        u.text(528,223,"Q / E    ·    LB / RB",13,dock.muted,"bold","right")
        for i,name in categories do
            local x,y=36+(i-1)%4*124,248+math.floor((i-1)/4)*43
            local label=if name=="ReSkate lettering" then "Lettering" else name
            u.rect(x,y,120,37,if category==i then dock.blaze else "#191A1D")
            u.text(x+60,y+10,string.upper(label),13,if category==i then dock.dark else dock.ink,"bold","centre")
        end
        for slot=1,math.min(pageSize,#visible-page()*pageSize) do
            local index=page()*pageSize+slot
            local piece=pieces[visible[index]]
            local x,y=tilePosition(slot)
            local selected=index==focus
            u.rect(x-2,y-2,tileWidth+4,tileHeight+4,if selected then dock.blaze else "#26272A")
            d:gradient(u.p(x,y),u.p(x+tileWidth,y+92),{"#5A564E","#555149","#3E3B35","#46433C"})
            thumbnail(piece,x+3,y+2,tileWidth-6,88)
            u.rect(x,y+92,tileWidth,24,if selected then dock.blaze else "#18191C")
            u.text(x+5,y+97,string.upper(piece.name),if #piece.name>15 then 12 else 14,if selected then dock.dark else dock.ink,"bold")
        end
        if #visible==0 then
            u.text(36,355,"No pieces match.",22,dock.ink,"bold")
            u.text(36,395,if category==#categories then "Save a .graffiti file in imports, then refresh." else "Try another category or clear the search.",18,dock.muted)
        else
            local function pageButton(x,label,enabled)
                u.rect(x,740,106,36,"#191A1D")
                u.text(x+53,750,label,14,if enabled then dock.ink else "#737477","bold","centre")
            end
            pageButton(36,"‹  PREV",page()>0)
            pageButton(422,"NEXT  ›",page()+1<pageCount())
            u.text(282,750,string.format("%d %s   ·   %d / %d",#visible,if #visible==1 then "piece" else "pieces",page()+1,pageCount()),16,dock.muted,"bold","centre")
            local piece=pieces[visible[focus]]
            u.rect(36,798,492,1,"#38393B")
            thumbnail(piece,39,811,96,96)
            u.text(148,825,string.upper(piece.name),if #piece.name>16 then 24 else 29,dock.ink,"heading")
            local detail=if piece.number then "No. "..piece.number else piece.colourway
            u.text(148,872,if piece.problem then "Re-export this image and refresh." else piece.category.."  ·  "..detail..string.format("  ·  %.2f × %.2f m",piece.width or 0.65,piece.height or 0.65),16,dock.muted)
            u.rect(36,944,492,52,dock.blaze)
            u.heading(51,960,"Place on Wall",21,dock.dark)
            u.text(509,960,"Enter / A",17,dock.dark,"bold","right")
        end
        u.text(36,1023,"D-pad / Arrows   Browse      Enter / A   Aim      Esc / B   Back",15,dock.muted,"bold")
    end)
    reskate.on("tick",function()
        if not open then return end
        if not reskate.session.active() and reskate.time.now()>=nextRead then
            for slot=1,math.min(pageSize,#visible-page()*pageSize) do
                local piece=pieces[visible[page()*pageSize+slot]]
                if piece.file and not piece.parts and not piece.problem then
                    imports.load(piece)
                    nextRead=reskate.time.now()+100
                    break
                end
            end
        end
        local cursor=reskate.input.cursor()
        local pad=dock.buttons()
        local now={left=reskate.input.key("Left") or pad.left,right=reskate.input.key("Right") or pad.right,
            up=reskate.input.key("Up") or pad.up,down=reskate.input.key("Down") or pad.down,
            accept=reskate.input.key("Enter") or pad.a,back=pad.b,click=cursor and cursor.left,
            import=reskate.input.key("I"),reload=reskate.input.key(116),slash=reskate.input.key(191),erase=reskate.input.key("Backspace"),
            prev=reskate.input.key("Q") or pad.lb,next=reskate.input.key("E") or pad.rb}
        local prev=held
        held=now
        if now.back and not prev.back then back() return end
        local accept=now.accept and not prev.accept
        if typing then
            local input=reskate.input.text(true):gsub("[^ -~]","")
            if input~="" then query=(query..input):sub(1,36) filter(visible[focus]) end
            if now.erase and not prev.erase then query=query:sub(1,-2) filter(visible[focus]) end
            if accept then typing=false return end
        elseif now.slash and not prev.slash then
            reskate.input.text(true) typing=true return
        else
            if now.import and not prev.import then openImporter() return end
            if now.reload and not prev.reload then refresh(true,visible[focus]) return end
            local shift=if now.prev and not prev.prev then -1 elseif now.next and not prev.next then 1 else 0
            if shift~=0 then selectCategory((category-1+shift)%#categories+1) end
            if #visible>0 then
                local delta=if now.left and not prev.left then -1 elseif now.right and not prev.right then 1
                    elseif now.up and not prev.up then -columns elseif now.down and not prev.down then columns else 0
                focus=math.clamp(focus+delta,1,#visible)
            end
        end
        if now.click and not prev.click and scale and scale>0 then
            local x,y=cursor.position.x/scale,cursor.position.y/scale
            if dock.inside(x,y,36,32,66,33) then back() return end
            if not reskate.session.active() then
                if dock.inside(x,y,309,82,112,38) then openImporter() return end
                if dock.inside(x,y,426,82,102,38) then refresh(true,visible[focus]) return end
            end
            if dock.inside(x,y,36,164,492,46) then
                if x>=481 and query~="" then query="" filter(visible[focus]) end
                typing=true reskate.input.text(true) return
            end
            typing=false
            for i=1,#categories do
                if dock.inside(x,y,36+(i-1)%4*124,248+math.floor((i-1)/4)*43,120,37) then selectCategory(i) return end
            end
            if dock.inside(x,y,36,740,106,36) then turnPage(-1) return end
            if dock.inside(x,y,422,740,106,36) then turnPage(1) return end
            for slot=1,math.min(pageSize,#visible-page()*pageSize) do
                local left,top=tilePosition(slot)
                if dock.inside(x,y,left,top,tileWidth,tileHeight) then focus=page()*pageSize+slot return end
            end
            accept=dock.inside(x,y,36,944,492,52)
        end
        if accept and #visible>0 then
            local piece=pieces[visible[focus]]
            if piece.file and (reskate.session.active() or not imports.load(piece)) then
                reskate.ui.toast(piece.problem or "Imported artwork is available offline.")
                return
            end
            close() onChoose(visible[focus])
        end
    end)
    local function resume()
        open,typing,held=true,false,{click=true,accept=true,back=true}
        reskate.ui.open(title)
    end
    return {open=function(index)
        category,query=1,""
        refresh(false,index)
        resume()
    end,resume=resume,close=close,active=function() return open end}
end
