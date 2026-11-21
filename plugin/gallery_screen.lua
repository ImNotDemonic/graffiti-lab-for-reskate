local api=require("gallery")
local imports=require("imports")
local dock=require("dock")
local palette=require("blackbook").palette
local screen="Public Artworks"
local function trim(s) return s:match("^%s*(.-)%s*$") end
local function short(value,n)
    -- Display native widget labels within their byte budgets.
    if #value<=n then return value end
    local ending=n-3
    while ending>0 and (value:byte(ending+1) or 0)>=128 and (value:byte(ending+1) or 0)<192 do ending-=1 end
    return value:sub(1,ending).."..."
end
return function(onBack)
    local open,busy,generation=false,false,0
    local tab,query,page,rows,more=1,"",1,{},false
    local selection,profiles,profile=nil,{},nil
    local sources,sourcePage={},1
    local image,aspect,raw,pieceTitle,description,tagText=nil,1,nil,"","",""
    local note,lastRequest,op,opContent="",nil,nil,nil
    local sequence=0
    local function show(frame)
        if frame then image,aspect=imports.decode(frame) else image,aspect=nil,1 end
    end
    local function invalidate()
        generation+=1 busy=false lastRequest=nil
    end
    local function request(message,send,thenDo)
        invalidate()
        busy,note=true,message
        local id=generation
        lastRequest=function() request(message,send,thenDo) end
        send(function(result,why)
            if not open or id~=generation then return end
            busy=false
            if not result then note=tostring(why or "Gallery unavailable") return end
            lastRequest=nil thenDo(result,why)
        end)
    end
    local function browse(n)
        local needle=query
        request("Loading artwork…",function(done) api.browse(needle,n,done) end,function(data)
            page,rows,more,selection=n,data.items,data.more==true,nil
            show(nil)
            note=if #rows==0 then "No matching artwork." else "Select a piece to preview it."
        end)
    end
    local function refreshSources()
        sources,sourcePage=api.sources(),1
        raw,op=nil,nil show(nil)
        note=if #sources==0 then "Save a Blackbook drawing or import a piece first." else "Choose your own artwork to preview it."
    end
    local function chooseTab(value)
        invalidate() tab=value raw,selection=nil,nil show(nil)
        if tab==1 then browse(1) elseif tab==2 then refreshSources() else note="Select the gallery identity for this installation." end
    end
    local function buyCopy(item)
        local account=profile
        request("Downloading "..item.title.."…",function(done) api.download(item.id,account,done) end,function(data)
            local ok,message=api.store(data,item.id)
            if not ok then note="Download could not be saved: "..tostring(message) return end
            note=message..(if data.downloadedBy then " as "..data.downloadedBy else "")
            reskate.log("Gallery downloaded "..data.id.." by "..data.creator.." as "..(data.downloadedBy or "guest"))
        end)
    end
    local function publish()
        if not raw or not profile or trim(pieceTitle)=="" then note="Choose a profile, a piece and a title." return end
        local tags={}
        for tag in tagText:gmatch("[^,]+") do
            tag=trim(tag)
            if #tag>24 or #tags>=8 then note="Use up to eight tags of 24 bytes each." return end
            if #tag>0 then table.insert(tags,tag) end
        end
        local account=profile
        local data={title=trim(pieceTitle),description=trim(description),tags=if #tags>0 then tags else nil,
            asset={version=1,kind="ink",frames={raw},frameMs=250}}
        local signature=reskate.json.encode(data)
        if not op or opContent~=signature then
            sequence+=1
            op=string.format("game-%d-%d-%d",math.floor(reskate.time.now()),math.random(1,1000000000),sequence)
            opContent=signature
        end
        data.operation=op
        request("Publishing "..data.title.."…",function(done) api.request("publish",data,account,done) end,function(response)
            if type(response.id)~="string" then note="Unknown publication result. Check Browse before retrying." return end
            note="Published "..data.title
            reskate.log("Gallery published "..response.id.." as "..account)
            op,raw=nil,nil
        end)
    end
    local function close()
        if open then open=false invalidate() show(nil) reskate.ui.close() end
    end
    reskate.ui.screen(screen,function(ui)
        if not open then return end
        local nextTab=ui:tabs("gallery-tabs",{"Browse","Publish","Account"},tab)
        if nextTab~=tab then chooseTab(nextTab) end
        ui:note(short(note,185))
        if busy then
            if ui:button("stop-wait","Stop waiting") then invalidate() note="Stopped waiting. Refresh Browse to check any submitted change." end
            return
        end
        if lastRequest and ui:button("retry","Retry last request") then lastRequest() return end
        if tab==1 then
            query=short(ui:text("query","Search",query,"Title, artist or tag"),80)
            if ui:button("search","Search / refresh") then browse(1) return end
            for i,item in rows do
                if ui:button("pick-"..i,short(item.title.."  /  "..item.creator,70)) then
                    selection=item show(item.thumbnail) note=short(item.description,170)
                end
            end
            if selection then
                if ui:button("download","Download to My imports",true) then buyCopy(selection) return end
                if profile and ui:button("flag","Report and hide this entry") then
                    local id=selection.id
                    request("Sending report…",function(done) api.request("report",{id=id,reason="Player reported this artwork"},profile,done) end,function()
                        for i,item in rows do if item.id==id then table.remove(rows,i) break end end
                        selection=nil show(nil) note="Report submitted."
                    end)
                end
                if profile and ui:button("unpublish","Unpublish my selected piece") then
                    local id=selection.id
                    request("Unpublishing…",function(done) api.request("unpublish",{id=id},profile,done) end,function() browse(page) end)
                end
            end
            if page>1 and ui:button("prev","Previous page") then browse(page-1) end
            if more and ui:button("next","Next page") then browse(page+1) end
        elseif tab==2 then
            if not profile then ui:note("Choose a creator key on the Account tab to publish.") end
            for i=(sourcePage-1)*6+1,math.min(#sources,sourcePage*6) do
                local item=sources[i]
                if ui:button("source-"..i,short(item.name,68)) then
                    local data,name=api.prepare(item)
                    if data then raw,pieceTitle,description,tagText=data,short(name,64),"","" show(raw) note="Preview the piece, then confirm below."
                    else raw=nil show(nil) note=tostring(name) end
                end
            end
            if sourcePage>1 and ui:button("sprev","Previous sources") then sourcePage-=1 end
            if sourcePage*6<#sources and ui:button("snext","More sources") then sourcePage+=1 end
            if raw then
                pieceTitle=short(ui:text("title","Title",pieceTitle,"Artwork title"),64)
                description=short(ui:text("desc","Description",description,"Optional"),240)
                tagText=short(ui:text("tags","Tags",tagText,"Comma-separated"),160)
                if profile and ui:button("publish","Publish this artwork",true) then publish() end
            end
        else
            ui:info("Using",profile or "Guest")
            for i=1,math.min(#profiles,16) do
                if ui:button("profile-"..i,profiles[i]) then profile=profiles[i] note="Using "..profile end
            end
            if ui:button("guest","Browse as guest") then profile=nil note="Guest downloads are public." end
            if ui:button("keys","Open creator key folder") then
                local ok,why=reskate.files.write("gallery/accounts/README.txt","Place your operator-issued 64-character creator key in a file named Your Name.key. Keep it private.")
                if ok then ok,why=reskate.files.reveal("gallery/accounts") end
                note=if ok then "Add your .key file, then refresh profiles." else tostring(why)
            end
            if ui:button("profiles","Refresh profiles") then profiles=api.profiles() end
        end
        if ui:button("back","Back to Graffiti Lab") then close() onBack() end
    end,{dock="left",width=0.36})
    reskate.on("screen_closed",function(name)
        if name==screen and open then open=false invalidate() show(nil) onBack() end
    end)
    reskate.on("draw",function(d)
        if not open or not image then return end
        local u=dock.draw(d)
        local w=210*math.min(1,aspect)
        local h=210*math.min(1,1/aspect)
        local x,y=u.width-w-32,84
        u.rect(x-4,y-4,w+8,h+8,dock.dark)
        d:image("art/checker.png",u.p(x,y),u.p(x+w,y+h))
        for _,part in image do
            u.rect(x+(part.x+0.5-part.w/2)*w,y+(part.y+0.5-part.h/2)*h,part.w*w,part.h*h,palette[part.colour])
        end
    end)
    return {open=function()
        open=true profiles=api.profiles()
        if profile and not table.find(profiles,profile) then profile=nil end
        tab=1 reskate.ui.open(screen) browse(1)
    end,close=close,active=function() return open end}
end
