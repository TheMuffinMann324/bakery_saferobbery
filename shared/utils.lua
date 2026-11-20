-- Small helpers shared by the client and the server.
Utils = {}

local charset = 'abcdefghijklmnopqrstuvwxyz0123456789'

function Utils.uid(prefix)
    local s = {}
    for i = 1, 8 do
        local n = math.random(1, #charset)
        s[i] = charset:sub(n, n)
    end
    return (prefix and (prefix .. '_') or '') .. table.concat(s)
end

function Utils.find(list, id)
    if type(list) ~= 'table' then return nil end
    for i, v in ipairs(list) do
        if v.id == id then return v, i end
    end
    return nil
end

function Utils.contains(list, value)
    if type(list) ~= 'table' then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

function Utils.clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function Utils.finite(value, fallback)
    local n = tonumber(value)
    if n and n == n and n > -math.huge and n < math.huge then return n end
    return fallback
end

function Utils.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Utils.copy(v) end
    return out
end

-- Random 4 digit code, as a string ("0427").
function Utils.code()
    return ('%04d'):format(math.random(0, 9999))
end

function Utils.validCode(code)
    return type(code) == 'string' and code:match('^%d%d%d%d$') ~= nil
end

-- Body-space offset -> world, for an upright prop with only a heading.
function Utils.offset(pos, heading, off)
    local h = math.rad(heading)
    local c, s = math.cos(h), math.sin(h)
    return vector3(pos.x + off.x * c - off.y * s, pos.y + off.x * s + off.y * c, pos.z + off.z)
end

function Utils.debug(...)
    if Config.Debug then print('^5[bakery_saferobbery]^7', ...) end
end
