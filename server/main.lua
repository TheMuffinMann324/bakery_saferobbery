-- Boot, the admin command and the client -> server callback surface.
local RES = GetCurrentResourceName()
local ready = false

CreateThread(function()
    DB.init()
    Data.load()
    Safes.load()
    ready = true
    local safes, boxes = 0, 0
    for _, s in ipairs(Safes.list) do if s.kind == 'lockbox' then boxes = boxes + 1 else safes = safes + 1 end end
    print(('^2[%s] ready - %d safes, %d lockboxes^7'):format(RES, safes, boxes))
    TriggerClientEvent('bakery_saferobbery:client:all', -1, Safes.views())
    TriggerClientEvent('bakery_saferobbery:client:settings', -1, ClientSettings())
end)

RegisterCommand(Config.Admin.Command, function(src)
    if src <= 0 or not ready then return end
    if not Bridge.isAdmin(src) then
        return Bridge.notify(src, 'You don\'t have access to that.', 'error')
    end
    TriggerClientEvent('bakery_saferobbery:client:openAdmin', src)
end, false)

-- Per player throttle so the callbacks can't be spammed.
local throttle = {}
local function allowed(src, key, ms)
    local t = GetGameTimer()
    throttle[src] = throttle[src] or {}
    local last = throttle[src][key]
    if last and t - last < ms then return false end
    throttle[src][key] = t
    return true
end
AddEventHandler('playerDropped', function() throttle[source] = nil end)

lib.callback.register(RES .. ':getSafes', function(src)
    if ready and allowed(src, 'getSafes', 1500) then return Safes.views() end
end)

-- Prompt reach and the item to watch for inventory changes.
function ClientSettings()
    return { interactDistance = Data.settings.interactDistance, explosiveItem = Data.settings.explosiveItem }
end

lib.callback.register(RES .. ':settings', function(src)
    if ready and allowed(src, 'settings', 1500) then return ClientSettings() end
end)

for name, fn in pairs(Robbery.handlers) do
    lib.callback.register(('%s:%s'):format(RES, name), function(src, payload)
        if not ready then return { ok = false, error = 'Starting up.' } end
        if not allowed(src, name, name == 'keypad:try' and 600 or 250) then return { ok = false, error = 'Slow down.' } end
        local ok, res = pcall(fn, src, type(payload) == 'table' and payload or {})
        if not ok then
            print(('^1[%s] %s failed: %s^7'):format(RES, name, res))
            return { ok = false, error = 'Something went wrong.' }
        end
        return res
    end)
end

local writes = { save = true, reset = true, saveSafe = true, deleteSafe = true, resetSafe = true, resetAll = true }
local writing = false
for name, fn in pairs(Admin.handlers) do
    lib.callback.register(('%s:admin:%s'):format(RES, name), function(src, payload)
        if not Bridge.isAdmin(src) then return { ok = false, error = 'No access.' } end
        if not ready then return { ok = false, error = 'Starting up.' } end
        if not allowed(src, 'admin:' .. name, 250) then return { ok = false, error = 'Slow down.' } end
        if writes[name] then
            if writing then return { ok = false, error = 'Another change is being saved. Try again.' } end
            writing = true
        end
        local ok, res = pcall(fn, src, payload)
        if writes[name] then writing = false end
        if not ok then
            print(('^1[%s] admin:%s failed: %s^7'):format(RES, name, res))
            return { ok = false, error = 'Something went wrong.' }
        end
        return res
    end)
end
