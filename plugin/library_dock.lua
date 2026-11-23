-- The library and reshape editor share the overlay dock and captured-input screen.
local dock=require("dock")
local palette=require("blackbook").palette
local function short(s,n)
    if not utf8.len(s) or utf8.len(s)<=n then return s end
    return s:sub(1,utf8.offset(s,n)-1).."…"
end

return function(back)
    local controls,targets={},{}
    local focus,editing,sliding,pending,value,held,scale
    local selectAll=false
    local scroll,maximum,title=0,0,nil
    local top,bottom=164,971
    local function reset()
        controls,targets={},{}
        focus,editing,sliding,pending,value=nil,nil,nil,nil,nil
        selectAll=false
        held={mouse=true,enter=true} scroll,maximum=0,0
    end
    reset()
    local function widget(kind,id,label,current,extra)
        local row=extra or {}
        row.kind,row.id,row.label,row.value=kind,id,label,current
        table.insert(controls,row)
        if pending==id then pending=nil return value end
        return current
    end
    local ui={}
    function ui:editingGesture()
        if sliding then return sliding.row.id end
        return editing
    end
    function ui:button(id,label,primary) return widget("button",id,label,false,{primary=primary}) end
    function ui:text(id,label,current,hint) return widget("text",id,label,current,{hint=hint}) end
    function ui:slider(id,label,current,lo,hi) return widget("slider",id,label,current,{lo=lo,hi=hi}) end
    function ui:tabs(id,options,selected) return widget("tabs",id,"",selected,{options=options}) end
    function ui:piece(id,p,selected) return widget("piece",id,p.name,false,{piece=p,selected=selected}) end
    function ui:inks(id,selected,label) return widget("inks",id,label,selected) end
    function ui:note(label) if label~="" then table.insert(controls,{kind="note",label=label}) end end
    function ui:info(label,display) table.insert(controls,{kind="info",label=label,value=display}) end
    local function draw(d,name,panel)
        if name~=title then reset() title=name end
        controls,targets={},{}
        panel(ui)
        pending=nil
        local u=dock.draw(d)
        scale=u.scale
        u.header(name)
        local function hit(row,x,y,w,h,option)
            local key=row.id..(if option then "-"..option else "")
            local t={key=key,row=row,x=x,y=y,w=w,h=h,option=option}
            table.insert(targets,t)
            if y>=top and y+h<=bottom and focus==key then u.border(x,y,w,h,dock.ink) end
            return t
        end
        local y=top-scroll
        local column=0
        for _,row in controls do
            local kind=row.kind
            if kind~="piece" and column~=0 then column=0 y+=117 end
            local h=if kind=="piece" then 109 elseif kind=="slider" then 53 elseif kind=="text" then 61
                elseif kind=="inks" and row.label then 52 elseif kind=="note" then 35 elseif kind=="info" then 34 else 38
            local visible=y>=top and y+h<=bottom
            if kind=="piece" then
                local p=row.piece
                local x=36+column*166
                if visible then
                    u.rect(x,y,158,h,if row.selected then dock.blaze else "#313135")
                    u.rect(x+2,y+2,154,79,"#454442")
                    local w=math.min(147,75*(p.aspect or 1))
                    local height=w/(p.aspect or 1)
                    local l,t=x+(158-w)/2,y+(83-height)/2
                    if p.stencil then
                        require("shape_preview").draw(u,p.stencil,l,t,w,height,palette[p.ink],palette[2],100)
                    elseif p.textureParts then
                        require("native_arch").draw(d,u,p.textureParts,p.textureSheet,l,t,w,height)
                    elseif p.parts then
                        for _,part in p.parts do
                            u.rect(l+(part.x+.5-part.w/2)*w,t+(part.y+.5-part.h/2)*height,part.w*w,part.h*height,palette[part.colour])
                        end
                    elseif p.sheet then d:image(p.sheet,u.p(l,t),u.p(l+w,t+height),{uv=p.thumb})
                    else u.text(x+10,y+32,short(p.category or "Artwork",15),16,dock.muted,"body") end
                    local source=if p.category=="Editable project" then "PROJECT" elseif p.frames and #p.frames>1 then "ANIMATED"
                        elseif p.drawing then "BLACKBOOK" elseif p.downloaded then "GALLERY" elseif p.file then "IMPORT"
                        elseif p.sheet then "PREMADE" else nil
                    if source then
                        u.rect(x+4,y+4,10+#source*8,17,dock.dark)
                        u.text(x+8,y+6,source,11,dock.ink,"bold")
                    end
                    u.text(x+6,y+88,string.upper(short(p.name,16)),14,if row.selected then dock.dark else dock.ink,"bold")
                end
                hit(row,x,y,158,h)
                column=(column+1)%3
                if column==0 then y+=117 end
                continue
            elseif kind=="inks" then
                local topY=y+(if row.label then 20 else 5)
                if visible and row.label then u.text(36,y,string.upper(row.label),14,dock.muted,"bold") end
                for i,colour in palette do
                    local x=36+(i-1)*31
                    if visible then
                        u.rect(x,topY,28,28,colour)
                        if i==row.value then u.border(x-1,topY-2,30,32,dock.ink) end
                    end
                    hit(row,x,if row.label then topY else y,30,if row.label then 28 else h,i)
                end
            elseif kind=="tabs" then
                local w=(490-(#row.options-1)*5)/#row.options
                for i,label in row.options do
                    local x=36+(i-1)*(w+5)
                    if visible then
                        u.rect(x,y,w,h,if i==row.value then dock.blaze else "#252629")
                        u.text(x+w/2,y+11,string.upper(label),15,if i==row.value then dock.dark else dock.ink,"bold","centre")
                    end
                    hit(row,x,y,w,h,i)
                end
            elseif kind=="button" then
                if visible then
                    u.rect(36,y,490,h,if row.primary then dock.blaze else "#252629")
                    u.text(50,y+9,short(row.label,53),18,if row.primary then dock.dark else dock.ink,"bold")
                end
                hit(row,36,y,490,h)
            elseif kind=="text" then
                if visible then
                    u.text(36,y,string.upper(row.label),13,dock.muted,"bold")
                    u.rect(36,y+20,490,38,"#1A1B1E")
                    u.border(36,y+20,490,38,if editing==row.id then dock.blaze else "#49484B")
                    local s=if row.value~="" then row.value else row.hint
                    if row.id=="word" then s=s:gsub("\n"," ↵ ") end
                    if editing==row.id then
                        s=if row.id=="word" then row.value:gsub("\n"," ↵ ") else row.value
                        if utf8.len(s) and utf8.len(s)>45 then s="…"..s:sub(utf8.offset(s,-44)) end
                        s..="|"
                        if selectAll then u.rect(40,y+24,482,30,"#793A22") end
                    end
                    u.text(46,y+29,short(s,48),17,dock.ink)
                end
                hit(row,36,y+20,490,38)
            elseif kind=="slider" then
                local x=36+490*(row.value-row.lo)/(row.hi-row.lo)
                if visible then
                    u.text(36,y,string.upper(row.label),14,dock.muted,"bold")
                    local unit=if row.id=="angle" then "°" elseif row.id=="cooldown" then " s"
                        elseif row.id=="brush-size" then " px"
                        elseif row.id=="spacing" or row.id=="ink" or row.id=="brush-ink" or row.id=="repeat" then "" else "%"
                    u.text(526,y,tostring(math.round(row.value))..unit,16,dock.ink,"bold","right")
                    u.rect(36,y+33,490,5,"#525154")
                    if x>36 then u.rect(36,y+33,x-36,5,dock.blaze) end
                    u.rect(x-4,y+27,8,17,dock.ink)
                end
                hit(row,36,y+17,490,36)
            elseif visible then
                if kind=="info" then u.text(36,y+4,short(row.value,40),22,dock.ink,"heading")
                else
                    local cut=utf8.offset(row.label,62)
                    if cut then
                        local first=row.label:sub(1,cut-1)
                        local split=first:match(".*()%s") or cut
                        u.text(36,y,row.label:sub(1,split-1),15,dock.muted)
                        u.text(36,y+17,short(row.label:sub(split):gsub("^%s+",""),61),15,dock.muted)
                    else
                        u.text(36,y,row.label,15,dock.muted)
                    end
                end
            end
            y+=h+7
        end
        if column~=0 then y+=117 end
        maximum=math.max(0,y+scroll-bottom)
        scroll=math.clamp(scroll,0,maximum)
        if maximum>0 then
            u.rect(535,top,3,bottom-top,"#343437")
            local handle=(bottom-top)^2/(bottom-top+maximum)
            u.rect(535,top+(bottom-top-handle)*scroll/maximum,3,handle,dock.muted)
        end
        u.text(36,1008,if maximum>0 then "Wheel / ↑ ↓   Browse     Enter / A   Select     Esc / B   Back" else "↑ ↓   Select      ← →   Adjust      Enter / A   Open      Esc / B   Back",14,dock.muted,"bold")
    end
    local function tick()
        if not scale then return end
        local c=reskate.input.cursor()
        local pad=dock.buttons()
        local keys={mouse=c and (c.left or reskate.input.key(1)),enter=reskate.input.key("Enter") or pad.a,
            back=pad.b,up=reskate.input.key("Up") or pad.up,down=reskate.input.key("Down") or pad.down,
            left=reskate.input.key("Left") or pad.left,right=reskate.input.key("Right") or pad.right,erase=reskate.input.key("Backspace"),
            selectAll=editing=="word" and reskate.input.key(0x11) and reskate.input.key(0x41)}
        local old=held held=keys
        local function edge(k) return keys[k] and not old[k] end
        if edge("back") then if editing then editing=nil else back() end return end
        local x,y=if c then c.position.x/scale else -1,if c then c.position.y/scale else -1
        if c and x<576 and (c.wheel or 0)~=0 then scroll=math.clamp(scroll-c.wheel*96,0,maximum) end
        if not keys.mouse then sliding=nil end
        local current
        for _,t in targets do if t.key==focus then current=t break end end
        local function activate(t,pointer)
            focus=t.key
            local r=t.row
            editing=nil
            if r.kind=="slider" then
                if pointer then sliding=t pending,value=r.id,math.round(r.lo+(r.hi-r.lo)*math.clamp((x-t.x)/t.w,0,1)) end
            elseif r.kind=="text" then
                editing=r.id selectAll=(r.id=="word" and (r.value=="TAG" or r.value=="Tag")) reskate.input.text(true)
            else pending,value=r.id,t.option or true end
        end
        if edge("mouse") then
            editing=nil
            if dock.inside(x,y,36,29,64,35) then back() return end
            for _,t in targets do
                if t.y>=top and t.y+t.h<=bottom and dock.inside(x,y,t.x,t.y,t.w,t.h) then activate(t,true) return end
            end
        elseif sliding then activate(sliding,true) return end
        if editing and current then
            local v=current.row.value
            local extra=reskate.input.text(true):gsub("[%c]","")
            if edge("selectAll") then selectAll=true return end
            local lineBreak=editing=="word" and edge("enter") and reskate.input.key(0x10)
            if lineBreak then extra="\n"..extra end
            if selectAll and (extra~="" or edge("erase")) then v="" selectAll=false
            elseif edge("erase") and #v>0 then v=v:sub(1,(utf8.offset(v,-1) or #v)-1) end
            if extra~="" or v~=current.row.value then pending,value=editing,v..extra end
            if edge("enter") and not lineBreak then editing=nil selectAll=false end
            return
        end
        if current and edge("enter") then activate(current,false) return end
        local dx=if edge("right") then 1 elseif edge("left") then -1 else 0
        local dy=if edge("down") then 1 elseif edge("up") then -1 else 0
        if dx==0 and dy==0 then return end
        if current and current.row.kind=="slider" and dx~=0 then
            local r=current.row pending,value=r.id,math.clamp(r.value+dx,r.lo,r.hi) return
        end
        local target=targets[1]
        if current then
            local score=math.huge
            target=current
            for _,t in targets do
                local vx=t.x+t.w/2-current.x-current.w/2
                local vy=t.y+t.h/2-current.y-current.h/2
                local along,cross=vx*dx+vy*dy,math.abs(vx*dy-vy*dx)
                if along>1 and along+cross*2<score then score,target=along+cross*2,t end
            end
        end
        if target then
            focus=target.key
            scroll=math.clamp(scroll+math.min(0,target.y-top)+math.max(0,target.y+target.h-bottom),0,maximum)
        end
    end
    return {draw=draw,tick=tick,reset=function() title=nil reset() end}
end
