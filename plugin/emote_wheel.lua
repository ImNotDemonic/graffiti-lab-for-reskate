local dock=require("dock")
local painter=require("graffiti_emotes")
return function(service,browse,close)
    local open,wheel,slot,previous,note=false,false,1,{},""
    local points={}
    local offered
    local screen={}
    function screen.open() open=true previous={click=true,accept=true} note="" end
    function screen.close() open=false wheel=false offered=nil end
    function screen.offer(piece) offered=piece note="Select a slot for "..piece.name end
    function screen.quick() wheel=true previous={click=true,accept=true} end
    function screen.assign(piece)
        local ok,why=service.assign(slot,piece)
        note=if ok then "Equipped "..piece.name.." in slot "..slot else tostring(why)
        return ok,why
    end
    function screen.title() return if wheel then "Emote Wheel" else "Emote Loadout" end
    local function fire()
        local ok,why=service.fire(slot)
        if ok then close() if why then reskate.ui.toast(why) end else note=tostring(why) end
    end
    function screen.panel(ui)
        ui:info("Selected","Slot "..slot)
        local _,name=service.slot(slot)
        ui:note(name or "Empty slot")
        if wheel then
            if ui:button("fire","Display above my head",true) then fire() return end
            if ui:button("manage","Manage loadout") then wheel=false end
        else
            if offered and ui:button("equip-offer","Equip "..offered.name.." here",true) then
                if screen.assign(offered) then offered=nil end
            end
            if ui:button("pick","Choose artwork for this slot",true) then browse() return end
            if name and ui:button("remove","Remove from slot") then
                local ok,msg=service.change(slot,nil) note=if ok then "Slot cleared." else tostring(msg)
            end
            if name and ui:button("fire","Display above my head") then fire() return end
            local s,why=service.settings()
            if s then
                local seconds=ui:slider("cooldown","Cooldown (seconds)",s.cooldown,1,30)
                if seconds~=s.cooldown then local ok,msg=service.change(nil,nil,seconds) if not ok then note=tostring(msg) end end
                if ui:button("others",if s.others then "Other players’ emotes: shown" else "Other players’ emotes: hidden") then
                    local ok,msg=service.change(nil,nil,nil,not s.others) if not ok then note=tostring(msg) end
                end
            else ui:note(tostring(why)) end
        end
        ui:note("1–8 or click a slot. Left / right cycles slots. Enter or A on the wheel displays your art.")
        if note~="" then ui:note(note) end
    end
    reskate.on("draw",function(d)
        if not open then return end
        local u=dock.draw(d)
        local left=570 local width=u.width-left
        if width<70 then return end
        u.rect(left,0,width,u.height,dock.panel)
        local cx,cy=left+width/2,u.height*.48
        local radius=math.min(width*.32,u.height*.30)
        local side=math.min(105,radius*.6)
        for i=1,8 do
            local a=(i-1)*math.pi/4-math.pi/2
            local x,y=cx+radius*math.cos(a),cy+radius*math.sin(a)
            points[i]={x=x,y=y,side=side,scale=u.scale}
            u.rect(x-side/2,y-side/2,side,side,"#242527")
            u.border(x-side/2,y-side/2,side,side,if i==slot then dock.blaze else dock.muted)
            u.text(x-side/2+4,y-side/2+2,tostring(i),13,dock.ink)
            local art=service.slot(i)
            if art then
                local w=side*.72*math.min(1,art.aspect)
                local h=w/art.aspect
                painter.drawArt(d,art,(x-w/2)*u.scale,(y-h/2)*u.scale,w*u.scale,h*u.scale,0)
            end
        end
        local art,name=service.slot(slot)
        if art then
            local w=side*1.35*math.min(1,art.aspect)
            painter.drawArt(d,art,(cx-w/2)*u.scale,(cy-w/art.aspect/2)*u.scale,w*u.scale,w/art.aspect*u.scale,reskate.time.now())
        end
        u.text(cx,cy+side,name or "Empty slot",18,dock.ink,"bold","centre")
    end)
    reskate.on("tick",function()
        if not open then return end
        local c=reskate.input.cursor()
        local pad=dock.buttons()
        local now={click=c and c.left,accept=reskate.input.key("Enter") or pad.a,left=reskate.input.key("Left") or pad.left,right=reskate.input.key("Right") or pad.right}
        for i=1,8 do now[i]=reskate.input.key(48+i) if now[i] and not previous[i] then slot=i end end
        if now.left and not previous.left then slot=(slot-2)%8+1 end
        if now.right and not previous.right then slot=slot%8+1 end
        local hit=false
        if c and now.click and not previous.click then
            for i,p in points do
                if dock.inside(c.position.x/p.scale,c.position.y/p.scale,p.x-p.side/2,p.y-p.side/2,p.side,p.side) then slot=i hit=true break end
            end
        end
        local activate=wheel and ((now.accept and not previous.accept) or hit)
        previous=now if activate then fire() end
    end)
    return screen
end
