--[[--
Cursor movement over the scanned words of the visible page.

The words are kept in document reading order, which gives a natural linear
left/right movement (index +/- 1). Vertical movement picks the nearest
neighbour in the requested direction, using the `|dx| * 2 + |dy|` metric.

Pure Lua, unit testable.

@module koplugin.hop_lookup.hoplookup_nav
--]]--

local Nav = {}

-- Horizontal weight of the distance when looking for the nearest word above
-- or below the current one (a small horizontal move is cheaper than a big
-- horizontal move on a further line).
Nav.dx_weight = 2

function Nav.center(word)
    if not word or not word.x or not word.y or not word.w or not word.h then
        return nil, nil
    end
    return word.x + word.w / 2, word.y + word.h / 2
end

--[[--
Index of the word closest to the horizontal middle line of the screen.

Ties are broken by the distance to the vertical middle of the screen.
Returns nil when there is no word at all.
]]
function Nav.initial_index(words, screen_w, screen_h)
    local best_index
    local best_dy, best_dx
    for i, word in ipairs(words or {}) do
        local cx, cy = Nav.center(word)
        if cx and cy then
            local dy = math.abs(cy - screen_h / 2)
            local dx = math.abs(cx - screen_w / 2)
            if not best_index or dy < best_dy or (dy == best_dy and dx < best_dx) then
                best_index, best_dy, best_dx = i, dy, dx
            end
        end
    end
    return best_index
end

--[[--
Linear move: `step` is -1 (previous word) or 1 (next word).
No wrapping: moving past either end returns nil.
]]
function Nav.move_linear(words, index, step)
    if not index or not step or step == 0 then
        return nil
    end
    local target = index + step
    if target < 1 or target > #(words or {}) then
        return nil
    end
    return target
end

--[[--
Nearest neighbour above (`direction` < 0) or below (`direction` > 0) the
current word, minimizing `|dx| * 2 + |dy|`. Returns nil when there is no
word in that direction.
]]
function Nav.move_vertical(words, index, direction)
    local current = words and words[index]
    if not current or direction == 0 then
        return nil
    end
    local cur_x, cur_y = Nav.center(current)
    if not cur_x or not cur_y then
        return nil
    end
    local best_index, best_score
    for i, word in ipairs(words) do
        if i ~= index then
            local cx, cy = Nav.center(word)
            if cx and cy then
                local dy = cy - cur_y
                local towards = (direction < 0 and dy < 0) or (direction > 0 and dy > 0)
                if towards then
                    local score = math.abs(cx - cur_x) * Nav.dx_weight + math.abs(dy)
                    if not best_score or score < best_score then
                        best_index, best_score = i, score
                    end
                end
            end
        end
    end
    return best_index
end

return Nav
