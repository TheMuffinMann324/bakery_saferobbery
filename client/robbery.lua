-- What players do at a safe: prompts, breaching charges, breaking padlocks and grabbing the loot.
-- Sticky notes need no interaction: the code is drawn on the note itself (client/note.lua).
-- The keypad lives in keypad.lua. The server checks everything; this only asks and animates.
local Busy = false

local KEY_E, KEY_G, THROW_GRENADE = 38, 47, 58
local TAP_MS, HOLD_MS = 275, 850

local function settings() return World.settings or Config.Defaults.settings end

local function clock(sec)
    sec = math.max(0, math.floor(sec))
    if sec >= 60 then return ('%d:%02d'):format(sec // 60, sec % 60) end
    return ('%ds'):format(sec)
end

local function facePoint(ped, rig, local_)
    local p = Utils.offset(rig.pos, rig.h, local_)
    local heading = (rig.h + 180.0) % 360.0
    TaskGoStraightToCoord(ped, p.x, p.y, p.z, 1.0, 2500, heading, 0.05)
    local untilT = GetGameTimer() + 2500
    while GetGameTimer() < untilT and #(GetEntityCoords(ped).xy - vector2(p.x, p.y)) > 0.15 do Wait(50) end
    ClearPedTasks(ped)
    SetEntityHeading(ped, heading)
end

-- ---------- breaching charge ----------
-- The heist breaching scene: the player swings the bag off their shoulder, takes the charge out and sticks it on
-- the door. Networked synchronised scene, so everyone sees the bag and the charge in hand. The moment it touches
-- the door the server arms it and every client sticks the charge on the door itself.

local function plantCharge(id)
    local rig = World.rigs[id]
    if not rig or not rig.door then return end
    Busy = true
    local res = Nui.call('charge:check', { id = id })
    if not res or not res.ok then
        Busy = false
        return Bridge.notify(res and res.error or 'Can\'t do that now.', 'error')
    end
    local A = Config.Anims.plant
    local ped = PlayerPedId()
    local bagHash = World.loadModel(A.bag)
    local chargeHash = World.loadModel(Config.ChargeModel)
    if not lib.requestAnimDict(A.dict, 3000) then
        Nui.call('charge:plant', { id = id, session = res.session, cancel = true })
        Busy = false
        return
    end
    -- the scene sits on the charge spot (its origin is where the hand puts the charge), facing the door;
    -- walk to where the clip starts first so the player doesn't slide into place
    local origin, gripPos, gripRot = World.plantPose()
    local doorH = GetEntityHeading(rig.door)
    local start = Props.Safe.hinge + origin + Props.Safe.plant.start
    facePoint(ped, rig, vector3(start.x, start.y, 0.0))
    Wait(100)

    local pos = GetOffsetFromEntityInWorldCoords(rig.door, origin.x, origin.y, origin.z)
    local scene = NetworkCreateSynchronisedScene(pos.x, pos.y, pos.z, 0.0, 0.0, (doorH + 180.0) % 360.0, 2, false, false, 1065353216, 0, 1.3)
    local bag = bagHash and CreateObject(bagHash, pos.x, pos.y, pos.z, true, true, false) or nil
    if bag then SetEntityCollision(bag, false, true) end
    NetworkAddPedToSynchronisedScene(ped, scene, A.dict, A.clip, 1.5, -4.0, 1, 16, 1148846080, 0)
    if bag then NetworkAddEntityToSynchronisedScene(bag, scene, A.dict, A.bagClip, 4.0, -8.0, 1) end
    NetworkStartSynchronisedScene(scene)
    local t0 = GetGameTimer()

    -- out of the bag at grabAt; held so that it lands exactly where the stuck charge goes
    Wait(A.grabAt)
    local held
    if chargeHash then
        held = CreateObject(chargeHash, pos.x, pos.y, pos.z + 0.2, true, true, false)
        SetEntityCollision(held, false, true)
        AttachEntityToEntity(held, ped, GetPedBoneIndex(ped, 28422), gripPos.x, gripPos.y, gripPos.z, gripRot.x, gripRot.y, gripRot.z,
            true, true, false, true, 2, true)
    end
    Wait(math.max(0, A.stickAt - (GetGameTimer() - t0)))

    -- on the door: the server arms it, the broadcast puts the charge on the door for everyone
    local r = Nui.call('charge:plant', { id = id, session = res.session, cancel = IsEntityDead(ped) })
    if r and r.ok and r.fuse then
        local untilT = GetGameTimer() + 1000
        while GetGameTimer() < untilT and not (rig.charge and DoesEntityExist(rig.charge)) do Wait(0) end
    end
    World.delete(held)
    if r and r.ok and r.fuse then
        Bridge.notify(('Charge armed. Get clear, %d seconds!'):format(r.fuse or 10), 'warning')
    elseif not IsEntityDead(ped) then
        Bridge.notify(r and r.error or 'Couldn\'t place it.', 'error')
    end
    Wait(math.max(0, A.length - (GetGameTimer() - t0)))
    NetworkStopSynchronisedScene(scene)
    World.delete(bag)
    ClearPedTasks(ped)
    Busy = false
end

-- ---------- padlock ----------

local function jiggle(rig)
    if not rig.padlock or not DoesEntityExist(rig.padlock) then return end
    local lock = rig.padlock
    CreateThread(function()
        for i = 1, 6 do
            if not DoesEntityExist(lock) then return end
            SetEntityRotation(lock, (i % 2 == 0 and 1 or -1) * (18 - i * 3), 0.0, rig.h, 2, true)
            Wait(35)
        end
        if DoesEntityExist(lock) then SetEntityRotation(lock, 0.0, 0.0, rig.h, 2, true) end
    end)
end

local function breakPadlock(id)
    local rig = World.rigs[id]
    if not rig then return end
    Busy = true
    local res = Nui.call('padlock:start', { id = id })
    if not res or not res.ok then
        Busy = false
        return Bridge.notify(res and res.error or 'Can\'t do that now.', 'error')
    end
    local ped = PlayerPedId()
    facePoint(ped, rig, vector3(0.0, 0.62, 0.0))
    local A = Config.Anims.padlock
    local tool
    if res.hasCrowbar then
        local hash = World.loadModel(Config.CrowbarModel)
        if hash then
            tool = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
            AttachEntityToEntity(tool, ped, GetPedBoneIndex(ped, 57005), 0.10, 0.02, -0.02, -80.0, 0.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(hash)
        end
    end
    if lib.requestAnimDict(A.dict, 2000) then
        TaskPlayAnim(ped, A.dict, A.clip, 4.0, 4.0, -1, 1, 0.0, false, false, false)
    end
    local ok = true
    for i = 1, res.hits do
        local hit
        if res.skill then
            hit = Bridge.skillCheck(res.difficulty)
        else
            hit = Bridge.progress(('Breaking the padlock (%d/%d)'):format(i, res.hits), 1100, nil)
        end
        if not hit then ok = false break end
        PlaySoundFromCoord(-1, 'Drill_Pin_Break', rig.pos.x, rig.pos.y, rig.pos.z, 'DLC_HEIST_FLEECA_SOUNDSET', false, 10, false)
        jiggle(rig)
        if res.skill then Wait(350) end
    end
    StopAnimTask(ped, A.dict, A.clip, 2.0)
    World.delete(tool)
    local r = Nui.call('padlock:finish', { id = id, session = res.session, success = ok })
    Busy = false
    if not ok then
        Bridge.notify('Your hand slipped. The lock is still on.', 'error')
    elseif not r or not r.ok then
        Bridge.notify(r and r.error or 'The lock held.', 'error')
    end
end

-- ---------- loot ----------
-- Every item inside is real props (a few bundles of cash, a couple of bars...). Third eye on any of them:
-- the player reaches in and the props vanish one by one as they're grabbed, then the server pays out.
Loot = {}

local noTarget = false    -- no target system: E grabs the next item instead

local function grab(id, index)
    if Busy then return end
    local rig, v = World.rigs[id], World.safes[id]
    local g = rig and rig.loot and rig.loot[index]
    if not g or not v or v.state ~= 'open' then return end
    Busy = true
    local start = Nui.call('loot:start', { id = id, index = index })
    if not start or not start.ok then
        Busy = false
        return Bridge.notify(start and start.error or 'Couldn\'t take that.', 'error')
    end
    local ped = PlayerPedId()
    for _, e in ipairs(g.props) do Bridge.removeTarget(e) end
    if g.props[1] then
        TaskTurnPedToFaceEntity(ped, g.props[1], 500)
        Wait(500)
    end
    local A = Config.Anims.loot
    local per = math.ceil(start.duration / 2)
    if lib.requestAnimDict(A.dict, 1500) then
        TaskPlayAnim(ped, A.dict, A.clip, 8.0, 8.0, -1, 1, 0.0, false, false, false)
    end
    -- top of the pile first. Only cash, drugs and diamonds (Config.LootDespawn) leave the safe
    local vanish = Config.LootDespawn[g.category]
    for n = #g.props, 1, -1 do
        Wait(per)
        local e = g.props[n]
        if vanish and e and DoesEntityExist(e) then
            SetEntityVisible(e, false, false)
            SetEntityCollision(e, false, false)
            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
    end
    StopAnimTask(ped, A.dict, A.clip, 2.0)
    local res = Nui.call('loot:take', { id = id, index = index, session = start.session })
    Busy = false
    if res and res.ok then
        if rig.loot and rig.loot[index] == g then
            if vanish then World.removeLootGroup(rig, index) else World.keepLootGroup(rig, index) end
        end
        Bridge.notify(res.money and ('$%s'):format(res.amount) or ('%dx %s'):format(res.amount or 1, res.label or g.label), 'success')
    else
        -- not paid (inventory full, someone was quicker...): put it back
        for _, e in ipairs(g.props) do
            if DoesEntityExist(e) then
                SetEntityVisible(e, true, false)
                SetEntityCollision(e, true, true)
            end
        end
        if rig.loot and rig.loot[index] == g then Loot.register(id, index, g) end
        Bridge.notify(res and res.error or 'Couldn\'t take that.', 'error')
    end
end

-- Called by props.lua for every group of props it spawns inside an open safe.
function Loot.register(id, index, g)
    for _, e in ipairs(g.props) do
        if not Bridge.addTarget(e, ('Grab %s'):format(g.label), 'fas fa-hand', function() CreateThread(function() grab(id, index) end) end) then
            noTarget = true
        end
    end
end

-- Next item still inside, for the no-target fallback.
local function nextItem(id)
    local rig = World.rigs[id]
    local best
    for index, g in pairs(rig and rig.loot or {}) do
        if not best or g.slot < rig.loot[best].slot then best = index end
    end
    return best
end

-- ---------- prompts ----------

local function nearest(me)
    local best, bestRig
    local bestD = settings().interactDistance or 1.6
    for id, rig in pairs(World.rigs) do
        local v = World.safes[id]
        if v and v.enabled then
            local d = #(me - rig.front)
            if d < bestD then best, bestRig, bestD = v, rig, d end
        end
    end
    return best, bestRig
end

local chargeCheck
local function hasCharge(id, now)
    if not chargeCheck or chargeCheck.id ~= id then
        chargeCheck = { id = id, nextCheck = 0 }
    end
    local check = chargeCheck
    if not check.pending and now >= check.nextCheck then
        check.pending = true
        CreateThread(function()
            check.available = Nui.call('charge:available', { id = id }) == true
            check.nextCheck = GetGameTimer() + 700
            check.pending = false
        end)
    end
    return check.available == true
end

local function options(v, canPlant, time)
    if v.busy then return 'Someone is working on it' end
    if v.kind == 'lockbox' then return nil, 'Break open' end
    if v.lockoutUntil and v.lockoutUntil > time then
        return ('Keypad locked out · %s'):format(clock(v.lockoutUntil - time)), nil, canPlant
    end
    return nil, 'Enter code', canPlant
end

local gPressed
local function useG(v, primary, charge, now)
    if gPressed and (gPressed.id ~= v.id or (gPressed.charge and not charge)) then gPressed = nil end
    if not primary and not charge then
        gPressed = nil
        return 0
    end

    DisableControlAction(0, KEY_G, true)
    DisableControlAction(0, THROW_GRENADE, true)
    if IsDisabledControlJustPressed(0, KEY_G) then
        if v.kind == 'lockbox' then return 0, breakPadlock end
        gPressed = { id = v.id, at = now, charge = charge, primary = primary }
    end
    if not gPressed then return 0 end

    local elapsed = now - gPressed.at
    local released = IsDisabledControlJustReleased(0, KEY_G)
    local down = IsDisabledControlPressed(0, KEY_G)
    if (down or released) and charge and gPressed.charge and elapsed >= HOLD_MS then
        gPressed = nil
        return 1, plantCharge
    end
    if released or not down then
        local tap = released and elapsed <= TAP_MS and primary and gPressed.primary
        gPressed = nil
        if tap then return 0, Keypad.open end
        return 0
    end
    return gPressed.charge and elapsed / HOLD_MS or 0
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local blocked = Busy or Keypad.active or Placement.active or Nui.admin or IsNuiFocused()
            or IsPauseMenuActive() or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped)
        local v, rig
        if not blocked then v, rig = nearest(GetEntityCoords(ped)) end
        local locked = v and v.state == 'locked'
        local canLoot = v and v.state == 'open' and noTarget
        local x, y
        if locked or canLoot then x, y = PromptDui.project(rig.prompt) end

        if locked and x then
            local now = GetGameTimer()
            local canPlant = false
            if v.kind == 'safe' and v.state == 'locked' and not v.busy then
                canPlant = hasCharge(v.id, now)
            else
                chargeCheck = nil
            end
            local title, primary, charge = options(v, canPlant, World.serverNow())
            local progress, use = useG(v, primary, charge, now)
            if use then
                Busy = true
                chargeCheck = nil
                CreateThread(function()
                    use(v.id)
                    Busy = false
                end)
            end
            if title or primary or charge then
                PromptDui.draw(x, y, title, primary, charge, progress)
            end
        else
            gPressed, chargeCheck = nil, nil
            if canLoot and x and IsControlJustPressed(0, KEY_E) then
                local index = nextItem(v.id)
                if index then CreateThread(function() grab(v.id, index) end) end
            end
        end
        Wait((locked or canLoot) and 0 or 200)
    end
end)

-- Live settings the client needs. Refreshed when an admin saves.
RegisterNetEvent('bakery_saferobbery:client:settings', function(s)
    if source == 65535 and type(s) == 'table' then
        World.settings = s
        chargeCheck = nil
    end
end)

AddEventHandler('ox_inventory:itemCount', function(item)
    if chargeCheck and item == settings().explosiveItem then chargeCheck = nil end
end)

CreateThread(function()
    local value = Nui.call('settings')
    if value then World.settings = value end
end)
