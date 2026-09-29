SeaM = SeaM or {}

SeaM.Resource = GetCurrentResourceName()
SeaM.Version  = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
SeaM.IsServer = IsDuplicityVersion() == true
SeaM.IsClient = not SeaM.IsServer
SeaM.Side     = SeaM.IsServer and 'server' or 'client'

local registry = {}
local readyCallbacks = {}
local isReady = false

function SeaM.provide(name, value)
    if registry[name] then
        error(('module "%s" is already registered'):format(name), 2)
    end
    registry[name] = value
    SeaM[name] = value
    return value
end

function SeaM.use(name)
    local mod = registry[name]
    if not mod then
        error(('module "%s" is not registered (loaded too early, or misspelled)'):format(name), 2)
    end
    return mod
end

function SeaM.has(name) return registry[name] ~= nil end

function SeaM.onReady(fn)
    if isReady then return fn() end
    readyCallbacks[#readyCallbacks + 1] = fn
end

function SeaM.markReady()
    if isReady then return end
    isReady = true
    for i = 1, #readyCallbacks do
        local ok, err = pcall(readyCallbacks[i])
        if not ok then print(('^1[SeaM_Core] onReady callback failed: %s^0'):format(err)) end
    end
    readyCallbacks = {}
end

function SeaM.isReady() return isReady end

function SeaM.event(name) return ('SeaM_Core:%s'):format(name) end

function SeaM.on(name, handler) return RegisterNetEvent(SeaM.event(name), handler) end

function SeaM.emit(name, ...) return TriggerEvent(SeaM.event(name), ...) end

if SeaM.IsServer then

    function SeaM.emitNet(name, target, ...)
        return TriggerClientEvent(SeaM.event(name), target or -1, ...)
    end
else
    function SeaM.emitNet(name, ...)
        return TriggerServerEvent(SeaM.event(name), ...)
    end
end
