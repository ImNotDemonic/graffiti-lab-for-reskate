-- Organisation has its own file. Each edit commits before becoming visible.
local library={}
local path="library/organisation.json"
local state,original
local undo,redo={},{}
local function fresh() return {version=1,folders={},items={},recent={},collections={}} end
local function label(s,n) return type(s)=="string" and #s>0 and #s<=n and not s:find("%c") end
local function valid(s)
    if type(s)~="table" or s.version~=1 or type(s.items)~="table" or type(s.folders)~="table" or type(s.recent)~="table" then return false end
    for k,v in s.folders do if not label(k,40) or v~=true then return false end end
    for k,v in s.items do
        if not label(k,200) or type(v)~="table" or (v.folder and not s.folders[v.folder]) or
            (v.favourite~=nil and type(v.favourite)~="boolean") then return false end
    end
    for i,k in s.recent do if type(i)~="number" or not label(k,200) then return false end end
    if s.collections~=nil then
        if type(s.collections)~="table" then return false end
        for key,c in s.collections do
            if type(key)~="string" or not key:match("^c%x+%-%x+$") or #key>24 or type(c)~="table" or not label(c.name,64)
                or type(c.names)~="table" or #c.names>12 then return false end
            for _,n in c.names do if not label(n,64) then return false end end
        end
    end
    return true
end
function library.get()
    if state then return state end
    local raw,why=reskate.files.read(path)
    if not raw then
        if why~="not found" then return nil,why or "Cannot read library" end
        state=fresh()
    else
        local ok,s=pcall(reskate.json.decode,raw)
        if not ok or not valid(s) then return nil,"Organisation file could not be read. Your artwork is still available." end
        state=s
    end
    original=raw
    return state
end
local function write(s)
    local disk,why=reskate.files.read(path)
    if not disk and why~="not found" then return nil,why end
    if disk~=original then state=nil table.clear(undo) table.clear(redo) return nil,"Library changed on disk. Reopen it." end
    local encoded,raw=pcall(reskate.json.encode,s)
    if not encoded then return nil,"Unable to encode library" end
    local ok,msg=reskate.files.write(path,raw)
    if not ok then return nil,msg end
    state,original=s,raw
    return true
end
local function clone(s)
    return {version=1,folders=table.clone(s.folders),items=table.clone(s.items),recent=table.clone(s.recent),collections=table.clone(s.collections or {})}
end
function library.change(action,id,value)
    local s,why=library.get()
    if not s then return nil,why end
    local nextState=clone(s)
    if action=="create folder" or action=="rename folder" then
        if not label(value,40) or not value:find("%S") or s.folders[value] then return nil,"Choose a unique folder name (1–40 characters)." end
        nextState.folders[value]=true
    end
    if action=="collection import" then
        if nextState.collections[id] then return nil,"Collection identity already exists." end
        nextState.collections[id]=value
        if not valid(nextState) then return nil,"Invalid collection listing." end
    elseif action=="rename folder" or action=="remove folder" then
        if not s.folders[id] then return nil,"Select a folder first." end
        nextState.folders[id]=nil
        for key,old in s.items do
            if old.folder==id then
                local row=table.clone(old)
                row.folder=if action=="rename folder" then value else nil
                nextState.items[key]=row
            end
        end
    elseif action=="favourite" or action=="move artwork" then
        if not label(id,200) or (action=="move artwork" and value and not s.folders[value]) then return nil,"Select artwork and a valid destination." end
        local row=table.clone(s.items[id] or {})
        if action=="favourite" then row.favourite=not row.favourite else row.folder=value end
        nextState.items[id]=row
    elseif action~="create folder" then return nil,"Unknown library action" end
    local ok,msg=write(nextState)
    if not ok then return nil,msg end
    table.insert(undo,{before=s,after=nextState,label=action})
    if #undo>24 then table.remove(undo,1) end
    table.clear(redo)
    return true
end
function library.used(id)
    local s,why=library.get()
    if not s then return nil,why end
    if s.recent[1]==id then return true end
    local nextState=clone(s)
    local i=table.find(nextState.recent,id)
    if i then table.remove(nextState.recent,i) end
    table.insert(nextState.recent,1,id)
    if #nextState.recent>64 then table.remove(nextState.recent) end
    return write(nextState)
end
function library.history(forward,apply)
    local src,dest=if forward then redo else undo,if forward then undo else redo
    local item=src[#src]
    if not item or not apply then return item and item.label end
    local s=clone(if forward then item.after else item.before)
    s.recent=table.clone(state.recent)
    local ok,why=write(s)
    if not ok then return nil,why end
    table.remove(src) table.insert(dest,item) return true
end
function library.filter(rows,query,folder,favourite,recent)
    local s=library.get() or fresh()
    local out={}
    query=string.lower(query)
    for _,row in rows do
        local entry=s.items[row.id] or {}
        if (not folder or entry.folder==folder) and (not favourite or entry.favourite)
            and (not recent or table.find(s.recent,row.id)) and row.search:find(query,1,true) then table.insert(out,row) end
    end
    if recent then table.sort(out,function(a,b) return table.find(s.recent,a.id)<table.find(s.recent,b.id) end) end
    return out
end
return library
