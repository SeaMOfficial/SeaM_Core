exports('GetCoreObject', function() return SeaM end)

exports('GetPlayerData', function() return SeaM.Player.get() end)

exports('GetGroup', function()
    local data = SeaM.Player.get()
    return data and data.group or 'user'
end)

exports('HasGroup', function(required)
    if required == nil or required == 'user' then return true end

    local data = SeaM.Player.get()
    if not data then return false end

    local order, rank = {}, 0

    for index, group in ipairs(SeaM.Config.Permissions.Groups) do
        order[group.name] = index
    end

    rank = order[data.group] or 0
    return rank >= (order[required] or math.huge)
end)
exports('IsPlayerLoaded', function() return SeaM.Player.isLoaded() end)
exports('AwaitPlayerData', function(timeoutMs) return SeaM.Player.await(timeoutMs) end)

exports('GetMoney', function(account) return SeaM.Player.getMoney(account) end)
exports('GetJob', function() return SeaM.Player.getJob() end)
exports('GetGang', function() return SeaM.Player.getGang() end)
exports('GetMetadata', function(key) return SeaM.Player.getMeta(key) end)
exports('HasJobPermission', function(permission) return SeaM.Player.hasJobPermission(permission) end)

exports('GetJobs', function() return SeaM.Jobs end)
exports('GetGangs', function() return SeaM.Gangs end)
exports('GetAccounts', function() return SeaM.Config.Accounts end)

exports('FormatMoney', function(amount, symbol) return SeaM.Util.formatMoney(amount, symbol) end)
