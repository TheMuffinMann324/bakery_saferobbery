-- Admin panel endpoints. main.lua re-checks admin permission before every one of these.
Admin = { handlers = {} }

local H = Admin.handlers

-- Full safe data for the panel, code and live state included.
local function adminSafe(s)
    local v = Safes.view(s)
    v.code = s.code
    v.rewards = s.rewards
    v.lootLeft = v.loot and #v.loot or 0
    v.loot = nil
    v.busyBy = s.action and GetPlayerName(s.action.src) or nil
    return v
end

local function safes()
    local out = {}
    for _, s in ipairs(Safes.list) do out[#out + 1] = adminSafe(s) end
    return out
end

H.getData = function()
    return {
        settings = Data.settings,
        safes = safes(),
        serverTime = os.time(),
    }
end

H.live = function()
    return { safes = safes(), serverTime = os.time() }
end

H.save = function(_, p)
    if type(p) ~= 'table' then return { ok = false, error = 'Bad request.' } end
    local value = Data.save(p.section, p.value)
    if value == nil then return { ok = false, error = 'Could not save that.' } end
    if p.section == 'settings' then TriggerClientEvent('bakery_saferobbery:client:settings', -1, ClientSettings()) end
    return { ok = true, value = value }
end

H.reset = function(_, p)
    local value = Data.reset(type(p) == 'table' and p.section)
    if value == nil then return { ok = false, error = 'Unknown section.' } end
    if p.section == 'settings' then TriggerClientEvent('bakery_saferobbery:client:settings', -1, ClientSettings()) end
    return { ok = true, value = value }
end

H.saveSafe = function(_, p)
    local s = Safes.upsert(p)
    if not s then return { ok = false, error = 'That safe has no position yet.' } end
    return { ok = true, value = adminSafe(s) }
end

H.deleteSafe = function(_, p)
    return { ok = Safes.remove(type(p) == 'table' and p.id) }
end

-- Shut and relock straight away (ends any cooldown, puts the padlock back).
H.resetSafe = function(_, p)
    local s = Safes.get(type(p) == 'table' and p.id)
    if not s then return { ok = false, error = 'Not found.' } end
    Safes.relock(s, true)
    return { ok = true, value = adminSafe(s) }
end

H.resetAll = function()
    for _, s in ipairs(Safes.list) do
        if s.state ~= 'locked' or s.lockoutUntil or s.action then Safes.relock(s, true) end
    end
    return { ok = true }
end

H.randomCode = function()
    return { ok = true, code = Utils.code() }
end
