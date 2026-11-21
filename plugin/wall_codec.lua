local codec={}
local rowBytes=53
local assetRoot="world/materials/decal/reskate_graffitilab/ink_%02d_dv"
function codec.pack(id,colour,matrix)
    local b=buffer.create(rowBytes)
    buffer.writeu32(b,0,id)
    buffer.writeu8(b,4,colour)
    for axis=0,3 do
        for j=0,2 do buffer.writef32(b,5+axis*12+j*4,matrix[axis*4+j+1]) end
    end
    return buffer.tostring(b)
end

function codec.unpack(row)
    local b=buffer.fromstring(row)
    local id,colour=buffer.readu32(b,0),buffer.readu8(b,4)
    if id==0 or colour<1 or colour>8 then return end
    local m=table.create(16,0)
    for axis=0,3 do
        for j=0,2 do
            local n=buffer.readf32(b,5+axis*12+j*4)
            if not (math.abs(n)<math.huge) then return end
            m[axis*4+j+1]=n
        end
    end
    m[16]=1
    return id,string.format(assetRoot,colour),m
end

return codec
