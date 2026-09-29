local callbacks = {}
local handlers = {}

function callbacks.register(name, handler)
    local invoker = GetInvokingResource() or SeaM.Resource

    if not SeaM.Util.isCallable(handler) then
        SeaM.Log.error('callbacks', ('"%s" (from %s) is not callable; not registered')
            :format(tostring(name), invoker))
        return false
    end

    if handlers[name] then
        SeaM.Log.warn('callbacks', ('overwriting existing callback "%s"'):format(name))
    end

    handlers[name] = { fn = handler, resource = invoker }
    return true
end

function callbacks.remove(name) handlers[name] = nil end

function callbacks.exists(name) return handlers[name] ~= nil end

RegisterNetEvent(SeaM.event('callback:request'), function(name, requestId, args)
    local src = source

    if type(name) ~= 'string' or type(requestId) ~= 'string' then
        SeaM.RateLimit.flag(src, 'malformed callback')
        return
    end

    if not SeaM.RateLimit.consume(src, 'callback') then
        TriggerClientEvent(SeaM.event('callback:response'), src, requestId, nil, 'rate_limited')
        return
    end

    local entry = handlers[name]
    if not entry then
        SeaM.Log.warn('callbacks', ('%s requested unknown callback "%s"'):format(src, name))
        TriggerClientEvent(SeaM.event('callback:response'), src, requestId, nil, 'unknown_callback')
        return
    end

    args = type(args) == 'table' and args or {}

    CreateThread(function()
        local results = table.pack(pcall(entry.fn, src, table.unpack(args, 1, args.n or #args)))

        if not results[1] then
            SeaM.Log.error('callbacks', ('"%s" (from %s) errored: %s')
                :format(name, entry.resource, results[2]))
            TriggerClientEvent(SeaM.event('callback:response'), src, requestId, nil, 'handler_error')
            return
        end

        TriggerClientEvent(SeaM.event('callback:response'), src, requestId,
            table.pack(table.unpack(results, 2, results.n)))
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    for name, entry in pairs(handlers) do
        if entry.resource == resource then handlers[name] = nil end
    end
end)

SeaM.provide('Callbacks', callbacks)

exports('registerCallback', function(name, handler)
    return callbacks.register(name, handler)
end)
