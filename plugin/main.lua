local surface = require("surface")
local arm = require("spray_arm")
local makeMenu = require("menu")
local makeSelector = require("selector")
local makeStudio = require("studio")
local makePaint = require("paint")
local makeSharing = require("sharing")
local wallArt = require("wall_art")
local instances = require("placements")
local playback=require("playback")
local organisation = require("library")
local openPublic, syncInstance, attachMedia
local previewScale,previewAngle,editingInstance=1,0,nil
local retryInstances={}
local nextInstanceRetry=0
local highlighted,originalPreview
local lastMapWarning=0
local function warnMap(message)
    if reskate.time.now()>=lastMapWarning then
        reskate.ui.toast(tostring(message)) lastMapWarning=reskate.time.now()+3000
    end
end
local pieces = assert(reskate.package.read_json("art/catalogue.json"))
local fx = reskate.effects
local ink = require("wall_ink")(fx)
local artHandles = 0
local assetRoot = "world/materials/decal/reskate_graffitilab/"
local sharing = makeSharing(pieces,assetRoot)
local sessionActive, worldId, mapName = false, nil, nil
local scopeCheck = 0
local lastScopeWorld,lastScopeMap
local nextMarkExpiry=math.huge
local selected, aiming, preview = 1, false, nil
local returnToBrowser,returnOnCancel
local design = pieces[selected]
local placed = {}
local restoredStrokes={}
local store=require("wall_store")(function(id,asset,matrix,page,slot)
    local mark=restoredStrokes[id]
    if not mark then
        mark={id="paint",strokeId=id,samples={}}
        restoredStrokes[id]=mark
        table.insert(placed,mark)
    end
    local sample=ink.add(mark,asset,matrix,reskate.time.now(),true)
    sample.page,sample.slot,sample.matrix=page,slot,nil
end)
local unloadingMap
local lifetime, capacity = 590000, 16
local elapsed, sinceSample, epoch, assetError = 0, 0, nil, nil
local selector, studio, paint, menu, publicGallery
local fromHome, pendingHome = false, false
local function backToHome()
    pendingHome=fromHome
end
local openAfterMenu = false
local showAimControls, confirmHeld, cancelHeld = false, true, true
local handleBudget = 768
-- Aim above the third-person skater. Use the same offset for the ring and the wall ray.
local aimScreenY = 0.35
local ringY = aimScreenY

local function release(mark)
    for _, handle in mark.handles do fx.release(handle) end
end

local function artworkCount()
    return #placed-ink.strokes
end

local function releasePlaced(mark,forget)
    if mark.samples then
        ink.remove(mark,forget)
        restoredStrokes[mark.strokeId]=nil
    else
        playback.remove(mark)
        artHandles-=#mark.handles
        release(mark)
    end
end

local function removeMark(index,forget)
    local mark=table.remove(placed,index)
    if mark==highlighted then highlighted,originalPreview=nil,nil end
    releasePlaced(mark,forget)
end

local function distance(m,pos)
    return vector.magnitude(vector.create(m[13],m[14],m[15])-pos)
end
local function makeRoom(count,pos,closerThan)
    while artHandles+count>handleBudget or artworkCount()>=capacity do
        local index,far=nil,closerThan
        for i,mark in placed do
            if mark.instance and mark~=highlighted and mark.instance~=editingInstance then
                local dist=distance(mark.transform,pos)
                if dist>far then far,index=dist,i end
            end
        end
        if not index then return false end
        local old=placed[index].instance
        retryInstances[old.id]=old
        removeMark(index)
    end
    return true
end
local function discardPreview()
    if preview then release(preview) end
    preview, assetError = nil, nil
end

local function stopAiming()
    discardPreview()
    editingInstance,previewScale,previewAngle=nil,1,0
    aiming, returnToBrowser = false, nil
end

local function reset()
    if publicGallery then publicGallery.close() end
    arm.reset()
    openAfterMenu, fromHome, pendingHome = false,false,false
    menu.close()
    instances.close() nextInstanceRetry=0 table.clear(retryInstances) highlighted,originalPreview=nil,nil
    sharing.reset()
    paint.close()
    store.close()
    table.clear(restoredStrokes)
    playback.clear()
    fx.clear()
    ink.reset()
    artHandles=0
    table.clear(placed)
    aiming, preview, sinceSample, elapsed, assetError = false, nil, 0, 0, nil
    returnToBrowser = nil
    if selector then selector.close() end
    studio.close()
    scopeCheck,nextMarkExpiry=0,math.huge
    lastScopeWorld,lastScopeMap=nil,nil
end

local function scope()
    local world = reskate.session.world().world
    local level = reskate.level.current()
    if world~="0" and level and level.name and level.name~="" then return world,string.lower(level.name) end
end

-- On build 20261116 the host has a lobby world before its first peer handshakes.
-- Keep its confirmed premades across that edge. Discard private art and other worlds.
local function changeConnection(world, map)
    if publicGallery then publicGallery.close() end
    arm.reset()
    fromHome,pendingHome=false,false
    instances.close() nextInstanceRetry=0 table.clear(retryInstances) highlighted,originalPreview=nil,nil
    menu.close()
    sharing.reset()
    stopAiming()
    selector.close()
    studio.close()
    paint.close()
    store.close()
    for i=#placed,1,-1 do
        local mark=placed[i]
        if not world or mark.world~=world or mark.map~=map then
            removeMark(i)
        end
    end
end

local function ready()
    local available, current = fx.state()
    local active = reskate.session.active()
    local world, map
    if active or sessionActive then world,map=scope() end
    local level=reskate.level.current()
    local offlineMap=not active and level and level.name and level.name~="" and string.lower(level.name)
    if unloadingMap and (current~=epoch or (offlineMap and offlineMap~=unloadingMap)) then unloadingMap=nil end
    if current==epoch and available and active~=sessionActive then
        changeConnection(world,map)
    elseif current~=epoch or (store.map and store.map~=offlineMap) or (active and (world~=worldId or map~=mapName))
        or (not available and (aiming or #placed>0 or paint.active() or sharing.count()>0)) then
        reset()
    end
    if active and design.parts then selected,design=1,pieces[1] end
    epoch,sessionActive,worldId,mapName=current,active,world,map
    if available and offlineMap and not unloadingMap then
        if store.map~=offlineMap then store.open(offlineMap) end
        store.load(reskate.time.now())
        local ok,row=instances.load(offlineMap)
        if not ok then warnMap(row) elseif row then syncInstance(row,row.id) end
    end
    return available and not unloadingMap and (if active then world~=nil else not not offlineMap)
end

local function updatePreview()
    local view = reskate.camera.get()
    ringY = 0.5
    if view and view.fov and view.fov > 1 and view.fov < 175 then
        ringY = aimScreenY
        local rise = (1 - 2*aimScreenY) * math.tan(math.rad(view.fov)/2)
        view = {position=view.position, forward=vector.normalize(view.forward + view.up*rise), right=view.right, up=view.up}
    end
    local transform = surface(reskate.world, view, reskate.level.current, (design.width or .65)*previewScale, (design.height or .65)*previewScale, previewAngle)
    if not transform then discardPreview() return false end
    local parts = design.textureParts or design.parts
    if preview then
        local changed = false
        for i = 1,16 do
            if math.abs(transform[i]-preview.transform[i]) > 0.00001 then changed = true break end
        end
        if changed then
            for i,h in preview.handles do fx.move(h, if parts then wallArt.transform(transform,parts[i]) else transform) end
            preview.transform = transform
        end
        return true
    end
    local count = if parts then #parts else 1
    if not sessionActive and view then makeRoom(count,view.position,-1) end
    if artHandles+count > handleBudget then
        if assetError ~= "budget" then reskate.log("Remove a mark to make room for this drawing") end
        assetError = "budget"
        return false
    end
    ink.reserve(artHandles+count)
    local mark = {id=design.id,name=design.name,handles={},transform=transform,expires=elapsed+lifetime}
    for i=1,count do
        local asset = if parts then parts[i].asset else design.id
        local matrix = if parts then wallArt.transform(transform,parts[i]) else transform
        local handle, why = fx.decal(assetRoot .. asset .. "_dv", matrix)
        if not handle then
            if ink.live>0 then
                ink.rendererBusy(artHandles+#mark.handles,reskate.time.now())
                ink.reserve(artHandles+count)
            end
            release(mark)
            if why ~= assetError then reskate.log(design.name .. " preview: " .. tostring(why)) end
            assetError = why
            return false
        end
        table.insert(mark.handles,handle)
        fx.opacity(handle,0.45)
    end
    preview = mark
    assetError = nil
    return true
end

local function aim(piece, onPlaced, scale, angle, edit, returnOnBack)
    if not ready() then return end
    discardPreview()
    previewScale,previewAngle,editingInstance=scale or 1,angle or 0,edit
    if not onPlaced then fromHome=false end
    pendingHome=false
    design, aiming, returnToBrowser, returnOnCancel = piece, true, onPlaced, returnOnBack
    showAimControls, confirmHeld, cancelHeld = false, true, true
    local start = os.clock()
    local visible = updatePreview()
    reskate.log(piece.name .. (if visible then " preview active" else " selected, waiting for a wall"))
    if visible and piece.resolution then
        reskate.log(string.format("Blackbook preview %s: %d decals, %d x %d, initial update %.2f ms",
            piece.id,#piece.parts,piece.resolution,piece.resolution/2,(os.clock()-start)*1000))
    end
end

studio = makeStudio(function(file,doc)
    if sessionActive then return false,"Blackbook wall placement is available offline." end
    local parts, resolution = wallArt.compile(doc)
    if not parts then return false,resolution end

    studio.close()
    local piece={id=file,name=doc.name,parts=parts,resolution=resolution,width=wallArt.width,height=wallArt.height}
    if doc.animation then
        local asset,msg=require("media_format").fromDrawing(doc,wallArt)
        if not asset then studio.resumeGallery() return false,msg end
        piece.media=asset piece.frames=require("media_format").validate(asset,require("imports").decode)
        piece.parts=piece.frames[1]
    end
    aim(piece,studio.resumeGallery)
    return true
end, backToHome, function(index)
    if not index then return #placed end
    local mark=placed[#placed-index+1]
    return mark.name or (if mark.samples then "Freehand stroke" else mark.id)
end,function() openPublic("map") end)
paint = makePaint(function(mark,asset,matrix,colour)
    if not mark then
        mark={id="paint",strokeId=store.nextId(),samples={}}
        table.insert(placed,mark)
    end
    local sample=ink.add(mark,asset,matrix,reskate.time.now())
    store.add(sample,mark.strokeId,colour)
    return mark
end, function()
    for i=#placed,1,-1 do
        if placed[i].samples then
            local samples=#placed[i].samples
            removeMark(i,store.erase)
            store.checkpoint()
            reskate.log("Undid paint stroke (" .. samples .. " samples)")
            return "Stroke removed"
        end
    end
    return "No paint strokes to undo"
end, backToHome, function() return ink.live,ink.total,ink.reason end,
function(hit,radius)
    ink.erase(hit,radius,store.erase,function(mark)
        restoredStrokes[mark.strokeId]=nil
        local index=table.find(placed,mark)
        if index then table.remove(placed,index) end
    end)
end, function() return store.ready,store.warning end, store.checkpoint)
local function openPaint()
    if sessionActive then return end
    selector.close()
    studio.close()
    stopAiming()
    paint.open()
end
local function openStudio(which)
    if sessionActive then return end
    paint.close()
    selector.close()
    stopAiming()
    studio.open(which)
end
selector = makeSelector(pieces, function(index)
    selected = index
    aim(pieces[index],selector.resume)
end, backToHome,function() openPublic("library") end)

local function place()
    if not aiming then return end
    if sessionActive and artworkCount() >= capacity and not editingInstance then
        reskate.log("Remove a mark before placing another (16 on this map)")
        return
    end
    if not updatePreview() then reskate.log("Placement needs a valid preview") return end
    local editing=editingInstance
    if not sessionActive then
        local base=instances.matrix(preview.transform,1/previewScale,-previewAngle)
        local row=instances.new(design,base,previewScale,previewAngle)
        if editing then row.id=editing.id end
        local ok,msg=instances.change(if editing then "placement move" else "placement",editing,row)
        if not ok then warnMap("Placement unsaved: "..tostring(msg)) return end
        if editing then syncInstance(nil,editing.id) end
        preview.instance=row preview.parts=design.textureParts or design.parts
    end
    for _,handle in preview.handles do fx.opacity(handle,1) end
    attachMedia(preview,design.media)
    if not design.parts and not design.media then
        preview.world,preview.map=scope()
    end
    if not design.parts or design.file then arm.place(preview.transform) end
    table.insert(placed, preview)
    artHandles+=#preview.handles
    nextMarkExpiry=math.min(nextMarkExpiry,preview.expires)
    if sessionActive then sharing.changed() end
    reskate.log("Placed " .. preview.id .. " handle " .. preview.handles[1] .. " (" .. #preview.handles .. " decals)")
    local reopen = returnToBrowser
    preview, aiming, returnToBrowser = nil, false, nil
    reskate.ui.toast("Placed " .. design.name)
    editingInstance=nil
    local ok,msg=organisation.used(design.id)
    if not ok then warnMap("Recent artwork unsaved: "..tostring(msg)) end
    if reopen then reopen() end
end

local function remove()
    if aiming then
        local reopen=returnOnCancel and returnToBrowser
        stopAiming()
        if reopen then reopen() end
    elseif #placed > 0 then
        local piece=placed[#placed]
        local details=if piece.samples then #piece.samples.." paint samples" else "handle "..piece.handles[1].." ("..#piece.handles.." decals)"
        if piece.samples and not store.ready then return end
        if piece.instance and not sessionActive then
            local ok,msg=instances.change("placement deletion",piece.instance,nil)
            if not ok then warnMap(msg) return end
        end
        removeMark(#placed,store.erase)
        if piece.samples then store.checkpoint() end
        if sessionActive then sharing.changed() end
        reskate.log("Removed "..piece.id.." "..details)
    end
end

local sizeKeys={}
local function placementInput()
    showAimControls = reskate.input.allowed()
    if not showAimControls then
        confirmHeld, cancelHeld = true, true
        return
    end
    local pad = reskate.input.gamepad()
    if not sessionActive then
        local keys={reskate.input.key(219) or (pad and pad.buttons.lb),reskate.input.key(221) or (pad and pad.buttons.rb),
            reskate.input.key("Q"),reskate.input.key("E"),reskate.input.key(0x30)} -- Top-row 0. ReSkate coerces "0" to invalid VK 0.
        for i=1,5 do
            if keys[i] and not sizeKeys[i] then
                if i<=2 then previewScale=math.clamp(previewScale+(if i==1 then -.05 else .05),.1,5)
                elseif i<=4 then previewAngle=(previewAngle+(if i==3 then -5 else 5)+180)%360-180
                else previewScale,previewAngle=1,0 end
                updatePreview()
            end
        end
        sizeKeys=keys
    end
    local confirm = reskate.input.key(1) or (pad and pad.buttons.a)
    local cancel = pad and pad.buttons.b
    if cancel and not cancelHeld then remove()
    elseif confirm and not confirmHeld then place() end
    confirmHeld, cancelHeld = confirm, cancel
end

reskate.on("draw", function(d)
    if not aiming or not showAimControls then return end
    local screen = d:size()
    local scale = math.min(screen.y / 1080, screen.x / 720)
    if scale <= 0 then return end
    local cx, cy = screen.x / 2, screen.y * ringY
    local function point(x,y) return vector.create(cx + x*scale, screen.y + y*scale, 0) end
    local canPlace = preview ~= nil and (not sessionActive or artworkCount() < capacity)
    local accent = if canPlace then "#74F2B6" else "#FFA57C"
    local status = "Aim at a flat wall within 8 m"
    if (sessionActive and artworkCount() >= capacity) or assetError == "budget" then status = "Cancel and remove an old mark to make room"
    elseif assetError then status = "Artwork unavailable for this wall"
    elseif canPlace then status = "Wall ready" end
    local centre = vector.create(cx,cy,0)
    d:circle(centre,7*scale,{colour="#171819",thickness=4*scale})
    d:circle(centre,7*scale,{colour=accent,thickness=2*scale})
    d:rect(point(-294,-156),point(294,-64),{colour="#111215ED",fill=true})
    d:text(point(0,-147),status,{align="centre",font="heading",size=25,colour=accent})
    local hint = if canPlace then "Left click / Ctrl+P / A   Place     Â·     Ctrl+R / B   Cancel" else "Centre the ring on the wall     Â·     Ctrl+R / B   Cancel"
    d:text(point(0,-101),hint,{align="centre",font="bold",size=18,colour="#F2EFE9"})
    if not sessionActive then
        d:text(point(0,-186),string.format("[ / ] Size %d%%   Q / E Rotate %dÂ°   0 Reset",math.round(previewScale*100),previewAngle),{align="centre",font="bold",size=18,colour=accent})
    end
    local top=vector.create(cx,12*scale,0)
    d:rect(top-vector.create(156*scale,0,0),top+vector.create(156*scale,35*scale,0),{colour="#0D0E10EB",fill=true})
    d:text(top+vector.create(0,6*scale,0), "PLACING   /   "..string.upper(design.name),{align="centre",font="bold",size=16,colour="#F2EFE9"})
end)

-- Keep the three original action IDs so milestone 1 player rebindings still work.
local function openLibrary()
    openAfterMenu = false
    paint.close()
    studio.close()
    stopAiming()
    selector.open(selected)
    reskate.log("Opened Premade Art")
end
local stock={}
for _,p in pieces do stock[p.id]=p end

attachMedia=function(mark,asset)
    if asset then
        local frames=require("media_format").validate(asset,require("imports").decode)
        if frames then playback.attach(mark,frames,asset) end
    else playback.remove(mark) end
end
local function moveHandles(mark,m)
    local parts=mark.parts
    for i,h in mark.handles do fx.move(h,if parts then wallArt.transform(m,parts[i]) else m) end
end
syncInstance=function(row,id)
    retryInstances[id]=nil
    for i=#placed,1,-1 do
        local mark=placed[i]
        if mark.instance and mark.instance.id==id then
            if row then
                mark.instance=row mark.transform=instances.matrix(row.base,row.scale,row.angle,row.stretch)
                moveHandles(mark,mark.transform)
                attachMedia(mark,row.media)
            else removeMark(i) end
            return
        end
    end
    if not row or sessionActive then return end
    local piece=instances.design(row)
    if not piece.parts and not stock[piece.id] then warnMap("Missing artwork: "..piece.name) return end
    local parts=piece.textureParts or piece.parts
    local count=if parts then #parts else 1
    if artHandles+count>handleBudget or artworkCount()>=capacity then retryInstances[id]=row return end
    local m=instances.matrix(row.base,row.scale,row.angle,row.stretch)
    local mark={id=piece.id,name=piece.name,handles={},transform=m,parts=parts,instance=row,expires=elapsed+lifetime}
    ink.reserve(artHandles+count)
    for i=1,count do
        local part=parts and parts[i]
        local h=fx.decal(assetRoot..(if part then part.asset else piece.id).."_dv",if part then wallArt.transform(m,part) else m)
        if not h then release(mark) retryInstances[id]=row return end
        table.insert(mark.handles,h) fx.opacity(h,1)
    end
    attachMedia(mark,row.media)
    table.insert(placed,mark) artHandles+=count nextMarkExpiry=math.min(nextMarkExpiry,mark.expires)
end
local function mapPreview(row,scale,angle,stretch)
    if highlighted then moveHandles(highlighted,highlighted.transform) highlighted=nil end
    if not row then originalPreview=nil return true end
    for _,mark in placed do
        if mark.instance and mark.instance.id==row.id then
            highlighted=mark
            originalPreview=instances.matrix(row.base,scale,angle,stretch or row.stretch)
            moveHandles(mark,originalPreview)
            return true
        end
    end
    return nil,"This placement is outside the current render budget."
end
reskate.on("draw",function(d)
    if not highlighted or not originalPreview then return end
    local m=originalPreview
    local p=vector.create(m[13],m[14],m[15])
    local a=vector.create(m[1],m[2],m[3])*.5
    local b=vector.create(m[9],m[10],m[11])*.5
    local prev=d:world_to_screen(p-a-b)
    for _,v in {p+a-b,p+a+b,p-a+b,p-a-b} do
        local pt=d:world_to_screen(v)
        if pt and prev then d:line(prev,pt,{colour="#FF6622",thickness=2}) end
        prev=pt
    end
end)
local function footprint(m)
    local p=vector.create(m[13],m[14],m[15])
    local a=vector.create(m[1],m[2],m[3])*.5
    local b=vector.create(m[9],m[10],m[11])*.5
    local n=vector.normalize(vector.create(m[5],m[6],m[7]))
    for _,pt in {p-a-b,p+a-b,p+a+b,p-a+b} do
        local hit=reskate.world.probe(pt+n*.09,pt-n*.09)
        if hit.status~="hit" or vector.magnitude(hit.position-pt)>.035 then return false end
    end
    return true
end
local function buildPanels()
    local function libraryAim(p)
        publicGallery.close() aim(p,function() openPublic("library") end)
    end
    local screens={}
    screens.library=require("library_screen")(pieces,libraryAim,function() publicGallery.close() backToHome() end,function() openPublic("map") end)
    screens.map=require("map_screen")({
        preview=mapPreview,library=function() openPublic("library") end,
        change=function(label,row,scale,angle,stretch)
            local after
            if scale then
                after=table.clone(row) after.scale,after.angle=scale,angle after.stretch=stretch or row.stretch
                if not footprint(instances.matrix(row.base,scale,angle,after.stretch)) then return nil,"The new size does not fit this wall." end
            end
            local ok,msg=instances.change(label,row,after)
            if ok then mapPreview(nil) syncInstance(after,row.id) end
            return ok,msg
        end,
        aim=function(row,scale,angle,copy,stretch)
            publicGallery.close()
            local moved=instances.design(row)
            moved.width*=stretch or row.stretch or 1
            aim(moved,function() openPublic("map") end,scale,angle,if copy then nil else row,true)
        end,
        history=function(forward)
            local ok,row,id=instances.history(forward,true)
            if ok then syncInstance(row,id) end
            return ok,if ok then nil else row
        end,
    })
    return require("gallery_screen")(backToHome,screens)
end
openPublic=function(view)
    if (view=="library" or view=="map") and sessionActive then reskate.ui.toast("The personal library is available offline.") return end
    menu.close() selector.close() studio.close() paint.close() stopAiming()
    if not publicGallery then publicGallery=buildPanels() end
    publicGallery.open(view)
end
menu=makeMenu(function(index)
    if index==1 then openLibrary() elseif index==2 then openStudio("editor")
    elseif index==3 then openPaint() elseif index==4 then openStudio("gallery") elseif index==6 then openPublic() end
end, backToHome, paint, function()
    return {marks=artworkCount(),limit=capacity,handles=artHandles+(if preview then #preview.handles else 0),budget=handleBudget,
        strokes=ink.strokes,visiblePaint=ink.live,samples=ink.total}
end, assert(reskate.package.read_json("manifest.json")).version_number)

local function openHome()
    if publicGallery then publicGallery.close() end
    selector.close()
    studio.close()
    paint.close()
    stopAiming()
    openAfterMenu,pendingHome,fromHome=false,false,true
    menu.open("home")
    reskate.log("Opened Graffiti Lab main menu")
end
reskate.menu.page("Graffiti Lab", function(ui)
    local label = if openAfterMenu then "Cancel" else "Open Graffiti Lab"
    if ui:button("open-lab", label, true) then openAfterMenu = not openAfterMenu end
    if openAfterMenu then ui:note("Close the menu to open Graffiti Lab. In the Insert menu, press Insert again.") end
end)
reskate.on("menu_changed", function(state)
    if not openAfterMenu or state.reskate or state.pause then return end
    openAfterMenu = false
    if ready() then openHome() else reskate.ui.toast("Enter a map to open Graffiti Lab.") end
end)
local actions = {
    ["Public Artworks"] = openPublic,
    ["Open Wall Paint"] = openPaint,
    ["Open Custom Editor"] = function() openStudio("editor") end,
    ["Open Blackbook"] = function() openStudio("gallery") end,
    ["Open Graffiti Lab"] = openHome,
    ["Open Graffiti Lab on pad"] = openHome,
    ["Open Premade Art"] = openLibrary,
    ["Aim Switchback"] = function() if aiming then remove() else aim(design) end end,
    ["Place Switchback"] = place,
    ["Remove Switchback"] = remove,
}
local function action(name)
    if publicGallery and publicGallery.active() then
        if name=="Aim Switchback" or name=="Place Switchback" or name=="Remove Switchback" then return end
        publicGallery.close()
    end
    if (menu.active() or selector.active() or studio.active() or paint.active()) and (name == "Aim Switchback" or name == "Place Switchback" or name == "Remove Switchback") then return end
    if actions[name] and ready() then
        if name=="Open Custom Editor" or name=="Open Blackbook" or name=="Open Premade Art" or name=="Open Wall Paint" then
            fromHome,pendingHome=false,false
            menu.close()
        end
        actions[name]()
    end
end
reskate.input.bind("Open Wall Paint", "Ctrl+I")
reskate.input.bind("Open Custom Editor", "Ctrl+E")
reskate.input.bind("Open Blackbook", "Ctrl+B")
reskate.input.bind("Open Graffiti Lab", "Ctrl+L")
reskate.input.bind("Open Graffiti Lab on pad", "Pad.Back+Pad.Y")
reskate.input.bind("Aim Switchback", "Ctrl+G")
reskate.input.bind("Place Switchback", "Ctrl+P")
reskate.input.bind("Remove Switchback", "Ctrl+R")
reskate.on("action", action)
reskate.console.command("graffiti", "menu, library, editor, blackbook, paint, aim, place, remove or status", function(args)
    if args[1]=="organise" or args[1]=="placements" then if ready() then openPublic(if args[1]=="organise" then "library" else "map") end return end
    local commands = {public = "Public Artworks", menu = "Open Graffiti Lab", library = "Open Premade Art", editor = "Open Custom Editor", blackbook = "Open Blackbook",
        aim = "Aim Switchback", place = "Place Switchback", remove = "Remove Switchback", paint = "Open Wall Paint"}
    if commands[args[1]] then action(commands[args[1]]) return end
    local available = ready()
    local marks = {}
    for _, mark in placed do
        if not mark.samples then table.insert(marks,mark.id.."#"..mark.handles[1]) end
    end
    reskate.log(string.format("Wall Paint: %d strokes, %d recorded samples, %d visible decals",ink.strokes,ink.total,ink.live))
    reskate.log(string.format("ready=%s selected=%s preview=%s placed=[%s]", tostring(available),
        design.id, if preview then preview.id .. "#" .. preview.handles[1] else "none", table.concat(marks, ", ")))
    local world,map=scope()
    reskate.log(string.format("Sharing peers connected=%s world=%s map=%s remote decals=%d",tostring(sessionActive),
        tostring(world), tostring(map), sharing.count()))
end)
reskate.on("message",function(from,text)
    if ready() and sessionActive then sharing.receive(from,text,worldId,mapName) end
end)
reskate.on("player_left",function(player) sharing.drop(player.id) end)
reskate.on("level_unloading", function()
    unloadingMap=store.map or mapName or true
    reset()
end)
reskate.on("level_loaded",function() unloadingMap=nil end)
reskate.on("unload",reset)
reskate.on("tick", function(dt)
    if not ready() then arm.reset() pendingHome=false menu.close() selector.close() studio.close() paint.close() return end
    if pendingHome and not reskate.input.key("Escape") then openHome() end
    if not sessionActive and not aiming and #placed == 0 and not next(retryInstances) and not paint.active() then arm.tick(dt) return end
    elapsed += dt
    if not sessionActive and artworkCount()>0 then
        -- A host can leave one empty lobby and host the same map again. Once the
        -- native world changes, the earlier mark may stay local but must not be sent.
        scopeCheck+=dt
        if scopeCheck>=250 then
            scopeCheck=0
            local world,map=scope()
            if world~=lastScopeWorld or map~=lastScopeMap then
                for _,mark in placed do
                    if mark.world~=world or mark.map~=map then mark.world,mark.map=nil,nil end
                end
                lastScopeWorld,lastScopeMap=world,map
            end
        end
    end
    if elapsed>=nextMarkExpiry then
        nextMarkExpiry=math.huge
        local keep=0
        for _,mark in placed do
            if mark.expires and elapsed>=mark.expires then
                if mark.instance and not sessionActive then retryInstances[mark.instance.id]=mark.instance end
                releasePlaced(mark)
                if sessionActive then sharing.changed() end
            else
                keep+=1
                placed[keep]=mark
                if mark.expires then nextMarkExpiry=math.min(nextMarkExpiry,mark.expires) end
            end
        end
        for i=#placed,keep+1,-1 do placed[i]=nil end
    end
    if not sessionActive and not aiming and next(retryInstances) and elapsed>=nextInstanceRetry then
        local view=reskate.camera.get()
        if view then
            local nearest,dist=nil,math.huge
            for _,row in retryInstances do
                local d=distance(row.base,view.position)
                if d<dist then nearest,dist=row,d end
            end
            local needed=instances.handleCount(nearest)
            if makeRoom(needed,view.position,dist+1) then syncInstance(nearest,nearest.id) end
            nextInstanceRetry=elapsed+(if retryInstances[nearest.id] then 500 else 32)
        end
    end
    local brushHit, brushColour
    if sessionActive then
        sharing.tick(placed,worldId,mapName)
    else
        local parts=design.textureParts or design.parts
        local previewSlots=if aiming then (if parts then #parts else 1) else 0
        playback.tick(dt,wallArt,handleBudget-artHandles-previewSlots)
        ink.reserve(artHandles+previewSlots+playback.handles())
        brushHit,brushColour=paint.tick()
        ink.tick(reskate.time.now())
    end
    if aiming then placementInput() end
    if aiming then
        if preview and elapsed >= preview.expires then discardPreview() end
        sinceSample += dt
        if sinceSample >= 100 then
            sinceSample = 0
            updatePreview()
        end
    end
    local premadeHit = aiming and showAimControls and (not design.parts or design.file) and preview and preview.transform
    arm.tick(dt,brushHit or premadeHit,brushHit~=nil,brushColour)
end)
-- Disk replacement can block. Keep checkpoint I/O out of the interactive paint callback.
reskate.on("tick",function() store.flush(false) end)
