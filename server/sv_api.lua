local Manager = SeaM.Manager
local Util    = SeaM.Util

exports('GetCoreObject', function() return SeaM end)

exports('GetPlayer', function(source) return Manager.get(source) end)
exports('GetPlayerByCitizenId', function(citizenid) return Manager.getByCitizenId(citizenid) end)
exports('GetPlayerByLicense', function(license) return Manager.getByLicense(license) end)
exports('GetPlayers', function() return Manager.all() end)
exports('GetPlayerCount', function() return Manager.count() end)
exports('GetPlayersByJob', function(job, onDutyOnly) return Manager.getByJob(job, onDutyOnly) end)
exports('GetPlayersByGang', function(gang) return Manager.getByGang(gang) end)

exports('Login', function(source, citizenid) return Manager.login(source, citizenid) end)
exports('Logout', function(source) return Manager.logout(source) end)
exports('SaveAll', function(immediate) return Manager.saveAll(immediate) end)

exports('Ban', function(source, reason, duration, bannedBy)
    return Manager.ban(source, reason, duration, bannedBy)
end)

exports('GetJobs', function() return SeaM.Jobs end)
exports('GetGangs', function() return SeaM.Gangs end)
exports('GetAccounts', function() return SeaM.Config.Accounts end)

exports('GetTransactions', function(citizenid, limit, account)
    return SeaM.Ledger.history(citizenid, limit, account)
end)
exports('GetEconomySnapshot', function(hours) return SeaM.Ledger.economy(hours) end)

exports('GetCitizenId', function(source)
    local player = Manager.get(source)
    return player and player.citizenid or nil
end)

exports('GetPlayerData', function(source)
    local player = Manager.get(source)
    return player and player:snapshot() or nil
end)

exports('HasMoney', function(source, account, amount)
    local player = Manager.get(source)
    return player and player:hasMoney(account, amount) or false
end)

exports('GetJob', function(source)
    local player = Manager.get(source)
    return player and Util.deepCopy(player:getJob()) or nil
end)

exports('GetGang', function(source)
    local player = Manager.get(source)
    return player and Util.deepCopy(player:getGang()) or nil
end)

exports('SetJob', function(source, name, grade)
    local player = Manager.get(source)
    if not player then return false, 'player_not_loaded' end
    return player:setJob(name, grade)
end)

exports('SetGang', function(source, name, grade)
    local player = Manager.get(source)
    if not player then return false, 'player_not_loaded' end
    return player:setGang(name, grade)
end)

exports('SetDuty', function(source, onDuty)
    local player = Manager.get(source)
    if not player then return false end
    return player:setDuty(onDuty)
end)

exports('GetMetadata', function(source, key)
    local player = Manager.get(source)
    return player and player:getMeta(key) or nil
end)

exports('SetMetadata', function(source, key, value)
    local player = Manager.get(source)
    if not player then return false end
    return player:setMeta(key, value)
end)

exports('AddMetadata', function(source, key, delta, min, max)
    local player = Manager.get(source)
    if not player then return nil end
    return player:addMeta(key, delta, min, max)
end)

exports('Notify', function(source, message, kind, duration, title)
    TriggerClientEvent(SeaM.event('notify'), source, message, kind or 'inform', duration, title)
end)

exports('SavePlayer', function(source, immediate)
    local player = Manager.get(source)
    if not player then return false end

    player:save(immediate)
    return true
end)

exports('TransferMoney', function(source, from, to, amount, reason)
    local player = Manager.get(source)
    if not player then return false, 'player_not_loaded' end
    return player:transferMoney(from, to, amount, reason)
end)

exports('AddMoney', function(source, account, amount, reason)
    local player = Manager.get(source)
    if not player then return false, 'player_not_loaded' end
    return player:addMoney(account, amount, reason)
end)

exports('RemoveMoney', function(source, account, amount, reason)
    local player = Manager.get(source)
    if not player then return false, 'player_not_loaded' end
    return player:removeMoney(account, amount, reason)
end)

exports('GetMoney', function(source, account)
    local player = Manager.get(source)
    return player and player:getMoney(account) or 0
end)

exports('HasJobPermission', function(source, permission)
    local player = Manager.get(source)
    return player and player:hasJobPermission(permission) or false
end)

exports('HasGroup', function(source, group) return SeaM.Perms.has(source, group) end)

SeaM.Callbacks.register('player:get', function(source)
    local player = Manager.get(source)
    return player and player:snapshot() or nil
end)

SeaM.Callbacks.register('player:transactions', function(source, limit)
    local player = Manager.get(source)
    if not player then return {} end
    return SeaM.Ledger.history(player.citizenid, math.min(tonumber(limit) or 20, 50))
end)

SeaM.Callbacks.register('player:spawnpoint', function(source)
    local player = Manager.get(source)
    return player and player.position or SeaM.Config.Defaults.Spawn
end)

RegisterNetEvent(SeaM.event('client:ready'), function()
    SeaM.Commands.pushSuggestions(source)
end)

local Commands = SeaM.Commands

Commands.register('logout', {
    help = 'Return to character selection',
    handler = function(source)
        if not Manager.get(source) then return end
        Manager.logout(source)
    end,
})

Commands.register('setjob', {
    help = 'Set a player\'s job',
    permission = 'admin',
    params = {
        { name = 'target', type = 'player',  help = 'Server id' },
        { name = 'job',    type = 'job',     help = 'Job name' },
        { name = 'grade',  type = 'integer', help = 'Grade level', optional = true, default = 0 },
    },
    handler = function(source, args)
        local ok, err = args.target:setJob(args.job, args.grade)
        if not ok then return args.target:notify(err, 'error') end

        args.target:notify(SeaM.t('job.changed', args.target.job.label, args.target.job.gradeLabel), 'success')
        SeaM.Log.audit('admin', 'Job set', ('`%s` set **%s** to %s (%d)')
            :format(GetPlayerName(source) or 'console', args.target.name, args.job, args.grade))
    end,
})

Commands.register('setgang', {
    help = 'Set a player\'s gang',
    permission = 'admin',
    params = {
        { name = 'target', type = 'player',  help = 'Server id' },
        { name = 'gang',   type = 'gang',    help = 'Gang name' },
        { name = 'grade',  type = 'integer', help = 'Grade level', optional = true, default = 0 },
    },
    handler = function(source, args)
        local ok, err = args.target:setGang(args.gang, args.grade)
        if not ok then return args.target:notify(err, 'error') end
        args.target:notify(SeaM.t('gang.changed', args.target.gang.label, args.target.gang.gradeLabel), 'success')
    end,
})

Commands.register('setgroup', {
    help = 'Set a player\'s permission group',
    permission = 'owner',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
        { name = 'group',  type = 'group',  help = 'Permission group' },
    },
    handler = function(source, args)
        local by = source == 0 and 'console' or ('%s (%s)'):format(GetPlayerName(source) or '?', source)

        if not SeaM.Perms.set(args.target, args.group, by) then
            return TriggerClientEvent(SeaM.event('notify'), source, 'That could not be set.', 'error')
        end

        TriggerClientEvent(SeaM.event('notify'), args.target,
            ('Your permission group is now %s.'):format(args.group), 'success')
    end,
})

Commands.register('givemoney', {
    help = 'Give money to a player',
    permission = 'admin',
    params = {
        { name = 'target',  type = 'player',  help = 'Server id' },
        { name = 'account', type = 'account', help = 'cash, bank, ...' },
        { name = 'amount',  type = 'integer', help = 'Amount' },
    },
    handler = function(source, args)
        local actor = source == 0 and 'console' or (GetPlayerName(source) or tostring(source))
        local ok, err = args.target:addMoney(args.account, args.amount, 'admin grant', actor)
        if not ok then return SeaM.Log.warn('commands', ('givemoney failed: %s'):format(err)) end

        args.target:notify(SeaM.t('money.received', Util.formatMoney(args.amount), args.account), 'success')
        SeaM.Log.audit('money', 'Admin grant', ('**%s** gave %s %s to `%s`')
            :format(actor, Util.formatMoney(args.amount), args.account, args.target.name), 'warn')
    end,
})

Commands.register('setmoney', {
    help = 'Set a player\'s account balance',
    permission = 'owner',
    params = {
        { name = 'target',  type = 'player',  help = 'Server id' },
        { name = 'account', type = 'account', help = 'cash, bank, ...' },
        { name = 'amount',  type = 'integer', help = 'New balance' },
    },
    handler = function(source, args)
        args.target:setMoney(args.account, args.amount, 'admin set')
        SeaM.Log.audit('money', 'Admin set balance', ('**%s** set `%s` %s to %s')
            :format(GetPlayerName(source) or 'console', args.target.name, args.account,
                Util.formatMoney(args.amount)), 'warn')
    end,
})

Commands.register('balance', {
    help = 'Show your account balances',
    handler = function(source)
        local player = Manager.get(source)
        if not player then return end

        local lines = {}
        for _, account in ipairs(SeaM.Config.Accounts) do
            lines[#lines + 1] = ('%s: %s')
                :format(account.label, Util.formatMoney(player:getMoney(account.name)))
        end
        player:notify(table.concat(lines, '  |  '), 'inform')
    end,
})

Commands.register('players', {
    help = 'List loaded players',
    permission = 'mod',
    handler = function(source)
        local lines = {}
        for src, player in pairs(Manager.all()) do
            lines[#lines + 1] = ('[%d] %s (%s) - %s %s')
                :format(src, player.name, player.citizenid, player.job.label,
                    player.job.onDuty and '(on duty)' or '')
        end

        local body = #lines > 0 and table.concat(lines, '\n') or 'Nobody is loaded.'
        if source == 0 then print(body) else Manager.get(source):notify(body, 'inform') end
    end,
})

Commands.register('kick', {
    help = 'Kick a player',
    permission = 'mod',
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
        { name = 'reason', type = 'text',   help = 'Reason', optional = true },
    },
    handler = function(source, args)
        SeaM.Log.audit('admin', 'Player kicked', ('**%s** kicked `%s`: %s')
            :format(GetPlayerName(source) or 'console', GetPlayerName(args.target) or '?',
                args.reason or 'no reason'), 'warn')
        DropPlayer(args.target, ('Kicked: %s'):format(args.reason or 'No reason provided'))
    end,
})

Commands.register('ban', {
    help = 'Ban a player. Duration in hours, 0 for permanent.',
    permission = 'admin',
    params = {
        { name = 'target', type = 'source',  help = 'Server id' },
        { name = 'hours',  type = 'integer', help = 'Duration in hours (0 = permanent)' },
        { name = 'reason', type = 'text',    help = 'Reason', optional = true },
    },
    handler = function(source, args)
        Manager.ban(args.target, args.reason or 'No reason provided', args.hours * 3600,
            source == 0 and 'console' or (GetPlayerName(source) or tostring(source)))
    end,
})

Commands.register('saveall', {
    help = 'Force-save every loaded character',
    permission = 'admin',
    handler = function(source)
        local count = Manager.saveAll(true)
        SeaM.Log.info('commands', ('saved %d character(s) on request'):format(count))
        if source ~= 0 then
            local player = Manager.get(source)
            if player then player:notify(('Saved %d character(s).'):format(count), 'success') end
        end
    end,
})

Commands.register('economy', {
    help = 'Print money created/destroyed over the last N hours',
    permission = 'admin',
    consoleOnly = true,
    params = {
        { name = 'hours', type = 'integer', help = 'Window in hours', optional = true, default = 24 },
    },
    handler = function(_, args)
        local rows = SeaM.Ledger.economy(args.hours)
        print(('--- SeaM economy, last %d hour(s) ---'):format(args.hours))
        for _, row in ipairs(rows) do
            print(('  %-8s created %-14s destroyed %-14s net %-14s over %d moves'):format(
                row.account,
                Util.formatMoney(row.created or 0),
                Util.formatMoney(row.destroyed or 0),
                Util.formatMoney((row.created or 0) - (row.destroyed or 0)),
                row.moves or 0))
        end
    end,
})

Commands.register('coreinfo', {
    help = 'Print core status',
    permission = 'admin',
    consoleOnly = true,
    handler = function()
        print(('SeaM_Core v%s | %d loaded | %d queued write(s) | db %s')
            :format(SeaM.Version, Manager.count(), SeaM.DB.pendingCount(),
                SeaM.DB.ready and 'ok' or 'DOWN'))
    end,
})
