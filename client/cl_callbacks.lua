local Config = SeaM.Config.Callbacks
local callbacks = {}
local pending = {}

RegisterNetEvent(SeaM.event('callback:response'), function(requestId, results, err)
    local entry = pending[requestId]
    if not entry then return end

    pending[requestId] = nil

    if err then
        SeaM.Log.warn('callbacks', ('"%s" rejected: %s'):format(entry.name, err))
        entry.promise:resolve({ n = 0 })
        return
    end

    entry.promise:resolve(results or { n = 0 })
end)

function callbacks.await(name, ...)
    local requestId = SeaM.Util.uuid()
    local p = promise.new()

    pending[requestId] = { promise = p, name = name }
    TriggerServerEvent(SeaM.event('callback:request'), name, requestId, table.pack(...))

    SetTimeout(Config.TimeoutMs, function()
        local entry = pending[requestId]
        if not entry then return end
        pending[requestId] = nil
        SeaM.Log.warn('callbacks', ('"%s" timed out after %dms'):format(name, Config.TimeoutMs))
        entry.promise:resolve({ n = 0 })
    end)

    local results = Citizen.Await(p)
    return table.unpack(results, 1, results.n or #results)
end

function callbacks.trigger(name, cb, ...)
    local args = table.pack(...)
    CreateThread(function()
        cb(callbacks.await(name, table.unpack(args, 1, args.n)))
    end)
end

SeaM.provide('Callbacks', callbacks)

exports('TriggerCallback', function(name, ...) return callbacks.await(name, ...) end)
