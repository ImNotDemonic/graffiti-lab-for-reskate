-- A page is replaced atomically by ReSkate. Only touched pages need rewriting.
-- Each row is stroke ID, colour, and the four 3D axes/translation of a decal.
local rowBytes, rowsPerPage = 53, 2048
local codec=require("wall_codec")

local function folder(map)
    local hash, second=5381,7
    for i=1,#map do
        local byte=string.byte(map,i)
        hash=(hash*33+byte)%4294967296
        second=(second*131+byte)%4294967296
    end
    return string.format("wall-paint/%08x%08x/",hash,second)
end

local function call(method,...)
    local ok,value,why=pcall(method,...)
    if not ok then return nil,tostring(value) end
    return value,why
end

return function(restore)
    local store={ready=false}
    local prefix,header,names,current,pageIndex,slot,newestId,nextRead
    local lastPage, pages, dirty = 0, {}, {}
    local nextWrite,nextAuto,nextWarning=0,0,0

    local function warn(message)
        store.warning=message
        local now=reskate.time.now()
        if now>=nextWarning then
            reskate.log(message)
            reskate.ui.toast(message)
            nextWarning=now+5000
        end
    end

    local function writePage(page)
        local rows={}
        for _,row in ipairs(page.rows) do
            if row then table.insert(rows,row) end
        end
        if #rows==0 then
            local ok,why=call(reskate.files.remove,page.path)
            return ok or why=="not found",why
        end
        return call(reskate.files.write,page.path,page.header..table.concat(rows))
    end

    function store.checkpoint()
        nextAuto=0
    end

    function store.flush(all)
        local now=reskate.time.now()
        if not next(dirty) or (not all and (now<nextWrite or now<nextAuto)) then return end
        for path,page in dirty do
            if not all and page.retry and now<page.retry then continue end
            local ok,why=writePage(page)
            if not ok then
                page.retry=now+1500
                warn("Wall paint unsaved: "..tostring(why))
            else
                dirty[path]=nil
                if not all then break end
            end
        end
        if not next(dirty) then store.warning=nil end
        local completed=reskate.time.now()
        nextWrite,nextAuto=completed+75,completed+1000
    end

    function store.close()
        store.flush(true)
        store.map,store.ready=nil,false
        pages,names,current={},nil,nil
    end

    function store.open(map)
        store.map,store.ready=map,false
        prefix,header=folder(map),"GLW1\n"..map.."\n"
        names,current,pageIndex,slot,newestId,nextRead=nil,nil,1,1,0,0
        lastPage,pages=0,{}
        if not next(dirty) then store.warning=nil end
    end

    local function makePage(number)
        return {path=prefix..string.format("%08d.ink",number),header=header,rows={}}
    end

    function store.load(now)
        if store.ready or not store.map or now<nextRead then return end
        if not names then
            local list,why=call(reskate.files.list,prefix)
            if not list and why~="not found" then
                warn("Cannot open wall paint: "..tostring(why)) nextRead=now+2000 return
            end
            local numbered={}
            for _,name in list or {} do
                local id=name:match("^(%d%d%d%d%d%d%d%d)%.ink$")
                if id then numbered[tonumber(id)]=true end
            end
            for path in dirty do
                if path:sub(1,#prefix)==prefix then numbered[tonumber(path:sub(#prefix+1,-5))]=true end
            end
            names={}
            for id in numbered do table.insert(names,id) end
            table.sort(names)
        end
        if not current then
            local number=names[pageIndex]
            if not number then
                store.ready=true
                if not next(dirty) then store.warning=nil end
                return
            end
            local page=makePage(number)
            if dirty[page.path] then
                page=dirty[page.path]
            else
                local raw,why=call(reskate.files.read,page.path)
                if not raw then warn("Cannot read wall paint: "..tostring(why)) nextRead=now+2000 return end
                if raw:sub(1,#header)~=header or (#raw-#header)%rowBytes~=0 or #raw-#header>rowBytes*rowsPerPage then
                    warn("Unrecognised wall paint file. Saved paint is protected.")
                    nextRead=math.huge return
                end
                for offset=#header+1,#raw,rowBytes do table.insert(page.rows,raw:sub(offset,offset+rowBytes-1)) end
            end
            if page.header~=header then warn("Wall paint map mismatch. Saved paint is protected.") nextRead=math.huge return end
            lastPage,pages[number],current,slot=number,page,page,1
        end
        for _=1,96 do
            local row=current.rows[slot]
            if row==nil then current=nil pageIndex+=1 nextRead=now+35 return end
            if row then
                local id,asset,m=codec.unpack(row)
                if not id then warn("Damaged wall paint. Saved paint is protected.") nextRead=math.huge return end
                newestId=math.max(newestId,id)
                restore(id,asset,m,current,slot)
            end
            slot+=1
        end
    end

    function store.nextId()
        newestId+=1
        return newestId
    end

    function store.add(sample,id,colour)
        local page=pages[lastPage]
        if not page or #page.rows>=rowsPerPage then
            lastPage+=1
            page=makePage(lastPage)
            pages[lastPage]=page
        end
        local slot=#page.rows+1
        page.rows[slot]=codec.pack(id,colour,sample.matrix)
        sample.page,sample.slot,sample.matrix=page,slot,nil
        dirty[page.path]=page
    end

    function store.erase(sample)
        local page=sample.page
        page.rows[sample.slot]=false
        while page.rows[#page.rows]==false do table.remove(page.rows) end
        dirty[page.path]=page
    end

    return store
end
