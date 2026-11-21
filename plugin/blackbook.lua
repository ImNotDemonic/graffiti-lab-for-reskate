-- One file is one editable drawing. The file name is its stable ID across renames.
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

local function valid(doc)
    if type(doc) ~= "table" or doc.version ~= 1 or type(doc.name) ~= "string"
        or #doc.name < 1 or #doc.name > 32 or doc.name:find("[^ -~]")
        or not array(doc.strokes, book.maxStrokes) then return false end
    for _, stroke in doc.strokes do
        if type(stroke) ~= "table" or not integer(stroke.colour, 1, #book.palette)
            or not integer(stroke.size, 2, 64) or not array(stroke.xy, book.maxPoints * 2)
            or #stroke.xy < 2 or #stroke.xy % 2 ~= 0 then return false end
        for i = 1, #stroke.xy, 2 do
            if not integer(stroke.xy[i], 0, book.width) or not integer(stroke.xy[i+1], 0, book.height) then return false end
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
    local raw, why = reskate.files.read(file)
    if not raw then return nil, why end
    local ok, doc = pcall(reskate.json.decode, raw)
    if not ok or not valid(doc) then return nil, "Unsupported or damaged drawing" end
    return doc, raw
end

function book.new()
    return {version = 1, name = "Untitled", strokes = {}}
end

function book.save(doc, file, original)
    if not valid(doc) then return nil, "Drawing exceeds the supported limits" end
    if file then
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
    local raw = reskate.json.encode(doc)
    local ok, why = reskate.files.write(file, raw)
    if not ok then return nil, why end
    return file, raw
end

return book
