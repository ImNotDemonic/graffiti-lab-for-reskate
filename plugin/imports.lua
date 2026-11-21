-- User files describe rectangles of existing resident wall inks. No material or
-- asset path is accepted from the file, or announced to a multiplayer session.
local imports={}
local folder,helper="imports","Import Artwork.html"

function imports.reveal()
    local html,why=reskate.package.read("art/"..helper)
    if not html then return nil,why end
    local ok
    ok,why=reskate.files.write(folder.."/"..helper,html)
    if not ok then return nil,why end
    return reskate.files.reveal(folder)
end

function imports.list()
    local entries,why=reskate.files.list(folder)
    if not entries then return {},why end
    local designs={}
    for _,file in entries do
        local name=file:match("^([%w _%-]+)%.graffiti$")
        if name and #name<=64 then
            table.insert(designs,{id="import/"..file,name=name,category="My imports",
                file=folder.."/"..file,aspect=1,colourway="Local artwork"})
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

function imports.load(piece)
    if piece.parts then return true end
    if piece.problem then return false end
    local raw,why=reskate.files.read(piece.file)
    local parts,aspect
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
