local Config = SeaM.Config.Admin
local Commands = SeaM.Commands
local Manager = SeaM.Manager
local Perms = SeaM.Perms

local function actor(source)
    if source == 0 then return 'console' end
    return ('%s (%s)'):format(GetPlayerName(source) or '?', source)
end

local function record(source, title, detail, level)
    if not Config.LogActions then return end
    SeaM.Log.audit('admin', title, ('**%s** %s'):format(actor(source), detail), level or 'info')
end

local function tell(source, message, kind)
    if source == 0 then
        print(('[SeaM] %s'):format(message))
        return
    end
    TriggerClientEvent(SeaM.event('notify'), source, message, kind or 'inform')
end

local function outranks(source, target)
    if source == 0 then return true end
    if source == target then return true end
    return Perms.rank(Perms.get(source)) > Perms.rank(Perms.get(target))
end

local function requireOutranks(source, target)
    if outranks(source, target) then return true end
    tell(source, 'They outrank you.', 'error')
    return false
end

Commands.register('tp', {
    help = 'Teleport to a player, or to coordinates',
    permission = 'admin',
    params = {
        { name = 'where', type = 'text', help = 'Server id, or: x y z' },
    },
    handler = function(source, args)
        if source == 0 then return tell(source, 'That has to come from a player.') end

        local parts = SeaM.Util.split(args.where, ' ')

        if #parts == 1 then
            local target = tonumber(parts[1])
            if not target or not GetPlayerName(target) then
                return tell(source, 'No player with that server id.', 'error')
            end

            local coords = GetEntityCoords(GetPlayerPed(target))
            TriggerClientEvent(SeaM.event('admin:teleport'), source, coords)
            record(source, 'Teleport', ('went to `%s`'):format(GetPlayerName(target)))
            return
        end

        if #parts < 3 then return tell(source, 'Give a server id, or x y z.', 'error') end

        local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
        if not x or not y or not z then
            return tell(source, 'Those are not valid coordinates.', 'error')
        end

        TriggerClientEvent(SeaM.event('admin:teleport'), source, vector3(x, y, z))
        record(source, 'Teleport', ('went to `%.1f, %.1f, %.1f`'):format(x, y, z))
    end,
})

Commands.register('tpm', {
    help = 'Teleport to your map marker',
    permission = 'admin',
    handler = function(source)
        if source == 0 then return tell(source, 'That has to come from a player.') end
        TriggerClientEvent(SeaM.event('admin:teleportMarker'), source)
    end,
})

Commands.register('bring', {
    help = 'Bring a player to you',
    permission = 'admin',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
    },
    handler = function(source, args)
        if source == 0 then return tell(source, 'That has to come from a player.') end
        if not requireOutranks(source, args.target) then return end

        local coords = GetEntityCoords(GetPlayerPed(source))
        TriggerClientEvent(SeaM.event('admin:teleport'), args.target, coords)

        tell(args.target, 'You have been moved by staff.', 'warning')
        record(source, 'Bring', ('brought `%s`'):format(GetPlayerName(args.target) or args.target))
    end,
})

Commands.register('goto', {
    help = 'Teleport to a player',
    permission = 'admin',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
    },
    handler = function(source, args)
        if source == 0 then return tell(source, 'That has to come from a player.') end

        local coords = GetEntityCoords(GetPlayerPed(args.target))
        TriggerClientEvent(SeaM.event('admin:teleport'), source, coords)
        record(source, 'Goto', ('went to `%s`'):format(GetPlayerName(args.target) or args.target))
    end,
})

Commands.register('coords', {
    help = 'Show your current position',
    permission = 'admin',
    handler = function(source)
        if source == 0 then return tell(source, 'That has to come from a player.') end
        TriggerClientEvent(SeaM.event('admin:coords'), source)
    end,
})

local toggles = {
    noclip    = { event = 'admin:noclip',    label = 'Noclip' },
    invisible = { event = 'admin:invisible', label = 'Invisibility' },
    god       = { event = 'admin:god',       label = 'God mode' },
}

for name, toggle in pairs(toggles) do
    Commands.register(name, {
        help = ('Toggle %s'):format(toggle.label:lower()),
        permission = 'admin',
        handler = function(source)
            if source == 0 then return tell(source, 'That has to come from a player.') end
            TriggerClientEvent(SeaM.event(toggle.event), source)
            record(source, toggle.label, 'toggled it')
        end,
    })
end

Commands.register('freeze', {
    help = 'Freeze or unfreeze a player',
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
    },
    handler = function(source, args)
        if not requireOutranks(source, args.target) then return end

        TriggerClientEvent(SeaM.event('admin:freeze'), args.target)
        record(source, 'Freeze', ('toggled freeze on `%s`'):format(GetPlayerName(args.target) or args.target))
    end,
})

Commands.register('spectate', {
    help = 'Spectate a player, or run it again to stop',
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id', optional = true },
    },
    handler = function(source, args)
        if source == 0 then return tell(source, 'That has to come from a player.') end

        if not args.target then
            TriggerClientEvent(SeaM.event('admin:spectate'), source, nil)
            return
        end

        TriggerClientEvent(SeaM.event('admin:spectate'), source,
            args.target, GetEntityCoords(GetPlayerPed(args.target)))
        record(source, 'Spectate', ('is watching `%s`'):format(GetPlayerName(args.target) or args.target))
    end,
})

Commands.register('revive', {
    help = 'Revive a player, or yourself',
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id', optional = true },
    },
    handler = function(source, args)
        local target = args.target or source
        if target == 0 then return tell(source, 'Name a player to revive.', 'error') end

        TriggerClientEvent(SeaM.event('admin:revive'), target)

        local player = Manager.get(target)
        if player then
            player:setMeta('isDead', false)
            player:setMeta('inLastStand', false)
        end

        if target ~= source then tell(target, 'You have been revived by staff.', 'success') end
        record(source, 'Revive', ('revived `%s`'):format(GetPlayerName(target) or target))
    end,
})

Commands.register('heal', {
    help = 'Restore health and armour',
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id', optional = true },
    },
    handler = function(source, args)
        local target = args.target or source
        if target == 0 then return tell(source, 'Name a player to heal.', 'error') end

        -- SetEntityHealth has no server-side version in FiveM, so the client
        -- that owns the ped applies it.
        TriggerClientEvent(SeaM.event('admin:heal'), target)
        TriggerClientEvent(SeaM.event('admin:armour'), target, 100)

        record(source, 'Heal', ('healed `%s`'):format(GetPlayerName(target) or target))
    end,
})

Commands.register('kill', {
    help = 'Kill a player',
    permission = 'admin',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
    },
    handler = function(source, args)
        if not requireOutranks(source, args.target) then return end

        TriggerClientEvent(SeaM.event('admin:kill'), args.target)
        record(source, 'Kill', ('killed `%s`'):format(GetPlayerName(args.target) or args.target), 'warn')
    end,
})

Commands.register('car', {
    help = 'Spawn a vehicle',
    permission = 'admin',
    params = {
        { name = 'model', type = 'string', help = 'Vehicle model, e.g. sultan' },
    },
    handler = function(source, args)
        if source == 0 then return tell(source, 'That has to come from a player.') end

        TriggerClientEvent(SeaM.event('admin:spawnVehicle'), source,
            args.model, Config.ReplaceSpawnedVehicle)
        record(source, 'Vehicle', ('spawned `%s`'):format(args.model))
    end,
})

Commands.register('dv', {
    help = 'Delete the vehicle you are in or looking at',
    permission = 'admin',
    handler = function(source)
        if source == 0 then return tell(source, 'That has to come from a player.') end
        TriggerClientEvent(SeaM.event('admin:deleteVehicle'), source)
    end,
})

Commands.register('fix', {
    help = 'Repair your vehicle',
    permission = 'admin',
    handler = function(source)
        if source == 0 then return tell(source, 'That has to come from a player.') end
        TriggerClientEvent(SeaM.event('admin:fixVehicle'), source)
    end,
})

Commands.register('announce', {
    help = 'Send a message to everyone',
    permission = 'mod',
    params = {
        { name = 'message', type = 'text', help = 'What to say' },
    },
    handler = function(source, args)
        TriggerClientEvent(SeaM.event('notify'), -1, args.message, 'warning', 10000, Config.AnnounceTitle)
        record(source, 'Announcement', ('announced: %s'):format(args.message))
    end,
})

Commands.register('warn', {
    help = 'Warn a player',
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
        { name = 'reason', type = 'text',   help = 'Why' },
    },
    handler = function(source, args)
        if not requireOutranks(source, args.target) then return end

        TriggerClientEvent(SeaM.event('notify'), args.target,
            args.reason, 'error', 12000, 'Warning')

        tell(source, ('Warned %s.'):format(GetPlayerName(args.target) or args.target), 'success')
        record(source, 'Warning', ('warned `%s`: %s')
            :format(GetPlayerName(args.target) or args.target, args.reason), 'warn')
    end,
})

Commands.register('unban', {
    help = 'Lift a ban by licence or ban id',
    permission = 'admin',
    params = {
        { name = 'target', type = 'string', help = 'Licence, or the ban id' },
    },
    handler = function(source, args)
        local removed = SeaM.DB.execute(
            'DELETE FROM seam_bans WHERE license = ? OR discord = ? OR id = ?',
            { args.target, args.target, tonumber(args.target) or 0 })

        if removed < 1 then return tell(source, 'No ban matched that.', 'error') end

        tell(source, ('Lifted %d ban(s).'):format(removed), 'success')
        record(source, 'Unban', ('lifted a ban on `%s`'):format(args.target), 'warn')
    end,
})

Commands.register('perms', {
    help = "Show a player's permission group",
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
    },
    handler = function(source, args)
        tell(source, ('%s is %s.')
            :format(GetPlayerName(args.target) or args.target, Perms.get(args.target)))
    end,
})

Commands.register('addperm', {
    help = 'Grant a permission group by licence, so it follows the account',
    permission = 'owner',
    params = {
        { name = 'license', type = 'string', help = 'Licence identifier' },
        { name = 'group',   type = 'group',  help = 'Permission group' },
    },
    handler = function(source, args)
        if not Perms.setLicense(args.license, args.group, actor(source)) then
            return tell(source, 'That could not be granted.', 'error')
        end

        tell(source, ('%s is now %s.'):format(args.license, args.group), 'success')
        record(source, 'Permission granted',
            ('set `%s` to **%s**'):format(args.license, args.group), 'warn')
    end,
})

Commands.register('removeperm', {
    help = 'Take a permission group back to user',
    permission = 'owner',
    params = {
        { name = 'license', type = 'string', help = 'Licence identifier' },
    },
    handler = function(source, args)
        Perms.setLicense(args.license, 'user', actor(source))

        tell(source, ('%s is now user.'):format(args.license), 'success')
        record(source, 'Permission removed', ('reset `%s`'):format(args.license), 'warn')
    end,
})

Commands.register('myid', {
    help = 'Show your own licence identifier',
    handler = function(source)
        if source == 0 then return end
        tell(source, Perms.identifier(source) or 'unknown')
        print(('[SeaM] %s licence: %s'):format(GetPlayerName(source), Perms.identifier(source) or 'unknown'))
    end,
})
