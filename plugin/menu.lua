local dock=require("dock")
local title="Graffiti Lab"
local rows={
    {"Premade Art","Browse the collection and place a piece","on a wall.",364,112},
    {"Custom Editor","Draw on a transparent canvas and save","to your Blackbook.",480,112},
    {"Wall Painting","Equip the can and paint straight onto surfaces.","",596,112},
    {"Saved Gallery","","",748,60},
    {"Settings","","",812,60},
}
local tabs={"Controls","Painting","Performance"}
local controls={
    {"Open Graffiti Lab","Ctrl+L","Back + Y"},{"Select menu row","↑ / ↓","D-pad"},
    {"Open selection","Enter","A"},{"Back / close","Esc","B"},
    {"Place artwork","LMB / Ctrl+P","A"},{"Cancel aim","Ctrl+R","B"},
    {"Paint stroke","LMB","—"},{"Brush width","[ / ]","—"},{"Paint colour","1–8","—"},
    {"Undo stroke","Ctrl+Z","—"},
}
return function(choose, returnHome, paint, stats, version)
    local page, focus, tab, scale, held, lastX, lastY
    local function close()
        if page then page=nil reskate.ui.close() end
    end
    local function open(which)
        page,focus,tab=which or "home",focus or 1,1
        held={click=true,accept=true,back=true}
        lastX,lastY=nil,nil
        reskate.ui.open(title)
    end
    local function back()
        if page=="settings" then open("home") else close() end
    end
    reskate.ui.screen(title,function() end,{panel=false})
    reskate.on("screen_closed",function(name)
        if name~=title or not page then return end
        local settings=page=="settings"
        page=nil
        if settings then returnHome() end
    end)
    local function selectRow(index)
        focus=index
        if reskate.session.active() and index>=2 and index<=4 then
            reskate.ui.toast("This tool is available offline.")
        elseif index==5 then open("settings")
        else close() choose(index) end
    end
    reskate.on("draw",function(d)
        if not page then return end
        local u=dock.draw(d)
        scale=u.scale
        local can=paint.can()
        if page=="home" then
            u.rect(0,0,576,u.height,dock.panel)
            u.art(376,0,200,200,310,0,510,200)
            u.text(44,50,"R E S K A T E   P L U G I N    ·    v"..version,14,dock.muted,"bold")
            u.heading(44,80,"Graffiti",62)
            u.heading(44,148,"Lab",62)
            u.rule(44,233,230)
            u.rect(44,282,484,62,"#18191C")
            d:circle(u.p(74,313),15*scale,{colour=can.hex,fill=true})
            u.text(103,294,"C U R R E N T   C A N",12,dock.muted,"bold")
            u.text(103,309,can.name.." · "..can.mm.." mm",18,dock.ink,"bold")
            u.text(511,305,"Set in Wall Paint",14,dock.muted,"body","right")
            u.rect(44,733,484,1,"#353639")
            for i,row in rows do
                local y,h=row[4],row[5]
                local selected=focus==i
                local disabled=reskate.session.active() and i>=2 and i<=4
                local fg=if selected then dock.dark elseif disabled then dock.muted else dock.ink
                local sub=if selected then "#442211" else dock.muted
                local mid=y+h/2
                if selected then u.rect(44,y,484,h,dock.blaze) end
                u.border(64,mid-18,36,36,if selected then "#91360E" else "#48494B")
                u.text(82,mid-12,tostring(i),19,fg,"bold","centre")
                u.heading(123,if i<=3 then y+16 else mid-10,row[1],if i<=3 then 29 else 20,fg)
                if i<=3 then
                    u.text(123,y+56,if disabled then "Available offline" else row[2],15,sub)
                    if not disabled and row[3]~="" then u.text(123,y+77,row[3],15,sub) end
                elseif disabled then u.text(420,mid-10,"Offline",15,sub) end
                if selected then u.text(503,mid-14,"→",25,fg,"bold","right") end
            end
            u.text(44,1023,"↑ ↓   Select      Enter / A   Open      Esc / B   Close",16,dock.muted,"bold")
        else
            u.header("Settings")
            for i,name in tabs do
                local x=44+(i-1)*162
                u.rect(x,168,155,46,if tab==i then dock.blaze else "#191A1D")
                u.text(x+77,181,string.upper(name),15,if tab==i then dock.dark else dock.ink,"bold","centre")
            end
            if tab==1 then
                u.text(53,244,"ACTION",13,dock.muted,"bold")
                u.text(286,244,"DEFAULT KEY",13,dock.muted,"bold")
                u.text(435,244,"PAD",13,dock.muted,"bold")
                for i,item in controls do
                    local y=274+(i-1)*48
                    u.rect(44,y,479,45,if i%2==0 then "#18191B" else "#151618")
                    u.text(56,y+10,item[1],17,dock.ink,"bold")
                    u.text(281,y+10,item[2],16,dock.ink,"bold")
                    u.text(440,y+10,item[3],15,dock.muted)
                end
                u.text(44,936,"Change global shortcuts in ReSkate’s Binds menu.",16,dock.muted)
            elseif tab==2 then
                u.text(44,269,"CAN COLOUR",15,dock.muted,"bold")
                for i,c in can.palette do
                    if i>8 then break end
                    local x=44+(i-1)*60
                    if can.index==i then u.rect(x-2,312,57,56,dock.blaze) end
                    u.rect(x+2,316,49,48,c)
                end
                u.text(44,387,can.name,21,dock.ink,"bold")
                u.text(44,477,"BRUSH WIDTH",15,dock.muted,"bold")
                for i,w in can.widths do
                    local x=44+(i-1)*163
                    u.rect(x,516,152,48,if i==can.size then dock.blaze else "#252629")
                    u.text(x+76,528,math.round(w*1000).." mm",19,if i==can.size then dock.dark else dock.ink,"bold","centre")
                end
                u.text(44,936,"Click a swatch or width to equip it for this session.",16,dock.muted)
            else
                local counts=stats()
                for i,row in {{"Artwork placements",counts.marks.." / "..counts.limit},
                    {"Artwork decals",counts.handles.." / "..counts.budget},{"Freehand strokes",tostring(counts.strokes)},
                    {"Visible paint / recorded",counts.visiblePaint.." / "..counts.samples},{"Wall reach","8 m"}} do
                    local y=280+(i-1)*58
                    u.rect(44,y,479,52,"#191A1D")
                    u.text(57,y+13,row[1],19)
                    u.text(505,y+13,row[2],19,dock.ink,"bold","right")
                end
            end
            u.text(44,1023,"← →   Tabs        Esc / B   Back",16,dock.muted,"bold")
        end
    end)
    reskate.on("tick",function()
        if not page then return end
        local cursor=reskate.input.cursor()
        local pad=dock.buttons()
        local now={up=reskate.input.key("Up") or pad.up, down=reskate.input.key("Down") or pad.down,
            left=reskate.input.key("Left") or pad.left, right=reskate.input.key("Right") or pad.right,
            accept=reskate.input.key("Enter") or pad.a,back=pad.b,click=cursor and cursor.left}
        local prev=held
        held=now
        if now.back and not prev.back then back() return end
        local x,y
        if scale and scale>0 and cursor then x,y=cursor.position.x/scale,cursor.position.y/scale end
        local click=now.click and not prev.click
        if page=="home" then
            if x and (click or x~=lastX or y~=lastY) then
                for i,row in rows do
                    if dock.inside(x,y,44,row[4],484,row[5]) then
                        if click then selectRow(i) return end
                        if lastX then focus=i end
                    end
                end
            end
            if now.up and not prev.up then focus=(focus-2)%#rows+1 end
            if now.down and not prev.down then focus=focus%#rows+1 end
            if now.accept and not prev.accept then selectRow(focus) end
        else
            if now.left and not prev.left then tab=(tab-2)%3+1 end
            if now.right and not prev.right then tab=tab%3+1 end
            if x and click then
                if dock.inside(x,y,36,32,66,33) then back() return end
                for i=1,3 do
                    if dock.inside(x,y,44+(i-1)*162,168,155,46) then tab=i return end
                    if tab==2 and dock.inside(x,y,44+(i-1)*163,516,152,48) then paint.setCan(nil,i) return end
                end
                if tab==2 then
                    for i=1,8 do
                        if dock.inside(x,y,44+(i-1)*60,312,55,56) then paint.setCan(i,nil) return end
                    end
                end
            end
        end
        lastX,lastY=x,y
    end)
    return {open=open,close=close,active=function() return page~=nil end}
end
