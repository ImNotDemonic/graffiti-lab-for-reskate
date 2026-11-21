-- The native capture is taken before the overlay. Leave camera, HUD and game input in their existing state.
local photo={}
local phase,deadline,path,done
local function finish(note)
    if phase=="recording" or phase=="saving" then reskate.capture.discard() end
    local callback=done
    phase,done=nil,nil
    if note and callback then callback(note) end
end
function photo.start(callback)
    if phase then return false,"A photo is already in progress." end
    path=string.format("imports/Photo-%08x-%08x.png",math.floor(reskate.time.now())%4294967296,math.random(0,0x3fffffff))
    local existing,why=reskate.files.read(path)
    if existing or why~="not found" then return false,why or "Please take the photo again." end
    done,phase,deadline=callback,"framing",reskate.time.now()+4000
    reskate.ui.toast("Frame your photo. Capturing in 4 seconds. Esc cancels.")
    return true
end
function photo.cancel() if phase then finish(nil) end end
reskate.on("level_unloading",photo.cancel)
reskate.on("unload",photo.cancel)
reskate.on("tick",function()
    if not phase then return end
    if phase~="saving" and reskate.input.key("Escape") then finish("Photo cancelled.") return end
    local now=reskate.time.now()
    if phase=="framing" then
        if now<deadline then return end
        local ok,why=reskate.capture.start({depth=false,height=512,frames=1,seconds=3})
        if not ok then finish("Capture unavailable: "..tostring(why)) return end
        phase,deadline="recording",now+8000
    else
        local state=reskate.capture.state()
        if state.state=="failed" then finish(tostring(state.message or "Capture failed.")) return end
        if phase=="recording" and state.state=="stopped" then
            local kept=reskate.capture.kept()
            if #kept==0 then finish("No frame captured. Try again in a loaded map.") return end
            local ok,why=reskate.capture.save(path,{format="png",cutout="none",frames={kept[1]},size=512})
            if not ok then finish(tostring(why)) return end
            phase,deadline="saving",now+60000
        elseif phase=="saving" and state.state=="saved" then
            finish("Saved "..path:sub(9)..". Open the image preparer and choose this photo.")
        elseif now>deadline then finish("Capture timed out. Check the imports folder before retrying.") end
    end
end)
return photo
