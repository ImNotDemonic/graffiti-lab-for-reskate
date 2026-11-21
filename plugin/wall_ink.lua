-- Wall strokes own their samples. ReSkate handles are a disposable view of them.
local cellSize = 8
local eraseCellSize = 0.5
local hostLimit = 2048
local batchSize = 32

return function(fx)
    local ink = {live=0, total=0, strokes=0, limit=hostLimit}
    local cells, live, eraseCells = {}, {}, {}
    local newestCell, lastInput, serial = nil, 0, 0
    local queue, index, nextPlan, nextExpiry = {}, 1, 0, math.huge
    local dirty,lastEye,lastActiveCell=true,nil,nil
    local capacity, reserved, retryAt, probeAt = hostLimit, 0, 0, 0

    local function hide(sample)
        -- The host may already have pruned this handle during pause or a mode change.
        pcall(fx.release,live[sample])
        live[sample]=nil
        ink.live-=1
    end

    function ink.rendererBusy(artHandles,now)
        capacity=math.min(hostLimit,math.max(1,ink.live+artHandles))
        ink.limit=math.max(0,capacity-reserved)
        retryAt,probeAt=now+125,now+1000
        dirty=true
    end

    local function display(sample,now)
        local handle,why=fx.decal(sample.asset,sample.matrix)
        if not handle then
            -- A full global pool and a temporarily unavailable renderer share a return value.
            ink.rendererBusy(reserved,now)
            ink.reason=why
            return false
        end
        live[sample]=handle
        ink.live+=1
        sample.refresh=now+585000
        nextExpiry=math.min(nextExpiry,sample.refresh)
        ink.reason=nil
        return true
    end

    function ink.add(mark,asset,matrix,now,restoring)
        local position=vector.create(matrix[13],matrix[14],matrix[15])
        local key=vector.floor(position/cellSize)
        local cell=cells[key]
        if not cell then
            cell={key=key,centre=(key+vector.create(0.5,0.5,0.5))*cellSize}
            cells[key]=cell
        end
        serial+=1
        local sample={asset=asset,matrix=matrix,cell=cell,older=cell.head,serial=serial,mark=mark,index=#mark.samples+1}
        local eraseKey=vector.floor(position/eraseCellSize)
        local bin=eraseCells[eraseKey]
        if not bin then
            bin={key=eraseKey,items={}}
            eraseCells[eraseKey]=bin
        end
        sample.bin,sample.binIndex=bin,#bin.items+1
        table.insert(bin.items,sample)
        if cell.head then cell.head.newer=sample end
        cell.head=sample
        if not restoring then newestCell,lastInput=cell,now end
        if #mark.samples==0 then ink.strokes+=1 end
        table.insert(mark.samples,sample)
        ink.total+=1
        dirty=true
        if not restoring and ink.live<ink.limit and now>=retryAt then display(sample,now) end
        return sample
    end

    local function unlink(sample)
        if live[sample] then hide(sample) end
        local cell=sample.cell
        if sample.newer then sample.newer.older=sample.older else cell.head=sample.older end
        if sample.older then sample.older.newer=sample.newer end
        if not cell.head then
            cells[cell.key]=nil
            if newestCell==cell then newestCell=nil end
        end
        local bin=sample.bin
        local tail=bin.items[#bin.items]
        tail.binIndex=sample.binIndex
        bin.items[sample.binIndex]=tail
        bin.items[#bin.items]=nil
        if #bin.items==0 then eraseCells[bin.key]=nil end
        sample.cell,sample.older,sample.newer,sample.bin=nil,nil,nil,nil
        ink.total-=1
        dirty=true
        nextPlan=0
    end

    function ink.remove(mark,forget)
        for _,sample in mark.samples do
            if forget then forget(sample) end
            unlink(sample)
        end
        ink.strokes-=1
        table.clear(mark.samples)
    end

    -- Intersect the eraser disk with each stamp's rectangle on the picked face.
    function ink.erase(hit,radius,forget,onEmpty)
        local point=vector.create(hit[13],hit[14],hit[15])
        local face=vector.normalize(vector.create(hit[5],hit[6],hit[7]))
        local reach=vector.one*(radius+0.15)
        local lo,hi=vector.floor((point-reach)/eraseCellSize),vector.floor((point+reach)/eraseCellSize)
        for x=lo.x,hi.x do for y=lo.y,hi.y do for z=lo.z,hi.z do
            local bin=eraseCells[vector.create(x,y,z)]
            if not bin then continue end
            for i=#bin.items,1,-1 do
                local sample=bin.items[i]
                local m=sample.matrix
                local offset=point-vector.create(m[13],m[14],m[15])
                local n=vector.normalize(vector.create(m[5],m[6],m[7]))
                if vector.dot(offset,offset)<(radius+0.15)^2 and vector.dot(face,n)>0.95 and math.abs(vector.dot(offset,n))<0.012 then
                    local a,b=vector.create(m[1],m[2],m[3]),vector.create(m[9],m[10],m[11])
                    local dx=math.max(0,math.abs(vector.dot(offset,vector.normalize(a)))-vector.magnitude(a)/2)
                    local dy=math.max(0,math.abs(vector.dot(offset,vector.normalize(b)))-vector.magnitude(b)/2)
                    if dx*dx+dy*dy<=radius*radius then
                        local mark=sample.mark
                        forget(sample)
                        unlink(sample)
                        local tail=mark.samples[#mark.samples]
                        tail.index=sample.index
                        mark.samples[sample.index]=tail
                        mark.samples[#mark.samples]=nil
                        if #mark.samples==0 then ink.strokes-=1 onEmpty(mark) end
                    end
                end
            end
        end end end
    end

    -- Free slots for a premade or Blackbook preview before the artwork asks the host.
    function ink.reserve(artHandles)
        if reserved~=artHandles then dirty=true end
        reserved=artHandles
        ink.limit=math.max(0,capacity-reserved)
        if ink.live<=ink.limit then return end
        for sample in live do
            hide(sample)
            if ink.live<=ink.limit then break end
        end
        nextPlan=0
    end

    local function plan(eye,activeCell)
        local ordered={}
        for _,cell in cells do
            local delta=cell.centre-eye
            cell.distance=vector.dot(delta,delta)
            table.insert(ordered,cell)
        end
        if activeCell then activeCell.distance=-1 end
        table.sort(ordered,function(a,b)
            if a.distance==b.distance then return a.head.serial>b.head.serial end
            return a.distance<b.distance
        end)
        local remaining=ink.limit
        local wanted={}
        table.clear(queue)
        index=1
        for _,cell in ordered do
            local sample=cell.head
            while sample and remaining>0 do
                wanted[sample]=true
                if not live[sample] then table.insert(queue,sample) end
                remaining-=1
                sample=sample.older
            end
            if remaining==0 then break end
        end
        -- Retire only enough for this batch. Keep other visible ink until its replacement is ready.
        local freed=0
        for sample in live do
            if not wanted[sample] then
                hide(sample)
                freed+=1
                if freed>=batchSize then break end
            end
        end
        dirty=freed>=batchSize
        lastActiveCell,lastEye=activeCell,eye
    end

    function ink.tick(now)
        if ink.total==0 then return end
        if now>=nextExpiry then
            nextExpiry=math.huge
            dirty=true
            for sample in live do
                if now>=sample.refresh then hide(sample) else nextExpiry=math.min(nextExpiry,sample.refresh) end
            end
        end
        if capacity<hostLimit and now>=probeAt then
            capacity=hostLimit
            dirty=true
            ink.limit=math.max(0,capacity-reserved)
        end
        if ink.live==ink.total or now<retryAt then return end
        if now>=nextPlan then
            local camera=reskate.camera.get()
            if not camera then return end
            local activeCell=if now-lastInput<=350 then newestCell else nil
            local delta=if lastEye then camera.position-lastEye else vector.zero
            if dirty or activeCell~=lastActiveCell or vector.dot(delta,delta)>1 then
                plan(camera.position,activeCell)
            end
            nextPlan=now+125
        end
        for _=1,batchSize do
            if index>#queue or ink.live>=ink.limit then break end
            local sample=queue[index]
            if sample.cell and not live[sample] and not display(sample,now) then
                nextPlan=0
                break
            end
            index+=1
        end
    end

    -- Called after fx.clear() invalidates the whole map's handles.
    function ink.reset()
        table.clear(cells)
        table.clear(eraseCells)
        table.clear(live)
        table.clear(queue)
        newestCell,lastInput,serial=nil,0,0
        index,nextPlan,nextExpiry=1,0,math.huge
        dirty,lastEye,lastActiveCell=true,nil,nil
        capacity,reserved,retryAt,probeAt=hostLimit,0,0,0
        ink.total,ink.live,ink.strokes,ink.limit,ink.reason=0,0,0,hostLimit,nil
    end
    return ink
end
