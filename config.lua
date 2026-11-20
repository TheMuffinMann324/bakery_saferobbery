Config = {}

-- Almost everything (safes, codes, sticky notes, loot, cooldowns, police, items) is set up in-game:
-- /saferobbery opens the admin panel. This file holds what needs a restart, plus the factory defaults
-- that the panel's "Defaults" button restores.

-- ============================================================
-- Debug
-- ============================================================
Config.Debug = false

-- ============================================================
-- Admins
-- ============================================================
-- Anyone with this ace, or a license listed below, can open the admin panel.
-- server.cfg:  add_ace group.admin bakery_saferobbery.admin allow
Config.Admin = {
    Ace = 'bakery_saferobbery.admin',
    Command = 'saferobbery',          -- chat command that opens the admin panel
    Licenses = {},
}

-- ============================================================
-- World
-- ============================================================
-- Safes are spawned on each client (not networked) when a player gets this close, and removed past it + 10 m.
Config.StreamDistance = 60.0

-- Breaching charge prop stuck on the door while the fuse runs (and in the planter's hand).
Config.ChargeModel = 'prop_c4_final_green'
Config.ChargeBeep = { name = 'IDLE_BEEP', set = 'EPSILONISM_04_SOUNDSET' }

-- Hand prop while breaking a padlock.
Config.CrowbarModel = 'w_me_crowbar'

-- Props shown inside an open safe / lockbox for each reward category (names from forge.plebmasters.de/objects).
-- Only models that exist in the game AND fit the slot are used; when a category has several, each reward picks
-- a different one so two jewelry rewards don't look the same. Newer DLC models are listed last.
-- stack = how many copies are piled up in one slot.
-- Reward categories whose props vanish one by one as they're grabbed. The others stay where they are
-- (the reward is still paid, they're just not taken out of the safe).
Config.LootDespawn = { cash = true, diamonds = true, coke = true, weed = true, meth = true, drugs = true }

Config.LootProps = {
    cash      = { stack = 2, models = { 'ex_cash_pile_01', 'ex_cash_pile_02', 'ex_cash_pile_004', 'ex_cash_pile_005', 'ex_cash_pile_006', 'ex_cash_pile_07',
                                        'bkr_prop_bkr_cashpile_01', 'bkr_prop_bkr_cashpile_02', 'bkr_prop_bkr_cashpile_04', 'hei_prop_heist_cash_pile',
                                        'prop_anim_cash_pile_01', 'prop_anim_cash_pile_02', 'sf_prop_sf_cash_pile_01', 'prop_cash_pile_01', 'prop_cash_pile_02' } },
    jewelry   = { stack = 1, models = { 'ex_office_swag_jewelwatch', 'ex_office_swag_jewelwatch2', 'sf_prop_sf_jewel_01a', 'h4_prop_h4_necklace_01a',
                                        'sf_prop_sf_necklace_01a', 'tr_prop_tr_dd_necklace_01a', 'prop_jewel_02a', 'prop_jewel_02b', 'prop_jewel_04a', 'p_jewel_necklace_02' } },
    watches   = { stack = 1, models = { 'ex_office_swag_jewelwatch3', 'sf_prop_sf_watch_01a', 'p_watch_01', 'p_watch_02', 'p_watch_03', 'p_watch_04', 'p_watch_05', 'p_watch_06' } },
    diamonds  = { stack = 1, models = { 'ch_prop_casino_diamonds_01a', 'ch_prop_casino_diamonds_02a', 'ch_prop_casino_diamonds_03a', 'ch_prop_vault_dimaondbox_01a', 'h4_prop_h4_diamond_01a' } },
    gold      = { stack = 3, models = { 'ch_prop_gold_bar_01a', 'hei_prop_heist_gold_bar', 'prop_gold_bar' } },
    coke      = { stack = 2, models = { 'ba_prop_battle_coke_block_01a', 'bkr_prop_coke_box_01a', 'prop_coke_block_01' } },
    weed      = { stack = 2, models = { 'hei_prop_heist_weed_block_01b', 'prop_weed_block_01', 'xm3_prop_xm3_bag_weed_01a', 'm25_1_prop_m51_bag_weed_01a' } },
    meth      = { stack = 2, models = { 'tr_prop_meth_smallbag_01a', 'prop_meth_bag_01', 'bkr_prop_meth_openbag_02' } },
    drugs     = { stack = 2, models = { 'prop_drug_package', 'prop_drug_package_02', 'ba_prop_battle_drug_package_02', 'xm3_prop_xm3_drug_pkg_01a', 'prop_mp_drug_package' } },
    valuables = { stack = 1, models = { 'ch_prop_vault_dimaondbox_01a', 'v_res_jewelbox', 'ex_office_swag_jewelwatch2' } },
    documents = { stack = 2, models = { 'prop_cd_folder_pile1', 'p_amb_clipboard_01' } },
    other     = { stack = 1, models = { 'prop_cs_package_01', 'prop_drug_package_02' } },
}

-- Animations. dict / clip pairs, change them if your server has its own.
Config.Anims = {
    keypad   = { dict = 'anim@heists@keypad@', enter = 'enter', loop = 'idle_a', exit = 'exit' },
    -- heist breaching scene: the player swings the bag round, takes the charge out and sticks it on the door
    plant    = { dict = 'anim@heists@ornate_bank@thermal_charge', clip = 'thermal_charge', bagClip = 'bag_thermal_charge',
                 bag = 'hei_p_m_bag_var22_arm_s', grabAt = 1400, stickAt = 5300, length = 6200 },
    padlock  = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
    loot     = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'grab' },
}

-- ============================================================
-- Factory defaults (edited in-game, these are only the starting values)
-- ============================================================
Config.Defaults = {}

Config.Defaults.settings = {
    -- police
    policeRequired   = 0,                       -- on-duty police needed to start any robbery
    policeJobs       = { 'police', 'sheriff' },
    alertKeypadFail  = true,                    -- alert police when the keypad locks out
    alertExplosion   = true,                    -- alert police when a charge goes off
    alertPadlock     = 35,                      -- % chance police get an alert when a padlock is broken

    -- cooldowns (seconds). Big safes and lockboxes are tracked separately.
    safeCooldown          = 3600,               -- a big safe stays open and empty this long, then relocks
    lockboxCooldown       = 1800,               -- same for lockboxes
    playerSafeCooldown    = 600,                -- after robbing a safe, a player waits this long before the next safe
    playerLockboxCooldown = 180,                -- after a lockbox, the wait before the next lockbox

    -- keypad
    keypadAttempts   = 3,                       -- wrong codes before the keypad locks out
    lockoutTime      = 300,                     -- seconds the keypad stays locked
    randomizeCode    = true,                    -- every reset picks a new code (the sticky note follows it)

    -- breaching charge
    explosiveItem    = 'safe_charge',
    fuseTime         = 10,                      -- seconds from planting to the blast
    explosionDamage  = true,                    -- the blast hurts anyone standing too close
    explosionLoss    = 25,                      -- % of the contents destroyed by the blast

    -- lockbox
    breakItem        = 'weapon_crowbar',        -- needed to break a padlock ('' = bare hands)
    breakHits        = 3,                       -- good hits needed to snap the padlock
    breakSkillCheck  = true,                    -- every hit is an ox_lib skill check
    breakDifficulty  = 'medium',                -- easy / medium / hard

    -- looting
    lootTime         = 1200,                    -- ms to grab one item
    interactDistance = 1.6,
}

-- Rewards a NEW safe / lockbox starts with. Every safe keeps its own list after that, edited in its page of
-- the admin panel (Duplicate copies them to another spot). Every entry rolls its chance on its own; at least
-- minItems and at most maxItems end up inside (a safe has room for 6, a lockbox for 3).
-- type 'money' pays into `account` instead of giving an item. category picks the props (Config.LootProps).
Config.Defaults.rewards = {
    safe = {
        minItems = 3, maxItems = 6,
        items = {
            { item = 'money',        label = 'Cash',            type = 'money', account = 'cash', min = 4000, max = 12000, chance = 100, category = 'cash' },
            { item = 'markedbills',  label = 'Marked bills',    type = 'item', min = 1, max = 3, chance = 45, category = 'cash' },
            { item = 'goldbar',      label = 'Gold bar',        type = 'item', min = 1, max = 2, chance = 30, category = 'gold' },
            { item = 'rolex',        label = 'Rolex',           type = 'item', min = 1, max = 3, chance = 55, category = 'watches' },
            { item = 'diamond_ring', label = 'Diamond ring',    type = 'item', min = 1, max = 2, chance = 40, category = 'diamonds' },
            { item = 'goldchain',    label = 'Gold chain',      type = 'item', min = 1, max = 4, chance = 50, category = 'jewelry' },
            { item = 'coke_brick',   label = 'Brick of coke',   type = 'item', min = 1, max = 2, chance = 20, category = 'coke' },
            { item = 'weed_brick',   label = 'Brick of weed',   type = 'item', min = 1, max = 3, chance = 25, category = 'weed' },
        },
    },
    lockbox = {
        minItems = 1, maxItems = 3,
        items = {
            { item = 'money',        label = 'Cash',            type = 'money', account = 'cash', min = 500, max = 2500, chance = 85, category = 'cash' },
            { item = 'rolex',        label = 'Rolex',           type = 'item', min = 1, max = 1, chance = 25, category = 'watches' },
            { item = 'goldchain',    label = 'Gold chain',      type = 'item', min = 1, max = 2, chance = 35, category = 'jewelry' },
            { item = 'weed_baggy',   label = 'Bag of weed',     type = 'item', min = 2, max = 6, chance = 40, category = 'weed' },
            { item = 'meth_baggy',   label = 'Bag of meth',     type = 'item', min = 1, max = 4, chance = 20, category = 'meth' },
        },
    },
}
