local Config = SeaM.Config
local Util   = SeaM.Util

local characters = {}

local function generateCitizenId()
    for _ = 1, 12 do
        local candidate = ('SEAM-%s'):format(Util.randomString(6))
        local taken = SeaM.DB.scalar('SELECT 1 FROM seam_players WHERE citizenid = ?', { candidate })
        if not taken then return candidate end
    end

    return ('SEAM-%s%s'):format(Util.randomString(4), os.time() % 10000)
end

local function licenseOf(source)
    return GetPlayerIdentifierByType(source, Config.Server.RequiredIdent)
end

function characters.list(license)
    local rows = SeaM.DB.query([[
        SELECT citizenid, slot, name, charinfo, job, gang, playtime, last_seen
        FROM seam_players WHERE license = ? ORDER BY slot ASC
    ]], { license })

    local out = {}
    for i = 1, #rows do
        local row = rows[i]
        local charinfo = json.decode(row.charinfo or '{}') or {}
        local job = json.decode(row.job or '{}') or {}
        local jobDef = SeaM.Jobs[job.name or ''] or {}

        out[i] = {
            citizenid = row.citizenid,
            slot      = row.slot,
            name      = row.name,
            firstname = charinfo.firstname,
            lastname  = charinfo.lastname,
            dob       = charinfo.dob,
            gender    = charinfo.gender,
            jobLabel  = jobDef.label or 'Civilian',
            playtime  = row.playtime,
            lastSeen  = row.last_seen,
        }
    end
    return out
end

function characters.create(source, slot, data)
    local license = licenseOf(source)
    if not license then return nil, 'no_identifier' end

    slot = math.floor(tonumber(slot) or 0)
    if slot < 1 or slot > Config.Server.MaxCharacters then return nil, 'invalid_slot' end

    local firstname = Util.sanitize(data and data.firstname, 24)
    local lastname  = Util.sanitize(data and data.lastname, 24)
    if not firstname or not lastname then return nil, 'invalid_name' end

    local used = SeaM.DB.scalar('SELECT COUNT(*) FROM seam_players WHERE license = ?', { license }) or 0
    if used >= Config.Server.MaxCharacters then return nil, 'limit_reached' end

    local occupied = SeaM.DB.scalar(
        'SELECT 1 FROM seam_players WHERE license = ? AND slot = ?', { license, slot })
    if occupied then return nil, 'slot_taken' end

    local charinfo = {
        firstname   = firstname,
        lastname    = lastname,
        dob         = Util.sanitize(data and data.dob, 10) or '1990-01-01',
        gender      = (data and data.gender == 1) and 1 or 0,
        nationality = Util.sanitize(data and data.nationality, 32) or 'Unknown',
        phone       = tostring(math.random(1000000, 9999999)),
    }

    local ctx = { source = source, license = license, slot = slot, charinfo = charinfo }
    local allowed, reason = SeaM.Hooks.run('character:create', ctx)
    if not allowed then return nil, reason or 'cancelled by hook' end

    local citizenid = generateCitizenId()

    SeaM.DB.insert([[
        INSERT INTO seam_players (citizenid, license, slot, name, charinfo, money, job, gang, metadata, position)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid, license, slot,
        ('%s %s'):format(ctx.charinfo.firstname, ctx.charinfo.lastname),
        json.encode(ctx.charinfo),
        json.encode(SeaM.AccountDefaults),
        json.encode(Config.Defaults.Job),
        json.encode(Config.Defaults.Gang),
        json.encode(Config.Defaults.Metadata),
        json.encode(Config.Defaults.Spawn),
    })

    SeaM.Log.audit('join', 'Character created',
        ('`%s` created **%s %s** (`%s`) in slot %d'):format(
            GetPlayerName(source) or '?', ctx.charinfo.firstname, ctx.charinfo.lastname, citizenid, slot))

    return { citizenid = citizenid, slot = slot, charinfo = ctx.charinfo }
end

function characters.delete(source, citizenid)
    local license = licenseOf(source)
    if not license then return false, 'no_identifier' end

    local owned = SeaM.DB.scalar(
        'SELECT 1 FROM seam_players WHERE citizenid = ? AND license = ?', { citizenid, license })
    if not owned then return false, 'not_found' end

    local allowed, reason = SeaM.Hooks.run('character:delete', {
        source = source, citizenid = citizenid, license = license,
    })
    if not allowed then return false, reason or 'cancelled by hook' end

    local active = SeaM.Manager.getByCitizenId(citizenid)
    if active then SeaM.Manager.logout(active.source, true) end

    SeaM.DB.execute('DELETE FROM seam_players WHERE citizenid = ? AND license = ?', { citizenid, license })

    SeaM.Log.audit('join', 'Character deleted',
        ('`%s` deleted `%s`'):format(GetPlayerName(source) or '?', citizenid))
    return true
end

SeaM.Callbacks.register('characters:list', function(source)
    local license = licenseOf(source)
    if not license then return {} end
    return characters.list(license), Config.Server.MaxCharacters
end)

SeaM.Callbacks.register('characters:create', function(source, slot, data)
    local character, err = characters.create(source, slot, data)
    if not character then return false, err end
    return true, character
end)

SeaM.Callbacks.register('characters:select', function(source, citizenid)
    if type(citizenid) ~= 'string' then return false, 'invalid_request' end

    local license = licenseOf(source)
    local owned = license and SeaM.DB.scalar(
        'SELECT 1 FROM seam_players WHERE citizenid = ? AND license = ?', { citizenid, license })

    if not owned then
        SeaM.RateLimit.flag(source, 'character select spoof')
        return false, 'not_found'
    end

    local player, err = SeaM.Manager.login(source, citizenid)
    if not player then return false, err end
    return true, player:snapshot()
end)

SeaM.Callbacks.register('characters:delete', function(source, citizenid)
    if type(citizenid) ~= 'string' then return false, 'invalid_request' end
    return characters.delete(source, citizenid)
end)

SeaM.provide('Characters', characters)
