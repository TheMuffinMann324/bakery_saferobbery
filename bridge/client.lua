-- ============================================================
-- CLIENT BRIDGE
-- Notifications, dispatch, progress bars, skill checks and targeting all go through here.
-- Defaults use kq_link (notify / dispatch) and ox_lib. Edit these to swap any of them.
-- ============================================================
Bridge = {}

local kq = exports.kq_link

-- kind: 'info' | 'success' | 'error' | 'warning'
function Bridge.notify(message, kind)
    if not message or message == '' then return end
    local ok = pcall(function() kq:Notify(message, kind or 'info') end)
    if not ok then
        lib.notify({ description = message, type = kind == 'warning' and 'warning' or kind or 'inform' })
    end
end

RegisterNetEvent('bakery_saferobbery:client:notify', function(message, kind)
    if source == 65535 then Bridge.notify(message, kind) end
end)

-- Police alert. data = { coords, title, description, code, jobs }
function Bridge.dispatch(data)
    pcall(function()
        kq:SendDispatchMessage({
            coords = data.coords,
            message = data.title,
            description = data.description,
            code = data.code or '10-90',
            jobs = data.jobs,
            blip = { sprite = 618, color = 1, scale = 1.0, text = data.title, flash = true },
        })
    end)
end

RegisterNetEvent('bakery_saferobbery:client:dispatch', function(data)
    if source == 65535 and type(data) == 'table' and data.coords then
        data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
        Bridge.dispatch(data)
    end
end)

-- Progress bar. Returns true when completed.
function Bridge.progress(label, duration, anim, prop)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim,
        prop = prop,
    })
end

-- One skill check. difficulty: 'easy' | 'medium' | 'hard'. Returns true on success.
function Bridge.skillCheck(difficulty)
    return lib.skillCheck({ difficulty or 'medium' }, { 'e' }) == true
end

-- Third eye on a local entity (ox_target / qb-target / interact, whichever kq_link is set up for).
-- Returns true when a target system took it; false means there is none, and the prompt is used instead.
local targets = {}
local TARGET_EVENT = 'bakery_saferobbery:client:target'

function Bridge.addTarget(entity, label, icon, onSelect)
    if not entity or not DoesEntityExist(entity) then return false end
    local ok, handle = pcall(function()
        return kq:AddEntityToTargeting(entity, label, TARGET_EVENT, nil, { bakery = true }, 2.0, icon or 'fas fa-hand')
    end)
    if not ok or not handle then return false end
    targets[entity] = onSelect
    return true
end

function Bridge.removeTarget(entity)
    if not entity or not targets[entity] then return end
    targets[entity] = nil
    pcall(function() kq:RemoveTargetEntity(entity) end)
end

AddEventHandler(TARGET_EVENT, function(data)
    local entity = type(data) == 'table' and (data.entity or (data.data and data.data.entity)) or nil
    local fn = entity and targets[entity]
    if fn then fn(entity) end
end)
