local surface = require("surface")
local makeSelector = require("selector")
local studio = require("studio")()
local pieces = assert(reskate.package.read_json("art/catalogue.json"))
local fx = reskate.effects
local assetRoot = "world/materials/decal/reskate_graffitilab/"
local selected, aiming, preview = 1, false, nil
local placed = {}
local lifetime, capacity = 590000, 16
local elapsed, sinceSample, epoch, assetError = 0, 0, nil, nil
local selector

local function discardPreview()
    if preview then fx.release(preview.handle) end
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
    local transform = surface(reskate.world, reskate.camera.get(), reskate.level.current)
    if not transform then discardPreview() return false end
    if preview then
        fx.move(preview.handle, transform)
        return true
    end
    local piece = pieces[selected]
    local handle, why = fx.decal(assetRoot .. piece.id .. "_dv", transform)
    if not handle then
        if why ~= assetError then reskate.log(piece.name .. " preview: " .. tostring(why)) end
        assetError = why
        return false
    end
    fx.opacity(handle, 0.45)
    preview = {id = piece.id, handle = handle, expires = elapsed + lifetime}
    assetError = nil
    return true
end

local function aim(index)
    if not ready() then return end
    if selected ~= index then discardPreview() end
    selected, aiming = index, true
    local visible = updatePreview()
    reskate.log(pieces[index].name .. (if visible then " preview active" else " selected, waiting for a wall"))
end

selector = makeSelector(pieces, aim, studio.open)

local function place()
    if not aiming then return end
    if #placed >= capacity then
        reskate.log("Remove a mark before placing another (16 on this map)")
        return
    end
    if not updatePreview() then reskate.log("Placement needs a valid preview") return end
    fx.opacity(preview.handle, 1)
    -- Transfer ownership of this exact handle. Future selections only replace the preview.
    table.insert(placed, preview)
    reskate.log("Placed " .. preview.id .. " handle " .. preview.handle)
    preview, aiming = nil, false
end

local function remove()
    if aiming then
        discardPreview()
        aiming = false
    elseif #placed > 0 then
        local piece = table.remove(placed)
        fx.release(piece.handle)
        reskate.log("Removed " .. piece.id .. " handle " .. piece.handle)
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
    ["Aim Switchback"] = function() if aiming then remove() else aim(selected) end end,
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
    for _, mark in placed do table.insert(marks, mark.id .. "#" .. mark.handle) end
    reskate.log(string.format("ready=%s selected=%s preview=%s placed=[%s]", tostring(available),
        pieces[selected].id, if preview then preview.id .. "#" .. preview.handle else "none", table.concat(marks, ", ")))
end)
reskate.on("level_unloading", reset)
reskate.on("unload", reset)
reskate.on("tick", function(dt)
    if not ready() then selector.close() studio.close() return end
    if not aiming and #placed == 0 then return end
    elapsed += dt
    -- Placed handles keep their creation deadline, even when a preview was held for a while.
    for i = #placed, 1, -1 do
        if elapsed >= placed[i].expires then fx.release(table.remove(placed, i).handle) end
    end
    if not aiming then return end
    if preview and elapsed >= preview.expires then discardPreview() end
    sinceSample += dt
    if sinceSample >= 100 then
        sinceSample = 0
        updatePreview()
    end
end)
