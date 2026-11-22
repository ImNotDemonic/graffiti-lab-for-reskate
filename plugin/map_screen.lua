local storage=require("placements")
return function(actions)
    local selected,page,scale,angle,note=nil,1,1,0,""
    local stretch,unlocked=1,false
    local function pick(row)
        selected=row
        scale,angle=if row then row.scale else 1,if row then row.angle else 0
        stretch=if row then row.stretch or 1 else 1
        unlocked=stretch~=1
        actions.preview(row,scale,angle,stretch)
    end
    local function clear() pick(nil) end
    local function finish(ok,msg)
        if ok then note="Placement saved." clear() else note=tostring(msg or "Could not save placement.") end
    end
    local function panel(ui)
        local rows=storage.rows()
        page=math.clamp(page,1,math.max(1,math.ceil(#rows/6)))
        ui:note("World placement editing")
        if #rows==0 then ui:note("Place artwork on this map to edit it here.") end
        for i=(page-1)*6+1,math.min(#rows,page*6) do
            local r=rows[i]
            if ui:button("mark"..i,(if r==selected then "> " else "")..r.name:sub(1,36).." / "..r.id:sub(2,9)) then pick(r) end
        end
        if page>1 and ui:button("mprev","Previous placements") then page-=1 end
        if page*6<#rows and ui:button("mnext","More placements") then page+=1 end
        if selected then
            local pct=ui:slider("scale","Size (%)",math.round(scale*100),10,500)
            local deg=ui:slider("angle","Rotation (degrees)",angle,-180,180)
            if ui:button("lock",if unlocked then "Lock proportions" else "Unlock proportions") then
                unlocked=not unlocked
                if not unlocked then stretch=1 actions.preview(selected,scale,angle,stretch) end
            end
            local horizontal=if unlocked then ui:slider("stretch","Width (%)",math.round(stretch*100),10,500)/100 else stretch
            if pct/100~=scale or deg~=angle or horizontal~=stretch then
                stretch=horizontal
                scale,angle=pct/100,deg
                local ok,why=actions.preview(selected,scale,angle,stretch) note=if ok then "Preview" else tostring(why)
            end
            if ui:button("reset","Reset to original size and angle") then scale,angle,stretch=1,0,1 actions.preview(selected,scale,angle,stretch) end
            if ui:button("apply","Apply placement settings",true) then finish(actions.change("placement transform",selected,scale,angle,stretch)) end
            if selected and ui:button("move","Move to another wall") then actions.aim(selected,scale,angle,false,stretch) return end
            if selected and ui:button("copy","Duplicate and aim") then actions.aim(selected,scale,angle,true,stretch) return end
            if selected and ui:button("delete","Remove this placement") then finish(actions.change("placement deletion",selected)) end
            if selected and ui:button("cancel","Cancel preview") then clear() end
        end
        for i,forward in {false,true} do
            local what=storage.history(forward)
            if what and ui:button("hist"..i,(if forward then "Redo " else "Undo ")..what) then
                clear() finish(actions.history(forward))
            end
        end
        ui:note(note:sub(1,150))
        if ui:button("back","Back to artwork library") then clear() actions.library() end
    end
    return {open=function() page=1 note="" clear() end,close=clear,panel=panel}
end
