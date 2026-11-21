local media={}
local function integer(n,a,b) return type(n)=="number" and n%1==0 and n>=a and n<=b end
function media.sound(s)
    return s==nil or (type(s)=="table" and (s.id=="spray-burst" or s.id=="spray-loop")
        and (s.trigger=="interact" or s.trigger=="approach" or s.trigger=="nearby-loop")
        and integer(s.volume,0,100) and integer(s.radius,1,20) and integer(s.cooldown,1,60))
end
function media.validate(asset,decode)
    if type(asset)~="table" or asset.version~=1 or asset.kind~="ink" or type(asset.frames)~="table" or
        not integer(#asset.frames,1,8) or not integer(asset.frameMs,100,5000) or not media.sound(asset.sound) then
        return nil,"Unsupported artwork version, timing, sound or frame count."
    end
    local frames,ratio={},nil
    for i,raw in asset.frames do
        if not integer(i,1,#asset.frames) or type(raw)~="string" then return nil,"Invalid animation frame." end
        local parts,aspect=decode(raw)
        if not parts or (ratio and math.abs(aspect-ratio)>0.00001) then return nil,"Damaged frame or mismatched proportions." end
        frames[i],ratio=parts,aspect
    end
    return frames,ratio
end
function media.frame(parts,w)
    local h=w/2
    local lines={string.format("GLART1 %d %d 2048 1024",w,h)}
    for _,p in parts do
        table.insert(lines,string.format("%d %d %d %d %d",math.round((p.x+.5-p.w/2)*w),
            math.round((p.y+.5-p.h/2)*h),math.round(p.w*w),math.round(p.h*h),p.colour))
    end
    return table.concat(lines,"\n")
end
function media.fromDrawing(doc,wall)
    local frames={}
    local src=if doc.animation then doc.animation.frames else {doc}
    for i,frame in src do
        local parts,w=wall.compile(frame,if #src>1 then 16 else 64)
        if not parts then return nil,"Frame "..i..": "..tostring(w) end
        frames[i]=media.frame(parts,w)
    end
    return {version=1,kind="ink",frames=frames,frameMs=if doc.animation then doc.animation.frameMs else 250,sound=doc.sound}
end
return media
