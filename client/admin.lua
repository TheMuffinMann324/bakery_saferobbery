-- Admin panel helpers that need the game world. The server re-checks admin permission on every save.

-- Street (or district) at a spot, used to name a new safe.
RegisterNUICallback('admin:area', function(data, cb)
    if not Nui.admin then return cb({ ok = false }) end
    local x, y, z
    if type(data) == 'table' then x, y, z = Utils.finite(data.x), Utils.finite(data.y), Utils.finite(data.z) end
    local p = x and y and z and vector3(x, y, z) or GetEntityCoords(PlayerPedId())
    local street = GetStreetNameFromHashKey((GetStreetNameAtCoord(p.x, p.y, p.z)))
    local zone = GetLabelText(GetNameOfZone(p.x, p.y, p.z))
    if zone == 'NULL' then zone = '' end
    cb({ label = street ~= '' and street or zone })
end)

-- Teleports in front of a safe (facing it), or to plain coords.
RegisterNUICallback('admin:teleport', function(data, cb)
    if not Nui.admin or type(data) ~= 'table' then return cb({ ok = false }) end
    local x, y, z = Utils.finite(data.x), Utils.finite(data.y), Utils.finite(data.z)
    if x and y and z then
        local ped = PlayerPedId()
        local h = Utils.finite(data.h)
        if h and data.kind then
            local p = Utils.offset(vector3(x, y, z), h, Props.def(data.kind).front + vector3(0.0, 0.4, 0.0))
            SetEntityCoords(ped, p.x, p.y, p.z + 0.1, false, false, false, false)
            SetEntityHeading(ped, (h + 180.0) % 360.0)
        else
            SetEntityCoords(ped, x, y, z + 0.3, false, false, false, false)
        end
    end
    cb({ ok = x ~= nil and y ~= nil and z ~= nil })
end)
