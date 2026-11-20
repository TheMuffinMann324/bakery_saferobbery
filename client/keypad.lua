-- The big safe's keypad. The camera moves in on the keypad on the door and every button of the prop is
-- projected to the screen; the NUI lays click areas exactly over them (and the LCD), so players press the
-- real buttons with the mouse (or type the digits). On the right code the player steps clear of the door
-- and the camera pulls back to watch it swing open.
Keypad = { active = nil }

local function screenRect(door, ax, az, bx, bz, y)
    local a = GetOffsetFromEntityInWorldCoords(door, ax, y, az)
    local b = GetOffsetFromEntityInWorldCoords(door, bx, y, bz)
    local _, x0, y0 = GetScreenCoordFromWorldCoord(a.x, a.y, a.z)
    local _, x1, y1 = GetScreenCoordFromWorldCoord(b.x, b.y, b.z)
    return { x0 = math.min(x0, x1), y0 = math.min(y0, y1), x1 = math.max(x0, x1), y1 = math.max(y0, y1) }
end

-- Click areas for the 12 buttons and the LCD, in 0..1 screen space.
local function layout(door)
    local kp, K = Props.Safe.keypad, Props.Keypad
    local front = kp.y + Props.Safe.keypadDepth
    local buttons = {}
    for r, z in ipairs(K.rows) do
        for c, x in ipairs(K.cols) do
            local cx, cz = kp.x + x, kp.z + z
            local rect = screenRect(door, cx + K.button.w / 2, cz + K.button.h / 2, cx - K.button.w / 2, cz - K.button.h / 2, front)
            rect.label = K.labels[r][c]
            buttons[#buttons + 1] = rect
        end
    end
    local l = K.lcd
    local lcd = screenRect(door, kp.x + l.w / 2, kp.z + l.z + l.h / 2, kp.x - l.w / 2, kp.z + l.z - l.h / 2, kp.y + 0.017)
    local housing = screenRect(door, kp.x + K.width / 2, kp.z + K.height / 2, kp.x - K.width / 2, kp.z - K.height / 2, kp.y + 0.016)
    return buttons, lcd, housing
end

local function playAnim(ped, dict, clip, flag, blend)
    if not dict or not lib.requestAnimDict(dict, 2000) then return end
    TaskPlayAnim(ped, dict, clip, blend or 4.0, blend or 4.0, -1, flag or 1, 0.0, false, false, false)
end

local function walkTo(ped, p, heading, timeoutMs)
    TaskGoStraightToCoord(ped, p.x, p.y, p.z, 1.0, timeoutMs or 3000, heading, 0.05)
    local untilT = GetGameTimer() + (timeoutMs or 3000)
    while GetGameTimer() < untilT do
        local d = #(GetEntityCoords(ped).xy - vector2(p.x, p.y))
        if d < 0.15 then break end
        Wait(50)
    end
    ClearPedTasks(ped)
    SetEntityHeading(ped, heading)
end

local function endCam(k, ms)
    if k.cam then
        RenderScriptCams(false, true, ms or 600, true, true)
        DestroyCam(k.cam, false)
        k.cam = nil
    end
end

local function finish(k, opened)
    if Keypad.active ~= k then return end
    Keypad.active = nil
    Nui.send('keypad', { open = false })
    Nui.setFocus('keypad', false)
    local ped = PlayerPedId()
    local A = Config.Anims.keypad
    if opened then
        -- step clear of the door's swing, then watch it open from a wider angle
        local rig = k.rig
        local wide = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 50.0, false, 2)
        local cp = Utils.offset(rig.pos, rig.h, vector3(-1.25, 1.75, 1.45))
        local look = Utils.offset(rig.pos, rig.h, vector3(0.05, 0.35, 0.62))
        SetCamCoord(wide, cp.x, cp.y, cp.z)
        PointCamAtCoord(wide, look.x, look.y, look.z)
        SetCamActiveWithInterp(wide, k.cam, 900, 1, 1)
        DestroyCam(k.cam, false)
        k.cam = wide
        StopAnimTask(ped, A.dict, A.loop, 2.0)
        local stand = Utils.offset(rig.pos, rig.h, vector3(-0.55, 0.95, 0.0))
        walkTo(ped, stand, (rig.h + 200.0) % 360.0, 1800)
        Wait(2400)
        endCam(k, 900)
    else
        StopAnimTask(ped, A.dict, A.loop, 2.0)
        playAnim(ped, A.dict, A.exit, 0, 4.0)
        endCam(k, 600)
        Nui.call('keypad:close', { id = k.id, session = k.session })
    end
end

function Keypad.open(id)
    if Keypad.active then return end
    local rig, view = World.rigs[id], World.safes[id]
    if not rig or not rig.door or not view then return end
    local res = Nui.call('keypad:open', { id = id })
    if not res or not res.ok then return Bridge.notify(res and res.error or 'The keypad isn\'t responding.', 'error') end

    local k = { id = id, rig = rig, session = res.session }
    Keypad.active = k
    local ped = PlayerPedId()
    local kp = Props.Safe.keypad
    -- stand square in front of the keypad
    local stand = Utils.offset(rig.pos, rig.h, vector3(Props.Safe.hinge.x + kp.x, 0.82, 0.0))
    walkTo(ped, vector3(stand.x, stand.y, GetEntityCoords(ped).z), (rig.h + 180.0) % 360.0, 2500)
    local A = Config.Anims.keypad
    if lib.requestAnimDict(A.dict, 2000) then
        TaskPlayAnim(ped, A.dict, A.enter, 4.0, 4.0, -1, 0, 0.0, false, false, false)
        Wait(600)
        TaskPlayAnim(ped, A.dict, A.loop, 4.0, 4.0, -1, 1, 0.0, false, false, false)
    end

    -- close-up on the keypad
    local centre = GetOffsetFromEntityInWorldCoords(rig.door, kp.x, kp.y + 0.02, kp.z - 0.005)
    local camPos = GetOffsetFromEntityInWorldCoords(rig.door, kp.x - 0.02, kp.y + 0.34, kp.z + 0.04)
    k.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 42.0, false, 2)
    PointCamAtCoord(k.cam, centre.x, centre.y, centre.z)
    SetCamActive(k.cam, true)
    RenderScriptCams(true, true, 700, true, true)
    Wait(760)
    if Keypad.active ~= k then return end

    local buttons, lcd, housing = layout(rig.door)
    Nui.send('keypad', { open = true, id = id, label = view.label, buttons = buttons, lcd = lcd, housing = housing, attemptsLeft = res.attemptsLeft })
    Nui.setFocus('keypad', true)

    CreateThread(function()
        while Keypad.active == k do
            DisableAllControlActions(0)
            -- the safe can be removed under us. 'open' is our own success (its broadcast can beat the callback)
            local v = World.safes[id]
            if not v or not v.enabled or v.state == 'charged' or not DoesEntityExist(rig.door) then
                finish(k, false)
                break
            end
            Wait(0)
        end
    end)
end

RegisterNUICallback('keypad:submit', function(data, cb)
    local k = Keypad.active
    if not k then return cb({ ok = false }) end
    local code = type(data) == 'table' and tostring(data.code or '') or ''
    local res = Nui.call('keypad:try', { id = k.id, session = k.session, code = code }) or { ok = false, error = 'No response.' }
    cb(res)
    if res.ok then
        SetTimeout(700, function() finish(k, true) end)
    elseif res.lockout then
        Bridge.notify('The keypad locked up.', 'error')
        SetTimeout(1400, function() finish(k, false) end)
    end
end)

RegisterNUICallback('keypad:close', function(_, cb)
    cb({ ok = true })
    local k = Keypad.active
    if k then CreateThread(function() finish(k, false) end) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not Keypad.active then return end
    RenderScriptCams(false, false, 0, true, true)
    ClearPedTasks(PlayerPedId())
end)
