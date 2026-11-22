-- One centre ray, two nearby samples for the plane, then a footprint check.
local up = vector.create(0, 1, 0)
local reach = 8
local size = 0.65
local tolerance = 0.035

return function(world, view, width, height, angle)
    if not view then return nil end
    width, height = width or size, height or size
    local origin, forward = view.position, view.forward
    local function sample(start)
        local ray = world.probe(start, start + forward * reach)
        return if ray.status == "hit" then ray.position else nil
    end

    local centre = sample(origin)
    if not centre then return nil end
    local picked = world.pick(origin, origin + forward * reach)
    if not picked or not picked.position or vector.magnitude(picked.position - centre) > tolerance then
        return nil
    end

    local across = sample(origin + view.right * 0.09)
    local above = sample(origin + view.up * 0.09)
    if not across or not above then return nil end
    local cross = vector.cross(across - centre, above - centre)
    if vector.magnitude(cross) < 0.001 then return nil end
    local normal = vector.normalize(cross)
    if vector.dot(normal, forward) > 0 then normal = -normal end
    if math.abs(normal.y) > 0.35 or vector.dot(normal, forward) > -0.4 then return nil end

    local right = vector.normalize(vector.cross(up, normal))
    local down = vector.cross(right, normal)
    local c,s=math.cos(math.rad(angle or 0)),math.sin(math.rad(angle or 0))
    right,down=right*c+down*s,down*c-right*s
    for x = -1, 1, 2 do
        for z = -1, 1, 2 do
            local corner = centre + right * (x * width / 2) + down * (z * height / 2)
            local cast = world.probe(origin, corner + vector.normalize(corner - origin) * 0.10)
            if cast.status ~= "hit" or vector.magnitude(cast.position - corner) > tolerance then
                return nil
            end
        end
    end
    local x, y, z = right * width, normal * 0.045, down * height
    local p = centre + normal * 0.006
    return {x.x, x.y, x.z, 0, y.x, y.y, y.z, 0, z.x, z.y, z.z, 0, p.x, p.y, p.z, 1}
end
