-- Placed safes and lockboxes: what the admin set up (saved) plus their live state (memory only,
-- apart from the cooldown which survives a restart).
--
-- state: 'locked'  ready to rob
--        'charged' a breaching charge is on the door, fuse running
--        'open'    opened; loot can be taken until the cooldown ends, then it closes and relocks
Safes = { list = {} }
local byId = {}
local active = {}
local actionId = 0

local function now() return os.time() end

local function persisted(s)
    return {
        label = s.label, kind = s.kind, enabled = s.enabled,
        x = s.x, y = s.y, z = s.z, h = s.h,
        code = s.code, note = s.note, rewards = s.rewards,
    }
end

local num = Utils.finite

local function round(n, p) local m = 10 ^ (p or 3) return math.floor(n * m + 0.5) / m end

-- Cleans an admin payload into a safe definition. Returns nil if it can't be used.
local function clean(v, existing)
    if type(v) ~= 'table' then return nil end
    local kind = v.kind == 'lockbox' and 'lockbox' or 'safe'
    local x, y, z = num(v.x), num(v.y), num(v.z)
    if not x or not y or not z or (x == 0 and y == 0) then return nil end
    local note = nil
    if kind == 'safe' and type(v.note) == 'table' and num(v.note.x) and num(v.note.y) and num(v.note.z) then
        -- orientation as two unit vectors: up = out of the surface, fwd = the top edge of the note
        local function unit(x, y, z, fx, fy, fz)
            x, y, z = num(x, fx), num(y, fy), num(z, fz)
            local l = math.sqrt(x * x + y * y + z * z)
            if l < 0.001 then return fx, fy, fz end
            return round(x / l, 4), round(y / l, 4), round(z / l, 4)
        end
        local ux, uy, uz = unit(v.note.ux, v.note.uy, v.note.uz, 0.0, 0.0, 1.0)
        local fx, fy, fz = unit(v.note.fx, v.note.fy, v.note.fz, 0.0, 1.0, 0.0)
        note = {
            x = round(num(v.note.x), 4), y = round(num(v.note.y), 4), z = round(num(v.note.z), 4),
            ux = ux, uy = uy, uz = uz, fx = fx, fy = fy, fz = fz,
        }
    end
    local code = Utils.validCode(v.code) and v.code or (existing and existing.code) or Utils.code()
    -- own rewards; a safe saved before rewards existed copies the loot table it used
    local rewards
    if type(v.rewards) == 'table' then
        rewards = Data.cleanRewards(v.rewards, kind)
    elseif existing and existing.rewards and existing.kind == kind then
        rewards = existing.rewards
    else
        rewards = Data.legacyRewards(v.lootTable, kind)
    end
    local label = type(v.label) == 'string' and v.label:sub(1, 48) or ''
    if label == '' then label = kind == 'lockbox' and 'Lockbox' or 'Safe' end
    local id = existing and existing.id
    if not id then
        local prefix = kind == 'lockbox' and 'box' or 'safe'
        repeat id = Utils.uid(prefix) until not byId[id]
    end
    return {
        id = id,
        label = label,
        kind = kind,
        enabled = v.enabled ~= false,
        x = round(x), y = round(y), z = round(z), h = round(num(v.h, 0.0) % 360.0, 2),
        code = kind == 'safe' and code or nil,
        note = note,
        rewards = rewards,
    }
end

-- What every client gets: never the code, loot only as categories (for the props inside).
function Safes.view(s)
    local loot = nil
    if s.state == 'open' and s.loot then
        loot = {}
        for i, e in ipairs(s.loot) do
            if not e.taken then loot[#loot + 1] = { i = i, c = e.category, l = e.label } end
        end
    end
    -- a random tag that changes whenever the code does, so clients know to redraw the note (without being told the code)
    if s.note and s._tagCode ~= s.code then s._tagCode, s._noteTag = s.code, math.random(1, 2000000000) end
    return {
        id = s.id, label = s.label, kind = s.kind, enabled = s.enabled,
        x = s.x, y = s.y, z = s.z, h = s.h, note = s.note, noteTag = s.note and s._noteTag or nil,
        state = s.state, method = s.method, loot = loot,
        fuseEnd = s.fuseEnd, lockoutUntil = s.lockoutUntil, cooldownUntil = s.cooldownUntil,
        busy = s.action ~= nil,
    }
end

function Safes.views()
    local out = {}
    for _, s in ipairs(Safes.list) do out[#out + 1] = Safes.view(s) end
    return out
end

function Safes.get(id)
    if type(id) == 'string' and #id <= 32 then return byId[id] end
end

function Safes.broadcast(s)
    TriggerClientEvent('bakery_saferobbery:client:safe', -1, Safes.view(s))
end

function Safes.cooldownFor(s)
    return s.kind == 'lockbox' and Data.settings.lockboxCooldown or Data.settings.safeCooldown
end

function Safes.reserve(s, src, mode, item)
    if s.removed or not s.enabled or s.state ~= 'locked' or s.action or active[src] then return end
    actionId = actionId + 1
    local action = { id = actionId, src = src, mode = mode, started = GetGameTimer(),
        bucket = GetPlayerRoutingBucket(src), item = item }
    s.action, active[src] = action, s
    Safes.broadcast(s)
    return action
end

function Safes.release(s)
    if not s.action then return end
    active[s.action.src], s.action = nil, nil
end

function Safes.load()
    Safes.list = {}
    byId = {}
    for _, row in ipairs(DB.loadSafes()) do
        local s = clean(row, { id = row.id, code = row.code })
        if s then
            s.state, s.attempts = 'locked', 0
            if row._cooldownUntil > now() then
                -- restarted during a cooldown: stays open (and empty) until it runs out
                s.state, s.method, s.loot, s.cooldownUntil = 'open', 'restart', {}, row._cooldownUntil
            end
            Safes.list[#Safes.list + 1] = s
            byId[s.id] = s
        end
    end
end

-- Create or update from the admin panel. Keeps the live state of an existing safe.
function Safes.upsert(v)
    local existing = type(v) == 'table' and type(v.id) == 'string' and Safes.get(v.id) or nil
    local s = clean(v, existing)
    if not s then return nil end
    DB.saveSafe(s, persisted(s))
    if existing then
        local changed = not s.enabled or existing.kind ~= s.kind or existing.code ~= s.code
            or existing.x ~= s.x or existing.y ~= s.y or existing.z ~= s.z or existing.h ~= s.h
        if changed then
            Safes.release(existing)
        end
        for k, val in pairs(s) do existing[k] = val end
        for _, k in ipairs({ 'note', 'code' }) do existing[k] = s[k] end
        s = existing
        if changed and s.state == 'charged' then
            Safes.relock(s, true)
            return s
        end
    else
        s.state, s.attempts = 'locked', 0
        Safes.list[#Safes.list + 1] = s
        byId[s.id] = s
    end
    Safes.broadcast(s)
    return s
end

function Safes.remove(id)
    local s = Safes.get(id)
    if not s then return false end
    DB.deleteSafe(id)
    local _, i = Utils.find(Safes.list, id)
    table.remove(Safes.list, i)
    byId[id] = nil
    s.removed = true
    Safes.release(s)
    TriggerClientEvent('bakery_saferobbery:client:remove', -1, id)
    return true
end

-- Back to 'locked': door shut, padlock back on, maybe a new code.
function Safes.relock(s, keepCode)
    Safes.release(s)
    s.state, s.method, s.loot = 'locked', nil, nil
    s.cooldownUntil, s.fuseEnd, s.lockoutUntil = nil, nil, nil
    s.attempts, s.charge = 0, nil
    local definition
    if s.kind == 'safe' and Data.settings.randomizeCode and not keepCode then
        s.code = Utils.code()
        definition = persisted(s)
    end
    DB.setCooldown(s.id, 0, definition)
    Safes.broadcast(s)
end

-- Ticks cooldowns and keypad lockouts.
CreateThread(function()
    while true do
        Wait(1000)
        local t = now()
        for _, s in ipairs(Safes.list) do
            if s.state == 'open' and s.cooldownUntil and s.cooldownUntil <= t then
                Safes.relock(s)
            elseif s.lockoutUntil and s.lockoutUntil <= t then
                s.lockoutUntil, s.attempts = nil, 0
                Safes.broadcast(s)
            end
            -- someone walked off mid-robbery without finishing: free it after 2 minutes
            if s.action and GetGameTimer() - s.action.started >= 120000 then
                Safes.release(s)
                Safes.broadcast(s)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local s = active[source]
    if not s then return end
    Safes.release(s)
    Safes.broadcast(s)
end)
