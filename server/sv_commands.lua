local commands = {}
local registry = {}

local parsers = {}

parsers.string = function(raw) return raw end

parsers.number = function(raw)
    local value = tonumber(raw)
    if not value then return nil, 'must be a number' end
    return value
end

parsers.integer = function(raw)
    local value = tonumber(raw)
    if not value or value % 1 ~= 0 then return nil, 'must be a whole number' end
    return value
end

parsers.boolean = function(raw)
    local lowered = raw:lower()
    if lowered == 'true' or lowered == '1' or lowered == 'yes' or lowered == 'on' then return true end
    if lowered == 'false' or lowered == '0' or lowered == 'no' or lowered == 'off' then return false end
    return nil, 'must be true or false'
end

parsers.player = function(raw)
    local id = tonumber(raw)
    if not id then return nil, 'must be a server id' end

    local player = SeaM.Manager.get(id)
    if not player then return nil, 'is not a loaded player' end
    return player
end

parsers.source = function(raw)
    local id = tonumber(raw)
    if not id or not GetPlayerName(id) then return nil, 'is not a connected player' end
    return id
end

parsers.job = function(raw)
    if not SeaM.Jobs[raw] then return nil, 'is not a known job' end
    return raw
end

parsers.gang = function(raw)
    if not SeaM.Gangs[raw] then return nil, 'is not a known gang' end
    return raw
end

parsers.account = function(raw)
    if not SeaM.AccountIndex[raw] then return nil, 'is not a known account' end
    return raw
end

parsers.group = function(raw)
    if not SeaM.Perms.exists(raw) then return nil, 'is not a known permission group' end
    return raw
end

parsers.text = parsers.string

local function reply(source, message, kind)
    if source == 0 then
        print(('[SeaM] %s'):format(message))
        return
    end

    TriggerClientEvent(SeaM.event('notify'), source, message, kind or 'error')
end

function commands.reply(source, message, kind)
    reply(source, message, kind)
end

local function parseArgs(definition, raw)
    local out = {}
    local params = definition.params or {}

    for i = 1, #params do
        local param = params[i]
        local value

        if param.type == 'text' then
            value = table.concat(raw, ' ', i)
            if value == '' then value = nil end
        else
            value = raw[i]
        end

        if value == nil then
            if not param.optional then
                return nil, SeaM.t('cmd.missing_arg', param.name)
            end
            out[param.name] = param.default
        else
            local parser = parsers[param.type or 'string']
            local parsed, err = parser(value)
            if err then
                return nil, ('argument "%s" %s'):format(param.name, err)
            end
            out[param.name] = parsed
        end
    end

    return out
end

function commands.register(name, definition)
    local invoker = GetInvokingResource() or SeaM.Resource

    if type(definition) ~= 'table' or not SeaM.Util.isCallable(definition.handler) then

        SeaM.Log.error('commands',
            ('"%s" (from %s) has no handler function; command not registered'):format(name, invoker))
        return false
    end

    definition.resource = invoker
    registry[name] = definition

    RegisterCommand(name, function(source, raw)
        local def = registry[name]
        if not def then return end

        if def.consoleOnly and source ~= 0 then
            return reply(source, SeaM.t('cmd.console_only'))
        end

        if source ~= 0 then
            if not SeaM.RateLimit.consume(source, 'command') then
                return reply(source, SeaM.t('cmd.rate_limited'))
            end

            if def.permission and not SeaM.Perms.has(source, def.permission) then
                SeaM.Log.debug('commands', ('%s denied /%s'):format(source, name))
                return reply(source, SeaM.t('cmd.no_permission'))
            end

            if def.jobPermission then
                local player = SeaM.Manager.get(source)
                if not player or not player:hasJobPermission(def.jobPermission) then
                    return reply(source, SeaM.t('cmd.no_permission'))
                end
            end
        end

        local args, err = parseArgs(def, raw)
        if not args then return reply(source, err) end

        local ok, result = pcall(def.handler, source, args, raw)
        if not ok then
            SeaM.Log.error('commands', ('/%s (from %s) errored: %s'):format(name, def.resource, result))
            reply(source, 'That command failed. Check the server console.')
        end
    end, false)

    if SeaM.Config.Permissions.SyncAcePrincipals and SeaM.Perms.canWriteAces('add_ace')
        and definition.permission and definition.permission ~= 'user' then
        ExecuteCommand(('add_ace group.seam.%s command.%s allow'):format(definition.permission, name))
    end

    return true
end

function commands.remove(name) registry[name] = nil end

function commands.all() return registry end

function commands.pushSuggestions(source)
    for name, def in pairs(registry) do
        if not def.consoleOnly and (not def.permission or SeaM.Perms.has(source, def.permission)) then
            local params = {}
            for i, param in ipairs(def.params or {}) do
                params[i] = {
                    name = param.optional and ('[%s]'):format(param.name) or param.name,
                    help = param.help or param.type or '',
                }
            end
            TriggerClientEvent('chat:addSuggestion', source, ('/%s'):format(name), def.help or '', params)
        end
    end
end

AddEventHandler(SeaM.event('player:loaded'), function(source)
    commands.pushSuggestions(source)
end)

AddEventHandler(SeaM.event('job:changed'), function(source)
    commands.pushSuggestions(source)
end)

AddEventHandler('onResourceStop', function(resource)
    for name, def in pairs(registry) do
        if def.resource == resource then registry[name] = nil end
    end
end)

SeaM.provide('Commands', commands)

exports('registerCommand', function(name, definition)
    definition.resource = GetInvokingResource() or 'unknown'
    return commands.register(name, definition)
end)
