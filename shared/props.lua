-- Prop models and the offsets the scripts use to put the pieces together.
-- These offsets match the pivots and dimensions of the streamed models.
Props = {}

Props.Models = {
    safeBody    = 'bkr_safe_body_v2',
    safeDoor    = 'bkr_safe_door_v2',
    safeWheel   = 'bkr_safe_wheel_v2',
    lockboxBody = 'bkr_lockbox_body_v2',
    lockboxLid  = 'bkr_lockbox_lid_v2',
    padlock     = 'bkr_padlock_v2',
    note        = 'bkr_sticky_note',
}

-- Big safe (body space: origin bottom centre, +Y is the front)
-- bkr_sticky_note_1..N: copies of the note, each showing its own cell of the bks_note atlas (build_props.py NOTE_VARIANTS)
Props.NoteVariants = 15

Props.Safe = {
    size        = vector3(0.86, 0.76, 1.25),
    hinge       = vector3(0.355, 0.38, 0.0),      -- door pivot
    openAngle   = -105.0,                          -- door heading relative to the body when open
    blastAngle  = -128.0,                          -- blown doors swing further
    wheel       = vector3(-0.35, 0.038, 0.52),     -- wheel, door space
    charge      = vector3(-0.56, 0.030, 1.00),     -- breaching charge: x / z centre on the door panel, y = the panel's front face
    -- Planting (Config.Anims.plant): the scene's origin is where the hand puts the charge, so the scene is placed
    -- on the charge itself. Measured in game from the heist thermal_charge clip, door space, ped facing the door:
    plant = {
        handX = vector3(-0.993, -0.078, -0.085),   -- right hand prop bone (28422) axes while it holds the charge on
        handY = vector3(-0.087, 0.022, 0.996),     -- the door (2.45 s to 6.1 s into the clip)
        grip  = 0.015,                             -- the hand sits this far out from the charge centre
        start = vector3(0.39, 0.82, 0.0),          -- where the clip starts the player, from the scene origin
        -- the clip puts the player's feet 1.0 m below the scene origin: charge.z = 1.0 keeps them on the floor
    },
    keypad      = vector3(-0.35, 0.030, 0.86),     -- back centre of the keypad housing, door space
    keypadDepth = 0.022,                           -- housing + buttons, so the front of a button is keypad.y + this
    front       = vector3(0.0, 0.95, 0.0),         -- where a player stands to use it
    prompt      = vector3(0.08, 0.46, 0.88),
    doorSwing   = 0.78,                            -- door length: the room needed in front to open it
    -- loot slots on the floor and the shelf (bottom centre of each), in the front half where they're easy to
    -- grab. slotSize = the room a slot has (w, d, h)
    slotSize = vector3(0.22, 0.30, 0.40),
    slots = {
        vector3(-0.20, 0.08, 0.15), vector3(0.0, 0.08, 0.15), vector3(0.20, 0.08, 0.15),
        vector3(-0.20, 0.08, 0.64), vector3(0.0, 0.08, 0.64), vector3(0.20, 0.08, 0.64),
    },
    -- Filler props in the back half so an open safe looks full. Never looted, always there. at = where the
    -- bottom centre of the prop goes (body space; floor z 0.15, shelf z 0.64), rot = degrees (x, y, z = turn).
    -- Sizes checked in game so nothing pokes through the walls or the shelf.
    decor = {
        { model = 'hei_prop_hei_security_case', at = vector3(-0.11, -0.225, 0.15),  rot = vector3(0.0, 0.0, 0.0) },
        { model = 'w_pi_vintage_pistol',        at = vector3(-0.12, -0.205, 0.559), rot = vector3(90.0, 0.0, 8.0) },
        { model = 'prop_poly_bag_money',        at = vector3(0.235, -0.17, 0.15),   rot = vector3(0.0, 0.0, 90.0) },
        { model = 'prop_folder_01',             at = vector3(-0.18, -0.235, 0.64),  rot = vector3(0.0, 0.0, 0.0) },
        { model = 'prop_cash_envelope_01',      at = vector3(0.0, -0.20, 0.64),     rot = vector3(90.0, 0.0, -10.0) },
        { model = 'tr_prop_tr_car_keys_01a',    at = vector3(0.01, -0.20, 0.668),   rot = vector3(0.0, 0.0, 35.0) },
        { model = 'sf_prop_sf_box_cigar_01a',   at = vector3(0.17, -0.18, 0.64),    rot = vector3(0.0, 0.0, 0.0) },
        { model = 'ch_prop_gold_bar_01a',       at = vector3(0.125, -0.18, 0.799),  rot = vector3(0.0, 0.0, 0.0) },
        { model = 'ch_prop_gold_bar_01a',       at = vector3(0.215, -0.18, 0.799),  rot = vector3(0.0, 0.0, 0.0) },
        { model = 'ch_prop_gold_bar_01a',       at = vector3(0.17, -0.18, 0.844),   rot = vector3(0.0, 0.0, 0.0) },
    },
}

-- Keypad layout, door space offsets from Props.Safe.keypad. x: + is the viewer's left.
Props.Keypad = {
    cols   = { 0.036, 0.0, -0.036 },
    rows   = { 0.030, -0.002, -0.034, -0.066 },
    labels = { { '1', '2', '3' }, { '4', '5', '6' }, { '7', '8', '9' }, { 'C', '0', 'OK' } },
    button = { w = 0.030, h = 0.026 },
    lcd    = { z = 0.064, w = 0.100, h = 0.024 },
    width  = 0.13, height = 0.18,
}

-- Lockbox (body space: origin bottom centre, +Y is the front)
Props.Lockbox = {
    size      = vector3(0.44, 0.28, 0.17),
    hinge     = vector3(0.0, -0.142, 0.17),       -- lid pivot
    openAngle = 105.0,                             -- lid pitch when open
    padlock   = vector3(0.0, 0.159, 0.128),
    front     = vector3(0.0, 0.70, 0.0),
    prompt    = vector3(0.04, 0.16, 0.13),
    doorSwing = 0.30,
    slotSize  = vector3(0.13, 0.23, 0.14),
    slots = { vector3(-0.12, 0.0, 0.012), vector3(0.0, 0.0, 0.012), vector3(0.12, 0.0, 0.012) },
}

function Props.def(kind)
    return kind == 'lockbox' and Props.Lockbox or Props.Safe
end
