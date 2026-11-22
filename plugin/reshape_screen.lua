local shape=require("reshape")
local arch=require("native_arch")
local dock=require("dock")
local palette=require("blackbook").palette
local cornerNames={"Top left","Top right","Bottom right","Bottom left"}

return function(saved)
    local editor={}
    local source,settings,name,frame,corner,raw,parts,message
    local textureParts,textureSheet
    local past,future,view,held,dragging,job
    local function remember(stack,value)
        table.insert(stack,value)
        if #stack>32 then table.remove(stack,1) end
    end
    local function change(value,history)
        if history then remember(past,settings) table.clear(future) end
        settings,raw,parts=value,nil,nil
    end
    local function render()
        local value,result=shape.render(source,settings,frame)
        raw=value or false
        parts=if value then result else {}
        textureParts,textureSheet=arch.parts(arch.identify(source,settings))
        message=if value then "" else tostring(result)
    end
    function editor.close() source,job,dragging,view=nil,nil,nil,nil end
    function editor.active() return source~=nil end
    function editor.open(p)
        local src,value=shape.source(p)
        if not src then return nil,value end
        source,settings,name=src,value,if p.reshape then p.name else p.name.." reshaped"
        frame,corner,past,future,raw,parts,message,held=1,1,{},{},nil,nil,"",true
        job,view,dragging=nil,nil,nil
        textureParts,textureSheet=nil,nil
        return true
    end
    function editor.draw(d)
        local u=dock.draw(d)
        local l,r=600,u.width-28
        if r<=l+60 then view=nil return end
        local w=math.min((r-l)/1.6,(u.height-180)*source.aspect/1.9)
        local h=w/source.aspect
        local x,y=(l+r-w)/2,(u.height-h)/2
        view={x=x,y=y,w=w,h=h,left=l,right=r,bottom=u.height-108,scale=u.scale}
        u.rect(l,54,r-l,u.height-108,dock.panel)
        u.text(l+20,76,name,22,dock.ink,"heading")
        local box=shape.bounds(settings,source.aspect)
        local bx,by,bw,bh=x+box.l*w,y+box.t*h,box.w*w,box.h*h
        u.border(bx-1,by-1,bw+2,bh+2,"#48484A")
        d:image("art/checker.png",u.p(bx,by),u.p(bx+bw,by+bh))
        if textureParts then
            arch.draw(d,u,textureParts,textureSheet,bx,by,bw,bh)
        else
            for _,p in parts or {} do
                u.rect(bx+(p.x+.5-p.w/2)*bw,by+(p.y+.5-p.h/2)*bh,p.w*bw,p.h*bh,palette[p.colour])
            end
        end
        local handles=shape.handles(settings)
        for i=1,#handles,2 do
            local hx,hy=x+handles[i]*w,y+handles[i+1]*h
            u.rect(hx-9,hy-9,18,18,dock.dark)
            u.rect(hx-6,hy-6,12,12,if settings.mode~="Corners" or i==2*corner-1 then dock.blaze else dock.ink)
        end
        u.text(l+16,u.height-92,"Drag a handle or click the preview to position it.",16,dock.muted,"body")
    end
    function editor.tick()
        if job then
            local i=#job+1
            local data,why=shape.render(source,settings,i)
            if not data then job=nil message="Frame "..i..": "..tostring(why) return end
            table.insert(job,data)
            if i==#source.grids then
                local file,reason=shape.save(name,source,settings,job)
                job=nil
                if file then editor.close() saved(file) else message=tostring(reason) end
            end
            return
        end
        local cursor=reskate.input.cursor()
        local down=cursor and (cursor.left or reskate.input.key(1))
        if cursor and view then
            local px,py=cursor.position.x/view.scale,cursor.position.y/view.scale
            if down and not held and px>=view.left and px<=view.right and py>=108 and py<=view.bottom then
                local handles=shape.handles(settings)
                local nearest,distance=1,math.huge
                for i=1,#handles,2 do
                    local dx=px-view.x-handles[i]*view.w
                    local dy=py-view.y-handles[i+1]*view.h
                    if dx*dx+dy*dy<distance then nearest,distance=(i+1)/2,dx*dx+dy*dy end
                end
                if settings.mode=="Corners" then corner=nearest end
                dragging={index=nearest,start=settings}
                if distance<=16*16 then
                    local i=nearest*2-1
                    dragging.dx=view.x+handles[i]*view.w-px
                    dragging.dy=view.y+handles[i+1]*view.h-py
                end
            end
            if dragging then
                if px~=dragging.lastX or py~=dragging.lastY then
                    local x=(px+(dragging.dx or 0)-view.x)/view.w
                    local y=(py+(dragging.dy or 0)-view.y)/view.h
                    change(shape.drag(dragging.start,dragging.index,x,y),false)
                    dragging.lastX,dragging.lastY=px,py
                end
                if not down then
                    remember(past,dragging.start) table.clear(future)
                    dragging=nil
                end
            end
        end
        held=down
        if raw==nil then render() end
    end
    function editor.panel(ui)
        ui:note("Reshape a copy for your artwork library.")
        if job then ui:note("Rendering frame "..(#job+1).." of "..#source.grids) return end
        local mode=shape.modes[ui:tabs("shape-mode",shape.modes,table.find(shape.modes,settings.mode))]
        if mode and mode~=settings.mode then local next=table.clone(settings) next.mode=mode change(next,true) end
        if settings.mode=="Corners" then
            corner=ui:tabs("shape-corner",cornerNames,corner)
            local i=2*corner-1
            local id=shape.identity().corners
            local dx=math.round(100*(settings.corners[i]-id[i]))
            local dy=math.round(100*(settings.corners[i+1]-id[i+1]))
            local x=math.round(ui:slider("shape-x","Horizontal (%)",dx,-24,24))
            local y=math.round(ui:slider("shape-y","Vertical (%)",dy,-24,24))
            if dx~=x or dy~=y then change(shape.drag(settings,corner,id[i]+x/100,id[i+1]+y/100),true) end
        else
            local pct=math.round(settings.amount*100)
            local amount=math.round(ui:slider("shape-strength","Strength (%)",pct,-100,100))
            if amount~=pct then local next=table.clone(settings) next.amount=amount/100 change(next,true) end
        end
        if #source.grids>1 and ui:button("shape-frame","Preview frame "..frame.." / "..#source.grids) then
            frame=frame%#source.grids+1 raw,parts=nil,nil
        end
        if #past>0 and ui:button("shape-undo","Undo reshape edit") then
            remember(future,settings) change(table.remove(past),false)
        end
        if #future>0 and ui:button("shape-redo","Redo reshape edit") then
            remember(past,settings) change(table.remove(future),false)
        end
        if ui:button("shape-reset","Reset to original shape") then change(shape.identity(),true) end
        name=ui:text("shape-name","Copy name",name,"Name your artwork"):sub(1,64)
        if ui:button("shape-save","Apply and save copy",true) then job={} end
        if ui:button("shape-cancel","Cancel and return to library") then editor.close() return end
        if message~="" then ui:note(message) end
    end
    return editor
end
