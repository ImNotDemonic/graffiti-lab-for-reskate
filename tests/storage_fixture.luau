-- ReSkate-shaped data store for standalone Luau. Values cross simulated restarts as bytes.
local function encodeValue(value)
    local kind=type(value)
    if kind=="table" then
        local fields={}
        for k,v in value do table.insert(fields,encodeValue(k)..encodeValue(v)) end
        table.sort(fields)
        return "t"..#fields..":"..table.concat(fields)
    end
    assert(kind=="boolean" or kind=="string" or kind=="number")
    local s=tostring(value)
    return kind:sub(1,1)..#s..":"..s
end
local function decodeValue(raw)
    local pos=1
    local function read()
        local kind=raw:sub(pos,pos)
        local split=assert(raw:find(":",pos+1,true))
        local n=assert(tonumber(raw:sub(pos+1,split-1)))
        pos=split+1
        if kind=="t" then
            local out={}
            for i=1,n do local k=read() out[k]=read() end
            return out
        end
        local s=raw:sub(pos,pos+n-1)
        pos+=n
        if kind=="b" then return s=="true" elseif kind=="n" then return assert(tonumber(s)) end
        assert(kind=="s") return s
    end
    local result=read() assert(pos==#raw+1)
    return result
end
local function memoryFiles(disk)
    return {
        read=function(p) if disk[p] then return disk[p] end return nil,"not found" end,
        write=function(p,s) assert(type(s)=="string" and #s<=1048576) disk[p]=s return true end,
        remove=function(p) disk[p]=nil return true end,
        list=function(p)
            p=p or ""
            local prefix=if p=="" or p:sub(-1)=="/" then p else p.."/"
            local names={}
            for key in disk do
                if key:sub(1,#prefix)==prefix and not key:sub(#prefix+1):find("/",1,true) then table.insert(names,key:sub(#prefix+1)) end
            end
            table.sort(names) return names
        end,
    }
end
reskate.json={encode=encodeValue,decode=decodeValue}
reskate.files=memoryFiles({})
