fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealitySucksRP'
description 'RS Visual Director v2.9.0 - scrollable studio, real private live moments'
version '2.9.0'

shared_scripts {
    'config.lua',
    'bridge/shared.lua'
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua'
}

server_scripts {
    'bridge/server.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

-- Uses GTA/FiveM runtime timecycle natives. No replacement weather,
-- visualsettings, ENB, ReShade or third-party graphics files are bundled.
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/woman_phone.png',
    'html/img/neon_ring.png',
    'html/img/honeycomb_controls.png'
}
