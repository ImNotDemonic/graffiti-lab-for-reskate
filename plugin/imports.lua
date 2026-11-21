-- User files describe rectangles of existing resident wall inks. No material or
-- asset path is accepted from the file, or announced to a multiplayer session.
local imports={}
local media=require("media_format")
local folder,helper="imports","Import Artwork.html"

function imports.reveal()
    local html,why=reskate.package.read("art/"..helper)
    if not html then return nil,why end
    local ok
    ok,why=reskate.files.write(folder.."/"..helper,html)
    if not ok then return nil,why end
    return reskate.files.reveal(folder)
end

function imports.stockSource(piece)
    if type(piece.id)~="string" or not piece.id:match("^[%w_]+$") then return nil,"Choose a packaged design." end
    local bytes,why=reskate.package.read("art/edit/"..piece.id..".png")
    if not bytes then return nil,why end
    local path=folder.."/"..piece.id..".png"
    local previous,reason=reskate.files.read(path)
    if previous~=bytes then
        if previous or reason~="not found" then return nil,"An existing source has this name. Rename that copy in imports." end
        local ok,msg=reskate.files.write(path,bytes)
        if not ok then return nil,msg end
    end
    return imports.reveal()
end

function imports.list()
    local entries,why=reskate.files.list(folder)
    entries=entries or {}
    local designs={}
    for _,file in entries do
        local name=file:match("^([%w _%-]+)%.graffiti$")
        if name and #name<=64 then
            table.insert(designs,{id="import/"..file,name=name,category="My imports",
                file=folder.."/"..file,aspect=1,colourway="Local artwork"})
        end
    end
    local shared=reskate.files.list("gallery/downloads")
    for _,file in shared or {} do
        local title,id=file:match("^([%w _%-]+)~([0-9a-f%-]+)%.json$")
        if title and #title<=64 and #id==36 then
            table.insert(designs,{id="gallery/"..id,name=title,category="My imports",downloaded=true,
                file="gallery/downloads/"..file,aspect=1,colourway="Public Artworks"})
        end
    end
    local state=require("library").get()
    for key,c in (state and state.collections or {}) do
        for index,name in c.names do
            table.insert(designs,{id="collection/"..key.."/"..index,name=name,file="library/collections/"..key..".json",
                index=index,category="My imports",aspect=1,colourway=c.name,tags={c.name}})
        end
    end
    return designs
end

local function decode(raw)
    if #raw>8192 then return nil end
    local w,h,sourceW,sourceH,first=raw:match("^GLART1 (%d+) (%d+) (%d+) (%d+)\r?\n()")
    if not first then return nil end
    w,h,sourceW,sourceH=tonumber(w),tonumber(h),tonumber(sourceW),tonumber(sourceH)
    if w<1 or w>96 or h<1 or h>96 or sourceW<1 or sourceW>1000000 or sourceH<1 or sourceH>1000000 then return nil end
    local aspect=sourceW/sourceH
    if aspect<1/16 or aspect>16 then return nil end
    local parts={}
    for line in raw:sub(first):gmatch("[^\r\n]+") do
        local x,y,dx,dy,c=line:match("^(%d+) (%d+) (%d+) (%d+) (%d+)$")
        if not c then return nil end
        x,y,dx,dy,c=tonumber(x),tonumber(y),tonumber(dx),tonumber(dy),tonumber(c)
        if dx<1 or dy<1 or x+dx>w or y+dy>h or c<1 or c>16 or #parts>=256 then return nil end
        table.insert(parts,{x=(x+dx/2)/w-0.5,y=(y+dy/2)/h-0.5,w=dx/w,h=dy/h,colour=c,asset=string.format("ink_%02d",c)})
    end
    if #parts>0 then return parts,aspect end
end

imports.decode=decode

function imports.addCollection(file)
    if type(file)~="string" or not file:match("^[%w _%-]+%.collection$") or #file>76 then return nil,"Select a collection in imports." end
    local raw,why=reskate.files.read("imports/"..file)
    if not raw or #raw>64000 then return nil,why or "Collection exceeds 64 KB." end
    local ok,pack=pcall(reskate.json.decode,raw)
    if not ok or type(pack)~="table" or pack.version~=1 or type(pack.items)~="table" or #pack.items<1 or #pack.items>12 then
        return nil,"Use a collection with 1–12 artworks."
    end
    local names={}
    for i,item in pack.items do
        if type(i)~="number" or i%1~=0 or i<1 or i>#pack.items or type(item)~="table" or type(item.name)~="string" or
            #item.name<1 or #item.name>64 or item.name:find("%c") or type(item.frame)~="string" or not decode(item.frame) then return nil,"Invalid collection artwork." end
        names[i]=item.name
    end
    -- Content keys make re-import idempotent. A hash collision never replaces different bytes.
    local a,b=5381,7
    for i=1,#raw do local byte=raw:byte(i) a=(a*33+byte)%4294967296 b=(b*131+byte)%4294967296 end
    local key=string.format("c%08x-%08x",a,b)
    local path="library/collections/"..key..".json"
    local prior,msg=reskate.files.read(path)
    if prior and prior~=raw then return nil,"Conflicting collection ID." end
    if not prior then
        if msg~="not found" then return nil,msg end
        local written,reason=reskate.files.write(path,raw)
        if not written then return nil,reason end
    end
    local lib=require("library")
    local state,problem=lib.get()
    if not state then return nil,problem end
    if state.collections and state.collections[key] then return true end
    return lib.change("collection import",key,{name=file:sub(1,-12),names=names})
end

function imports.load(piece)
    if piece.parts then return true end
    if piece.problem then return false end
    local raw,why=reskate.files.read(piece.file)
    local parts,aspect
    if raw and piece.index then
        local ok,pack=pcall(reskate.json.decode,raw)
        local item=ok and type(pack)=="table" and type(pack.items)=="table" and pack.items[piece.index]
        raw=if type(item)=="table" and type(item.frame)=="string" then item.frame else nil
        why="Damaged collection artwork."
    elseif raw and piece.downloaded then
        local ok,copy=pcall(reskate.json.decode,raw)
        if ok and type(copy)=="table" and copy.version==1 and copy.id==piece.id:sub(9)
            and type(copy.frame)=="string" then
            raw=copy.frame
            if copy.media then
                local frames,msg=media.validate(copy.media,decode)
                if frames then piece.media,piece.frames=copy.media,frames
                else piece.mediaWarning=msg end
            end
            if type(copy.title)=="string" then piece.name=copy.title end
            if type(copy.creator)=="string" then piece.creator=copy.creator end
            piece.tags={}
            if type(copy.tags)=="table" then
                for _,tag in copy.tags do if type(tag)=="string" and #piece.tags<8 then table.insert(piece.tags,tag) end end
            end
        else raw=nil why="Damaged downloaded artwork" end
    end
    if raw then parts,aspect=decode(raw) end
    if not parts then
        piece.problem=why or "Invalid artwork. Export the image again, then refresh."
        return false
    end
    piece.parts,piece.aspect=parts,aspect
    piece.width=0.65*math.min(1,aspect)
    piece.height=0.65*math.min(1,1/aspect)
    return true
end
return imports
