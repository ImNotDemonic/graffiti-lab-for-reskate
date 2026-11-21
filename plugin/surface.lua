-- One centre ray, two nearby samples for the plane, then a footprint check.
local up = vector.create(0, 1, 0)
local reach = 8
local size = 0.65
local tolerance = 0.035
-- These two identifiers were observed on separate visits to the Blue Light Beach kiosk.
local kioskReceivers = {
    ["world/plots/downtown/dtn_plt_14/dtn_plt_14_base_c_arch_foot_mid_01"] = true,
    ["levels/game/bam_levelroot/generated/stairslitepg_agasset_b8e7ee88"] = true,
}

local function structuralReceiver(object, level)
    if not level or not level.name then return false end
    local name = string.lower(level.name)
    local blueprint = string.lower(object.blueprint or "")
    if kioskReceivers[blueprint] then return name == "levels/game/bam_levelroot/bam_levelroot" end
    -- Studio gives the arcade's baked structural collision meshes their own blueprints.
    local map = string.match(blueprint, "^world/custom/([%w_]+)/collision/%d+_str_[%w_]+%.physics_bp$")
    return map ~= nil and string.match(name, "([^/]+)$") == map
end

return function(world, view, currentLevel)
    if not view then return nil end
    local origin, forward = view.position, view.forward
    local function sample(start)
        local ray = world.probe(start, start + forward * reach)
        return if ray.status == "hit" then ray.position else nil
    end

    local centre = sample(origin)
    if not centre then return nil end
    local picked = world.pick(origin, origin + forward * reach)
    if not picked or vector.magnitude(picked.position - centre) > tolerance then
        return nil
    end
    if picked.object and not structuralReceiver(picked.object, currentLevel()) then return nil end

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
    for x = -1, 1, 2 do
        for z = -1, 1, 2 do
            local corner = centre + (right * x + down * z) * (size / 2)
            local cast = world.probe(origin, corner + vector.normalize(corner - origin) * 0.10)
            if cast.status ~= "hit" or vector.magnitude(cast.position - corner) > tolerance then
                return nil
            end
        end
    end
    local x, y, z = right * size, normal * 0.045, down * size
    local p = centre + normal * 0.006
    return {x.x, x.y, x.z, 0, y.x, y.y, y.z, 0, z.x, z.y, z.z, 0, p.x, p.y, p.z, 1}
end
