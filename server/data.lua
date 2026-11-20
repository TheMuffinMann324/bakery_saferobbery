-- In-game editable data: global settings (each safe keeps its own rewards, see Data.cleanRewards). Starts from Config.Defaults,
-- saved to saferobbery_data once an admin saves. Every save is cleaned up here before it is stored.
Data = {}

local CATEGORIES = { cash = true, jewelry = true, watches = true, diamonds = true, gold = true, coke = true, weed = true, meth = true,
    drugs = true, valuables = true, documents = true, other = true }
local DIFFICULTY = { easy = true, medium = true, hard = true }

local function str(v, max, fallback)
    v = type(v) == 'string' and v:gsub('^%s+', ''):gsub('%s+$', '') or nil
    if not v or v == '' then return fallback end
    return v:sub(1, max)
end

local function int(v, lo, hi, fallback)
    return math.floor(Utils.clamp(Utils.finite(v, fallback), lo, hi))
end

local function bool(v, fallback)
    if type(v) == 'boolean' then return v end
    return fallback
end

local function cleanSettings(v)
    if type(v) ~= 'table' then return nil end
    local d = Config.Defaults.settings
    local jobs = {}
    for _, j in ipairs(type(v.policeJobs) == 'table' and v.policeJobs or d.policeJobs) do
        j = str(j, 32)
        if j and not Utils.contains(jobs, j) then jobs[#jobs + 1] = j end
    end
    return {
        policeRequired   = int(v.policeRequired, 0, 50, d.policeRequired),
        policeJobs       = jobs,
        alertKeypadFail  = bool(v.alertKeypadFail, d.alertKeypadFail),
        alertExplosion   = bool(v.alertExplosion, d.alertExplosion),
        alertPadlock     = int(v.alertPadlock, 0, 100, d.alertPadlock),
        safeCooldown     = int(v.safeCooldown, 0, 604800, d.safeCooldown),
        lockboxCooldown  = int(v.lockboxCooldown, 0, 604800, d.lockboxCooldown),
        playerSafeCooldown    = int(v.playerSafeCooldown or v.playerCooldown, 0, 86400, d.playerSafeCooldown),
        playerLockboxCooldown = int(v.playerLockboxCooldown or v.playerCooldown, 0, 86400, d.playerLockboxCooldown),
        keypadAttempts   = int(v.keypadAttempts, 1, 20, d.keypadAttempts),
        lockoutTime      = int(v.lockoutTime, 0, 86400, d.lockoutTime),
        randomizeCode    = bool(v.randomizeCode, d.randomizeCode),
        explosiveItem    = str(v.explosiveItem, 64, d.explosiveItem),
        fuseTime         = int(v.fuseTime, 3, 120, d.fuseTime),
        explosionDamage  = bool(v.explosionDamage, d.explosionDamage),
        explosionLoss    = int(v.explosionLoss, 0, 100, d.explosionLoss),
        breakItem        = str(v.breakItem, 64, ''),
        breakHits        = int(v.breakHits, 1, 15, d.breakHits),
        breakSkillCheck  = bool(v.breakSkillCheck, d.breakSkillCheck),
        breakDifficulty  = DIFFICULTY[v.breakDifficulty] and v.breakDifficulty or d.breakDifficulty,
        lootTime         = int(v.lootTime, 0, 15000, d.lootTime),
        interactDistance = Utils.clamp(Utils.finite(v.interactDistance, d.interactDistance), 0.8, 5.0),
    }
end

local function cleanItem(e)
    if type(e) ~= 'table' then return nil end
    local money = e.type == 'money'
    local item = str(e.item, 64, money and 'money' or nil)
    if not item then return nil end
    local lo = int(e.min, 1, 10000000, 1)
    local hi = int(e.max, 1, 10000000, lo)
    if hi < lo then lo, hi = hi, lo end
    return {
        item = item,
        label = str(e.label, 48, item),
        type = money and 'money' or 'item',
        account = money and str(e.account, 32, 'cash') or nil,
        min = lo, max = hi,
        chance = int(e.chance, 0, 100, 50),
        category = CATEGORIES[e.category] and e.category or 'other',
    }
end

-- A safe's own rewards: { minItems, maxItems, items = { entry... } }. kind caps the slots (safe 6, lockbox 3).
function Data.cleanRewards(v, kind)
    local d = Config.Defaults.rewards[kind] or Config.Defaults.rewards.safe
    if type(v) ~= 'table' then v = Utils.copy(d) end
    local cap = kind == 'lockbox' and 3 or 6
    local items = {}
    for _, e in ipairs(type(v.items) == 'table' and v.items or {}) do
        if #items >= 40 then break end
        local c = cleanItem(e)
        if c then items[#items + 1] = c end
    end
    local maxItems = int(v.maxItems, 1, cap, math.min(d.maxItems, cap))
    return {
        minItems = math.min(int(v.minItems, 0, cap, d.minItems), maxItems),
        maxItems = maxItems,
        items = items,
    }
end

-- Old installs had shared loot tables; a safe that still points at one gets a copy of it as its own rewards.
local legacyTables
function Data.legacyRewards(tableId, kind)
    if legacyTables == nil then
        local stored = DB.loadData('lootTables')
        legacyTables = type(stored) == 'table' and stored or {}
    end
    local t = Utils.find(legacyTables, tableId)
    if not t then
        local fallback = kind == 'lockbox' and 'lockbox_default' or 'safe_default'
        t = Utils.find(legacyTables, fallback)
    end
    return Data.cleanRewards(t, kind)
end

function Data.load()
    local defaults = Config.Defaults.settings
    Data.settings = cleanSettings(DB.loadData('settings') or defaults) or Utils.copy(defaults)
end

function Data.save(section, value)
    if section ~= 'settings' then return nil end
    local c = cleanSettings(value)
    if not c then return nil end
    DB.saveData(section, c)
    Data.settings = c
    return c
end

function Data.reset(section)
    return Data.save(section, Config.Defaults.settings)
end
