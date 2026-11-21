-- Each client owns its premade marks. A full snapshot also serves clients that just joined.
-- Wire format: GL1|world|map|sequence|key,art,x,y,z,nx,ny,nz|...
local interval, timeout, maxRemote = 3000, 12000, 64
local size, depth = 0.65, 0.045
local up = vector.create(0,1,0)

local function encodeMark(mark)
    local m = mark.transform
    return string.format("%d,%s,%.4f,%.4f,%.4f,%.6f,%.6f,%.6f", mark.handles[1], mark.id,
        m[13],m[14],m[15],m[5]/depth,m[6]/depth,m[7]/depth)
end

local function numberIn(text, limit)
    local n = tonumber(text)
    return if n and math.abs(n)<=limit then n else nil
end

local function decodeMark(row, catalogue)
    local f = string.split(row,",")
    if #f~=8 or not string.match(f[1],"^%d+$") or #f[1]>12 or not catalogue[f[2]] then return end
    local coords = {}
    for i=3,8 do
        local n = numberIn(f[i],if i<=5 then 100000 else 1.001)
        if not n then return end
        coords[i] = n
    end
    local normal = vector.create(coords[6],coords[7],coords[8])
    if math.abs(vector.magnitude(normal)-1)>0.002 or math.abs(normal.y)>0.351 then return end
    normal = vector.normalize(normal)
    local right = vector.normalize(vector.cross(up,normal))
    local x,y,z = right*size, normal*depth, vector.cross(right,normal)*size
    return f[1], {row=row,asset=catalogue[f[2]],matrix={
        x.x,x.y,x.z,0, y.x,y.y,y.z,0, z.x,z.y,z.z,0, coords[3],coords[4],coords[5],1,
    }}
end

return function(pieces, assetRoot)
    local catalogue, peers = {}, {}
    for _,piece in pieces do catalogue[piece.id]=assetRoot..piece.id.."_dv" end
    local count, nextSend, lastAttempt, sequence = 0, 0, -math.huge, 0
    local dirty = false

    local function drop(id)
        local peer = peers[id]
        if not peer then return end
        for _,entry in peer.marks do
            reskate.effects.release(entry.handle)
            count-=1
        end
        peers[id]=nil
    end

    local function receive(from, text, world, map)
        if from.me or from.server or type(text)~="string" or #text>4000 then return end
        local fields = string.split(text,"|")
        if #fields<4 or #fields>20 or fields[1]~="GL1" or fields[2]~=world or fields[3]~=map then return end
        local serial = numberIn(fields[4],2^53-1)
        local peer = peers[from.id]
        if not serial or serial%1~=0 or serial<=0 or (peer and serial<=peer.serial) then return end
        local desired = {}
        for i=5,#fields do
            local id,entry=decodeMark(fields[i],catalogue)
            if not id or desired[id] then return end
            desired[id]=entry
        end
        peer = peer or {marks={}}
        peer.serial, peer.seen = serial, reskate.time.now()
        peers[from.id]=peer
        for id,old in peer.marks do
            if not desired[id] or desired[id].row~=old.row then
                reskate.effects.release(old.handle)
                peer.marks[id]=nil
                count-=1
            end
        end
        for id,entry in desired do
            if not peer.marks[id] and count<maxRemote then
                local handle=reskate.effects.decal(entry.asset,entry.matrix)
                if handle then
                    peer.marks[id]={row=entry.row,handle=handle}
                    count+=1
                    reskate.log("Rendered shared " .. entry.asset .. " handle " .. handle)
                end
            end
        end
    end

    local function tick(placed, world, map)
        local now = reskate.time.now()
        for id,peer in peers do if now-peer.seen>=timeout then drop(id) end end
        if now<nextSend and (not dirty or now-lastAttempt<400) then return end
        sequence=math.max(sequence+1,math.floor(now))
        local rows={"GL1",world,map,tostring(sequence)}
        for _,mark in placed do
            if catalogue[mark.id] and mark.world==world and mark.map==map then
                table.insert(rows,encodeMark(mark))
            end
        end
        local sent=reskate.net.send("all",table.concat(rows,"|"))
        nextSend, lastAttempt, dirty = now+(if sent then interval else 1000), now, false
    end

    return {
        receive=receive, tick=tick, drop=drop,
        changed=function() dirty=true end,
        count=function() return count end,
        reset=function()
            for id in peers do drop(id) end
            nextSend,lastAttempt,dirty=0,-math.huge,false
        end,
    }
end
