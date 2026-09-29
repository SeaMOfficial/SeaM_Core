local Config = SeaM.Config.Permissions
local perms = {}

local order = {}
local defs = {}
local cache = {}
local licenses = {}

do
    local resolved = {}

    local function rankOf(name, seen)
        if resolved[name] then return resolved[name] end
        seen = seen or {}
        if seen[name] then
            error(('permission group "%s" has a circular inherits chain'):format(name), 0)
        end
        seen[name] = true

        local def = defs[name]
        if not def then
            error(('permission group "%s" inherits from an undefined group'):format(name), 0)
        end

        local rank = def.inherits and (rankOf(def.inherits, seen) + 1) or 0
        resolved[name] = rank
        return rank
    end

    for _, group in ipairs(Config.Groups) do defs[group.name] = group end
    for _, group in ipairs(Config.Groups) do order[group.name] = rankOf(group.name) end
end

function perms.exists(name) return defs[name] ~= nil end

function perms.rank(name) return order[name] or -1 end

function perms.list()
    local names = SeaM.Util.keys(defs)
    table.sort(names, function(a, b) return order[a] < order[b] end)
    return names
end

function perms.identifier(source)
    return GetPlayerIdentifierByType(source, SeaM.Config.Server.RequiredIdent)
end

function perms.loadLicense(license)
    if not license then return 'user' end
    if licenses[license] then return licenses[license] end

    local row = SeaM.DB.single('SELECT permission FROM seam_permissions WHERE license = ?', { license })
    local group = (row and defs[row.permission]) and row.permission or 'user'

    licenses[license] = group
    return group
end

function perms.setLicense(license, group, grantedBy)
    if not license or not defs[group] then return false end

    licenses[license] = group

    if group == 'user' then
        SeaM.DB.execute('DELETE FROM seam_permissions WHERE license = ?', { license })
    else
        SeaM.DB.execute([[
            INSERT INTO seam_permissions (license, permission, granted_by) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE permission = VALUES(permission), granted_by = VALUES(granted_by)
        ]], { license, group, grantedBy or 'console' })
    end

    for source, ident in pairs(perms.sources()) do
        if ident == license then
            cache[source] = nil
            perms.syncPrincipals(source, group)
        end
    end

    return true
end

function perms.sources()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        local ident = perms.identifier(source)
        if ident then out[source] = ident end
    end
    return out
end

function perms.canWriteAces(command)
    return IsPrincipalAceAllowed(('resource.%s'):format(SeaM.Resource),
        ('command.%s'):format(command or 'add_ace'))
end

local function grantAces(principal, group)
    for name in pairs(defs) do
        if perms.rank(group) >= perms.rank(name) then
            ExecuteCommand(('add_ace %s seam.%s allow'):format(principal, name))
        end
    end
end

function perms.aceGroup(source)
    local best = 'user'

    for name in pairs(defs) do
        if perms.rank(name) > perms.rank(best)
            and IsPlayerAceAllowed(source, ('seam.%s'):format(name)) then
            best = name
        end
    end

    return best
end

function perms.get(source)
    if source == 0 then return 'owner' end
    if cache[source] then return cache[source] end

    local group = perms.loadLicense(perms.identifier(source))

    local player = SeaM.Manager and SeaM.Manager.get(source)
    if player and perms.rank(player.group) > perms.rank(group) then
        group = player.group
    end

    local granted = perms.aceGroup(source)
    if perms.rank(granted) > perms.rank(group) then group = granted end

    cache[source] = group
    return group
end

function perms.has(source, required)
    if source == 0 then return true end
    if required == nil or required == 'user' then return true end

    if not defs[required] then
        SeaM.Log.warn('perms', ('check against undefined group "%s"'):format(required))
        return false
    end

    if perms.rank(perms.get(source)) >= perms.rank(required) then return true end

    return IsPlayerAceAllowed(source, ('seam.%s'):format(required))
end

function perms.syncPrincipals(source, group)
    if not Config.SyncAcePrincipals then return end
    if not perms.canWriteAces('add_principal') then return end

    local ident = perms.identifier(source)
    if not ident then return end

    for name in pairs(defs) do
        ExecuteCommand(('remove_principal identifier.%s group.seam.%s'):format(ident, name))
    end
    ExecuteCommand(('add_principal identifier.%s group.seam.%s'):format(ident, group))
end

function perms.set(source, group, grantedBy)
    if not defs[group] then return false end

    local license = perms.identifier(source)
    if not license then return false end

    perms.setLicense(license, group, grantedBy)
    cache[source] = group

    local player = SeaM.Manager and SeaM.Manager.get(source)
    if player then
        player.group = group
        player:markDirty('permission_group')
        player:sync()
    end

    perms.syncPrincipals(source, group)

    SeaM.Log.audit('admin', 'Group changed',
        ('`%s` (%s) is now **%s**'):format(GetPlayerName(source) or '?', source, group))
    return true
end

function perms.clear(source) cache[source] = nil end

AddEventHandler('playerDropped', function()
    perms.clear(source)
end)

AddEventHandler(SeaM.event('player:loaded'), function(source)
    perms.clear(source)

    local group = perms.get(source)
    perms.syncPrincipals(source, group)

    local player = SeaM.Manager and SeaM.Manager.get(source)
    if player and player.group ~= group then
        player.group = group
        player:sync()
    end
end)

CreateThread(function()
    local mapping = Config.AceGroups

    if not Config.MapAceGroups or type(mapping) ~= 'table' or not next(mapping) then return end

    if not perms.canWriteAces('add_ace') then
        SeaM.Log.warn('perms',
            ('cannot read your ace groups. Add this to server.cfg: add_ace resource.%s command.add_ace allow')
                :format(SeaM.Resource))
        return
    end

    local mapped = 0

    for ace, group in pairs(mapping) do
        if defs[group] then
            grantAces(ace, group)
            mapped = mapped + 1
        else
            SeaM.Log.warn('perms',
                ('AceGroups maps %s to "%s", which is not a defined group'):format(ace, group))
        end
    end

    for name in pairs(defs) do
        grantAces(('group.seam.%s'):format(name), name)
    end

    if mapped > 0 then
        SeaM.Log.info('perms', ('%d ace group(s) mapped onto SeaM groups'):format(mapped))
    end
end)

SeaM.provide('Perms', perms)
