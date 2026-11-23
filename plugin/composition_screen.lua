local model=require("composition")
local projects=require("studio_projects")
local symbols=require("studio_symbols")
local shapePreview=require("shape_preview")
local lettering=require("lettering")
local pattern=require("pattern")
local dock=require("dock")
local book=require("blackbook")
local imports=require("imports")
local function optionRows(options)
    local rows={}
    for i,option in options do
        if (i-1)%4==0 then table.insert(rows,{}) end
        table.insert(rows[#rows],option)
    end
    return rows
end
local categories={}
for _,group in symbols.categories do table.insert(categories,group[1]) end
local categoryRows,fontRows=optionRows(categories),optionRows(lettering.fonts)

local function tabGrid(ui,id,rows,selected)
    local choice=selected
    for row,options in rows do
        local offset=(row-1)*4
        local active=if selected>offset and selected<=offset+#options then selected-offset else 0
        local index=ui:tabs(id..row,options,active)
        if index~=active then choice=offset+index end
    end
    return choice
end
local function history(stack,p,label)
    table.insert(stack,{p=p,label=label})
    if #stack>40 then table.remove(stack,1) end
end
return function(actions)
    local screen={}
    local p,selected,raw,parts,rendered,gesture,view
    local opened,page,dirty,held,saveAt,note=false,"My Artwork",false,true,0,""
    local past,future,files,thumbs={}, {}, {}, {}
    local filePage,category=1,1
    local newShapeInk=3
    local zoom,panX,panY=1,0,0
    local grid,snap,angleSnap,uniform=true,true,false,true
    local tool,ink,size,opacity,stability,mode,tiles="Brush",3,2,100,25,1,1
    local fine=true
    local editGesture,lastGesture
    local shapeCards={}
    local canvasPlan,wallPreview
    local function selectID(id)
        for i,l in p.layers do if l.id==id then return i,l end end
    end
    local function refresh()
        if rendered~=p then
            raw,parts=model.render(p)
            if not raw then parts={} end
            canvasPlan=nil
            rendered=p
        end
    end
    local function changed(n,label)
        if n==p then return end
        if not editGesture or editGesture~=lastGesture or not past[#past] or past[#past].label~=label then history(past,p,label) end
        lastGesture=editGesture
        table.clear(future)
        p,dirty,saveAt=n,true,reskate.time.now()+700
    end
    local function stampDirty() dirty=true saveAt=reskate.time.now()+700 end
    local function undo(reverse)
        local src,dst=if reverse then future else past,if reverse then past else future
        local h=table.remove(src)
        if h then history(dst,p,h.label) p=h.p stampDirty() end
    end
    local function switchProject(n)
        p,selected,rendered,raw,gesture=n,nil,nil,nil,nil
        table.clear(past) table.clear(future)
        zoom,panX,panY,page,wallPreview=1,0,0,"Compose",false
        if n.layers[#n.layers] then selected=n.layers[#n.layers].id end
        stampDirty()
    end
    local function save(draft)
        refresh()
        local ok,why=projects.save(p,draft,raw)
        if not ok then note="Save failed: "..tostring(why) return false end
        if draft then dirty=false else note="Editable project saved." thumbs[p.id]=nil end
        return true
    end
    local function preserve()
        -- Switching projects also preserves the previous master outside the single draft slot.
        return not p or (save(false) and save(true))
    end
    function screen.open()
        opened,held=true,true
        files=projects.list()
        if not p then
            local draft,msg=projects.draft()
            if draft then p=draft
            elseif msg~="not found" then note=tostring(msg) end
        end
    end
    local function finishGesture()
        if not gesture then return end
        local g=gesture gesture=nil
        if p~=g.start then history(past,g.start,g.label) table.clear(future) stampDirty() end
    end
    function screen.close()
        finishGesture()
        if dirty and p and not save(true) then reskate.ui.toast(note) end
        opened=false view=nil
    end
    function screen.back()
        if page=="My Artwork" then return false end
        finishGesture()
        page=if page=="Compose" then "My Artwork" else "Compose"
        if page=="My Artwork" then files=projects.list() end
        return true
    end
    function screen.title() return page end
    local function add(kind,name)
        local n=model.edit(p)
        local l=model.add(n,kind,name)
        if kind=="shape" then l.ink=newShapeInk end
        selected=l.id changed(n,"add "..kind)
        return l
    end
    function screen.insert(piece,newProject)
        local g,aspect=projects.image(piece)
        if not g then return nil,aspect end
        if newProject or not p then
            if not preserve() then return nil,note end
            local n=model.new() n.name=piece.name:sub(1,60) n.aspect=aspect switchProject(n)
        end
        local n=model.edit(p)
        local l=model.add(n,"image",piece.name:sub(1,60))
        l.grid,l.source=g,piece.id
        l.w=math.min(1,aspect/p.aspect) l.h=l.w*p.aspect/aspect
        selected=l.id changed(n,"add image layer") page="Compose"
        note=if piece.frames and #piece.frames>1 then "First displayed frame added as an image layer." else "Editable image layer added."
        return true
    end
    local function replace(layer,label)
        local i=selectID(layer.id) if not i then return end
        local n=model.edit(p) n.layers[i]=layer changed(n,label)
    end
    local function set(l,k,value,label)
        if l[k]==value then return end
        local n=table.clone(l) n[k]=value replace(n,label)
    end
    local function layerOp(action)
        local i,l=selectID(selected)
        if not l then return end
        if l.locked and action~="Lock" and action~="Hide" then note="Unlock this layer to edit it." return end
        local n=model.edit(p)
        if action=="Duplicate" then
            n.serial+=1 local copy=table.clone(l) copy.id=n.serial copy.group=nil
            copy.name=(l.name:sub(1,56)).." copy" table.insert(n.layers,i+1,copy) selected=copy.id
        elseif action=="Delete" then
            table.remove(n.layers,i) selected=if #n.layers>0 then n.layers[math.min(i,#n.layers)].id else nil
        elseif action=="Raise" or action=="Lower" then
            local j=i+(if action=="Raise" then 1 else -1)
            if not n.layers[j] then return end
            n.layers[i],n.layers[j]=n.layers[j],n.layers[i]
        elseif action=="Group" then
            local below=n.layers[i-1]
            if not below or below.locked then note="Select an unlocked layer above another unlocked layer." return end
            n.serial+=1 local id=below.group or n.serial
            n.layers[i]=table.clone(l) n.layers[i].group=id
            n.layers[i-1]=table.clone(below) n.layers[i-1].group=id
        elseif action=="Ungroup" then
            if not l.group then return end
            for j,item in n.layers do if item.group==l.group then n.layers[j]=table.clone(item) n.layers[j].group=nil end end
        else
            local key=if action=="Hide" then "hidden" else "locked"
            n.layers[i]=table.clone(l) n.layers[i][key]=not l[key]
        end
        changed(n,action:lower().." layer")
    end
    local function transform(base,l,dx,dy,sx,sy,rot)
        local n=model.edit(base)
        local a=math.rad(rot)
        for j,item in base.layers do
            if item.id~=l.id and not (l.group and item.group==l.group) then continue end
            if item.locked then continue end
            local b=table.clone(item)
            local x=(item.x-l.x)*sx*base.aspect local y=(item.y-l.y)*sy
            b.x=math.clamp(l.x+dx+(x*math.cos(a)-y*math.sin(a))/base.aspect,-4,5)
            b.y=math.clamp(l.y+dy+x*math.sin(a)+y*math.cos(a),-4,5)
            b.w,b.h=math.clamp(item.w*sx,.001,10),math.clamp(item.h*sy,.001,10)
            b.angle=(item.angle+rot+180)%360-180
            n.layers[j]=b
        end
        return n
    end
    local function separate(l)
        local n=model.edit(p) local i=selectID(l.id)
        n.layers[i]=table.clone(l) n.layers[i].hidden=true
        if l.font then
            local layout=lettering.layout(l)
            local width,height=model.dimensions(l,p.aspect)
            local insertAt=i
            for _,g in layout.characters do
                if g.cp==32 then continue end
                local b=table.clone(l)
                local line=g.row or (g.y/16+1)
                local row=layout.lines[line]
                local lineHeight=layout.lineHeight or 16
                local left,span
                if layout.smooth then
                    left=g.pen+math.min(0,g.metric[2])
                    span=math.max(g.metric[1],g.metric[2]+g.metric[4])-math.min(0,g.metric[2])
                else left,span=g.x,g.shape.width end
                local u=(left+row.offset+span/2)/layout.width
                b.x,b.y=model.worldPoint(l,p.aspect,u,((line-.5)*lineHeight)/layout.height-l.arch*(.25-(u-.5)^2))
                b.w,b.h=math.max(.001,width*span/layout.width),math.max(.001,height*lineHeight/layout.height)
                b.arch,b.align,b.group=0,1,nil
                n.serial+=1
                b.id,b.name,b.text=n.serial,utf8.char(g.cp),g.text
                insertAt+=1 table.insert(n.layers,insertAt,b)
            end
            changed(n,"separate letters") note="Original lettering kept as a hidden layer."
            return
        end
        local stride=5+l.spacing local length=math.max(1,#l.text*stride-l.spacing)
        local span=math.max(12,length)
        for j=1,#l.text do
            local ch=l.text:sub(j,j) if ch==" " then continue end
            n.serial+=1 local b=table.clone(l)
            b.id,b.group,b.name,b.text,b.align=n.serial,nil,ch,ch,1
            local u=((span-length)*l.align/2+(j-1)*stride+2.5)/span
            b.x,b.y=model.worldPoint(l,p.aspect,u,.5-l.arch*(.25-(u-.5)^2))
            b.arch=0 b.w=l.w*12/span
            table.insert(n.layers,i+j> #n.layers+1 and #n.layers+1 or i+j,b)
        end
        changed(n,"separate letters") note="Original word kept as a hidden layer."
    end
    local function brush(g,u,v)
        local l=g.layer
        local x,y=model.localPoint(l,p.aspect,u,v)
        if x<0 or x>=1 or y<0 or y>=1 then g.lastX=nil return end
        local oldX,oldY=g.lastX or x,g.lastY or y
        local k=1-stability/130
        if tool~="Line" then x,y=oldX+(x-oldX)*k,oldY+(y-oldY)*k end
        if tool=="Line" then oldX,oldY=g.firstX or x,g.firstY or y g.bits=string.split(l.grid.pixels,"") end
        g.firstX,g.firstY=g.firstX or x,g.firstY or y
        local xy={oldX*2048,oldY*1024,x*2048,y*1024}
        local tile=if tiles>1 then {width=2048,height=1024,count=tiles} else nil
        local stroke={xy=xy,size=size*32,symmetry={mode=pattern.modes[mode],x=50,y=50,angle=0,sectors=6}}
        pattern.segments(stroke,tile,function(ax,ay,bx,by)
            for ty=0,tiles-1 do for tx=0,tiles-1 do
                model.stamp(g.bits,(ax/2048+tx)/tiles,(ay/1024+ty)/tiles,(bx/2048+tx)/tiles,(by/1024+ty)/tiles,
                    size/tiles,if tool=="Eraser" then 0 else ink,opacity)
            end end
        end)
        local n=model.edit(g.start) local b=table.clone(l)
        b.grid={w=l.grid.w,h=l.grid.h,pixels=table.concat(g.bits)} n.layers[g.index]=b p=n
        g.lastX,g.lastY=x,y
    end
    -- Keep normal layers in stacking order around the antialiased letters.
    -- The host accepts axis-aligned image UVs and has per-frame draw limits.
    local function buildCanvasPlan()
        local plan,run,total,glyphs={},model.edit(p),0,0
        run.layers={}
        local shapes=0
        for _,l in p.layers do
            if l.kind=="shape" and l.detailed and not l.hidden and l.opacity>0 then shapes+=1 end
        end
        local allowance=math.max(128,math.min(1000,math.floor(1500/math.max(1,shapes))))
        local function flush()
            if #run.layers==0 then return end
            local rawRun,rects=model.render(run)
            if rawRun then table.insert(plan,{rects=rects}) total+=#rects end
            run.layers={}
        end
        for _,l in p.layers do
            if l.hidden or l.opacity==0 then continue end
            local typeface=if l.kind=="text" and l.natural and l.font and l.angle==0 and l.arch==0 and not l.outline
                then lettering.layout(l) else nil
            if l.kind=="shape" and l.detailed then
                flush()
                local ratio=l.w*p.aspect/l.h
                local preview=shapePreview.get(l.symbol,ratio,l.angle,l.flipX,l.flipY,l.outline,allowance)
                local bw,bh=shapePreview.bounds(ratio,l.angle)
                table.insert(plan,{shape=preview,layer=l,w=bw*l.h/p.aspect,h=bh*l.h})
                total+=#preview.parts
            elseif typeface and typeface.smooth then
                flush()
                total+=#typeface.characters
                glyphs+=#typeface.characters
                table.insert(plan,{layer=l,layout=typeface})
            else table.insert(run.layers,l) end
            if total>1800 or glyphs>420 then return {{rects=parts}} end
        end
        if #plan==0 then return {{rects=parts}} end
        flush()
        return if total<=1800 then plan else {{rects=parts}}
    end
    local function drawWriting(d,u,entry,x,y,w,h)
        local l,font=entry.layer,entry.layout
        local lw,lh=model.dimensions(l,p.aspect)
        local colour=book.palette[l.ink]..string.format("%02X",math.round(l.opacity*2.55))
        for _,g in font.characters do
            local m=g.metric
            if m[4]==0 or m[5]==0 then continue end
            local a=(g.x+font.lines[g.row].offset)/font.width
            local b=g.y/font.height
            local gw,gh=m[4]/font.width,m[5]/font.height
            if l.flipX then a=1-a-gw end
            if l.flipY then b=1-b-gh end
            local left,top=l.x+(a-.5)*lw,l.y+(b-.5)*lh
            local right,bottom=left+gw*lw,top+gh*lh
            local x0,y0,x1,y1=math.max(0,left),math.max(0,top),math.min(1,right),math.min(1,bottom)
            if x1<=x0 or y1<=y0 then continue end
            local a0,a1=(x0-left)/(right-left),(x1-left)/(right-left)
            local b0,b1=(y0-top)/(bottom-top),(y1-top)/(bottom-top)
            if l.flipX then a0,a1=1-a0,1-a1 end
            if l.flipY then b0,b1=1-b0,1-b1 end
            d:image("art/lettering/writing-"..m[7]..".png",u.p(x+x0*w,y+y0*h),u.p(x+x1*w,y+y1*h),
                {colour=colour,uv={(m[8]+m[4]*a0)/512,(m[9]+m[5]*b0)/512,(m[8]+m[4]*a1)/512,(m[9]+m[5]*b1)/512}})
        end
    end
    local function layout(d)
        local u=dock.draw(d)
        local left,right=576,u.width
        if right-left<80 then view=nil return end
        u.rect(left,0,right-left,u.height,"#151619")
        local w=math.min((right-left-76)*.86,(u.height-300)*p.aspect)*zoom
        local h=w/p.aspect
        -- Panel coordinates stay independent of the artwork transform.
        local cx,cy=(left+right)/2+panX*(right-left)*.15,u.height*.5+panY*u.height*.12
        local x,y=cx-w/2,cy-h/2
        view={x=x,y=y,w=w,h=h,scale=u.scale}
        d:image("art/checker.png",u.p(x,y),u.p(x+w,y+h))
        u.text(left+30,34,p.name,27,dock.ink,"heading")
        if not canvasPlan then canvasPlan=buildCanvasPlan() end
        for _,entry in (if wallPreview then {{rects=parts}} else canvasPlan) do
            if entry.shape then
                local l=entry.layer
                shapePreview.draw(u,entry.shape,x+(l.x-entry.w/2)*w,y+(l.y-entry.h/2)*h,
                    entry.w*w,entry.h*h,book.palette[l.ink],book.palette[2],l.opacity,view)
            elseif entry.layer then drawWriting(d,u,entry,x,y,w,h)
            else
                for _,b in entry.rects do u.rect(x+(b.x+.5-b.w/2)*w,y+(b.y+.5-b.h/2)*h,b.w*w,b.h*h,book.palette[b.colour]) end
            end
        end
        if grid then
            for j=1,3 do
                local c=if j==2 then "#FF5A1F66" else "#EEEEEE25"
                d:line(u.p(x+w*j/4,y),u.p(x+w*j/4,y+h),{colour=c})
                d:line(u.p(x,y+h*j/4),u.p(x+w,y+h*j/4),{colour=c})
            end
        end
        local _,l=selectID(selected)
        if l and not l.hidden then
            local prev
            for _,corner in {{0,0},{1,0},{1,1},{0,1},{0,0}} do
                local a,b=model.worldPoint(l,p.aspect,corner[1],corner[2])
                local pt=u.p(x+a*w,y+b*h)
                if prev then d:line(prev,pt,{colour=dock.blaze,thickness=2}) end prev=pt
            end
        end
        local c=reskate.input.cursor()
        if c and page=="Freehand" and dock.inside(c.position.x/u.scale,c.position.y/u.scale,x,y,w,h) then
            d:circle(c.position,math.max(3,w*u.scale*size*(if l then l.w else 1)/model.paintW),{colour=book.palette[ink],thickness=2})
        end
        u.text(left+30,u.height-68,if page=="Freehand" then "Drag to draw on the selected paint layer" else "Drag a layer to move it",16,dock.muted)
    end
    reskate.on("draw",function(d)
        if opened and p and page~="My Artwork" then refresh() layout(d) end
    end)
    reskate.on("tick",function()
        if not opened then return end
        if dirty and not gesture and reskate.time.now()>=saveAt then
            if not save(true) then saveAt=reskate.time.now()+5000 end
        end
        if not p or not view or (page~="Compose" and page~="Freehand") then return end
        local c=reskate.input.cursor()
        if not c then finishGesture() held=false return end
        local down=c.left local px,py=c.position.x/view.scale,c.position.y/view.scale
        local u,v=(px-view.x)/view.w,(py-view.y)/view.h
        local inside=px>576 and u>=0 and u<1 and v>=0 and v<1
        if down and not held and inside then
            local i,l=selectID(selected)
            if page=="Compose" then
                i=model.pick(p,u,v) l=if i then p.layers[i] else nil
                if l then selected=l.id end
            elseif tool=="Picker" then
                refresh()
                for _,part in parts do
                    local left,top=part.x+.5-part.w/2,part.y+.5-part.h/2
                    if u>=left and u<left+part.w and v>=top and v<top+part.h then
                        ink=part.colour
                        break
                    end
                end
                held=down
                return
            elseif not l or l.kind~="paint" then note="Select or add a paint layer." held=down return end
            if l and not l.locked and not l.hidden then
                gesture={index=i,layer=l,start=p,x=u,y=v,label=if page=="Compose" then "layer move" else "brush stroke"}
                if page=="Freehand" then gesture.bits=string.split(l.grid.pixels,"") end
            end
        end
        if gesture and down and (u~=gesture.u or v~=gesture.v) then
            local g=gesture g.u,g.v=u,v
            if page=="Freehand" then if inside then brush(g,u,v) else g.lastX=nil end
            else
                local x,y=g.layer.x+u-g.x,g.layer.y+v-g.y
                if snap and math.abs(x-.5)<.014 then x=.5 end
                if snap and math.abs(y-.5)<.014 then y=.5 end
                if x~=g.layer.x or y~=g.layer.y then p=transform(g.start,g.layer,x-g.layer.x,y-g.layer.y,1,1,0) end
            end
        end
        if not down then finishGesture() end held=down
    end)
    local function listLayers(ui)
        for i=#p.layers,1,-1 do
            local l=p.layers[i]
            local label=string.format("%02d   %s   %s%s%s",i,l.name,if l.group then "Group " else "",if l.hidden then "Hidden " else "",if l.locked then "Locked" else "")
            if ui:button("layer-"..l.id,label,l.id==selected) then selected=l.id end
        end
    end
    local function saveUse(ui)
        if ui:button("master","Save project",true) then save(false) end
        if ui:button("premade","Save as premade") then
            refresh() local pie,why=projects.premade(p,raw) note=if pie then "Saved to My imports." else tostring(why)
        end
        for _,action in {"Place in World","Assign as Emote","Share Publicly"} do
            if ui:button(action,action) then
                refresh()
                if action=="Assign as Emote" then
                    if raw then actions.use(action,{id="studio/"..p.id,name=p.name,aspect=p.aspect,parts=parts})
                    else note="Add visible ink first." end
                    return
                end
                local pie,why=projects.premade(p,raw)
                if not pie then note=tostring(why) else actions.use(action,pie) end
                return
            end
        end
    end
    function screen.panel(ui)
        editGesture=ui:editingGesture()
        if not editGesture then lastGesture=nil end
        if page=="My Artwork" then
            if ui:button("new","Create new",true) and preserve() then switchProject(model.new()) return end
            if p and ui:button("continue","Continue editing "..p.name) then page="Compose" return end
            if ui:button("source","Start from premade or imported artwork") then actions.browse(true) return end
            if ui:button("emotes","Emote loadout") then actions.emotes() return end
            ui:note("Open a saved project")
            for i=(filePage-1)*4+1,math.min(filePage*4,#files) do
                local id=files[i]
                if not thumbs[id] then
                    local doc,t=projects.open(id)
                    thumbs[id]={id=id,name=if doc then doc.name else "Unreadable project",aspect=if doc then doc.aspect else 1,
                        parts=if doc and t then imports.decode(t) else nil,category="Editable project"}
                end
                if ui:piece("project-"..id,thumbs[id],false) then
                    if not preserve() then return end
                    local doc,msg=projects.open(id) if doc then switchProject(doc) else note=tostring(msg) end
                end
            end
            if filePage>1 and ui:button("prev","Previous projects") then filePage-=1 end
            if filePage*4<#files and ui:button("next","More projects") then filePage+=1 end
        elseif p then
            local tabs={"Compose","Shapes","Lettering","Freehand","Save & Use"}
            local idx=ui:tabs("views",tabs,table.find(tabs,page) or 1)
            if tabs[idx]~=page then finishGesture() page=tabs[idx] held=true return end
            local _,l=selectID(selected)
            if page=="Shapes" then
                newShapeInk=ui:inks("new-shape-ink",newShapeInk,"New shape colour")
                category=tabGrid(ui,"categories",categoryRows,category)
                for i=2,#symbols.categories[category] do
                    local name=symbols.categories[category][i]
                    if not shapeCards[name] then
                        local aspect=symbols.aspect(name)
                        shapeCards[name]={name=name,aspect=aspect,stencil=shapePreview.get(name,aspect,0,false,false,false,150)}
                    end
                    shapeCards[name].ink=newShapeInk
                    if ui:piece("symbol-"..name,shapeCards[name],false) then add("shape",name) page="Compose" return end
                end
            elseif page=="Lettering" then
                if ui:button("addword","Add text layer",true) then l=add("text","Lettering") end
                if l and l.kind=="text" and not l.locked then
                    local entered=ui:text("word","Your lettering   "..utf8.len(l.text).." / "..lettering.limit,l.text,"Type a tag or phrase")
                    if entered~=l.text then
                        local word=lettering.limitText(entered)
                        if not word then note="ReSkate sent an unreadable character." return end
                        if word~=entered then note="This text layer holds "..lettering.limit.." characters." end
                        if word~=l.text then
                            local nextLayer=table.clone(l)
                            nextLayer.text=word
                            if not l.font and word:find("[^A-Z0-9 !?%.%'%-]") then nextLayer.font="Slab" end
                            replace(nextLayer,"text change")
                        end
                        return
                    end
                    ui:note("Font preset")
                    local font=lettering.fonts[tabGrid(ui,"fonts",fontRows,table.find(lettering.fonts,l.font) or 0)]
                    if font and font~=l.font then
                        local nextLayer=table.clone(l)
                        nextLayer.font,nextLayer.natural=font,true
                        replace(nextLayer,"font change") return
                    end
                    if l.font and not l.natural and ui:button("natural-font","Use natural lettering") then
                        set(l,"natural",true,"natural lettering") return
                    end
                    if ui:button("wall-proof",if wallPreview then "Show Studio lettering" else "Preview wall detail") then wallPreview=not wallPreview end
                    if not l.font then
                        local style=symbols.styles[ui:tabs("styles",symbols.styles,table.find(symbols.styles,l.style))]
                        if style~=l.style then set(l,"style",style,"lettering style") return end
                    else
                        if lettering.layout(l).missing then ui:note("A boxed character is missing from the packaged fonts.") end
                        if #l.text<=40 and not l.text:find("[^A-Z0-9 !?%.%'%-]") and ui:button("classic","Use classic presets") then
                            set(l,"font",nil,"font change") return
                        end
                    end
                    ui:note("Ctrl+A replaces the text. Shift+Enter adds a line.")
                    local spacing=ui:slider("spacing","Letter spacing",l.spacing,0,5)
                    if spacing~=l.spacing then set(l,"spacing",spacing,"letter spacing") return end
                    local align=ui:tabs("align",{"Left","Centre","Right"},l.align+1)-1
                    if align~=l.align then set(l,"align",align,"text alignment") return end
                    local deform=model.deformations[ui:tabs("text-warp",model.deformations,table.find(model.deformations,l.deform or "Arch"))]
                    if deform~=(l.deform or "Arch") then set(l,"deform",deform,"text deformation") return end
                    local arch=ui:slider("arch","Deformation strength",math.round(l.arch*100),-100,100)/100
                    if arch~=l.arch then set(l,"arch",arch,"text deformation") return end
                    if utf8.len(l.text)>1 and ui:button("split","Separate letters and keep original") then separate(l) end
                end
                if ui:button("system-fonts","System fonts and emoji…") then
                    local ok,why=imports.reveal()
                    note=if ok then "Open Import Artwork.html and choose Type lettering with system fonts." else tostring(why)
                    reskate.ui.toast(note)
                end
                listLayers(ui)
            elseif page=="Freehand" then
                if ui:button("paint-layer","Add paint layer",true) then l=add("paint","Paint") end
                local tools={"Brush","Line","Eraser","Picker"} tool=tools[ui:tabs("tool",tools,table.find(tools,tool))]
                ink=ui:inks("brush-ink",ink)
                size=ui:slider("brush-size","Brush radius",size,1,12)
                opacity=ui:slider("brush-opacity","Brush opacity",opacity,1,100)
                stability=ui:slider("steady","Stroke stabilisation",stability,0,90)
                mode=ui:tabs("mirror",pattern.modes,mode) tiles=ui:slider("repeat","Tile repeats",tiles,1,4)
                listLayers(ui)
            elseif page=="Save & Use" then
                local name=ui:text("name","Project title",p.name,"Untitled"):sub(1,60)
                if name~=p.name then local n=model.edit(p) n.name=name changed(n,"project title") end
                if ui:button("export-proof",if wallPreview then "Show Studio detail" else "Preview wall detail") then wallPreview=not wallPreview end
                saveUse(ui)
            else
                if l and l.kind=="shape" and not l.locked then
                    local colour=ui:inks("selected-shape-ink",l.ink,"Shape colour")
                    if colour~=l.ink then set(l,"ink",colour,"shape colour") return end
                end
                if ui:button("insert","Add premade, import or Blackbook image") then actions.browse(false) return end
                listLayers(ui)
                if l then
                    local name=ui:text("layer-name","Layer name",l.name,"Layer"):sub(1,64)
                    if name~=l.name and not l.locked then set(l,"name",name,"layer rename") return end
                    for _,op in {"Hide","Lock","Raise","Lower","Duplicate","Delete","Group","Ungroup"} do
                        local label=if op=="Lock" and l.locked then "Unlock" elseif op=="Hide" and l.hidden then "Show" elseif op=="Group" then "Group with layer below" else op
                        if ui:button(op,label) then layerOp(op) return end
                    end
                    if not l.locked then
                        if ui:button("centre","Snap layer to centre") then changed(transform(p,l,.5-l.x,.5-l.y,1,1,0),"layer move") return end
                        if l.kind=="shape" and not l.detailed and ui:button("smooth-shape","Use smooth shape") then
                            set(l,"detailed",true,"smooth shape") return
                        end
                        if ui:button("fine",if fine then "Adjustment: fine" else "Adjustment: coarse") then fine=not fine end
                        local dirs={"←","→","↑","↓"} for i,dir in dirs do
                            if ui:button("nudge"..i,"Move "..dir) then
                                local amt=if fine then .005 else .05
                                changed(transform(p,l,if i==1 then -amt elseif i==2 then amt else 0,if i==3 then -amt elseif i==4 then amt else 0,1,1,0),"layer move") return
                            end
                        end
                        if ui:button("ratio",if uniform then "Aspect ratio locked" else "Aspect ratio unlocked") then uniform=not uniform end
                        for _,dim in {"w","h"} do
                            local old=math.round(l[dim]*100)
                            local val=ui:slider("dimension"..dim,if dim=="w" then "Width" else "Height",old,1,300)
                            if val~=old then
                                local k=val/100/l[dim]
                                changed(transform(p,l,0,0,if uniform or dim=="w" then k else 1,if uniform or dim=="h" then k else 1,0),"layer scale") return
                            end
                        end
                        local a=ui:slider("angle","Rotation",math.round(l.angle),-180,180)
                        if a~=math.round(l.angle) then
                            if angleSnap then a=15*math.round(a/15) end
                            changed(transform(p,l,0,0,1,1,a-l.angle),"layer rotation") return
                        end
                        for _,key in {"flipX","flipY","outline"} do
                            if (key~="outline" or not l.grid) and ui:button(key,if key=="outline" then "Toggle outline" elseif key=="flipX" then "Flip horizontally" else "Flip vertically") then
                                set(l,key,not l[key],"layer "..key) return
                            end
                        end
                        if l.kind=="text" then
                            local c=ui:inks("ink",l.ink)
                            if c~=l.ink then set(l,"ink",c,"layer colour") return end
                        end
                        local alpha=ui:slider("alpha","Layer opacity",l.opacity,0,100)
                        if alpha~=l.opacity then set(l,"opacity",alpha,"layer opacity") return end
                    end
                end
            end
            if page=="Freehand" or page=="Compose" then
                if ui:button("grid",if grid then "Hide guides" else "Show guides") then grid=not grid end
                if ui:button("snap",if snap then "Centre snapping on" else "Centre snapping off") then snap=not snap end
                if ui:button("angle-snap",if angleSnap then "15° snapping on" else "15° snapping off") then angleSnap=not angleSnap end
                zoom=ui:slider("zoom","Zoom",math.round(zoom*100),40,180)/100
                panX=ui:slider("pan-x","Pan horizontal",math.round(panX*100),-100,100)/100
                panY=ui:slider("pan-y","Pan vertical",math.round(panY*100),-100,100)/100
            end
            if #past>0 and ui:button("undo","Undo "..past[#past].label) then undo(false) end
            if #future>0 and ui:button("redo","Redo "..future[#future].label) then undo(true) end
            if ui:button("projects","My Artwork") then finishGesture() page="My Artwork" files=projects.list() end
        end
        if note~="" then ui:note(note) end
    end
    return screen
end
