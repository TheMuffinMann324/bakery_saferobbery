-- NUI glue: messages to the UI, the admin panel open / close, and admin calls proxied to the server.
Nui = { admin = false, focus = {} }

local RES = GetCurrentResourceName()

function Nui.send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- Several things can want the cursor (admin panel, keypad). The cursor stays while any does.
function Nui.setFocus(who, on)
    Nui.focus[who] = on or nil
    local any = next(Nui.focus) ~= nil
    SetNuiFocus(any, any)
end

function Nui.call(name, payload)
    local ok, result = pcall(lib.callback.await, ('%s:%s'):format(RES, name), false, payload)
    if ok then return result end
    Utils.debug(result)
end

RegisterNUICallback('call', function(data, cb)
    local name = type(data) == 'table' and data.name
    if not Nui.admin or type(name) ~= 'string' or not name:match('^admin:%w+$') then
        return cb({ ok = false, error = 'Not allowed.' })
    end
    local res = Nui.call(name, data.args)
    if res == nil then res = { ok = false, error = 'No response.' } end
    cb(res)
end)

local function openAdmin()
    if Nui.admin then return end
    Nui.admin = true
    Nui.setFocus('admin', true)
    Nui.send('admin', { open = true })
end

local function closeAdmin()
    if not Nui.admin then return end
    Nui.admin = false
    Nui.setFocus('admin', false)
    Nui.send('admin', { open = false })
end

RegisterNetEvent('bakery_saferobbery:client:openAdmin', function()
    if source == 65535 then openAdmin() end
end)

RegisterNUICallback('admin:close', function(_, cb)
    closeAdmin()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    SetNuiFocus(false, false)
end)
