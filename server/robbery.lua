Robbery = { handlers = {} }

local H = Robbery.handlers
local playerCooldown, pendingLoot = {}, {}
local lootSession = 0
local now = os.time

local function fail(err) return { ok = false, error = err } end

local function pedPos(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 0 then return end
    return GetEntityCoords(ped)
end

local function near(src, s)
    local at = pedPos(src)
    if not at then return false end
    local front = Utils.offset(vector3(s.x, s.y, s.z), s.h, Props.def(s.kind).front)
    return #(at - front) <= Data.settings.interactDistance + 1.2
end

local function clock(sec)
    if sec >= 3600 then return ('%dh %dm'):format(sec // 3600, (sec % 3600) // 60) end
    if sec >= 60 then return ('%dm %ds'):format(sec // 60, sec % 60) end
    return ('%ds'):format(math.max(0, sec))
end

local function start(src, s, kind, mode, item)
    if not s or s.removed or s.kind ~= kind then return nil, 'Nothing here.' end
    if not s.enabled then return nil, 'This can\'t be opened right now.' end
    if s.state ~= 'locked' then return nil, 'It\'s already been opened or charged.' end
    if s.action then return nil, 'Someone is already working on it.' end
    if not near(src, s) then return nil, 'Too far away.' end
    local identifier = Bridge.getIdentifier(src)
    if not identifier then return nil, 'Player data is unavailable.' end
    local key = identifier .. ':' .. kind
    local wait = (playerCooldown[key] or 0) - now()
    if wait > 0 then return nil, ('Lay low for another %s before the next %s.'):format(clock(wait), kind) end
    local needed = Data.settings.policeRequired
    if needed > 0 and Bridge.countPolice(Data.settings.policeJobs) < needed then
        return nil, 'It\'s too quiet out there. Not enough police around.'
    end
    if item and item ~= '' then
        local hasItem = mode == 'charge' and Bridge.getItemCount(src, item) > 0
            or mode == 'padlock' and Bridge.hasItem(src, item)
        if not hasItem then
            return nil, mode == 'charge' and 'You need a breaching charge.' or 'You need something to break the lock with.'
        end
    end
    if not near(src, s) or s.kind ~= kind then return nil, 'Too far away.' end
    if mode == 'keypad' and s.lockoutUntil and s.lockoutUntil > now() then
        return nil, ('The keypad is locked out. Try again in %s.'):format(clock(s.lockoutUntil - now()))
    end
    if (playerCooldown[key] or 0) > now() then return nil, 'You need to lay low.' end
    local action = Safes.reserve(s, src, mode, item)
    if not action then return nil, 'Someone is already working on it.' end
    action.key, action.identifier = key, identifier
    return action
end

local function ownAction(s, src, session, mode)
    local a = s and s.action
    if a and a.src == src and a.id == session and a.mode == mode and not a.committing
        and GetGameTimer() - a.started < 120000 and a.bucket == GetPlayerRoutingBucket(src) then
        return a
    end
end

local function release(s)
    Safes.release(s)
    Safes.broadcast(s)
    return { ok = true }
end

local function setPlayerCooldown(s, key, delay)
    local seconds = s.kind == 'lockbox' and Data.settings.playerLockboxCooldown or Data.settings.playerSafeCooldown
    if seconds <= 0 then return end
    seconds = seconds + (delay or 0)
    local untilTs = now() + seconds
    playerCooldown[key] = untilTs
    SetTimeout(seconds * 1000, function()
        if playerCooldown[key] == untilTs then playerCooldown[key] = nil end
    end)
end

local function alert(src, s, title, description)
    Bridge.dispatch(src, {
        coords = { x = s.x, y = s.y, z = s.z },
        title = title, description = description, code = '10-90', jobs = Data.settings.policeJobs,
    })
end

local function roll(s)
    local t = s.rewards
    if not t or #t.items == 0 then return {} end
    local slots = math.min(t.maxItems, #Props.def(s.kind).slots)
    local picked, rest = {}, {}
    for _, e in ipairs(t.items) do
        local pool = math.random(1, 100) <= e.chance and picked or rest
        pool[#pool + 1] = e
    end
    for i = #picked, 2, -1 do
        local j = math.random(1, i)
        picked[i], picked[j] = picked[j], picked[i]
    end
    while #picked > slots do table.remove(picked) end
    while #picked < math.min(t.minItems, slots) and #rest > 0 do
        picked[#picked + 1] = table.remove(rest, math.random(1, #rest))
    end
    local out = {}
    for _, e in ipairs(picked) do
        out[#out + 1] = {
            item = e.item, label = e.label, type = e.type, account = e.account,
            category = e.category, amount = math.random(e.min, e.max),
        }
    end
    return out
end

local function open(s, method, loot)
    Safes.release(s)
    s.state, s.method, s.loot = 'open', method, loot or roll(s)
    s.charge, s.fuseEnd = nil, nil
    s.cooldownUntil = now() + Safes.cooldownFor(s)
    DB.setCooldown(s.id, s.cooldownUntil)
    Safes.broadcast(s)
end

H['keypad:open'] = function(src, p)
    local s = Safes.get(p.id)
    local a, err = start(src, s, 'safe', 'keypad')
    if not a then return fail(err) end
    return { ok = true, session = a.id, attemptsLeft = math.max(1, Data.settings.keypadAttempts - s.attempts) }
end

H['keypad:try'] = function(src, p)
    local s = Safes.get(p.id)
    if not ownAction(s, src, p.session, 'keypad') then return fail('The keypad isn\'t responding.') end
    if not near(src, s) then return fail('Too far away.') end
    if not Utils.validCode(p.code) then return fail('Enter a four-digit code.') end
    if p.code == s.code then
        setPlayerCooldown(s, s.action.key)
        open(s, 'code')
        return { ok = true }
    end
    s.attempts = s.attempts + 1
    local max = Data.settings.keypadAttempts
    if s.attempts >= max then
        s.attempts = 0
        s.lockoutUntil = now() + Data.settings.lockoutTime
        release(s)
        if Data.settings.alertKeypadFail then
            alert(src, s, 'Safe tampering', ('Repeated wrong codes on a safe at %s.'):format(s.label))
        end
        return { ok = false, lockout = true, lockoutUntil = s.lockoutUntil }
    end
    return { ok = false, attemptsLeft = max - s.attempts }
end

H['keypad:close'] = function(src, p)
    local s = Safes.get(p.id)
    if ownAction(s, src, p.session, 'keypad') then return release(s) end
    return { ok = true }
end

local function detonate(s, charge)
    if s.removed or not s.enabled or s.state ~= 'charged' or s.charge ~= charge then return end
    local loot = roll(s)
    local loss, lost = Data.settings.explosionLoss / 100, false
    if loss > 0 then
        for i = #loot, 1, -1 do
            local e = loot[i]
            local keep = math.floor(e.amount * (1 - loss) + 0.5)
            if e.type ~= 'money' and math.random() < loss then keep = 0 end
            if keep < e.amount then lost = true end
            if keep <= 0 then table.remove(loot, i) else e.amount = keep end
        end
    end
    open(s, 'explosive', loot)
    local at = vector3(s.x, s.y, s.z)
    local planter = GetPlayerName(charge.src) and Bridge.getIdentifier(charge.src) == charge.identifier and charge.src
    local who, best = nil, 150.0
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local pos = GetPlayerRoutingBucket(src) == charge.bucket and pedPos(src)
        local distance = pos and #(pos - at)
        if distance and (distance < best or src == planter and distance < 150.0) then
            who, best = src, distance
            if src == planter then break end
        end
    end
    TriggerClientEvent('bakery_saferobbery:client:blast', -1, s.id, who, Data.settings.explosionDamage)
    if planter then
        if lost then Bridge.notify(planter, 'The blast wrecked some of what was inside.', 'warning') end
        if Data.settings.alertExplosion then
            alert(planter, s, 'Explosion reported', ('An explosion was heard near %s.'):format(s.label))
        end
    end
end

H['charge:available'] = function(src, p)
    local s = Safes.get(p.id)
    return s ~= nil and s.kind == 'safe' and s.enabled and s.state == 'locked' and not s.action
        and near(src, s) and Bridge.getItemCount(src, Data.settings.explosiveItem) > 0
end

H['charge:check'] = function(src, p)
    local a, err = start(src, Safes.get(p.id), 'safe', 'charge', Data.settings.explosiveItem)
    if not a then return fail(err) end
    return { ok = true, session = a.id }
end

H['charge:plant'] = function(src, p)
    local s = Safes.get(p.id)
    local a = ownAction(s, src, p.session, 'charge')
    if not a then return fail('Couldn\'t place it.') end
    if p.cancel == true then return release(s) end
    if GetGameTimer() - a.started < Config.Anims.plant.stickAt then return fail('Too fast.') end
    if not near(src, s) then return fail('Too far away.') end
    a.committing = true
    local removed = Bridge.removeItem(src, a.item, 1)
    if s.action ~= a then
        if removed and GetPlayerName(src) and Bridge.getIdentifier(src) == a.identifier then
            Bridge.addItem(src, a.item, 1)
        end
        return fail('Couldn\'t place it.')
    end
    if not removed then
        release(s)
        return fail('You need a breaching charge.')
    end
    local fuse = Data.settings.fuseTime
    Safes.release(s)
    s.state, s.charge, s.fuseEnd = 'charged', a, now() + fuse
    setPlayerCooldown(s, a.key, fuse)
    Safes.broadcast(s)
    SetTimeout(fuse * 1000, function() detonate(s, a) end)
    return { ok = true, fuse = fuse }
end

H['padlock:start'] = function(src, p)
    local s = Safes.get(p.id)
    local a, err = start(src, s, 'lockbox', 'padlock', Data.settings.breakItem)
    if not a then return fail(err) end
    local d = Data.settings
    a.minimum = d.breakHits * (d.breakSkillCheck and 350 or 1100)
    return {
        ok = true, session = a.id, hits = d.breakHits, skill = d.breakSkillCheck,
        difficulty = d.breakDifficulty, hasCrowbar = a.item ~= '',
    }
end

H['padlock:finish'] = function(src, p)
    local s = Safes.get(p.id)
    local a = ownAction(s, src, p.session, 'padlock')
    if not a then return fail('The lock is gone.') end
    if p.success == false then return release(s) end
    if p.success ~= true then return fail('Invalid result.') end
    if GetGameTimer() - a.started < a.minimum then return fail('Too fast.') end
    if not near(src, s) then return fail('Too far away.') end
    if a.item ~= '' and not Bridge.hasItem(src, a.item) then
        if s.action == a then release(s) end
        return fail('You need something to break the lock with.')
    end
    if ownAction(s, src, p.session, 'padlock') ~= a then return fail('The lock is gone.') end
    setPlayerCooldown(s, a.key)
    open(s, 'padlock')
    if math.random(1, 100) <= Data.settings.alertPadlock then
        alert(src, s, 'Break-in', ('Someone is breaking into a lockbox at %s.'):format(s.label))
    end
    return { ok = true }
end

local function availableLoot(src, p)
    local s = Safes.get(p.id)
    if not s or not s.enabled or s.state ~= 'open' then return nil, 'It\'s shut.' end
    if not near(src, s) then return nil, 'Too far away.' end
    local index = type(p.index) == 'number' and math.tointeger(p.index)
    local e = index and s.loot[index]
    if not e or e.taken then return nil, 'Already taken.' end
    return s, e
end

H['loot:start'] = function(src, p)
    local s, e = availableLoot(src, p)
    if not s then return fail(e) end
    local t = GetGameTimer()
    local a = pendingLoot[src]
    if a and t < a.expires and a.round == a.safe.loot and not a.loot.taken then
        return fail('Already grabbing something.')
    end
    local duration = math.max(600, Data.settings.lootTime)
    lootSession = lootSession + 1
    pendingLoot[src] = {
        session = lootSession, safe = s, round = s.loot, loot = e, ready = t + math.ceil(duration / 2),
        expires = t + 30000, bucket = GetPlayerRoutingBucket(src),
    }
    return { ok = true, session = lootSession, duration = duration }
end

H['loot:take'] = function(src, p)
    local a = pendingLoot[src]
    local t = GetGameTimer()
    if not a or a.session ~= p.session or a.expires <= t
        or a.bucket ~= GetPlayerRoutingBucket(src) then return fail('Start grabbing it first.') end
    local s, e = availableLoot(src, p)
    if not s then
        pendingLoot[src] = nil
        return fail(e)
    end
    if a.safe ~= s or a.loot ~= e then return fail('Start grabbing it first.') end
    if t < a.ready then return fail('Too fast.') end
    pendingLoot[src], e.taken = nil, true
    local money = e.type == 'money'
    local given
    if money then
        given = Bridge.addMoney(src, e.amount, e.account)
    else
        given = Bridge.addItem(src, e.item, e.amount)
    end
    if not given then
        e.taken = nil
        return fail('You can\'t carry that.')
    end
    if not s.removed then Safes.broadcast(s) end
    return { ok = true, label = e.label, amount = e.amount, money = money }
end

H['note:read'] = function(src, p)
    local s = Safes.get(p.id)
    if not s or not s.note or not s.enabled then return fail('Nothing written here.') end
    local at = pedPos(src)
    if not at or #(at - vector3(s.note.x, s.note.y, s.note.z)) > 35.0 then return fail('Too far away.') end
    return { ok = true, code = s.code }
end

AddEventHandler('playerDropped', function() pendingLoot[source] = nil end)
