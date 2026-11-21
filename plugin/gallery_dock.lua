-- Uses the same overlay and captured input screen as the drawing studio.
local dock=require("dock")
local palette=require("blackbook").palette
local function shorten(s,count)
    if utf8.len(s) and utf8.len(s)>count then return s:sub(1,utf8.offset(s,count)-1).."…" end
    return s
end
local function artwork(d,u,preview,x,y,w,h)
    d:image("art/checker.png",u.p(x,y),u.p(x+w,y+h))
    if not preview then return end
    local width=math.min(w-8,(h-8)*preview.aspect)
    local height=width/preview.aspect
    local l,t=x+(w-width)/2,y+(h-height)/2
    for _,p in preview.parts do
        u.rect(l+(p.x+.5-p.w/2)*width,t+(p.y+.5-p.h/2)*height,p.w*width,p.h*height,palette[p.colour])
    end
end
return function(state,actions)
    local targets,scale,focus,edit,held={},1,nil,nil,{}
    local function reset()
        targets,focus,edit,held={},nil,nil,{mouse=true,a=true}
    end
    local function draw(d)
        local u=dock.draw(d)
        scale=u.scale targets={}
        local function target(id,x,y,w,h,fn)
            local t={id=id,x=x,y=y,w=w,h=h,run=fn}
            table.insert(targets,t)
            if focus==id then u.border(x,y,w,h,dock.ink) end
        end
        local function button(id,x,y,w,h,label,fn,primary)
            u.rect(x,y,w,h,if primary then dock.blaze else "#252629")
            u.text(x+w/2,y+h/2-10,label,16,if primary then dock.dark else dock.ink,"bold","centre")
            target(id,x,y,w,h,fn)
        end
        local function field(id,x,y,w,h,placeholder,limit)
            local value=state[id]
            u.rect(x,y,w,h,"#18191C") u.border(x,y,w,h,if edit==id then dock.blaze else "#414246")
            u.text(x+12,y+10,if edit==id then shorten(value,38).."|" elseif value=="" then placeholder else shorten(value,40),17,dock.muted,"body")
            target(id,x,y,w,h,function() edit=id reskate.input.text(true) end)
        end
        u.header("Public Artworks")
        target("back",36,30,62,32,actions.back)
        for i,name in {"Browse","Publish","Account"} do
            button("tab"..i,36+(i-1)*166,165,158,41,string.upper(name),function() edit=nil actions.tab(i) end,state.tab==i)
        end
        if state.tab==1 then
            field("query",36,228,370,43,"Search title, creator or tag",80)
            button("search",416,228,110,43,"SEARCH",function() edit=nil actions.search() end)
            if #state.rows==0 and not state.busy then
                u.text(36,337,if state.failed then "Gallery unavailable" else "No matching artwork",24,dock.ink,"heading")
            end
            for i,item in state.rows do
                local x,y=36+(i-1)%3*166,301+math.floor((i-1)/3)*146
                local chosen=state.selection==item
                u.rect(x,y,158,137,if chosen then dock.blaze else "#303033")
                artwork(d,u,item.preview,x+2,y+2,154,90)
                u.text(x+7,y+96,shorten(item.title,14),16,if chosen then dock.dark else dock.ink,"bold")
                u.text(x+7,y+116,shorten(item.creator,17),13,if chosen then dock.dark else dock.muted,"body")
                target("art"..i,x,y,158,137,function() actions.select(item) end)
            end
            if state.page>1 then button("prev",36,751,108,34,"‹ PREV",function() actions.page(-1) end) end
            u.text(278,758,"PAGE  "..state.page,15,dock.muted,"bold","centre")
            if state.more then button("next",418,751,108,34,"NEXT ›",function() actions.page(1) end) end
            local item=state.selection
            if item then
                u.rect(36,802,494,1,"#47464A")
                u.text(36,819,shorten(item.title,32),28,dock.ink,"heading")
                u.text(36,858,shorten(item.creator,38),17,dock.muted,"bold")
                if u.width>950 and item.preview then
                    local w=math.min(384,u.width-650)
                    local x=u.width-w-36
                    u.rect(x-2,78,w+4,w+46,dock.panel)
                    artwork(d,u,item.preview,x,80,w,w)
                    u.text(x+10,91+w,shorten(item.title,28),18,dock.ink,"bold")
                end
                if state.profile and not state.busy then
                    button("manage",399,835,127,34,if state.manage then "CLOSE" else "OPTIONS",actions.options)
                    if state.manage then
                        button("report",36,880,238,35,"Report and hide",actions.report)
                        button("unpublish",285,880,241,35,"Unpublish my artwork",actions.unpublish)
                    end
                end
                if not state.manage and item.description~="" then u.text(36,886,shorten(item.description,48),16,dock.muted,"body") end
                if not state.busy and not state.manage then button("download",36,937,490,51,"DOWNLOAD TO MY IMPORTS",actions.download,true) end
            end
        elseif state.tab==2 then
            u.text(36,233,"YOUR ARTWORK",15,dock.muted,"bold")
            for i=(state.sourcePage-1)*6+1,math.min(#state.sources,state.sourcePage*6) do
                local source=state.sources[i]
                button("source"..i,36,263+(i-1)%6*43,490,37,shorten(source.name,39),function() actions.source(source) end,source==state.source)
            end
            if state.sourcePage>1 then button("sprev",36,526,145,33,"‹ PREVIOUS",function() actions.sourcePage(-1) end) end
            if state.sourcePage*6<#state.sources then button("snext",381,526,145,33,"MORE ›",function() actions.sourcePage(1) end) end
            if state.raw then
                for i,f in {{"title","Title",64},{"description","Description",240},{"tags","Tags, comma-separated",160}} do
                    u.text(36,570+(i-1)*75,string.upper(f[2]),14,dock.muted,"bold")
                    field(f[1],36,590+(i-1)*75,490,42,f[2],f[3])
                end
                if state.preview then artwork(d,u,state.preview,36,818,112,80) end
                u.text(160,840,shorten(state.title,26),20,dock.ink,"heading")
                if state.profile and not state.busy then button("publish",36,937,490,51,"PUBLISH ARTWORK",actions.publish,true) end
            end
        else
            u.text(36,236,"GALLERY PROFILE",15,dock.muted,"bold")
            u.text(36,269,state.profile or "Guest",29,dock.ink,"heading")
            for i=(state.profilePage-1)*6+1,math.min(#state.profiles,state.profilePage*6) do
                local name=state.profiles[i]
                button("profile"..i,36,330+(i-1)%6*46,490,38,shorten(name,40),function() actions.profile(name) end,name==state.profile)
            end
            if state.profilePage>1 then button("pprev",36,611,145,34,"‹ PREVIOUS",function() state.profilePage-=1 end) end
            if state.profilePage*6<#state.profiles then button("pnext",380,611,145,34,"MORE ›",function() state.profilePage+=1 end) end
            button("guest",36,676,490,43,"Browse as guest",function() actions.profile(nil) end)
            button("keys",36,732,490,43,"Open creator key folder",actions.keys)
            button("profiles",36,788,490,43,"Refresh profiles",actions.profiles)
        end
        if state.busy then
            button("cancel",36,937,490,50,"STOP WAITING",actions.cancel)
        elseif state.failed then
            button("retry",36,937,490,50,"RETRY REQUEST",actions.retry)
        end
        u.text(36,1001,shorten(state.note,55),15,dock.ink,"body")
        u.text(36,1037,"Arrows / D-pad   Select      Enter / A   Open      Esc / B   Back",14,dock.muted,"bold")
    end
    local function tick()
        local cursor=reskate.input.cursor()
        local pad=dock.buttons()
        local keys={mouse=cursor and cursor.left,a=reskate.input.key("Enter") or pad.a,b=pad.b,
            l=reskate.input.key("Left") or pad.left,r=reskate.input.key("Right") or pad.right,
            u=reskate.input.key("Up") or pad.up,d=reskate.input.key("Down") or pad.down,
            erase=reskate.input.key("Backspace"),slash=reskate.input.key(191),prev=pad.lb,next=pad.rb}
        local prior=held held=keys
        local function edge(k) return keys[k] and not prior[k] end
        if edge("b") then if edit then edit=nil else actions.back() end return end
        if edge("mouse") and cursor then
            local x,y=cursor.position.x/scale,cursor.position.y/scale
            for i=#targets,1,-1 do
                local t=targets[i]
                if dock.inside(x,y,t.x,t.y,t.w,t.h) then focus=t.id edit=nil t.run() return end
            end
        end
        if edit then
            local value=state[edit]
            local addition=reskate.input.text(true):gsub("%c","")
            if edge("erase") and #value>0 then value=value:sub(1,(utf8.offset(value,-1) or #value)-1) end
            local limit=({query=80,title=64,description=240,tags=160})[edit]
            if #value+#addition<=limit then value..=addition end
            state[edit]=value
            if edge("a") then local submit=edit=="query" edit=nil if submit then actions.search() end end
            return
        end
        if edge("slash") and state.tab==1 then edit="query" reskate.input.text(true) return end
        if edge("prev") or edge("next") then actions.tab((state.tab-1+(if edge("next") then 1 else -1))%3+1) return end
        local current
        for _,t in targets do if t.id==focus then current=t end end
        if not current then current=targets[2] or targets[1] end
        if not current then return end
        if edge("a") then current.run() return end
        local dx,dy=if edge("r") then 1 elseif edge("l") then -1 else 0,if edge("d") then 1 elseif edge("u") then -1 else 0
        if dx==0 and dy==0 then return end
        local best,score=nil,math.huge
        for _,t in targets do
            local x,y=t.x+t.w/2-current.x-current.w/2,t.y+t.h/2-current.y-current.h/2
            local along=x*dx+y*dy
            local cross=math.abs(x*dy-y*dx)
            if along>1 and along+cross*3<score then score,best=along+cross*3,t end
        end
        focus=(best or current).id
    end
    return {draw=draw,tick=tick,reset=reset}
end
