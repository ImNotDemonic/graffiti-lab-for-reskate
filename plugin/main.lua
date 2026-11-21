local surface = require("surface")
local makeMenu = require("menu")
local makeSelector = require("selector")
local makeStudio = require("studio")
local makePaint = require("paint")
local makeSharing = require("sharing")
local wallArt = require("wall_art")
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
local returnToBrowser
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
    sample.page,sample.slot=page,slot
end)
local unloadingMap
local lifetime, capacity = 590000, 16
local elapsed, sinceSample, epoch, assetError = 0, 0, nil, nil
local selector, studio, paint, menu
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
        artHandles-=#mark.handles
        release(mark)
    end
end

local function removeMark(index,forget)
    releasePlaced(table.remove(placed,index),forget)
end

local function discardPreview()
    if preview then release(preview) end
    preview, assetError = nil, nil
end

local function stopAiming()
    discardPreview()
    aiming, returnToBrowser = false, nil
end

local function reset()
    openAfterMenu, fromHome, pendingHome = false,false,false
    menu.close()
    sharing.reset()
    paint.close()
    store.close()
    table.clear(restoredStrokes)
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
    fromHome,pendingHome=false,false
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
    if active and design.parts then design=pieces[selected] end
    epoch,sessionActive,worldId,mapName=current,active,world,map
    if available and offlineMap and not unloadingMap then
        if store.map~=offlineMap then store.open(offlineMap) end
        store.load(reskate.time.now())
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
    local transform = surface(reskate.world, view, reskate.level.current, design.width, design.height)
    if not transform then discardPreview() return false end
    local parts = design.parts
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

local function aim(piece, onPlaced)
    if not ready() then return end
    if design ~= piece then discardPreview() end
    if not onPlaced then fromHome=false end
    pendingHome=false
    design, aiming, returnToBrowser = piece, true, onPlaced
    showAimControls, confirmHeld, cancelHeld = false, true, true
    local start = os.clock()
    local visible = updatePreview()
    reskate.log(piece.name .. (if visible then " preview active" else " selected, waiting for a wall"))
    if visible and piece.parts then
        reskate.log(string.format("Blackbook preview %s: %d decals, %d x %d, initial update %.2f ms",
            piece.id,#piece.parts,piece.resolution,piece.resolution/2,(os.clock()-start)*1000))
    end
end

studio = makeStudio(function(file,doc)
    if sessionActive then return false,"Blackbook wall placement is available offline." end
    local parts, resolution = wallArt.compile(doc)
    if not parts then return false,resolution end
    if artHandles+#parts > handleBudget or artworkCount() >= capacity then return false,"Remove a wall mark first." end
    studio.close()
    aim({id=file,name=doc.name,parts=parts,resolution=resolution,width=wallArt.width,height=wallArt.height},studio.resumeGallery)
    return true
end, backToHome, function(index)
    if not index then return #placed end
    local mark=placed[#placed-index+1]
    return mark.name or (if mark.samples then "Freehand stroke" else mark.id)
end)
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
            store.flush(false,true)
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
end, function() return store.ready,store.warning end, function() store.flush(false,true) end)
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
end, backToHome)

local function place()
    if not aiming then return end
    if artworkCount() >= capacity then
        reskate.log("Remove a mark before placing another (16 on this map)")
        return
    end
    if not updatePreview() then reskate.log("Placement needs a valid preview") return end
    for _,handle in preview.handles do fx.opacity(handle,1) end
    if not design.parts then preview.world,preview.map=scope() end
    table.insert(placed, preview)
    artHandles+=#preview.handles
    nextMarkExpiry=math.min(nextMarkExpiry,preview.expires)
    if sessionActive then sharing.changed() end
    reskate.log("Placed " .. preview.id .. " handle " .. preview.handles[1] .. " (" .. #preview.handles .. " decals)")
    local reopen = returnToBrowser
    preview, aiming, returnToBrowser = nil, false, nil
    reskate.ui.toast("Placed " .. design.name)
    if reopen then reopen() end
end

local function remove()
    if aiming then
        stopAiming()
    elseif #placed > 0 then
        local piece=placed[#placed]
        local details=if piece.samples then #piece.samples.." paint samples" else "handle "..piece.handles[1].." ("..#piece.handles.." decals)"
        if piece.samples and not store.ready then return end
        removeMark(#placed,store.erase)
        if piece.samples then store.flush(false,true) end
        if sessionActive then sharing.changed() end
        reskate.log("Removed "..piece.id.." "..details)
    end
end

local function placementInput()
    showAimControls = reskate.input.allowed()
    if not showAimControls then
        confirmHeld, cancelHeld = true, true
        return
    end
    local pad = reskate.input.gamepad()
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
    local canPlace = preview ~= nil and artworkCount() < capacity
    local accent = if canPlace then "#74F2B6" else "#FFA57C"
    local status = "Aim at a flat wall within 8 m"
    if artworkCount() >= capacity or assetError == "budget" then status = "Cancel and remove an old mark to make room"
    elseif assetError then status = "Artwork unavailable for this wall"
    elseif canPlace then status = "Wall ready" end
    local centre = vector.create(cx,cy,0)
    d:circle(centre,7*scale,{colour="#171819",thickness=4*scale})
    d:circle(centre,7*scale,{colour=accent,thickness=2*scale})
    d:rect(point(-294,-156),point(294,-64),{colour="#111215ED",fill=true})
    d:text(point(0,-147),status,{align="centre",font="heading",size=25,colour=accent})
    local hint = if canPlace then "Left click / Ctrl+P / A   Place     ·     Ctrl+R / B   Cancel" else "Centre the ring on the wall     ·     Ctrl+R / B   Cancel"
    d:text(point(0,-101),hint,{align="centre",font="bold",size=18,colour="#F2EFE9"})
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
menu=makeMenu(function(index)
    if index==1 then openLibrary() elseif index==2 then openStudio("editor")
    elseif index==3 then openPaint() elseif index==4 then openStudio("gallery") end
end, backToHome, paint, function()
    return {marks=artworkCount(),limit=capacity,handles=artHandles+(if preview then #preview.handles else 0),budget=handleBudget,
        strokes=ink.strokes,visiblePaint=ink.live,samples=ink.total}
end, assert(reskate.package.read_json("manifest.json")).version_number)

local function openHome()
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
    local commands = {menu = "Open Graffiti Lab", library = "Open Premade Art", editor = "Open Custom Editor", blackbook = "Open Blackbook",
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
    store.flush(false)
    if not ready() then pendingHome=false menu.close() selector.close() studio.close() paint.close() return end
    if pendingHome and not reskate.input.key("Escape") then openHome() end
    if not sessionActive and not aiming and #placed == 0 and not paint.active() then return end
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
    if sessionActive then
        sharing.tick(placed,worldId,mapName)
    else
        local previewSlots=if aiming then (if design.parts then #design.parts else 1) else 0
        ink.reserve(artHandles+previewSlots)
        paint.tick()
        ink.tick(reskate.time.now())
    end
    if not aiming then return end
    placementInput()
    if not aiming then return end
    if preview and elapsed >= preview.expires then discardPreview() end
    sinceSample += dt
    if sinceSample >= 100 then
        sinceSample = 0
        updatePreview()
    end
end)
