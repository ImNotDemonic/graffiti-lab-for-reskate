-- The Premade Art dock uses the handoff's 576 px column on a 1080-line canvas.
local title = "Premade Art"
local ink, muted, blaze = "#F2EFE9", "#B5B2AC", "#FF5A1F"
local tileX, tileY, tileSize, tileStep = 48, 198, 152, 164
local buttonY = 880

return function(pieces, onChoose)
    local open, focus, scale = false, 1, 1
    local held = {}

    local function close()
        open = false
        reskate.ui.close()
    end

    reskate.ui.screen(title, function() end, {panel = false})
    reskate.on("screen_closed", function(name)
        if name == title then open = false end
    end)

    reskate.on("draw", function(d)
        if not open then return end
        local screen = d:size()
        scale = math.min(screen.y / 1080, screen.x / 576)
        if scale <= 0 then return end
        local function p(x, y) return vector.create(x * scale, y * scale, 0) end
        local function rect(x, y, w, h, colour)
            d:rect(p(x, y), p(x + w, y + h), {colour = colour, fill = true})
        end
        local function label(x, y, value, font, size, colour)
            d:text(p(x, y), value, {font = font, size = size, colour = colour, shadow = false})
        end
        rect(0, 0, 576, screen.y / scale, "#0D0E10F0")
        label(48, 45, "GRAFFITI LAB  /  LIBRARY", "bold", 16, muted)
        label(48, 78, "PREMADE ART", "title_large", 54, ink)
        d:game_image("brush_bar", p(47, 144), p(198, 154), {colour = blaze, fit = "shape"})
        for i, piece in pieces do
            local x = tileX + (i - 1) * tileStep
            if focus == i then rect(x - 4, tileY - 4, tileSize + 8, tileSize + 8, blaze) end
            d:gradient(p(x, tileY), p(x + tileSize, tileY + tileSize),
                {"#5A564E", "#555149", "#3E3B35", "#46433C"})
            d:image("art/" .. piece.id .. ".png", p(x + 3, tileY + 2), p(x + 149, tileY + 148))
            label(x, tileY + 166, piece.name, "bold", 19, if focus == i then ink else muted)
        end

        local piece = pieces[focus]
        rect(48, 421, 480, 1, "#3A3B3F")
        label(48, 444, string.upper(piece.category), "bold", 15, muted)
        label(48, 469, string.upper(piece.name), "heading", 39, ink)
        d:gradient(p(48, 537), p(528, 804), {"#343432", "#313231", "#202123", "#252627"})
        d:image("art/" .. piece.id .. ".png", p(149, 534), p(425, 810))
        label(48, 824, piece.colourway .. "   /   0.65 × 0.65 m", "body", 20, ink)
        rect(48, buttonY, 480, 60, blaze)
        label(68, buttonY + 13, "PLACE ON WALL", "heading", 26, "#101113")
        label(422, buttonY + 18, "ENTER / A", "bold", 17, "#281914")
        label(48, 980, "Left / Right   Browse         Esc / B   Close", "body", 18, muted)
    end)

    reskate.on("tick", function()
        if not open then return end
        local cursor = reskate.input.cursor()
        local pad = reskate.input.gamepad()
        local buttons = if pad then pad.buttons else {}
        local now = {
            left = reskate.input.key("Left") or buttons.left,
            right = reskate.input.key("Right") or buttons.right,
            accept = reskate.input.key("Enter") or buttons.a,
            back = buttons.b,
            click = cursor and cursor.left,
        }
        local last = held
        held = now
        if now.back and not last.back then close() return end
        if now.left and not last.left then focus = math.max(1, focus - 1) end
        if now.right and not last.right then focus = math.min(#pieces, focus + 1) end
        local accept = now.accept and not last.accept
        if now.click and not last.click and scale > 0 then
            local x, y = cursor.position.x / scale, cursor.position.y / scale
            if y >= tileY and y <= tileY + tileSize + 32 then
                local col = math.floor((x - tileX) / tileStep) + 1
                if pieces[col] and (x - tileX) % tileStep <= tileSize then focus = col end
            elseif x >= 48 and x <= 528 and y >= buttonY and y <= buttonY + 60 then
                accept = true
            end
        end
        if accept then
            close()
            onChoose(focus)
        end
    end)
    return {
        open = function(index)
            if open then return end
            focus, open = index, true
            held = {accept = true, click = true, back = true}
            reskate.ui.open(title)
        end,
        close = function() if open then close() end end,
    }
end
