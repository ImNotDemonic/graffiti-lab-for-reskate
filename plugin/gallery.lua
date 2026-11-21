-- Only contact the HTTPS host explicitly approved by the plugin manifest.
local imports=require("imports")
local book=require("blackbook")
local wallArt=require("wall_art")
local base
local gallery={}

local function artId(id)
    return type(id)=="string" and #id==36 and id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")~=nil
end
local function label(value,limit)
    return type(value)=="string" and #value<=limit and not value:find("%c")
end
function gallery.row(item)
    if type(item)~="table" or not artId(item.id) or not label(item.title,256) or not label(item.creator,192)
        or not label(item.description,960) or type(item.thumbnail)~="string" then return nil end
    return imports.decode(item.thumbnail)
end
function gallery.profiles()
    local found={}
    for _,file in reskate.files.list("gallery/accounts") or {} do
        local name=file:match("^([%w _%-]+)%.key$")
        if name and #name<=48 then table.insert(found,name) end
    end
    table.sort(found)
    return found
end
local function token(profile)
    if not profile:match("^[%w _%-]+$") or #profile>48 then return nil,"Invalid profile" end
    local key,why=reskate.files.read("gallery/accounts/"..profile..".key")
    if not key then return nil,why end
    key=key:match("^%s*(.-)%s*$")
    if #key~=64 or not key:match("^%x+$") then return nil,"Invalid creator key. Check the selected profile." end
    return key
end
function gallery.request(path,payload,profile,callback)
    if not base then
        local m=reskate.package.read_json("reskate-plugin.json")
        if not m or not m.domains or not m.domains[1] then callback(nil,"Missing gallery domain. Reinstall Graffiti Lab.") return end
        base="https://"..m.domains[1].."/v1/"
    end
    local opts={url=base..path,method=if payload then "POST" else "GET"}
    if payload then
        payload=table.clone(payload)
        if profile then
            local key,why=token(profile)
            if not key then callback(nil,why) return end
            payload.token=key
        end
        local ok,raw=pcall(reskate.json.encode,payload)
        if not ok or #raw>65536 then callback(nil,"Artwork exceeds the request size.") return end
        opts.body,opts.content_type=raw,"application/json"
    end
    local ok,id,why=pcall(reskate.http.request,opts,function(status,raw,problem)
        local decoded,data=pcall(reskate.json.decode,raw or "")
        if problem or not decoded or type(data)~="table" or status<200 or status>=300 then
            local msg=if decoded and type(data)=="table" and label(data.error,180) then data.error
                else "Gallery unavailable. Check your connection and retry."
            callback(nil,msg) return
        end
        callback(data)
    end)
    if not ok or not id then callback(nil,if ok then tostring(why) else "Request refused. Check plugin permissions or retry in a minute.") end
end
function gallery.browse(query,page,callback)
    local escaped=query:gsub("([^%w%-_%.~])",function(c) return string.format("%%%02X",c:byte()) end)
    gallery.request("browse?q="..escaped.."&page="..page,nil,nil,function(data,why)
        if not data then callback(nil,why) return end
        if type(data.items)~="table" or #data.items>8 then callback(nil,"Unsupported gallery response") return end
        for _,item in data.items do
            local parts,aspect=gallery.row(item)
            if not parts then callback(nil,"Invalid gallery entry") return end
            item.preview={parts=parts,aspect=aspect}
        end
        callback(data)
    end)
end
function gallery.sources()
    local out={}
    for _,piece in imports.list() do
        if not piece.downloaded then table.insert(out,{name=piece.name,file=piece.file,index=piece.index,kind="import"}) end
    end
    for _,file in book.list() or {} do
        table.insert(out,{name=file,file=file,kind="drawing"})
    end
    table.sort(out,function(a,b) return a.file<b.file end)
    return out
end
function gallery.prepare(source)
    if source.kind=="import" then
        local raw,why=reskate.files.read(source.file)
        if raw and source.index then
            local ok,pack=pcall(reskate.json.decode,raw)
            local item=ok and type(pack)=="table" and type(pack.items)=="table" and pack.items[source.index]
            raw=if type(item)=="table" and type(item.frame)=="string" then item.frame else nil
        end
        if raw and imports.decode(raw) then return raw,source.name end
        return nil,why or "Damaged import"
    end
    local doc,why=book.read(source.file)
    if not doc then return nil,why end
    local asset,msg=require("media_format").fromDrawing(doc,wallArt)
    if not asset then return nil,msg end
    return asset.frames[1],doc.name,asset
end
function gallery.store(item,expected)
    if not gallery.row(item) or item.id~=expected then return nil,"Invalid downloaded artwork" end
    local a=item.asset
    local frames,reason=require("media_format").validate(a,imports.decode)
    if not frames then return nil,reason end
    local files,why=reskate.files.list("gallery/downloads")
    if not files and why~="not found" then return nil,why end
    for _,file in files or {} do
        if file:sub(-42)=="~"..expected..".json" then return true,"Already in My imports" end
    end
    local name=item.title:gsub("[^%w _%-]",""):sub(1,48)
    if name=="" then name="Gallery artwork" end
    local data={version=1,id=item.id,title=item.title,creator=item.creator,description=item.description,tags=item.tags,frame=a.frames[1],media=if #a.frames>1 or a.sound then a else nil}
    local path="gallery/downloads/"..name.."~"..expected..".json"
    local ok,problem=reskate.files.write(path,reskate.json.encode(data))
    if not ok then return nil,problem end
    return true,"Saved to Premade Art / My imports"
end
function gallery.download(id,profile,callback)
    if not artId(id) then callback(nil,"Invalid artwork ID") return end
    if profile then gallery.request("download",{id=id},profile,callback)
    else gallery.request("art/"..id,nil,nil,callback) end
end
return gallery
