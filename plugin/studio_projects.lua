local model=require("composition")
local imports=require("imports")
local storage={}
local root="studio/"
local function read(path)
    local bytes,why=reskate.files.read(path)
    if not bytes then return nil,why end
    local ok,obj=pcall(reskate.json.decode,bytes)
    if not ok or type(obj)~="table" or not model.valid(obj.master) then return nil,"Could not read layered artwork. The file was retained." end
    return obj.master,obj.thumb
end
function storage.list()
    local files,why=reskate.files.list("studio/projects")
    if not files and why~="not found" then return {},why end
    local ids={}
    for _,f in files or {} do
        local id=f:match("^(p%d+%-%d+)%.json$")
        if id then table.insert(ids,id) end
    end
    table.sort(ids)
    return ids
end
function storage.open(id)
    if type(id)~="string" or not id:match("^p%d+%-%d+$") then return nil,"Invalid project ID." end
    return read(root.."projects/"..id..".json")
end
function storage.draft() return read(root.."draft.json") end
function storage.save(p,asDraft,thumb)
    if not model.valid(p) then return nil,"Unsupported layer data. Your previous save is intact." end
    local path=if asDraft then root.."draft.json" else root.."projects/"..p.id..".json"
    local ok,raw=pcall(reskate.json.encode,{master=p,thumb=thumb})
    if not ok then return nil,"Could not encode the project." end
    return reskate.files.write(path,raw)
end
function storage.premade(p,raw)
    if not raw then return nil,"Add visible ink first." end
    local title=p.name:gsub("[^%w _%-]",""):sub(1,31)
    if title=="" then title="Studio" end
    local name=title.." "..model.key(raw)
    local file=name..".graffiti"
    local path="imports/"..file
    local prior,why=reskate.files.read(path)
    if prior~=raw then
        if prior or why~="not found" then return nil,why or "A different file already uses the artwork ID." end
        local ok,msg=reskate.files.write(path,raw)
        if not ok then return nil,msg end
    end
    local piece={name=p.name,id="import/"..file,file=path,category="My imports"}
    if not imports.load(piece) then return nil,piece.problem end
    return piece
end
function storage.prepare(p,forEmote)
    if p.parts or (p.sheet and not p.file) then return true end
    if p.project then
        local parts,aspect
        if type(p.rawFrame)=="string" then parts,aspect=imports.decode(p.rawFrame) end
        if not parts then
            local master,why=storage.open(p.project)
            if not master then return nil,why end
            p.rawFrame,parts=model.render(master)
            if not p.rawFrame then return nil,parts end
            aspect=master.aspect
        end
        p.parts,p.aspect=parts,aspect
    elseif p.drawing then
        local doc,why=require("blackbook").read(p.drawing)
        if not doc then return nil,why end
        local wall=require("wall_art")
        p.width,p.height,p.aspect=wall.width,wall.height,wall.width/wall.height
        if doc.animation and forEmote then
            local frames={}
            local cover
            for i,frame in doc.animation.frames do
                if #frame.strokes==0 then frames[i]={} else
                    local parts,why=wall.compile(frame,32)
                    if not parts then return nil,why end
                    frames[i]=parts
                    if #parts>0 and not cover then cover=parts end
                end
            end
            if not cover then return nil,"This drawing has no visible ink." end
            p.parts,p.frames,p.frameMs=cover,frames,doc.animation.frameMs
        elseif doc.animation then
            local format=require("media_format")
            local media,msg=format.fromDrawing(doc,wall)
            if not media then return nil,msg end
            local frames,aspect=format.validate(media,imports.decode)
            if not frames then return nil,aspect end
            p.media,p.frames,p.parts,p.aspect=media,frames,frames[1],aspect
        else
            local parts,resolution=wall.compile(doc)
            if not parts then return nil,resolution end
            p.parts,p.gridWidth=parts,resolution
        end
    elseif p.file then
        if not imports.load(p) then return nil,p.problem end
    end
    if not p.parts then return nil,"Artwork could not be decoded." end
    return true
end
function storage.image(p)
    if p.sheet and not p.file then
        local source,why=require("reshape").source(p)
        if not source then return nil,why end
        return source.grids[1],source.aspect
    end
    local ok,msg=storage.prepare(p)
    if not ok then return nil,msg end
    -- Use what actually displays, including already reshaped copies.
    local source,why=require("reshape").source({parts=p.parts,aspect=p.aspect,gridWidth=p.gridWidth,rawFrame=p.rawFrame,frames=p.frames,media=p.media})
    if not source then return nil,why end
    return source.grids[1],source.aspect
end
return storage
