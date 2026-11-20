-- ============================================================
-- SERVER BRIDGE
-- Framework / inventory / money / police / notifications. Routed through kq_link by default,
-- so changing kq_link's config changes this resource too. Edit any function to hook a different system.
-- ============================================================
Bridge = {}

local kq = exports.kq_link

local function safe(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then
        Utils.debug(('kq_link call failed: %s'):format(a))
        return nil, nil, false
    end
    return a, b, true
end

-- ---------- Identity ----------

function Bridge.getIdentifier(src)
    local id = safe(function() return kq:GetPlayerCharacterId(src) end)
    if type(id) == 'number' or (type(id) == 'string' and id ~= '') then return tostring(id) end
    return GetPlayerIdentifierByType(src, 'license')
end

function Bridge.getJob(src)
    local job = safe(function() return kq:GetPlayerJob(src) end)
    if type(job) == 'table' then return job.name end
    return job
end

function Bridge.countPolice(jobs)
    local list = safe(function() return kq:GetPlayersWithJob(jobs) end)
    if type(list) == 'table' then
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        return n
    end
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        if Utils.contains(jobs, Bridge.getJob(tonumber(id))) then n = n + 1 end
    end
    return n
end

-- ---------- Items ----------

function Bridge.getItemCount(src, item)
    return tonumber(safe(function() return kq:GetPlayerItemCount(src, item) end)) or 0
end

function Bridge.addItem(src, item, amount, meta)
    local result = safe(function() return kq:AddPlayerItem(src, item, amount or 1, meta) end)
    return result ~= nil and result ~= false
end

function Bridge.removeItem(src, item, amount)
    local result = safe(function() return kq:RemovePlayerItem(src, item, amount or 1) end)
    return result ~= nil and result ~= false
end

-- True when the player carries the item. Names starting with weapon_ are checked as weapons too
-- (some frameworks keep weapons out of the item list).
function Bridge.hasItem(src, item)
    if not item or item == '' then return true end
    if Bridge.getItemCount(src, item) > 0 then return true end
    if item:lower():sub(1, 7) == 'weapon_' then
        return safe(function() return kq:DoesPlayerHaveWeapon(src, item) end) == true
    end
    return false
end

-- ---------- Money ----------

function Bridge.addMoney(src, amount, account)
    if amount <= 0 then return true end
    -- ESX returns no value after crediting an account. An explicit false or export error is a failure.
    local result, _, called = safe(function() return kq:AddPlayerMoney(src, amount, account or 'cash') end)
    return called and result ~= false
end

-- ---------- Notifications ----------

function Bridge.notify(src, message, kind)
    TriggerClientEvent('bakery_saferobbery:client:notify', src, message, kind or 'info')
end

-- Police alert, sent from the robber's client (kq_link dispatch runs client side).
function Bridge.dispatch(src, data)
    TriggerClientEvent('bakery_saferobbery:client:dispatch', src, data)
end

-- ---------- Admin ----------

function Bridge.isAdmin(src)
    if IsPlayerAceAllowed(src, Config.Admin.Ace) then return true end
    local license = GetPlayerIdentifierByType(src, 'license')
    for _, l in ipairs(Config.Admin.Licenses or {}) do
        if l == license then return true end
    end
    return false
end
