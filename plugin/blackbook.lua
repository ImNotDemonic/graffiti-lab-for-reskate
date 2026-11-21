-- One file is one editable drawing. The file name is its stable ID across renames.
local pattern=require("pattern")
local media=require("media_format")
local book = {
    width = 2048, height = 1024, maxPoints = 448, maxStrokes = 96,
    palette = assert(reskate.package.read_json("art/palette.json")),
}

local function integer(n, lo, hi)
    return type(n) == "number" and n >= lo and n <= hi and n % 1 == 0
end

local function array(t, limit)
    if type(t) ~= "table" or #t > limit then return false end
    local count = 0
    for k in t do
        if not integer(k, 1, #t) then return false end
        count += 1
    end
    return count == #t
end

function book.pointCount(doc)
    local count = 0
    for _, stroke in doc.strokes do count += #stroke.xy / 2 end
    return count
end

local function fileName(file)
    return type(file) == "string" and file:match("^blackbook%-%d%d%d%d%.json$") ~= nil
end

local function valid(doc,frameOnly)
    if type(doc) ~= "table" or (doc.version ~= 1 and doc.version ~= 2 and doc.version ~= 3) or type(doc.name) ~= "string"
        or #doc.name < 1 or #doc.name > 32 or doc.name:find("[^ -~]")
        or not pattern.validTile(doc.tile) or not array(doc.strokes, book.maxStrokes) then return false end
    for _, stroke in doc.strokes do
        if type(stroke) ~= "table" or not pattern.validBrush(stroke.symmetry) or not integer(stroke.colour, 1, #book.palette)
            or not integer(stroke.size, 2, 64) or not array(stroke.xy, book.maxPoints * 2)
            or #stroke.xy < 2 or #stroke.xy % 2 ~= 0 then return false end
        for i = 1, #stroke.xy, 2 do
            if not integer(stroke.xy[i], 0, book.width) or not integer(stroke.xy[i+1], 0, book.height) then return false end
        end
    end
    if not media.sound(doc.sound) then return false end
    if doc.animation then
        local a=doc.animation
        if frameOnly or type(a)~="table" or not integer(a.frameMs,100,5000) or not array(a.frames,8) or #a.frames<1 then return false end
        for _,frame in a.frames do
            if type(frame)~="table" or frame.animation or not valid({version=2,name="Frame",strokes=frame.strokes,tile=frame.tile},true) then return false end
        end
    end
    return book.pointCount(doc) <= book.maxPoints
end

function book.list()
    local entries, why = reskate.files.list()
    if not entries then return nil, why end
    local names = {}
    for _, name in entries do
        if name:match("^blackbook%-%d%d%d%d%.json$") then table.insert(names, name) end
    end
    table.sort(names, function(a, b) return a > b end)
    return names
end

function book.read(file)
    if not fileName(file) then return nil, "Invalid drawing ID" end
    local raw, why = reskate.files.read(file)
    if not raw then return nil, why end
    local ok, doc = pcall(reskate.json.decode, raw)
    if not ok or not valid(doc) then return nil, "Unsupported or damaged drawing" end
    if doc.version >= 2 and (doc.kind ~= "drawing" or doc.artworkId ~= file) then
        return nil, "Drawing ID does not match its file"
    end
    -- Reading a legacy drawing never modifies its file.
    doc.kind, doc.artworkId = "drawing", file
    return doc, raw
end

function book.new()
    return {version = 2, kind = "drawing", name = "Untitled", strokes = {}}
end

function book.save(doc, file, original)
    if not valid(doc) then return nil, "Drawing exceeds the supported limits" end
    if file then
        if not fileName(file) or (doc.artworkId and doc.artworkId ~= file) then return nil, "Drawing ID mismatch" end
        local current, why = reskate.files.read(file)
        if not current then return nil, why end
        if current ~= original then return nil, "File changed on disk. Reopen it before saving." end
    else
        local names, why = book.list()
        if not names then return nil, why end
        local number = if names[1] then tonumber(names[1]:match("%d+")) + 1 else 1
        if number > 9999 then return nil, "Drawing IDs exhausted" end
        file = string.format("blackbook-%04d.json", number)
    end
    local saved = table.clone(doc)
    saved.version, saved.kind, saved.artworkId = 2, "drawing", file
    if doc.tile or doc.animation or doc.sound or doc.version==3 then saved.version=3 end
    for _,s in doc.strokes do if s.symmetry then saved.version=3 break end end
    local encoded, raw = pcall(reskate.json.encode, saved)
    if not encoded then return nil, "Cannot encode drawing" end
    if original and doc.version < saved.version then
        local backup = "recovery/blackbook-v"..doc.version.."/" .. file
        local prior, why = reskate.files.read(backup)
        if prior == nil then
            if why ~= "not found" then return nil, why or "Cannot check the recovery copy" end
            local copied, problem = reskate.files.write(backup, original)
            if not copied then return nil, problem or "Cannot preserve the original drawing" end
        elseif prior ~= original then
            return nil, "A different recovery copy exists. The original drawing is protected."
        end
    end
    local ok, why = reskate.files.write(file, raw)
    if not ok then return nil, why end
    doc.version, doc.kind, doc.artworkId = saved.version, saved.kind, saved.artworkId
    return file, raw
end

return book
