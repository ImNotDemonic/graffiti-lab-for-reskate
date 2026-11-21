local surface = require("surface")
local fx = reskate.effects
local asset = "world/materials/decal/reskate_graffitilab/switchback_dv"
local mode, handle, epoch = "idle", nil, nil
local sinceSample, age = 0, 0
local assetError

local function clear()
    -- clear is idempotent, including after the renderer has retired the handle.
    fx.clear()
    handle, age = nil, 0
end

local function reset()
    clear()
    mode, sinceSample, assetError = "idle", 0, nil
end

local function ready()
    local available, current = fx.state()
    if current ~= epoch or (not available and mode ~= "idle") then
        reset()
        epoch = current
    end
    local inSession = reskate.session.active()
    if mode ~= "idle" and inSession then reset() end
    return available and not inSession
end

local function updatePreview()
    local transform = surface(reskate.world, reskate.camera.get(), reskate.level.current)
    if not transform then
        if handle then clear() end
        return false
    end
    if handle then
        if pcall(fx.move, handle, transform) then return true end
        clear()
    end
    local why
    handle, why = fx.decal(asset, transform)
    if not handle then
        if why ~= assetError then reskate.log("Switchback preview: " .. tostring(why)) end
        assetError = why
        return false
    end
    fx.opacity(handle, 0.45)
    age, assetError = 0, nil
    return true
end

local function action(name)
    if not ready() then
        reskate.log("Switchback needs an offline level with a ready effects renderer")
        return
    end
    if name == "Aim Switchback" then
        if mode == "placed" then return end
        if mode == "aiming" then reset() else
            mode = "aiming"
            local visible = updatePreview()
            reskate.log(if visible then "Switchback preview active" else "Aiming Switchback, waiting for a suitable wall or decal asset")
        end
    elseif name == "Place Switchback" and mode == "aiming" then
        if updatePreview() then
            fx.opacity(handle, 1)
            mode = "placed"
            local level = reskate.level.current()
            reskate.log("Switchback placed in " .. (level and level.name or "unknown level"))
        else
            reskate.log("Switchback placement needs a valid preview")
        end
    elseif name == "Remove Switchback" then
        local removed = mode == "placed"
        reset()
        if removed then reskate.log("Switchback removed") end
    end
end

reskate.input.bind("Aim Switchback", "Ctrl+G")
reskate.input.bind("Place Switchback", "Ctrl+P")
reskate.input.bind("Remove Switchback", "Ctrl+R")
reskate.on("action", action)
reskate.console.command("graffiti", "aim, place, remove or status", function(args)
    local commands = {aim = "Aim Switchback", place = "Place Switchback", remove = "Remove Switchback"}
    if commands[args[1]] then
        action(commands[args[1]])
    else
        local available = ready()
        reskate.log(string.format("Switchback %s, ready %s, handle %s", mode, tostring(available), tostring(handle)))
    end
end)
reskate.on("level_unloading", reset)
reskate.on("unload", reset)
reskate.on("tick", function(dt)
    if not ready() or mode == "idle" then return end
    age += dt
    if handle and age >= 590000 then reset() return end
    if mode == "aiming" then
        sinceSample += dt
        if sinceSample >= 100 then
            sinceSample = 0
            updatePreview()
        end
    end
end)
