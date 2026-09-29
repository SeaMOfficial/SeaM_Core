local hooks = {}
local registry = {}

function hooks.register(name, fn, priority)
    local invoker = GetInvokingResource() or SeaM.Resource

    if not SeaM.Util.isCallable(fn) then
        SeaM.Log.error('hooks', ('listener for "%s" (from %s) is not callable; not registered')
            :format(tostring(name), invoker))
        return nil
    end

    registry[name] = registry[name] or { seq = 0, list = {} }
    local bucket = registry[name]
    bucket.seq = bucket.seq + 1

    bucket.list[#bucket.list + 1] = {
        id = bucket.seq,
        fn = fn,
        priority = priority or 50,
        resource = invoker,
    }

    table.sort(bucket.list, function(a, b)
        if a.priority == b.priority then return a.id < b.id end
        return a.priority < b.priority
    end)

    return bucket.seq
end

function hooks.remove(name, id)
    local bucket = registry[name]
    if not bucket then return false end
    for i = #bucket.list, 1, -1 do
        if bucket.list[i].id == id then
            table.remove(bucket.list, i)
            return true
        end
    end
    return false
end

function hooks.removeResource(resource)
    for _, bucket in pairs(registry) do
        for i = #bucket.list, 1, -1 do
            if bucket.list[i].resource == resource then table.remove(bucket.list, i) end
        end
    end
end

function hooks.run(name, ctx)
    local bucket = registry[name]
    if not bucket or #bucket.list == 0 then return true end

    for i = 1, #bucket.list do
        local listener = bucket.list[i]
        local ok, result, reason = pcall(listener.fn, ctx)

        if not ok then
            SeaM.Log.error('hooks', ('listener from "%s" on "%s" errored: %s')
                :format(listener.resource, name, result))
        elseif result == false then
            SeaM.Log.debug('hooks', ('"%s" cancelled by %s (%s)')
                :format(name, listener.resource, reason or 'no reason'))
            return false, reason
        end
    end

    return true
end

function hooks.count(name)
    local bucket = registry[name]
    return bucket and #bucket.list or 0
end

AddEventHandler('onResourceStop', hooks.removeResource)

SeaM.provide('Hooks', hooks)

exports('registerHook', function(name, fn, priority) return hooks.register(name, fn, priority) end)
exports('removeHook', function(name, id) return hooks.remove(name, id) end)
