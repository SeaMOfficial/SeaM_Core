fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'SeaM_Core'
author 'SeaM'
description ''
version '1.0.0'

shared_scripts {
    'shared/init.lua',
    'shared/class.lua',
    'shared/util.lua',
    'shared/schema.lua',
    'shared/logger.lua',
    'shared/locale.lua',
    'locales/*.lua',
    'config/config.lua',
    'config/jobs.lua',
    'config/gangs.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_boot.lua',
    'server/sv_db.lua',
    'server/sv_hooks.lua',
    'server/sv_ratelimit.lua',
    'server/sv_callbacks.lua',
    'server/sv_permissions.lua',
    'server/sv_ledger.lua',
    'server/sv_player.lua',
    'server/sv_manager.lua',
    'server/sv_characters.lua',
    'server/sv_commands.lua',
    'server/sv_api.lua',
    'server/sv_admin.lua',
}

client_scripts {
    'client/cl_boot.lua',
    'client/cl_callbacks.lua',
    'client/cl_notify.lua',
    'client/cl_points.lua',
    'client/cl_progress.lua',
    'client/cl_admin.lua',
    'client/cl_player.lua',
    'client/cl_api.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    -- Loaded by other resources with '@SeaM_Core/shared/progress.lua', so it
    -- has to be shipped to clients even though the core itself does not run it.
    'shared/progress.lua',
}

dependencies {
    '/server:7290',
    '/onesync',
    'oxmysql',
}
