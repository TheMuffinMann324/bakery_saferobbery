fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bakery_saferobbery'
author 'Bakery'
description 'Safe robbery - admin-placed safes with a working keypad, sticky-note codes, breaching charges and padlocked lockboxes'
version '1.0.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/*.html',
    'web/dist/assets/*',
}

-- Streamed props share the texture dictionary in stream/bkr_safe_props.ytd.
data_file 'DLC_ITYP_REQUEST' 'stream/bkr_safe_props.ytyp'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/props.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/nui.lua',
    'client/props.lua',
    'client/note.lua',
    'client/keypad.lua',
    'client/prompt.lua',
    'client/robbery.lua',
    'client/placement.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/db.lua',
    'server/data.lua',
    'server/safes.lua',
    'server/robbery.lua',
    'server/admin.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'kq_link',
}

escrow_ignore {
    'config.lua',
    'shared/*.lua',
    'bridge/*.lua',
}
