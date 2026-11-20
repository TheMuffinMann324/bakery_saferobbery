-- Admin placement in a free cam (same controls as bakery_boosting's free cam).
--
--   safe / lockbox  A see-through prop follows your aim and sits on the ground under it. Every corner of its
--                   footprint is probed: the outline goes green (good), amber (check it) or red (can't place)
--                   with the reason shown - uneven ground, something inside it, no room for the door or lid.
--                   Near a wall it backs up against it automatically. Scroll turns it.
--                   E puts it down solid for the TEST stage: O opens / closes it, X blows a safe open,
--                   Enter saves, Backspace goes back to moving it.
--   note            A sticky note sticks flat to whatever you aim at (walls, desks, monitors), the right way up.
--                   Wheel spins it on the surface. E sets it.
-- Esc cancels. Nothing is saved here: the result goes back to the admin panel, which saves it.
Placement = { active = false }

local sin, cos, rad, deg, floor, abs = math.sin, math.cos, math.rad, math.deg, math.floor, math.abs
local REACH, SPEED, SPEED_FAST = 120.0, 0.06, 0.4
local UP = vector3(0.0, 0.0, 1.0)

local function forward(rot)
    local p, y = rad(rot.x), rad(rot.z)
    return vector3(-sin(y) * cos(p), cos(y) * cos(p), sin(p))
end

local function round(n, p) local m = 10 ^ (p or 3) return floor(n * m + 0.5) / m end

local function ray(a, b, ignore)
    local h = StartExpensiveSynchronousShapeTestLosProbe(a.x, a.y, a.z, b.x, b.y, b.z, 1 | 2 | 16, ignore or 0, 7)
    local _, hit, coords, normal, ent = GetShapeTestResult(h)
    return hit == 1, coords, normal, ent
end

local function ground(p, ignore)
    local hit, c, n = ray(vector3(p.x, p.y, p.z + 0.6), vector3(p.x, p.y, p.z - 2.5), ignore)
    if hit then return c.z, n end
    return nil
end

local function headingOf(v)
    return (deg(math.atan(v.y, v.x)) - 90.0) % 360.0
end

local function text3d(p, line, c)
    local onScreen, sx, sy = World3dToScreen2d(p.x, p.y, p.z)
    if not onScreen then return end
    SetTextScale(0.0, 0.32) SetTextFont(4) SetTextCentre(true) SetTextOutline()
    SetTextColour(c[1], c[2], c[3], 240)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(line)
    EndTextCommandDisplayText(sx, sy)
end

local COLOURS = { ok = { 74, 222, 128 }, warn = { 251, 191, 36 }, bad = { 248, 113, 113 } }

-- Outline of the footprint box, coloured by how good the spot is.
local function drawBox(kind, pos, h, c)
    local s = Props.def(kind).size
    local hw, hd = s.x / 2, s.y / 2
    local pts = {}
    for i, xy in ipairs({ { -hw, -hd }, { hw, -hd }, { hw, hd }, { -hw, hd } }) do
        pts[i] = Utils.offset(pos, h, vector3(xy[1], xy[2], 0.01))
        pts[i + 4] = Utils.offset(pos, h, vector3(xy[1], xy[2], s.z + 0.01))
    end
    for i = 1, 4 do
        local j = i % 4 + 1
        DrawLine(pts[i].x, pts[i].y, pts[i].z, pts[j].x, pts[j].y, pts[j].z, c[1], c[2], c[3], 255)
        DrawLine(pts[i + 4].x, pts[i + 4].y, pts[i + 4].z, pts[j + 4].x, pts[j + 4].y, pts[j + 4].z, c[1], c[2], c[3], 255)
        DrawLine(pts[i].x, pts[i].y, pts[i].z, pts[i + 4].x, pts[i + 4].y, pts[i + 4].z, c[1], c[2], c[3], 255)
    end
    -- front arrow on the floor
    local f0 = Utils.offset(pos, h, vector3(0.0, hd + 0.05, 0.02))
    local f1 = Utils.offset(pos, h, vector3(0.0, hd + 0.35, 0.02))
    DrawLine(f0.x, f0.y, f0.z, f1.x, f1.y, f1.z, 255, 255, 255, 220)
    DrawMarker(26, f1.x, f1.y, f1.z, 0.0, 0.0, 0.0, 0.0, 0.0, h, 0.25, 0.25, 0.25, 255, 255, 255, 160, false, false, 2, false, nil, nil, false)
end

-- Door swing (safe) as a dotted arc on the floor.
local function drawSwing(pos, h)
    local hinge = Props.Safe.hinge
    local last
    for a = 0, 105, 7.5 do
        local r = rad(-a)
        local p = Utils.offset(pos, h, vector3(hinge.x - Props.Safe.doorSwing * cos(r), hinge.y - Props.Safe.doorSwing * sin(r), 0.02))
        if last then DrawLine(last.x, last.y, last.z, p.x, p.y, p.z, 255, 255, 255, 120) end
        last = p
    end
end

-- Checks a spot. Returns the snapped z and a list of { text, level } issues ('warn' or 'bad').
local function validate(kind, pos, h, ignore)
    local def = Props.def(kind)
    local s = def.size
    local issues = {}
    local hw, hd = s.x / 2 - 0.02, s.y / 2 - 0.02
    local zs, missing = {}, false
    for _, xy in ipairs({ { -hw, -hd }, { hw, -hd }, { hw, hd }, { -hw, hd }, { 0.0, 0.0 } }) do
        local p = Utils.offset(pos, h, vector3(xy[1], xy[2], 0.0))
        local z = ground(p, ignore)
        if z then zs[#zs + 1] = z else missing = true end
    end
    if #zs == 0 then return pos.z, { { text = 'No ground under it', level = 'bad' } } end
    local top, low = -math.huge, math.huge
    for _, z in ipairs(zs) do top, low = math.max(top, z), math.min(low, z) end
    if missing then issues[#issues + 1] = { text = 'Hanging over an edge', level = 'bad' } end
    local spread = top - low
    if spread > 0.07 then
        issues[#issues + 1] = { text = ('Uneven ground (%d cm)'):format(floor(spread * 100 + 0.5)), level = 'bad' }
    elseif spread > 0.025 then
        issues[#issues + 1] = { text = ('Slightly uneven (%d cm), check it sits flat'):format(floor(spread * 100 + 0.5)), level = 'warn' }
    end
    local base = vector3(pos.x, pos.y, top)
    -- anything inside the body (walls, furniture)
    for _, z in ipairs({ 0.12, s.z * 0.55, s.z - 0.05 }) do
        local a = Utils.offset(base, h, vector3(-hw, -hd, z))
        local b = Utils.offset(base, h, vector3(hw, hd, z))
        local c = Utils.offset(base, h, vector3(hw, -hd, z))
        local d = Utils.offset(base, h, vector3(-hw, hd, z))
        if ray(a, b, ignore) or ray(c, d, ignore) then
            issues[#issues + 1] = { text = 'Something is in the way', level = 'bad' }
            break
        end
    end
    -- room in front: the door / lid has to open and players have to reach it
    if kind == 'safe' then
        local hinge = Props.Safe.hinge
        local blocked = false
        for _, a in ipairs({ -25.0, -55.0, -85.0, -105.0 }) do
            local r = rad(a)
            local tip = vector3(hinge.x - Props.Safe.doorSwing * cos(r), hinge.y - Props.Safe.doorSwing * sin(r), 0.0)
            for _, z in ipairs({ 0.3, 0.95 }) do
                local from = Utils.offset(base, h, vector3(hinge.x - 0.05, hinge.y + 0.04, z))
                if ray(from, Utils.offset(base, h, vector3(tip.x, tip.y, z)), ignore) then blocked = true end
            end
        end
        if blocked then issues[#issues + 1] = { text = 'The door can\'t swing all the way open', level = 'warn' } end
    else
        local c = Utils.offset(base, h, vector3(0.0, Props.Lockbox.hinge.y + 0.02, s.z + 0.02))
        if ray(c, c + UP * 0.32, ignore) then issues[#issues + 1] = { text = 'No room above for the lid', level = 'warn' } end
    end
    local reach = Utils.offset(base, h, def.front + vector3(0.0, 0.0, 1.0))
    local face = Utils.offset(base, h, vector3(0.0, s.y / 2 + 0.03, math.min(1.0, s.z - 0.05)))
    if ray(reach, face, ignore) then issues[#issues + 1] = { text = 'Players can\'t get to the front', level = 'bad' } end
    return top, issues
end

local function worst(issues)
    local level = 'ok'
    for _, i in ipairs(issues) do
        if i.level == 'bad' then return 'bad' end
        level = 'warn'
    end
    return level
end

-- Sticky note basis: +Z out of the surface, +Y the top of the note.
local function noteBasis(normal, camFwd, spin)
    local z = normal
    local y
    if abs(z.z) > 0.85 then
        y = vector3(camFwd.x, camFwd.y, 0.0)       -- flat on a desk: reads the right way from the camera
    else
        y = UP - z * (UP.x * z.x + UP.y * z.y + UP.z * z.z)   -- on a wall: top of the note up
    end
    if #y < 0.001 then y = vector3(0.0, 1.0, 0.0) end
    y = y / #y
    local x = vector3(y.y * z.z - y.z * z.y, y.z * z.x - y.x * z.z, y.x * z.y - y.y * z.x)
    if spin ~= 0.0 then
        local r = rad(spin)
        local c, s = cos(r), sin(r)
        x, y = x * c + y * s, y * c - x * s
    end
    return x, y, z
end

local function hud(state)
    state.active = true
    Nui.send('place', state)
end

-- opts: { mode = 'safe' | 'lockbox' | 'note', label, start = { x, y, z, h } | note, anchor = { x, y, z } }
local function run(opts)
    local mode = opts.mode
    local kind = mode == 'lockbox' and 'lockbox' or 'safe'
    local ped = PlayerPedId()
    local home = GetEntityCoords(ped)
    local start = opts.start and (opts.start.x or 0) ~= 0 and opts.start or nil
    local focus = start or ((opts.anchor and (opts.anchor.x or 0) ~= 0) and opts.anchor) or nil
    local camPos = focus and vector3(focus.x, focus.y - 3.0, focus.z + 2.2) or vector3(home.x, home.y, home.z + 1.2)
    local camRot = focus and vector3(-30.0, 0.0, 0.0) or vector3(-25.0, 0.0, GetEntityHeading(ped))

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamRot(cam, camRot.x, 0.0, camRot.z, 2)
    SetCamFov(cam, 60.0)
    RenderScriptCams(true, true, 400, true, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)

    local speed, turn = 1.0, 0.0
    local opened = false   -- test stage: is the door / lid open right now
    local stage = 'aim'
    local rig, note
    if mode == 'note' then
        note = World.spawn(Props.Models.note, camPos, 0.0, false)
        if note then SetEntityAlpha(note, 230, false) end
    else
        rig = World.makeRig(kind, camPos, 0.0, 170)
    end
    -- the safe the note belongs to, so the admin can see where it is
    local anchorRig = mode == 'note' and opts.anchor and (opts.anchor.x or 0) ~= 0
        and World.makeRig(opts.anchor.kind or 'safe', vector3(opts.anchor.x, opts.anchor.y, opts.anchor.z), opts.anchor.h or 0.0, 140) or nil

    local probe, aim, aimNormal = nil, nil, nil
    local spot = start and vector3(start.x, start.y, start.z) or nil
    local heading = start and start.h or 0.0
    local issues, level, lastCheck = {}, 'ok', 0
    local snapped = false
    local noteF, noteU = vector3(0.0, 1.0, 0.0), UP
    local result

    while not result do
        -- ---------- camera
        local pos = GetCamCoord(cam)
        local s = (IsDisabledControlPressed(0, 21) and SPEED_FAST or SPEED) * speed
        local yaw = rad(camRot.z)
        local fx, fy = -sin(yaw), cos(yaw)
        local dx, dy, dz = 0.0, 0.0, 0.0
        if IsDisabledControlPressed(0, 32) then dx, dy = dx + fx, dy + fy end
        if IsDisabledControlPressed(0, 33) then dx, dy = dx - fx, dy - fy end
        if IsDisabledControlPressed(0, 34) then dx, dy = dx - fy, dy + fx end
        if IsDisabledControlPressed(0, 35) then dx, dy = dx + fy, dy - fx end
        if IsDisabledControlPressed(0, 22) then dz = dz + 1.0 end
        if IsDisabledControlPressed(0, 36) then dz = dz - 1.0 end
        pos = pos + vector3(dx * s, dy * s, dz * s)
        camRot = vector3(math.max(-89.0, math.min(89.0, camRot.x - GetDisabledControlNormal(0, 2) * 7.0)), 0.0, (camRot.z - GetDisabledControlNormal(0, 1) * 7.0) % 360.0)
        SetCamCoord(cam, pos.x, pos.y, pos.z)
        SetCamRot(cam, camRot.x, 0.0, camRot.z, 2)
        SetFocusPosAndVel(pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
        DisableAllControlActions(0)
        EnableControlAction(0, 249, true)   -- push to talk
        DisableFrontendThisFrame()
        local fwd = forward(camRot)

        -- wheel: ctrl = camera speed, otherwise turn
        local wheel = IsDisabledControlJustPressed(0, 15) and 1 or IsDisabledControlJustPressed(0, 14) and -1 or 0
        if wheel ~= 0 and IsDisabledControlPressed(0, 36) then
            speed = math.max(0.25, math.min(4.0, speed + wheel * 0.25))
        elseif wheel ~= 0 and stage == 'aim' then
            turn = (turn + wheel * 10.0) % 360.0
        end

        -- ---------- aim (async probe, one in flight)
        if stage == 'aim' then
            if probe then
                local status, hit, coords, normal = GetShapeTestResult(probe)
                if status == 2 then
                    if hit == 1 then aim, aimNormal = coords, normal else aim, aimNormal = nil, nil end
                    probe = nil
                elseif status == 0 then probe = nil end
            end
            if not probe then
                local e = pos + fwd * REACH
                probe = StartShapeTestLosProbe(pos.x, pos.y, pos.z, e.x, e.y, e.z, 1 | 2 | 16, ped, 7)
            end
        end

        -- ---------- place the ghost
        if stage == 'aim' and aim then
            if mode == 'note' then
                local x, y, z = noteBasis(aimNormal, fwd, turn)
                noteF, noteU = y, z
                local p = aim + z * 0.0008
                if note then
                    SetEntityMatrix(note, y.x, y.y, y.z, x.x, x.y, x.z, z.x, z.y, z.z, p.x, p.y, p.z)
                end
                spot = p
                issues = {}
                if opts.anchor and (opts.anchor.x or 0) ~= 0 then
                    local d = #(p - vector3(opts.anchor.x, opts.anchor.y, opts.anchor.z))
                    if d > 60.0 then issues[1] = { text = ('%d m from the safe, a long way to look'):format(floor(d)), level = 'warn' } end
                end
                level = worst(issues)
            else
                local def = Props.def(kind)
                local p = aim
                snapped = false
                if aimNormal.z < 0.45 then
                    -- aiming at a wall: back up against it, facing out
                    local n = vector3(aimNormal.x, aimNormal.y, 0.0)
                    if #n > 0.01 then
                        n = n / #n
                        heading = headingOf(n)
                        p = aim + n * (def.size.y / 2 + 0.015)
                        p = vector3(p.x, p.y, aim.z)
                        snapped = true
                    end
                else
                    heading = (camRot.z + 180.0 + turn) % 360.0
                    do
                        -- a wall just behind it: back it up to the wall and square it up
                        local back = Utils.offset(vector3(p.x, p.y, p.z + 0.5), heading, vector3(0.0, -(def.size.y / 2 + 0.6), 0.0))
                        local hit, c, n = ray(vector3(p.x, p.y, p.z + 0.5), back, ped)
                        if hit and n.z < 0.45 then
                            local nn = vector3(n.x, n.y, 0.0)
                            if #nn > 0.01 then
                                nn = nn / #nn
                                heading = headingOf(nn)
                                local q = vector3(c.x, c.y, p.z) + nn * (def.size.y / 2 + 0.015)
                                p = vector3(q.x, q.y, p.z)
                                snapped = true
                            end
                        end
                    end
                end
                local t = GetGameTimer()
                if t - lastCheck > 90 or not spot then
                    lastCheck = t
                    local z
                    z, issues = validate(kind, p, heading, ped)
                    spot = vector3(p.x, p.y, z)
                    level = worst(issues)
                else
                    spot = vector3(p.x, p.y, spot.z)
                end
                World.moveRig(rig, spot, heading)
            end
        end

        -- ---------- draw
        if stage == 'aim' and aim then
            DrawMarker(28, aim.x, aim.y, aim.z, 0, 0, 0, 0, 0, 0, 0.04, 0.04, 0.04, 255, 255, 255, 200, false, false, 2, false, nil, nil, false)
        end
        if mode ~= 'note' and spot then
            drawBox(kind, spot, heading, COLOURS[stage == 'test' and 'ok' or level])
            if kind == 'safe' and stage == 'aim' then drawSwing(spot, heading) end
        elseif mode == 'note' and spot then
            text3d(spot + vector3(0.0, 0.0, 0.08), 'STICKY NOTE', COLOURS[level])
        end
        if anchorRig then
            text3d(anchorRig.pos + vector3(0.0, 0.0, 1.45), (opts.anchor.label or 'SAFE'):upper(), { 255, 255, 255 })
        end

        hud({
            mode = mode, stage = stage, label = opts.label, issues = issues, level = level,
            snapped = snapped, opened = opened, speed = speed, hasAim = aim ~= nil,
        })

        -- ---------- keys
        local esc = IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322)
        if stage == 'aim' then
            if IsDisabledControlJustPressed(0, 38) and spot and aim then -- E
                local force = IsDisabledControlPressed(0, 21)
                if level == 'bad' and not force then
                    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                elseif mode == 'note' then
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    result = { note = {
                        x = round(spot.x, 4), y = round(spot.y, 4), z = round(spot.z, 4),
                        fx = round(noteF.x, 4), fy = round(noteF.y, 4), fz = round(noteF.z, 4),
                        ux = round(noteU.x, 4), uy = round(noteU.y, 4), uz = round(noteU.z, 4),
                    } }
                else
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    stage = 'test'
                    World.setAlpha(rig, 255)
                    World.setCollision(rig, true)
                end
            elseif esc then
                result = { cancelled = true }
            end
        else -- test
            if IsDisabledControlJustPressed(0, 39) then                                    -- O: open / close
                if opened then World.close(rig) else World.openWithCode(rig) end
                opened = not opened
            end
            if kind == 'safe' and not opened and IsDisabledControlJustPressed(0, 73) then -- X: blow it open
                World.openWithBlast(rig)
                World.blastFx(rig, false, false)
                opened = true
            end
            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then -- Enter
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                result = { x = round(spot.x), y = round(spot.y), z = round(spot.z), h = round(heading, 2) }
            elseif IsDisabledControlJustPressed(0, 177) then                              -- Backspace: back to moving it
                World.destroyRig(rig)
                rig = World.makeRig(kind, spot, heading, 170)
                stage, opened = 'aim', false
            elseif esc then
                result = { cancelled = true }
            end
        end
        Wait(0)
    end

    World.destroyRig(rig)
    World.destroyRig(anchorRig)
    World.delete(note)
    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(cam, false)
    ClearFocus()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
    Nui.send('place', { active = false })
    return result
end

RegisterNUICallback('admin:place', function(data, cb)
    if not Nui.admin or Placement.active then return cb({ cancelled = true }) end
    if type(data) ~= 'table' or (data.mode ~= 'safe' and data.mode ~= 'lockbox' and data.mode ~= 'note') then return cb({ cancelled = true }) end
    Placement.active = true
    Nui.setFocus('admin', false)
    Nui.send('admin', { open = true, hidden = true })
    local ok, res = pcall(run, data)
    Placement.active = false
    if Nui.admin then
        Nui.setFocus('admin', true)
        Nui.send('admin', { open = true, hidden = false })
    end
    if not ok then
        print(('^1[bakery_saferobbery] placement failed: %s^7'):format(res))
        Nui.send('place', { active = false })
        return cb({ cancelled = true })
    end
    cb(res or { cancelled = true })
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not Placement.active then return end
    RenderScriptCams(false, false, 0, true, true)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
end)
