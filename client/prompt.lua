-- One browser-backed texture, drawn next to the current prop.
PromptDui = {}

local RES = GetCurrentResourceName()
local DICTIONARY = RES .. '_prompt'
local dui, texture
local last, nextSend, warmUntil = nil, 0, 0

local function ready(now)
    if not dui then
        dui = CreateDui(('https://cfx-nui-%s/web/dist/prompt.html'):format(RES), 512, 192)
    end
    if not texture and dui and IsDuiAvailable(dui) then
        local txd = CreateRuntimeTxd(DICTIONARY)
        texture = CreateRuntimeTextureFromDuiHandle(txd, 'prompt', GetDuiHandle(dui))
        warmUntil = now + 1800
    end
    return texture ~= nil and texture ~= 0
end

function PromptDui.project(pos)
    local visible, x, y = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)
    if visible then return x, y end
end

function PromptDui.draw(x, y, title, action, charge, progress)
    local now = GetGameTimer()
    if not ready(now) then return end
    progress = math.floor(progress * 100 + 0.5)
    if not last or last.title ~= title or last.action ~= action
        or last.charge ~= charge or last.progress ~= progress or now < warmUntil and now >= nextSend then
        last = { title = title, action = action, charge = charge, progress = progress }
        SendDuiMessage(dui, json.encode(last))
        nextSend = now + 150
    end
    local h = 96 / 1080
    local pixel = 1 / (1080 * GetAspectRatio(false))
    local w = 256 * pixel
    x = math.min(x + w * 0.5 + 12 * pixel, 0.985 - w * 0.5)
    y = math.max(h * 0.5 + 0.01, math.min(y, 0.99 - h * 0.5))
    DrawSprite(DICTIONARY, 'prompt', x, y, w, h, 0.0, 255, 255, 255, 255)
end

AddEventHandler('onResourceStop', function(name)
    if name == RES and dui then DestroyDui(dui) end
end)
