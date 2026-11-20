-- The sticky-note DUI draws an atlas of 4x4 notes and replaces the
-- bks_note texture with it. Every note in view is spawned as its own model, bkr_sticky_note_N (see
-- World.noteSlots), which shows cell N of that atlas, so each note shows its own code from the one page.
-- A code is only fetched from the server once a player is close enough to see it, and fetched again whenever
-- the server says it changed (view.noteTag).
NoteDui = {}

local RES = GetCurrentResourceName()
local URL = ('https://cfx-nui-%s/web/dist/note.html'):format(RES)
local SEE = 30.0              -- metres: closer than this, the code is fetched and drawn

local dui = nil
local sent = ''               -- the last set of codes sent to the page (json)
local resendUntil = 0         -- the page may still be loading: keep resending until then
local codes = {}              -- safe id -> code
local pending = {}

-- The full set of codes ({ ["slot"] = code }) goes to the page every time, so a lost message costs nothing.
local function draw(cells)
    local data = json.encode({ codes = cells })
    if not dui then
        local parts = {}
        for slot, code in pairs(cells) do parts[#parts + 1] = slot .. ':' .. code end
        dui = CreateDui(URL .. '?codes=' .. table.concat(parts, ','), 1024, 1024)
        if not dui then return end
        local txd = CreateRuntimeTxd('bkr_saferob_note')
        CreateRuntimeTextureFromDuiHandle(txd, 'note', GetDuiHandle(dui))
        AddReplaceTexture('bkr_safe_props', 'bks_note', 'bkr_saferob_note', 'note')
        resendUntil = GetGameTimer() + 4000
    elseif data ~= sent or GetGameTimer() < resendUntil then
        SendDuiMessage(dui, data)
    end
    sent = data
end

local function fetch(id)
    if codes[id] or pending[id] then return end
    local request = {}
    pending[id] = request
    CreateThread(function()
        local res = Nui.call('note:read', { id = id })
        if pending[id] ~= request then return end
        pending[id] = nil
        if res and res.ok and type(res.code) == 'string' then codes[id] = res.code end
    end)
end

function NoteDui.forget(id)
    codes[id] = nil
    pending[id] = nil
end

function NoteDui.forgetAll()
    for id in pairs(codes) do NoteDui.forget(id) end
    for id in pairs(pending) do NoteDui.forget(id) end
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local cells, any = {}, false
        for id, slot in pairs(World.noteSlots) do
            local e = World.notes[id]
            if e and DoesEntityExist(e) and #(me - GetEntityCoords(e)) < SEE then
                any = true
                fetch(id)
                -- a slot only ever shows the code of the note using it now; anything else is left blank
                if codes[id] then cells[tostring(slot)] = codes[id] end
            end
        end
        if any or dui then draw(cells) end
        Wait(any and 300 or 1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    RemoveReplaceTexture('bkr_safe_props', 'bks_note')
    if dui then DestroyDui(dui) end
end)
