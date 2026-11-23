local library=require("library")
local book=require("blackbook")
local imports=require("imports")
local dock=require("dock")
local function searchable(piece)
    return string.lower(table.concat({piece.name,piece.category or "",piece.lettering or "",piece.number or "",
        piece.creator or "",table.concat(piece.tags or {}," ")}," "))
end
return function(stock,onAim,exit,onMap,useSelected,purpose,offerEmote,loadout)
    local projects=require("studio_projects")
    local rows,queue,filtered,selected={}, {}, {},nil
    local query,folderName,folder,favourites,recent,page,note="", "", nil,false,false,1,""
    local taskIndex,open=1,false
    local lastPurpose
    local inbox,inboxPage={},1
    local function filter()
        filtered=library.filter(rows,query,folder,favourites,recent)
        page=math.clamp(page,1,math.max(1,math.ceil(#filtered/6)))
        if selected and not table.find(filtered,selected) then selected=nil end
    end
    local function result(ok,why)
        note=if ok then "Library saved." else tostring(why or "Could not save changes.")
        filter()
    end
    local reshape
    local function begin()
        if reshape then reshape.close() end
        local intent=purpose()
        if intent~=lastPurpose then
            query,folder,favourites,recent,page="",nil,false,false,1
            lastPurpose=intent
        end
        rows,queue,selected,taskIndex,open={},{},nil,1,true
        inbox={} inboxPage=1
        for _,file in reskate.files.list("imports") or {} do
            if file:match("^[%w _%-]+%.collection$") and #file<=76 then table.insert(inbox,file) end
        end
        table.sort(inbox)
        for _,p in stock do
            if not p.file then local row=table.clone(p) row.search=searchable(row) table.insert(rows,row) end
        end
        for _,p in imports.list() do
            p.search=searchable(p) table.insert(rows,p)
            if p.downloaded then table.insert(queue,p) end
        end
        for _,file in book.list() or {} do table.insert(queue,{drawing=file}) end
        if intent=="Equip in selected slot" then
            for _,id in projects.list() do table.insert(queue,{project=id}) end
        end
        local _,why=library.get()
        note=why or ""
        filter()
    end
    reshape=require("reshape_screen")(function(file)
        begin()
        for _,row in rows do
            if row.file=="imports/"..file then
                selected=row
                query,folder,favourites,recent="",nil,false,false
                filter()
                page=math.ceil((table.find(filtered,row) or 1)/6)
                imports.load(row)
                break
            end
        end
        note="Copy saved to My imports."
    end)
    local function prepare(p)
        return projects.prepare(p,purpose()=="Equip in selected slot")
    end
    local function tick()
        if open and reshape.active() then reshape.tick() return end
        if not open then return end
        if not queue[taskIndex] then
            for i=(page-1)*6+1,math.min(page*6,#filtered) do
                local row=filtered[i]
                if not row.sheet and not row.parts and not row.problem then
                    local ok,why=prepare(row)
                    if not ok then row.problem=tostring(why) end
                    break
                end
            end
            return
        end
        local p=queue[taskIndex]
        taskIndex+=1
        if p.drawing then
            local doc=book.read(p.drawing)
            if doc then p.id,p.name,p.category,p.aspect=p.drawing,doc.name,"Blackbook",2 p.search=searchable(p) table.insert(rows,p) end
        elseif p.project then
            local master,thumb=projects.open(p.project)
            if master then
                p.id,p.name,p.category,p.aspect="studio/"..p.project,master.name,"Editable project",master.aspect
                p.rawFrame,p.search=thumb,searchable(p)
                table.insert(rows,p)
            end
        elseif p.downloaded then imports.load(p) p.search=searchable(p) end
        filter()
    end
    reskate.on("tick",tick)
    local function draw(d)
        if open and reshape.active() then reshape.draw(d) return end
        local p=selected
        if not open or not p then return end
        local u=dock.draw(d)
        local w=228*math.min(1,p.aspect or 1)
        local h=w/(p.aspect or 1)
        local x,y=u.width-32-w,86
        d:image("art/checker.png",u.p(x,y),u.p(x+w,y+h))
        if p.parts then
            for _,part in p.parts do
                u.rect(x+(part.x+.5-part.w/2)*w,y+(part.y+.5-part.h/2)*h,part.w*w,part.h*h,book.palette[part.colour])
            end
        elseif p.sheet then d:image(p.sheet,u.p(x,y),u.p(x+w,y+h),{uv=p.thumb}) end
    end
    reskate.on("draw",draw)
    local function panel(ui)
        if reshape.active() then reshape.panel(ui) return end
        local state,why=library.get()
        local nextQuery=ui:text("lib-query","Search",query,"Name, creator or tag")
        if nextQuery~=query then query=nextQuery:sub(1,80) page=1 filter() end
        local mode=ui:tabs("lib-mode",{"All","Recent"},if recent then 2 else 1)
        if (mode==2)~=recent then recent=mode==2 page=1 filter() end
        if ui:button("lib-favfilter",if favourites then "Showing favourites" else "Show favourites") then favourites=not favourites page=1 filter() end
        local names={}
        for name in (state and state.folders or {}) do table.insert(names,name) end
        table.sort(names)
        if ui:button("lib-folder","Folder: "..(folder or "All folders").."  (cycle)") then
            folder=names[(table.find(names,folder or "") or 0)+1]
            page=1 filter()
        end
        if #filtered==0 then ui:note(if taskIndex<=#queue then "Reading artwork..." else "No artwork matches these filters.") end
        for i=(page-1)*6+1,math.min(page*6,#filtered) do
            local p=filtered[i]
            if ui:piece("lib-item-"..i,p,p==selected) then
                selected=p local ok,msg=prepare(p) note=if ok then p.creator or p.category or "" else tostring(msg)
            end
        end
        if page>1 and ui:button("lib-prev","Previous page") then page-=1 end
        if page*6<#filtered and ui:button("lib-next","Next page") then page+=1 end
        local intent=purpose()
        if intent=="Equip in selected slot" then
            if selected and ui:button("studio-use",intent,true) then
                local ok,msg=useSelected(selected)
                if ok then return end
                note=tostring(msg)
            end
            ui:note(note)
            if ui:button("emote-back","Back to loadout") then loadout() end
            return
        end
        if selected then
            local p=selected
            ui:info("Artwork",p.name:sub(1,60))
            if intent and ui:button("studio-use",intent,true) then
                local ok,msg=prepare(p)
                if ok then ok,msg=useSelected(p) end
                if ok then return end
                note=tostring(msg)
            end
            if ui:button("lib-place","Place on wall",true) then
                local ok,msg=prepare(p)
                if ok then open=false onAim(p) return else note=tostring(msg) end
            end
            if not intent and ui:button("lib-emote","Use as emote") then offerEmote(p) return end
            if ui:button("lib-reshape","Reshape artwork",true) then
                local ok,msg=prepare(p)
                if ok then ok,msg=reshape.open(p) end
                if ok then return end
                note=tostring(msg)
            end
            if state and ui:button("lib-star",if (state.items[p.id] or {}).favourite then "Remove favourite" else "Favourite artwork") then
                result(library.change("favourite",p.id))
            end
            if state and ui:button("lib-move","Move artwork to "..(folderName~="" and folderName or "no folder")) then
                result(library.change("move artwork",p.id,if folderName=="" then nil else folderName))
            end
        end
        folderName=ui:text("lib-name","Folder name",folderName,"New name or move destination"):sub(1,40)
        if state and ui:button("lib-new","Create folder") then result(library.change("create folder",nil,folderName)) end
        if folder and ui:button("lib-rename","Rename selected folder") then
            local ok,msg=library.change("rename folder",folder,folderName)
            if ok then folder=folderName end result(ok,msg)
        end
        if folder and ui:button("lib-remove","Remove folder and keep its artwork") then
            local ok,msg=library.change("remove folder",folder)
            if ok then folder=nil end result(ok,msg)
        end
        for i,forward in {false,true} do
            local action=library.history(forward,false)
            if action and ui:button("lib-history-"..i,(if forward then "Redo " else "Undo ")..action) then
                local ok,msg=library.history(forward,true)
                if ok and folder and not library.get().folders[folder] then folder=nil end
                if ok and action=="collection import" then begin() end result(ok,msg)
            end
        end
        ui:note(tostring(why or note):sub(1,160))
        if selected and not selected.file and not selected.drawing and ui:button("edit-stock","Prepare a custom copy") then
            local ok,msg=imports.stockSource(selected)
            note=if ok then "Choose "..selected.id..".png in the image preparer." else tostring(msg)
        end
        if #inbox>0 then
            if #inbox>1 and ui:button("collection-next","Choose collection: "..inbox[inboxPage]) then inboxPage=inboxPage%#inbox+1 end
            if ui:button("collection-add","Import "..inbox[inboxPage]) then
                local ok,msg=imports.addCollection(inbox[inboxPage])
                if ok then begin() end result(ok,msg)
            end
        end
        if ui:button("prepare","Open image preparer") then
            local ok,msg=imports.reveal()
            note=if ok then "Open Import Artwork.html and choose your source." else tostring(msg)
        end
        local player=require("playback")
        local volume=player.volume()
        local newGain=math.round(ui:slider("lab-volume","Spray volume (0 mutes)",volume,0,100))
        if newGain~=volume then local ok,msg=player.setVolume(newGain) if not ok then note=tostring(msg) end end
        if ui:button("map-tools","Edit placements on this map") then onMap() end
        if ui:button("lib-back","Back to Graffiti Lab") then open=false exit() end
    end
    return {open=begin,close=function() open=false reshape.close() end,panel=panel,
        title=function() return if reshape.active() then "Reshape Artwork" else "Artwork Library" end,
        back=function()
            if reshape.active() then reshape.close() return true end
            if purpose()=="Equip in selected slot" then loadout() return true end
            return false
        end}

end
