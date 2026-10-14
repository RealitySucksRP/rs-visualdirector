fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealitySucksRP'
description 'RS Visual Director v2.6.0 - open-source cinematic world mood director with framework bridge'
version '2.6.0'

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
