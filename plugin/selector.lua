local dock=require("dock")
local title="Premade Art"
local categories={"All","Stencil","Character"}

return function(pieces,onChoose,onBack)
    local open,focus,category,query,typing=false,1,1,"",false
    local held,visible,scale={}, {}, nil
    local function filter()
        table.clear(visible)
        for i,piece in pieces do
            if (category==1 or piece.category==categories[category]) and
                string.find(string.lower(piece.name),string.lower(query),1,true) then table.insert(visible,i) end
        end
        if not table.find(visible,focus) then focus=visible[1] end
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
        u.header(title)
        u.rect(36,164,492,46,"#18191C")
        u.border(36,164,492,46,if typing then dock.blaze else "#393A3D")
        u.text(50,177,if typing then query.."|" elseif query~="" then query else "Search pieces",17,
            if typing or query~="" then dock.ink else dock.muted)
        u.text(506,178,if query~="" then "×" else "/",16,dock.muted,"bold","right")
        u.text(36,229,"C A T E G O R Y",13,dock.muted,"bold")
        for i,name in categories do
            local x=36+(i-1)*148
            u.rect(x,252,140,37,if category==i then dock.blaze else "#191A1D")
            u.text(x+70,260,string.upper(name),15,if category==i then dock.dark else dock.ink,"bold","centre")
        end
        for slot,i in visible do
            local piece=pieces[i]
            local x=36+(slot-1)%3*166
            local y=334+math.floor((slot-1)/3)*167
            u.rect(x-2,y-2,158,158,if focus==i then dock.blaze else "#26272A")
            d:gradient(u.p(x,y),u.p(x+154,y+128),{"#5A564E","#555149","#3E3B35","#46433C"})
            d:image("art/"..piece.id..".png",u.p(x+15,y),u.p(x+142,y+127))
            u.rect(x,y+128,154,26,if focus==i then dock.blaze else "#18191C")
            u.text(x+6,y+132,string.upper(piece.name),14,if focus==i then dock.dark else dock.ink,"bold")
        end
        if not focus then
            u.text(36,347,"No pieces match.",22,dock.ink,"bold")
            u.text(36,389,"Try another category or clear the search.",18,dock.muted)
        else
            local piece=pieces[focus]
            u.rect(36,798,492,1,"#38393B")
            d:image("art/"..piece.id..".png",u.p(39,815),u.p(129,905))
            u.text(148,825,string.upper(piece.name),29,dock.ink,"heading")
            u.text(148,872,piece.category.."  ·  "..piece.colourway.."  ·  0.65 × 0.65 m",17,dock.muted)
            u.rect(36,944,492,52,dock.blaze)
            u.heading(51,960,"Place on Wall",21,dock.dark)
            u.text(509,960,"Enter / A",17,dock.dark,"bold","right")
        end
        u.text(36,1023,"← →   Browse        Enter / A   Aim        Esc / B   Back",15,dock.muted,"bold")
    end)
    reskate.on("tick",function()
        if not open then return end
        local cursor=reskate.input.cursor()
        local pad=dock.buttons()
        local now={left=reskate.input.key("Left") or pad.left,right=reskate.input.key("Right") or pad.right,
            accept=reskate.input.key("Enter") or pad.a,back=pad.b,click=cursor and cursor.left,
            slash=reskate.input.key(191),erase=reskate.input.key("Backspace"),
            prev=reskate.input.key("Q") or pad.lb,next=reskate.input.key("E") or pad.rb}
        local prev=held
        held=now
        if now.back and not prev.back then back() return end
        local accept=now.accept and not prev.accept
        if typing then
            local input=reskate.input.text(true):gsub("[^ -~]","")
            if input~="" then query=(query..input):sub(1,36) filter() end
            if now.erase and not prev.erase then query=query:sub(1,-2) filter() end
            if accept then typing=false return end
        elseif now.slash and not prev.slash then
            reskate.input.text(true) typing=true return
        else
            local shift=if now.prev and not prev.prev then -1 elseif now.next and not prev.next then 1 else 0
            if shift~=0 then category=(category-1+shift)%#categories+1 filter() end
            if focus then
                local index=table.find(visible,focus)
                if now.left and not prev.left then focus=visible[math.max(1,index-1)] end
                if now.right and not prev.right then focus=visible[math.min(#visible,index+1)] end
            end
        end
        if now.click and not prev.click and scale and scale>0 then
            local x,y=cursor.position.x/scale,cursor.position.y/scale
            if dock.inside(x,y,36,32,66,33) then back() return end
            if dock.inside(x,y,36,164,492,46) then
                if x>=481 and query~="" then query="" filter() end
                typing=true reskate.input.text(true) return
            end
            typing=false
            for i=1,#categories do
                if dock.inside(x,y,36+(i-1)*148,252,140,37) then category=i filter() return end
            end
            for slot,i in visible do
                if dock.inside(x,y,36+(slot-1)%3*166,334+math.floor((slot-1)/3)*167,154,154) then focus=i return end
            end
            accept=dock.inside(x,y,36,944,492,52)
        end
        if accept and focus then close() onChoose(focus) end
    end)
    return {open=function(index)
        focus,category,query,typing=index,1,"",false
        filter()
        open,held=true,{click=true,accept=true,back=true}
        reskate.ui.open(title)
    end,close=close,active=function() return open end}
end
