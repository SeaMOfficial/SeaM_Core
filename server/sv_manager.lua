local Config = SeaM.Config
local PlayerClass = SeaM.PlayerClass

local manager = {}

local players    = {}
local byCitizen  = {}
local licenses   = {}
local sessions   = {}

function manager.get(source)
    return players[tonumber(source) or 0]
end

function manager.getByCitizenId(citizenid)
    local src = byCitizen[citizenid]
    return src and players[src] or nil
end

function manager.getByLicense(license)
    for _, player in pairs(players) do
        if player.license == license then return player end
    end
end

function manager.all() return players end

function manager.count() return SeaM.Util.count(players) end

function manager.getByJob(job, onDutyOnly)
    local out = {}
    for _, player in pairs(players) do
        if player.job.name == job and (not onDutyOnly or player.job.onDuty) then
            out[#out + 1] = player
        end
    end
    return out
end

function manager.getByGang(gang)
    local out = {}
    for _, player in pairs(players) do
        if player.gang.name == gang then out[#out + 1] = player end
    end
    return out
end

function manager.identifiers(source)
    local out = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        local kind, value = ident:match('^([^:]+):(.+)$')
        if kind then out[kind] = value end
    end
    return out
end

function manager.findBan(idents)
    local ban = SeaM.DB.single([[
        SELECT reason, expires, banned_by FROM seam_bans
        WHERE (license = ? OR discord = ? OR ip = ?)
          AND (expires IS NULL OR expires > ?)
        ORDER BY expires IS NULL DESC, expires DESC LIMIT 1
    ]], { idents.license or '-', idents.discord or '-', idents.ip or '-', os.time() })
    return ban
end

function manager.ban(source, reason, duration, bannedBy)
    local idents = manager.identifiers(source)
    local player = manager.get(source)
    local expires = (duration and duration > 0) and (os.time() + duration) or nil

    SeaM.DB.insert(
        'INSERT INTO seam_bans (license, discord, ip, citizenid, reason, expires, banned_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            idents.license, idents.discord, idents.ip,
            player and player.citizenid or nil,
            (reason or 'No reason provided'):sub(1, 255),
            expires, bannedBy or 'console',
        })

    SeaM.Log.audit('admin', 'Player banned',
        ('`%s` (%s) banned by **%s** for `%s` (%s)'):format(
            GetPlayerName(source) or '?', source, bannedBy or 'console', reason or 'no reason',
            expires and os.date('%Y-%m-%d %H:%M', expires) or 'permanent'), 'warn')

    DropPlayer(source, expires
        and SeaM.t('connect.banned', reason, os.date('%Y-%m-%d %H:%M', expires))
        or SeaM.t('connect.banned_perm', reason))
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    local useDeferrals = Config.Server.UseDeferrals and deferrals

    if useDeferrals then
        deferrals.defer()
        Wait(0)
        deferrals.update(SeaM.t('connect.checking'))
    end

    local idents = manager.identifiers(src)
    local required = Config.Server.RequiredIdent

    if not idents[required] then
        local msg = SeaM.t('connect.no_identifier', required)
        if useDeferrals then deferrals.done(msg) else DropPlayer(src, msg) end
        return
    end

    if not SeaM.DB.ready then
        local msg = SeaM.t('connect.db_offline')
        if useDeferrals then deferrals.done(msg) else DropPlayer(src, msg) end
        return
    end

    if Config.Server.WhitelistOnly and not IsPlayerAceAllowed(src, 'seam.join') then
        local msg = SeaM.t('connect.not_whitelisted')
        if useDeferrals then deferrals.done(msg) else DropPlayer(src, msg) end
        return
    end

    local ban = manager.findBan(idents)
    if ban then
        local msg = ban.expires
            and SeaM.t('connect.banned', ban.reason, os.date('%Y-%m-%d %H:%M', ban.expires))
            or SeaM.t('connect.banned_perm', ban.reason)
        if useDeferrals then deferrals.done(msg) else DropPlayer(src, msg) end
        return
    end

    licenses[src] = idents[required]

    if idents.discord then
        SeaM.DB.enqueue(('discord:%s'):format(idents[required]),
            'UPDATE seam_players SET discord = ? WHERE license = ?',
            { idents.discord, idents[required] })
    end

    if useDeferrals then deferrals.done() end
end)

function manager.login(source, citizenid)
    if players[source] then return nil, 'already_loaded' end

    local license = licenses[source] or GetPlayerIdentifierByType(source, Config.Server.RequiredIdent)
    if not license then return nil, 'no_identifier' end

    local row = SeaM.DB.single(
        'SELECT * FROM seam_players WHERE citizenid = ? AND license = ?',
        { citizenid, license })

    if not row then return nil, 'not_found' end

    local existing = byCitizen[citizenid]
    if existing and existing ~= source and GetPlayerName(existing) then
        DropPlayer(existing, 'Your character was loaded from another connection.')
    end

    local player = PlayerClass(row, source)

    local allowed, reason = SeaM.Hooks.run('player:load', { player = player, source = source })
    if not allowed then return nil, reason or 'cancelled by hook' end

    if not player.metadata.fingerprint then
        player:setMeta('fingerprint', ('%s%s')
            :format(SeaM.Util.randomString(4), math.random(10000, 99999)))
    end

    players[source] = player
    byCitizen[citizenid] = source
    player.loaded = true

    SeaM.Perms.clear(source)
    player:sync()

    sessions[source] = SeaM.DB.insert(
        'INSERT INTO seam_sessions (citizenid, endpoint) VALUES (?, ?)',
        { citizenid, GetPlayerEndpoint(source) })

    TriggerEvent(SeaM.event('player:loaded'), source, player)
    TriggerClientEvent(SeaM.event('player:loaded'), source, player:snapshot())

    SeaM.Log.audit('join', 'Character loaded',
        ('`%s` loaded **%s** (`%s`)'):format(GetPlayerName(source) or '?', player.name, citizenid))

    return player
end

function manager.logout(source, silent)
    local player = players[source]
    if not player then return false end

    SeaM.Hooks.run('player:logout', { player = player, source = source })

    player:save(true)
    manager.closeSession(source, player)

    players[source] = nil
    byCitizen[player.citizenid] = nil
    SeaM.Perms.clear(source)

    local entity = Player(source)
    if entity and entity.state then entity.state:set('seam', nil, true) end

    TriggerEvent(SeaM.event('player:unloaded'), source, player.citizenid)
    if not silent then TriggerClientEvent(SeaM.event('player:unloaded'), source) end
    return true
end

function manager.closeSession(source, player)
    local id = sessions[source]
    if not id then return end

    SeaM.DB.enqueue(('session:%s'):format(id),
        'UPDATE seam_sessions SET left_at = CURRENT_TIMESTAMP, duration = ? WHERE id = ?',
        { os.time() - player.sessionStart, id })

    sessions[source] = nil
end

AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = players[src]

    licenses[src] = nil
    if not player then return end

    if Config.Persistence.SaveOnDrop then player:save(true) end
    manager.closeSession(src, player)

    players[src] = nil
    byCitizen[player.citizenid] = nil
    sessions[src] = nil

    TriggerEvent(SeaM.event('player:dropped'), src, player.citizenid, reason)
    SeaM.Log.debug('manager', ('%s (%s) dropped: %s'):format(player.name, src, reason))
end)

function manager.saveAll(immediate)
    local count = 0
    for _, player in pairs(players) do
        player:save(immediate)
        count = count + 1
    end
    return count
end

SeaM.onReady(function()
    CreateThread(function()
        local interval = Config.Persistence.AutosaveInterval * 1000
        while true do
            Wait(interval)
            local count = manager.saveAll(false)
            if count > 0 then SeaM.Log.debug('manager', ('autosaved %d character(s)'):format(count)) end
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= SeaM.Resource then return end

    for src, player in pairs(players) do
        player:save(true)
        manager.closeSession(src, player)
    end
    SeaM.Log.info('manager', 'saved all characters on shutdown')
end)

SeaM.provide('Manager', manager)
