local api=require("gallery")
local imports=require("imports")
local dock=require("dock")
local publicScreen=dock.editingScreen()
local localScreen="Artwork Library"
local function trim(s) return s:match("^%s*(.-)%s*$") end

return function(onBack,localScreens)
    local s={tab=1,page=1,query="",rows={},sources={},sourcePage=1,profiles={},profilePage=1,note=""}
    local open,localView,generation=false,nil,0
    local retry,operation,signature
    local actions={}
    local overlay=require("gallery_dock")(s,actions)
    local function invalidate()
        generation+=1 retry=nil s.busy,s.failed=false,false
    end
    local function request(note,send,complete)
        invalidate()
        local ticket=generation
        s.busy,s.note=true,note
        retry=function() request(note,send,complete) end
        send(function(data,why)
            if not open or localView or ticket~=generation then return end
            s.busy=false
            if not data then s.failed,s.note=true,tostring(why or "Gallery unavailable.") return end
            retry=nil complete(data)
        end)
    end
    local function browse(page)
        local query=s.query
        request("Loading artwork…",function(done) api.browse(query,page,done) end,function(data)
            s.page,s.rows,s.more=page,data.items,data.more==true
            s.selection,s.manage=s.rows[1],false
            s.note=if #s.rows==0 then "Try a different title, creator or tag." else ""
        end)
    end
    local function profiles()
        s.profiles,s.profilePage=api.profiles(),1
        if s.profile and not table.find(s.profiles,s.profile) then s.profile=nil end
    end
    function actions.tab(n)
        invalidate()
        s.tab,s.selection,s.manage,s.source,s.raw,s.preview=n,nil,false,nil,nil,nil
        if n==1 then browse(1)
        elseif n==2 then
            s.sources,s.sourcePage=api.sources(),1
            s.note=if not s.profile then "Choose a creator profile on the Account tab to publish."
                elseif #s.sources==0 then "Save a drawing or import a piece first." else "Choose a piece to preview."
        else profiles() s.note="Creator keys are stored on this computer." end
    end
    function actions.select(item) if not s.busy then s.selection,s.manage,s.note=item,false,"" end end
    function actions.search() if not s.busy then browse(1) end end
    function actions.page(n) if not s.busy then browse(s.page+n) end end
    function actions.sourcePage(n) s.sourcePage+=n end
    function actions.options() s.manage=not s.manage end
    function actions.download()
        if s.busy or not s.selection then return end
        local id=s.selection.id
        local profile=s.profile
        request("Downloading "..s.selection.title.."…",function(done) api.download(id,profile,done) end,function(data)
            local ok,msg=api.store(data,id)
            s.note=if ok then msg else "Save failed: "..tostring(msg)
            if ok then reskate.log("Gallery downloaded "..id.." by "..data.creator.." as "..(data.downloadedBy or "guest")) end
        end)
    end
    local function moderation(action)
        if s.busy or not s.profile or not s.selection then return end
        local id,profile=s.selection.id,s.profile
        local payload={id=id}
        if action=="report" then payload.reason="Player reported this artwork" end
        request(if action=="report" then "Sending report…" else "Unpublishing…",
            function(done) api.request(action,payload,profile,done) end,function() browse(s.page) end)
    end
    function actions.report() moderation("report") end
    function actions.unpublish() moderation("unpublish") end
    function actions.source(item)
        if s.busy then return end
        s.source=item
        local raw,name,media=api.prepare(item)
        s.raw,s.media,s.preview=raw,media,nil
        if not raw then s.note=tostring(name) return end
        local parts,aspect=imports.decode(raw)
        s.preview={parts=parts,aspect=aspect}
        local last=utf8.offset(name,math.min(utf8.len(name) or 1,60)+1)
        s.title,s.description,s.tags=if last then name:sub(1,last-1) else name,"",""
        s.note=if media then string.format("%d frame(s) • %d ms",#media.frames,media.frameMs) else "Preview your artwork before publishing."
    end
    function actions.publish()
        if s.busy or not s.raw or not s.profile or trim(s.title)=="" then s.note="Choose a profile, piece and title." return end
        local tags={}
        for value in s.tags:gmatch("[^,]+") do
            local tag=trim(value)
            if #tag>24 or #tags>=8 then s.note="Use up to eight tags of 24 bytes each." return end
            if tag~="" then table.insert(tags,tag) end
        end
        local payload={title=trim(s.title),description=trim(s.description),tags=if #tags>0 then tags else nil,
            asset=s.media or {version=1,kind="ink",frames={s.raw},frameMs=250}}
        local key=reskate.json.encode(payload)
        if not operation or key~=signature then operation=string.format("game-%d-%d",math.floor(reskate.time.now()),math.random(1,1000000000)) signature=key end
        payload.operation=operation
        local profile=s.profile
        request("Publishing "..payload.title.."…",function(done) api.request("publish",payload,profile,done) end,function(data)
            if type(data.id)~="string" then s.note="Check Browse before retrying this publication." return end
            s.note="Published "..payload.title
            reskate.log("Gallery published "..data.id.." as "..profile)
            operation,s.raw,s.preview=nil,nil,nil
        end)
    end
    function actions.profile(name) s.profile=name s.note=if name then "Using "..name else "Browsing as guest." end
    function actions.keys()
        local ok,why=reskate.files.write("gallery/accounts/README.txt","Place your operator-issued 64-character creator key in a file named Your Name.key. Keep it private.")
        if ok then ok,why=reskate.files.reveal("gallery/accounts") end
        s.note=if ok then "Add a .key file, then refresh profiles." else tostring(why)
    end
    actions.profiles=profiles
    function actions.retry() if retry then retry() end end
    function actions.cancel() invalidate() s.note="Stopped waiting. Refresh Browse to check submitted changes." end
    local function clear()
        open=false invalidate() overlay.reset()
        if localView then localView.close() localView=nil end
    end
    local function close()
        if open then clear() reskate.ui.close() end
    end
    function actions.back() close() onBack() end
    local function backLocal()
        if localView and localView.back and localView.back() then return end
        actions.back()
    end
    local sidebar=require("library_dock")(backLocal)
    reskate.ui.screen(localScreen,function() end,{panel=false})
    reskate.on("screen_closed",function(name)
        if open and name==(if localView then localScreen else publicScreen) then
            if localView and localView.back and localView.back() then reskate.ui.open(localScreen) return end
            clear() onBack()
        end
    end)
    reskate.on("draw",function(d)
        if not open then return end
        if localView then sidebar.draw(d,if localView.title then localView.title() else "Map Placements",localView.panel)
        else overlay.draw(d) end
    end)
    reskate.on("tick",function()
        if not open then return end
        if localView then sidebar.tick() else overlay.tick() end
    end)
    return {open=function(view)
        if open then close() end
        open=true overlay.reset()
        if type(view)=="string" and localScreens and localScreens[view] then
            localView=localScreens[view] sidebar.reset() localView.open() reskate.ui.open(localScreen) return
        end
        profiles() s.rows={} s.page=1 s.more=false
        reskate.ui.open(publicScreen) actions.tab(1)
    end,close=close,active=function() return open end,
        publishSource=function(piece)
            actions.tab(2)
            for _,item in s.sources do
                if item.file==piece.file or item.id==piece.id then actions.source(item) return end
            end
            s.note="Choose your saved Studio premade to publish."
        end}
end
