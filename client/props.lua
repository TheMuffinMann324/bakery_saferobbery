-- Spawns the safes, lockboxes and sticky notes on this client (never networked), and animates them:
-- door swings, the wheel spinning, lids, padlocks dropping off, breaching charges and the loot inside.
--
-- A "rig" is one safe's set of entities: { kind, pos, h, body, door, wheel, lid, padlock, ... }.
-- The admin placement preview uses the same rigs, so its "test" buttons play the real animations.
World = { safes = {}, rigs = {}, notes = {}, noteSlots = {} }

local floor, exp, cos = math.floor, math.exp, math.cos

-- ---------- models ----------

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end
World.loadModel = loadModel

local function spawn(model, pos, heading, collide)
    local hash = loadModel(model)
    if not hash then
        Utils.debug('missing model', model)
        return nil
    end
    local e = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if e == 0 then return nil end
    SetEntityHeading(e, heading or 0.0)
    FreezeEntityPosition(e, true)
    SetEntityCollision(e, collide ~= false, collide ~= false)
    SetEntityLodDist(e, 200)
    return e
end
World.spawn = spawn

local function delete(e)
    if e and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true)
        DeleteEntity(e)
    end
end
World.delete = delete

-- ---------- easing ----------

local Ease = {}
function Ease.inOut(t) return t < 0.5 and 4 * t * t * t or 1 - ((-2 * t + 2) ^ 3) / 2 end
function Ease.out(t) return 1 - (1 - t) ^ 3 end
function Ease.outBack(t) local c1, c3 = 1.4, 2.4 return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2 end
-- Hits the hinge stop hard and bounces back: overshoots the target then settles.
function Ease.blast(t) return 1 - exp(-6.5 * t) * cos(11.0 * t) end

-- Runs fn(eased) every frame for `ms`. Cancels the rig's previous tween on the same channel.
local function tween(rig, channel, ms, ease, fn, done)
    rig.tweens = rig.tweens or {}
    local token = {}
    rig.tweens[channel] = token
    CreateThread(function()
        local start = GetGameTimer()
        while true do
            if rig.dead or rig.tweens[channel] ~= token then return end
            local t = math.min(1.0, (GetGameTimer() - start) / ms)
            fn(ease(t))
            if t >= 1.0 then break end
            Wait(0)
        end
        if done then done() end
    end)
end

-- ---------- poses ----------

function World.setDoor(rig, angle)
    rig.doorAngle = angle
    if not rig.door or not DoesEntityExist(rig.door) then return end
    local p = Utils.offset(rig.pos, rig.h, Props.Safe.hinge)
    SetEntityCoordsNoOffset(rig.door, p.x, p.y, p.z, false, false, false)
    SetEntityRotation(rig.door, 0.0, 0.0, (rig.h + angle) % 360.0, 2, true)
end

function World.setWheel(rig, spin)
    rig.wheelSpin = spin
    if not rig.wheel or not rig.door or not DoesEntityExist(rig.wheel) then return end
    local w = Props.Safe.wheel
    AttachEntityToEntity(rig.wheel, rig.door, 0, w.x, w.y, w.z, 0.0, spin, 0.0, false, false, not rig.ghost, false, 2, true)
end

function World.setLid(rig, angle)
    rig.lidAngle = angle
    if not rig.lid or not DoesEntityExist(rig.lid) then return end
    local p = Utils.offset(rig.pos, rig.h, Props.Lockbox.hinge)
    SetEntityCoordsNoOffset(rig.lid, p.x, p.y, p.z, false, false, false)
    SetEntityRotation(rig.lid, angle, 0.0, rig.h % 360.0, 2, true)
end

function World.attachPadlock(rig)
    delete(rig.padlock)
    local p = Utils.offset(rig.pos, rig.h, Props.Lockbox.padlock)
    rig.padlock = spawn(Props.Models.padlock, p, rig.h, not rig.ghost)
end

-- ---------- rigs ----------

-- alpha: nil for a normal prop, a number for a see-through placement ghost
function World.makeRig(kind, pos, h, alpha, opened)
    local rig = { kind = kind, pos = vector3(pos.x, pos.y, pos.z), h = h or 0.0 }
    local ghost = alpha ~= nil
    rig.ghost = ghost
    if kind == 'lockbox' then
        rig.body = spawn(Props.Models.lockboxBody, rig.pos, rig.h, not ghost)
        rig.lid = spawn(Props.Models.lockboxLid, Utils.offset(rig.pos, rig.h, Props.Lockbox.hinge), rig.h, not ghost)
        World.setLid(rig, opened and Props.Lockbox.openAngle or 0.0)
        if not opened then World.attachPadlock(rig) end
    else
        rig.body = spawn(Props.Models.safeBody, rig.pos, rig.h, not ghost)
        rig.door = spawn(Props.Models.safeDoor, Utils.offset(rig.pos, rig.h, Props.Safe.hinge), rig.h, not ghost)
        rig.wheel = spawn(Props.Models.safeWheel, rig.pos, rig.h, not ghost)
        World.setDoor(rig, opened or 0.0)
        World.setWheel(rig, 0.0)
        World.spawnDecor(rig)
    end
    if ghost then World.setAlpha(rig, alpha) end
    return rig
end

function World.rigEntities(rig)
    local out = {}
    for _, k in ipairs({ 'body', 'door', 'wheel', 'lid', 'padlock', 'charge' }) do
        if rig[k] and DoesEntityExist(rig[k]) then out[#out + 1] = rig[k] end
    end
    for _, g in pairs(rig.loot or {}) do
        for _, e in ipairs(g.props) do out[#out + 1] = e end
    end
    for _, e in ipairs(rig.decor or {}) do out[#out + 1] = e end
    for _, e in ipairs(rig.kept or {}) do out[#out + 1] = e end
    return out
end

function World.setAlpha(rig, alpha)
    for _, e in ipairs(World.rigEntities(rig)) do
        if alpha >= 255 then ResetEntityAlpha(e) else SetEntityAlpha(e, alpha, false) end
    end
end

function World.setCollision(rig, on)
    rig.ghost = not on
    for _, k in ipairs({ 'body', 'door', 'lid', 'wheel', 'padlock' }) do
        if rig[k] then SetEntityCollision(rig[k], on, on) end
    end
end

-- Moves a whole rig (placement preview).
function World.moveRig(rig, pos, h)
    rig.pos, rig.h = vector3(pos.x, pos.y, pos.z), h
    if rig.body then
        SetEntityCoordsNoOffset(rig.body, pos.x, pos.y, pos.z, false, false, false)
        SetEntityRotation(rig.body, 0.0, 0.0, h, 2, true)
    end
    if rig.kind == 'lockbox' then
        World.setLid(rig, rig.lidAngle or 0.0)
        if rig.padlock then
            local p = Utils.offset(rig.pos, rig.h, Props.Lockbox.padlock)
            SetEntityCoordsNoOffset(rig.padlock, p.x, p.y, p.z, false, false, false)
            SetEntityRotation(rig.padlock, 0.0, 0.0, h, 2, true)
        end
    else
        World.setDoor(rig, rig.doorAngle or 0.0)
        World.placeDecor(rig)
    end
end

function World.destroyRig(rig)
    if not rig then return end
    rig.dead = true
    for _, g in pairs(rig.loot or {}) do
        for _, e in ipairs(g.props) do Bridge.removeTarget(e) end
    end
    for _, e in ipairs(World.rigEntities(rig)) do delete(e) end
    for e in pairs(rig.dropped or {}) do delete(e) end
    rig.dropped = nil
end

-- ---------- animations ----------

local function soundAt(name, set, pos)
    PlaySoundFromCoord(-1, name, pos.x, pos.y, pos.z, set, false, 12, false)
end

-- Opening with the code: the wheel turns, the bolts pull back, the door swings out.
function World.openWithCode(rig)
    if rig.kind ~= 'safe' then return World.openLockbox(rig) end
    RequestScriptAudioBank('SAFE_CRACK', false)
    local clicks = 0
    tween(rig, 'wheel', 1300, Ease.inOut, function(t)
        World.setWheel(rig, -540.0 * t)
        local c = floor(t * 6)
        if c > clicks then
            clicks = c
            soundAt('TUMBLER_TURN', 'SAFE_CRACK_SOUNDSET', rig.pos)
        end
    end, function()
        soundAt('TUMBLER_PIN_FALL', 'SAFE_CRACK_SOUNDSET', rig.pos)
        Wait(180)
        local from = rig.doorAngle or 0.0
        tween(rig, 'door', 1900, Ease.out, function(t)
            World.setDoor(rig, from + (Props.Safe.openAngle - from) * t)
        end)
    end)
end

-- Blown open: scorched, flung hard against the hinge stop, bounces back and settles.
function World.openWithBlast(rig)
    if rig.kind ~= 'safe' then return World.openLockbox(rig) end
    if rig.door then SetEntityRenderScorched(rig.door, true) end
    local from = rig.doorAngle or 0.0
    tween(rig, 'door', 1500, Ease.blast, function(t)
        World.setDoor(rig, from + (Props.Safe.blastAngle - from) * t)
    end, function()
        World.setDoor(rig, Props.Safe.blastAngle)
    end)
    local spin = rig.wheelSpin or 0.0
    tween(rig, 'wheel', 900, Ease.out, function(t)
        World.setWheel(rig, spin + (220.0 - spin) * t)
    end)
end

-- Padlock snaps off and drops, the lid flips up.
function World.openLockbox(rig)
    if rig.padlock and DoesEntityExist(rig.padlock) then
        local lock = rig.padlock
        rig.padlock = nil
        rig.dropped = rig.dropped or {}
        rig.dropped[lock] = true
        FreezeEntityPosition(lock, false)
        SetEntityCollision(lock, true, true)
        SetEntityDynamic(lock, true)
        ActivatePhysics(lock)
        local fwd = Utils.offset(vector3(0, 0, 0), rig.h, vector3(0.0, 1.0, 0.0))
        ApplyForceToEntity(lock, 1, fwd.x * 0.6, fwd.y * 0.6, 0.9, 0.01, 0.0, 0.02, 0, false, true, true, false, true)
        SetTimeout(8000, function()
            if not rig.dropped or not rig.dropped[lock] then return end
            rig.dropped[lock] = nil
            delete(lock)
        end)
    end
    soundAt('Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET', rig.pos)
    SetTimeout(250, function()
        if rig.dead then return end
        local from = rig.lidAngle or 0.0
        tween(rig, 'lid', 900, Ease.outBack, function(t)
            World.setLid(rig, from + (Props.Lockbox.openAngle - from) * t)
        end)
    end)
end

-- Shut again after the cooldown (or an admin reset).
function World.close(rig)
    if rig.kind == 'lockbox' then
        local from = rig.lidAngle or 0.0
        tween(rig, 'lid', 900, Ease.inOut, function(t) World.setLid(rig, from * (1 - t)) end, function()
            if not rig.dead and not rig.padlock then World.attachPadlock(rig) end
        end)
        return
    end
    local from = rig.doorAngle or 0.0
    tween(rig, 'door', 1600, Ease.inOut, function(t) World.setDoor(rig, from * (1 - t)) end, function()
        if rig.door then SetEntityRenderScorched(rig.door, false) end
        soundAt('TUMBLER_RESET', 'SAFE_CRACK_SOUNDSET', rig.pos)
    end)
    local spin = rig.wheelSpin or 0.0
    tween(rig, 'wheel', 1600, Ease.inOut, function(t) World.setWheel(rig, spin * (1 - t)) end)
end

-- Snaps a rig to a state with no animation (when it streams in).
function World.pose(rig, view)
    local open = view.state == 'open'
    if rig.kind == 'lockbox' then
        World.setLid(rig, open and Props.Lockbox.openAngle or 0.0)
        if open then delete(rig.padlock) rig.padlock = nil elseif not rig.padlock then World.attachPadlock(rig) end
    else
        local blast = view.method == 'explosive'
        World.setDoor(rig, open and (blast and Props.Safe.blastAngle or Props.Safe.openAngle) or 0.0)
        World.setWheel(rig, open and (blast and 220.0 or -540.0) or 0.0)
        if rig.door then SetEntityRenderScorched(rig.door, open and blast) end
    end
end

-- ---------- loot inside ----------
-- rig.loot[index] = { props = { entity... }, label, category, slot }. index is the server's loot index, so items
-- taken by anyone disappear one by one and the rest stay where they are.

-- Every model of a category that exists and fits the slot (w / d either way round). If none fits, the
-- smallest one that exists. Each reward then takes a different one of these, by its index.
local fitCache = {}
local function lootModels(category, kind)
    local key = category .. kind
    if fitCache[key] then return fitCache[key] end
    local def = Config.LootProps[category] or Config.LootProps.other
    local room = Props.def(kind).slotSize
    local fits, smallest, smallestSize = {}, nil, nil
    for _, m in ipairs(def.models or {}) do
        local hash = joaat(m)
        if IsModelInCdimage(hash) and loadModel(hash) then
            local min, max = GetModelDimensions(hash)
            local w, d, h = max.x - min.x, max.y - min.y, max.z - min.z
            local pick = { model = m, turn = w > room.x }
            if h <= room.z and ((w <= room.x and d <= room.y) or (d <= room.x and w <= room.y)) then
                fits[#fits + 1] = pick
            else
                local size = w * d * h
                if not smallestSize or size < smallestSize then smallest, smallestSize = pick, size end
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
    if #fits == 0 and smallest then fits[1] = smallest end
    fitCache[key] = fits
    return fits
end

local function lootModel(category, kind, variant)
    local fits = lootModels(category, kind)
    if #fits == 0 then return nil end
    return fits[((variant or 1) - 1) % #fits + 1]
end

local function spawnGroup(rig, slotN, e)
    local def = Props.def(rig.kind)
    local slot = def.slots[slotN]
    local pick = slot and lootModel(e.c, rig.kind, e.i)
    if not pick then return nil end
    local hash = loadModel(pick.model)
    if not hash then return nil end
    local min, max = GetModelDimensions(hash)
    local h = max.z - min.z
    local stack = (Config.LootProps[e.c] or Config.LootProps.other).stack or 1
    stack = math.max(1, math.min(stack, math.floor(def.slotSize.z / math.max(h, 0.01))))
    local g = { props = {}, label = e.l or 'Loot', category = e.c, slot = slotN }
    for n = 1, stack do
        local jitter = vector3(((n * 7) % 5 - 2) * 0.006, ((n * 3) % 5 - 2) * 0.006, 0.0)
        local p = Utils.offset(rig.pos, rig.h, slot + jitter)
        local heading = rig.h + (pick.turn and 90.0 or 0.0) + ((slotN * 37 + n * 11) % 16 - 8)
        local prop = spawn(pick.model, vector3(p.x, p.y, p.z - min.z + (n - 1) * h), heading, true)
        if prop then g.props[#g.props + 1] = prop end
    end
    return g
end

function World.removeLootGroup(rig, index)
    local g = rig.loot and rig.loot[index]
    if not g then return end
    for _, e in ipairs(g.props) do
        Bridge.removeTarget(e)
        delete(e)
    end
    rig.loot[index] = nil
end

-- Taken, but not something that vanishes (gold, jewelry...): the props stay put, they just can't be grabbed.
function World.keepLootGroup(rig, index)
    local g = rig.loot and rig.loot[index]
    if not g then return end
    rig.kept = rig.kept or {}
    for _, e in ipairs(g.props) do
        Bridge.removeTarget(e)
        if DoesEntityExist(e) then rig.kept[#rig.kept + 1] = e end
    end
    rig.loot[index] = nil
end

-- list = the view's loot: { { i = index, c = category, l = label }, ... }. nil clears it.
function World.setLoot(rig, list, id)
    rig.loot = rig.loot or {}
    local want = {}
    for _, e in ipairs(type(list) == 'table' and list or {}) do want[e.i] = e end
    for index, g in pairs(rig.loot) do
        if not want[index] then
            if list and not Config.LootDespawn[g.category] then World.keepLootGroup(rig, index) else World.removeLootGroup(rig, index) end
        end
    end
    -- shut again: everything left in it goes (it's refilled when it's next opened)
    if not list then
        for _, e in ipairs(rig.kept or {}) do delete(e) end
        rig.kept = nil
    end
    for index, e in pairs(want) do
        if not rig.loot[index] then
            local g = spawnGroup(rig, index, e)
            if g then
                rig.loot[index] = g
                if id and Loot then Loot.register(id, index, g) end
            end
        end
    end
end

-- ---------- breaching charge ----------

-- Where and how the charge sits on the door: its thinnest side goes against the door, its biggest face out,
-- centred on Props.Safe.charge. Worked out from the model, so any charge model sits flush.
function World.chargeOffset()
    local hash = loadModel(Config.ChargeModel)
    if not hash then return Props.Safe.charge, vector3(0.0, 0.0, 0.0) end
    local mn, mx = GetModelDimensions(hash)
    local sx, sy, sz = mx.x - mn.x, mx.y - mn.y, mx.z - mn.z
    local cx, cy, cz = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2
    local at = Props.Safe.charge
    local front = at.y + 0.001
    if sz <= sx and sz <= sy then
        -- lies flat: tip it up so its top faces out of the door (local z -> door +y, local y -> door -z)
        return vector3(at.x - cx, front - mn.z, at.z + cy), vector3(-90.0, 0.0, 0.0)
    elseif sy <= sx then
        -- already stands up: turned round (the light is on its -y side) so its +y side goes against the door
        return vector3(at.x + cx, front + mx.y, at.z - cz), vector3(0.0, 0.0, 180.0)
    end
    -- thin along x: turn it a quarter (local x -> door +y, local y -> door -x)
    return vector3(at.x + cy, front - mn.x, at.z - cz), vector3(0.0, 0.0, 90.0)
end

-- Rotation matrices the way GTA builds them from euler degrees (rotation order 2: R = Rz * Rx * Ry), as columns.
local function rotMatrix(r)
    local a, b, c = math.rad(r.x), math.rad(r.y), math.rad(r.z)
    local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    return vector3(cc * cb - sc * sa * sb, sc * cb + cc * sa * sb, -ca * sb),   -- x axis
        vector3(-sc * ca, cc * ca, sa),                                         -- y axis
        vector3(cc * sb + sc * sa * cb, sc * sb - cc * sa * cb, ca * cb)        -- z axis
end

local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function cross(a, b) return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
local function norm(v) local l = math.sqrt(dot(v, v)); return l > 0 and v / l or v end

-- ---------- filler props ----------

-- Props.Safe.decor: spawned with the safe, always there. Each one is placed by its rotated bounds, so `at` is
-- the bottom centre of what you see whatever the model's own origin is.
local function placeDecor(rig)
    for i, e in ipairs(rig.decor or {}) do
        local d = rig.decorPose[i]
        local p = Utils.offset(rig.pos, rig.h, d.at)
        SetEntityCoordsNoOffset(e, p.x, p.y, p.z, false, false, false)
        SetEntityRotation(e, d.rot.x, d.rot.y, (rig.h + d.rot.z) % 360.0, 2, true)
    end
end
World.placeDecor = placeDecor

function World.spawnDecor(rig)
    for _, e in ipairs(rig.decor or {}) do delete(e) end
    rig.decor, rig.decorPose = {}, {}
    for _, d in ipairs(Props.Safe.decor or {}) do
        local hash = IsModelInCdimage(joaat(d.model)) and loadModel(d.model)
        if hash then
            local mn, mx = GetModelDimensions(hash)
            local rx, ry, rz = rotMatrix(d.rot)
            local lo, hi = vector3(1e9, 1e9, 1e9), vector3(-1e9, -1e9, -1e9)
            for _, cx in ipairs({ mn.x, mx.x }) do
                for _, cy in ipairs({ mn.y, mx.y }) do
                    for _, cz in ipairs({ mn.z, mx.z }) do
                        local c = rx * cx + ry * cy + rz * cz
                        lo = vector3(math.min(lo.x, c.x), math.min(lo.y, c.y), math.min(lo.z, c.z))
                        hi = vector3(math.max(hi.x, c.x), math.max(hi.y, c.y), math.max(hi.z, c.z))
                    end
                end
            end
            local e = spawn(d.model, rig.pos, 0.0, not rig.ghost)
            if e then
                rig.decor[#rig.decor + 1] = e
                rig.decorPose[#rig.decor] = { at = d.at - vector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z), rot = d.rot }
            end
        end
    end
    placeDecor(rig)
end

-- Where the planting scene goes (door space) and how the charge sits in the hand, so that while the hand holds it
-- on the door the charge in hand is exactly where World.attachCharge puts the stuck one: no jump when they swap.
function World.plantPose()
    local P = Props.Safe.plant
    local at, rot = World.chargeOffset()
    local origin = at + vector3(0.0, P.grip, 0.0)
    -- hand frame (cleaned up to be orthonormal)
    local hx = norm(P.handX)
    local hz = norm(cross(hx, P.handY))
    local hy = cross(hz, hx)
    -- the stuck charge's axes, in the hand frame
    local sx, sy, sz = rotMatrix(rot)
    local R = { { dot(hx, sx), dot(hx, sy), dot(hx, sz) }, { dot(hy, sx), dot(hy, sy), dot(hy, sz) }, { dot(hz, sx), dot(hz, sy), dot(hz, sz) } }
    local ex = math.deg(math.asin(math.max(-1.0, math.min(1.0, R[3][2]))))
    local ey = math.deg(math.atan(-R[3][1], R[3][3]))
    local ez = math.deg(math.atan(-R[1][2], R[2][2]))
    local d = at - origin
    return origin, vector3(dot(hx, d), dot(hy, d), dot(hz, d)), vector3(ex, ey, ez)
end

function World.attachCharge(rig, fuseEnd)
    if rig.kind ~= 'safe' or not rig.door then return end
    delete(rig.charge)
    rig.charge = spawn(Config.ChargeModel, rig.pos, rig.h, true)
    if not rig.charge then return end
    local off, rot = World.chargeOffset()
    AttachEntityToEntity(rig.charge, rig.door, 0, off.x, off.y, off.z, rot.x, rot.y, rot.z, false, false, true, false, 2, true)
    local charge = rig.charge
    -- beeps faster as the fuse runs down, with a red flash on every beep
    CreateThread(function()
        local nextBeep, flashUntil = 0, 0
        local beep = Config.ChargeBeep or { name = 'IDLE_BEEP', set = 'EPSILONISM_04_SOUNDSET' }
        while not rig.dead and rig.charge == charge and DoesEntityExist(charge) do
            local t = GetGameTimer()
            local left = fuseEnd and math.max(0, fuseEnd - World.serverNow()) or 5
            if t >= nextBeep then
                PlaySoundFromEntity(-1, beep.name, charge, beep.set, false, 0)
                flashUntil = t + 90
                nextBeep = t + math.floor(math.max(150, math.min(1000, left * 110)))
            end
            if t < flashUntil then
                local p = GetEntityCoords(charge)
                local out = GetEntityForwardVector(rig.door)
                DrawLightWithRange(p.x + out.x * 0.08, p.y + out.y * 0.08, p.z, 255, 20, 20, 1.2, 6.0)
            end
            Wait(0)
        end
    end)
end

function World.removeCharge(rig)
    delete(rig.charge)
    rig.charge = nil
end

-- Explosion effects at the safe door. `real` = this client makes the networked explosion.
function World.blastFx(rig, real, damage)
    local c = rig.door and DoesEntityExist(rig.door) and GetOffsetFromEntityInWorldCoords(rig.door, Props.Safe.charge.x, Props.Safe.charge.y + 0.1, Props.Safe.charge.z)
        or Utils.offset(rig.pos, rig.h, vector3(0.0, 0.5, 0.7))
    World.removeCharge(rig)
    if real then
        AddExplosion(c.x, c.y, c.z, 2, damage and 1.0 or 0.0, true, false, 0.6)
    end
    RequestNamedPtfxAsset('core')
    local timeout = GetGameTimer() + 1000
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < timeout do Wait(0) end
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke', c.x, c.y, c.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_sht_electrical_box', c.x, c.y, c.z, 0.0, 0.0, 0.0, 1.5, false, false, false)
    local me = GetEntityCoords(PlayerPedId())
    local d = #(me - c)
    if d < 25.0 then ShakeGameplayCam('MEDIUM_EXPLOSION_SHAKE', math.max(0.15, 1.0 - d / 25.0)) end
end

-- ---------- sticky notes ----------

-- The note's orientation is stored as two vectors (up = out of the surface, fwd = the top edge), which go
-- straight into SetEntityMatrix: no euler angles, so it lands exactly as it was placed, flat on the surface.
function World.noteBasis(n)
    local up = vector3(n.ux or 0.0, n.uy or 0.0, n.uz or 1.0)
    local fwd = vector3(n.fx or 0.0, n.fy or 1.0, n.fz or 0.0)
    local right = vector3(fwd.y * up.z - fwd.z * up.y, fwd.z * up.x - fwd.x * up.z, fwd.x * up.y - fwd.y * up.x)
    return fwd, right, up
end

-- Every note in view gets its own model (bkr_sticky_note_1..N), and so its own cell of the note atlas, so each can show
-- its own code (client/note.lua draws them). Past N notes nearby the plain model is used, without a code.
local function freeSlot()
    local used = {}
    for _, slot in pairs(World.noteSlots) do used[slot] = true end
    for i = 1, Props.NoteVariants do if not used[i] then return i end end
end

local function spawnNote(view)
    local n = view.note
    local slot = view.id and freeSlot() or nil
    local e = spawn(slot and (Props.Models.note .. '_' .. slot) or Props.Models.note, vector3(n.x, n.y, n.z), 0.0, false)
    if e and slot then World.noteSlots[view.id] = slot end
    if e then
        local f, r, u = World.noteBasis(n)
        SetEntityMatrix(e, f.x, f.y, f.z, r.x, r.y, r.z, u.x, u.y, u.z, n.x, n.y, n.z)
    end
    return e
end

local function deleteNote(id)
    delete(World.notes[id])
    World.notes[id] = nil
    World.noteSlots[id] = nil
end

-- ---------- state sync ----------

-- Unix time; the server stamps fuses / cooldowns with os.time().
function World.serverNow() return GetCloudTimeAsInt() end

local function despawn(id)
    World.destroyRig(World.rigs[id])
    World.rigs[id] = nil
    deleteNote(id)
end

local function sameLoot(a, b)
    if (a == nil) ~= (b == nil) then return false end
    if not a then return true end
    if #a ~= #b then return false end
    for i = 1, #a do if a[i].i ~= b[i].i then return false end end
    return true
end

-- A safe changed on the server.
local function apply(view)
    local old = World.safes[view.id]
    World.safes[view.id] = view
    local rig = World.rigs[view.id]
    -- moved or rebuilt by an admin: respawn it
    if rig and (not old or old.x ~= view.x or old.y ~= view.y or old.z ~= view.z or old.h ~= view.h or old.kind ~= view.kind or not view.enabled) then
        despawn(view.id)
        rig = nil
    end
    if old and json.encode(old.note or false) ~= json.encode(view.note or false) then
        deleteNote(view.id)
    end
    -- the code changed (admin edit, or a new random code after a relock): redraw the note
    if old and old.noteTag ~= view.noteTag and NoteDui then NoteDui.forget(view.id) end
    if not rig then return end
    if old and old.state ~= view.state then
        if view.state == 'open' then
            World.removeCharge(rig)
            if view.method == 'explosive' then World.openWithBlast(rig) else World.openWithCode(rig) end
            SetTimeout(view.kind == 'lockbox' and 500 or 900, function()
                if not rig.dead then World.setLoot(rig, (World.safes[view.id] or view).loot, view.id) end
            end)
        elseif view.state == 'locked' then
            World.removeCharge(rig)
            World.setLoot(rig, nil)
            World.close(rig)
        elseif view.state == 'charged' then
            World.attachCharge(rig, view.fuseEnd)
        end
    elseif view.state == 'open' and not sameLoot(old and old.loot, view.loot) then
        World.setLoot(rig, view.loot, view.id)
    end
end

RegisterNetEvent('bakery_saferobbery:client:safe', function(view)
    if source == 65535 and type(view) == 'table' then apply(view) end
end)

RegisterNetEvent('bakery_saferobbery:client:remove', function(id)
    if source ~= 65535 then return end
    despawn(id)
    World.safes[id] = nil
end)

RegisterNetEvent('bakery_saferobbery:client:all', function(list)
    if source ~= 65535 then return end
    for id in pairs(World.rigs) do despawn(id) end
    for id in pairs(World.notes) do deleteNote(id) end
    World.safes = {}
    for _, v in ipairs(list or {}) do World.safes[v.id] = v end
    if NoteDui then NoteDui.forgetAll() end
end)

RegisterNetEvent('bakery_saferobbery:client:blast', function(id, who, damage)
    if source ~= 65535 then return end
    local rig = World.rigs[id]
    local me = GetPlayerServerId(PlayerId())
    if rig then
        World.blastFx(rig, who == me, damage)
    elseif who == me then
        local v = World.safes[id]
        if v then AddExplosion(v.x, v.y, v.z + 0.7, 2, damage and 1.0 or 0.0, true, false, 0.6) end
    end
end)

-- Streams safes and notes in and out around the player.
CreateThread(function()
    local list = Nui.call('getSafes')
    for _, v in ipairs(list or {}) do World.safes[v.id] = v end
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local near, far = Config.StreamDistance, Config.StreamDistance + 10.0
        for id, v in pairs(World.safes) do
            local d = #(me - vector3(v.x, v.y, v.z))
            local rig = World.rigs[id]
            if v.enabled and d < near and not rig then
                rig = World.makeRig(v.kind, vector3(v.x, v.y, v.z), v.h)
                if World.safes[id] == v and rig.body then
                    local def = Props.def(v.kind)
                    rig.front = Utils.offset(rig.pos, rig.h, def.front)
                    rig.prompt = Utils.offset(rig.pos, rig.h, def.prompt)
                    World.rigs[id] = rig
                    World.pose(rig, v)
                    if v.state == 'charged' then World.attachCharge(rig, v.fuseEnd) end
                    if v.state == 'open' then World.setLoot(rig, v.loot, id) end
                else
                    World.destroyRig(rig)
                end
            elseif rig and (d > far or not v.enabled) then
                World.destroyRig(rig)
                World.rigs[id] = nil
            end
            if v.note and v.enabled then
                local nd = #(me - vector3(v.note.x, v.note.y, v.note.z))
                if nd < near and not World.notes[id] then
                    World.notes[id] = spawnNote(v)
                elseif nd > far and World.notes[id] then
                    deleteNote(id)
                end
            elseif World.notes[id] then
                deleteNote(id)
            end
        end
        Wait(750)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(World.rigs) do despawn(id) end
    for _, e in pairs(World.notes) do delete(e) end
end)
