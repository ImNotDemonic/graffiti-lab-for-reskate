local surface = require("surface")
local makeSelector = require("selector")
local makeStudio = require("studio")
local wallArt = require("wall_art")
local pieces = assert(reskate.package.read_json("art/catalogue.json"))
local fx = reskate.effects
local assetRoot = "world/materials/decal/reskate_graffitilab/"
local selected, aiming, preview = 1, false, nil
local design = pieces[selected]
local placed = {}
local lifetime, capacity = 590000, 16
local elapsed, sinceSample, epoch, assetError = 0, 0, nil, nil
local selector, studio
local handleBudget = 768

local function release(mark)
    for _, handle in mark.handles do fx.release(handle) end
end

local function usedHandles()
    local count = 0
    for _, mark in placed do count += #mark.handles end
    return count
end

local function discardPreview()
    if preview then release(preview) end
    preview, assetError = nil, nil
end

local function reset()
    fx.clear()
    table.clear(placed)
    aiming, preview, sinceSample, elapsed, assetError = false, nil, 0, 0, nil
    if selector then selector.close() end
    studio.close()
end

local function ready()
    local available, current = fx.state()
    local offline = not reskate.session.active()
    if current ~= epoch or ((not available or not offline) and (aiming or #placed > 0)) then
        reset()
        epoch = current
    end
    return available and offline
end

local function updatePreview()
    local transform = surface(reskate.world, reskate.camera.get(), reskate.level.current, design.width, design.height)
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
    if usedHandles()+count > handleBudget then
        if assetError ~= "budget" then reskate.log("Remove a mark to make room for this drawing") end
        assetError = "budget"
        return false
    end
    local mark = {id=design.id,handles={},transform=transform,expires=elapsed+lifetime}
    for i=1,count do
        local asset = if parts then parts[i].asset else design.id
        local matrix = if parts then wallArt.transform(transform,parts[i]) else transform
        local handle, why = fx.decal(assetRoot .. asset .. "_dv", matrix)
        if not handle then
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

local function aim(piece)
    if not ready() then return end
    if design ~= piece then discardPreview() end
    design, aiming = piece, true
    local start = os.clock()
    local visible = updatePreview()
    reskate.log(piece.name .. (if visible then " preview active" else " selected, waiting for a wall"))
    if visible and piece.parts then
        reskate.log(string.format("Blackbook preview %s: %d decals, %d x %d, initial update %.2f ms",
            piece.id,#piece.parts,piece.resolution,piece.resolution/2,(os.clock()-start)*1000))
    end
end

studio = makeStudio(function(file,doc)
    local parts, resolution = wallArt.compile(doc)
    if not parts then return false,resolution end
    if usedHandles()+#parts > handleBudget or #placed >= capacity then return false,"Remove a wall mark first." end
    studio.close()
    aim({id=file,name=doc.name,parts=parts,resolution=resolution,width=wallArt.width,height=wallArt.height})
    return true
end)
selector = makeSelector(pieces, function(index)
    selected = index
    aim(pieces[index])
end, studio.open)

local function place()
    if not aiming then return end
    if #placed >= capacity then
        reskate.log("Remove a mark before placing another (16 on this map)")
        return
    end
    if not updatePreview() then reskate.log("Placement needs a valid preview") return end
    for _,handle in preview.handles do fx.opacity(handle,1) end
    table.insert(placed, preview)
    reskate.log("Placed " .. preview.id .. " handle " .. preview.handles[1] .. " (" .. #preview.handles .. " decals)")
    preview, aiming = nil, false
end

local function remove()
    if aiming then
        discardPreview()
        aiming = false
    elseif #placed > 0 then
        local piece = table.remove(placed)
        release(piece)
        reskate.log("Removed " .. piece.id .. " handle " .. piece.handles[1] .. " (" .. #piece.handles .. " decals)")
    end
end

-- Keep the three original action IDs so milestone 1 player rebindings still work.
local function openLibrary()
    studio.close()
    selector.open(selected)
    reskate.log("Opened Premade Art")
end
local function openStudio(which)
    selector.close()
    studio.open(which)
end
local actions = {
    ["Open Custom Editor"] = function() openStudio("editor") end,
    ["Open Blackbook"] = function() openStudio("gallery") end,
    ["Open Graffiti Lab"] = openLibrary,
    ["Open Graffiti Lab on pad"] = openLibrary,
    ["Aim Switchback"] = function() if aiming then remove() else aim(design) end end,
    ["Place Switchback"] = place,
    ["Remove Switchback"] = remove,
}
local function action(name)
    if studio.active() and (name == "Aim Switchback" or name == "Place Switchback" or name == "Remove Switchback") then return end
    if actions[name] and ready() then actions[name]() end
end
reskate.input.bind("Open Custom Editor", "Ctrl+E")
reskate.input.bind("Open Blackbook", "Ctrl+B")
reskate.input.bind("Open Graffiti Lab", "Ctrl+L")
reskate.input.bind("Open Graffiti Lab on pad", "Pad.Back+Pad.Y")
reskate.input.bind("Aim Switchback", "Ctrl+G")
reskate.input.bind("Place Switchback", "Ctrl+P")
reskate.input.bind("Remove Switchback", "Ctrl+R")
reskate.on("action", action)
reskate.console.command("graffiti", "library, editor, blackbook, aim, place, remove or status", function(args)
    local commands = {library = "Open Graffiti Lab", editor = "Open Custom Editor", blackbook = "Open Blackbook",
        aim = "Aim Switchback", place = "Place Switchback", remove = "Remove Switchback"}
    if commands[args[1]] then action(commands[args[1]]) return end
    local available = ready()
    local marks = {}
    for _, mark in placed do table.insert(marks, mark.id .. "#" .. mark.handles[1]) end
    reskate.log(string.format("ready=%s selected=%s preview=%s placed=[%s]", tostring(available),
        design.id, if preview then preview.id .. "#" .. preview.handles[1] else "none", table.concat(marks, ", ")))
end)
reskate.on("level_unloading", reset)
reskate.on("unload", reset)
reskate.on("tick", function(dt)
    if not ready() then selector.close() studio.close() return end
    if not aiming and #placed == 0 then return end
    elapsed += dt
    -- Placed handles keep their creation deadline, even when a preview was held for a while.
    for i = #placed, 1, -1 do
        if elapsed >= placed[i].expires then release(table.remove(placed, i)) end
    end
    if not aiming then return end
    if preview and elapsed >= preview.expires then discardPreview() end
    sinceSample += dt
    if sinceSample >= 100 then
        sinceSample = 0
        updatePreview()
    end
end)
