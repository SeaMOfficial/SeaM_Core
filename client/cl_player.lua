local player = { data = nil, loaded = false }

local function bagName()
    return ('player:%d'):format(GetPlayerServerId(PlayerId()))
end

function player.get() return player.data end

function player.isLoaded() return player.loaded end

function player.await(timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 30000)
    while not player.loaded do
        if GetGameTimer() > deadline then return nil end
        Wait(100)
    end
    return player.data
end

function player.getMoney(account)
    return player.data and player.data.money[account] or 0
end

function player.getJob() return player.data and player.data.job end

function player.getGang() return player.data and player.data.gang end

function player.getMeta(key)
    return player.data and player.data.metadata[key]
end

function player.hasJobPermission(permission)
    local job = player.getJob()
    if not job or not job.permissions then return false end
    for i = 1, #job.permissions do
        if job.permissions[i] == '*' or job.permissions[i] == permission then return true end
    end
    return false
end

local function apply(snapshot)
    local wasLoaded = player.loaded

    if not snapshot then
        player.data, player.loaded = nil, false
        if wasLoaded then TriggerEvent(SeaM.event('client:unloaded')) end
        return
    end

    player.data = snapshot
    player.loaded = true

    if not wasLoaded then
        TriggerEvent(SeaM.event('client:loaded'), snapshot)
    else
        TriggerEvent(SeaM.event('client:updated'), snapshot)
    end
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end

    AddStateBagChangeHandler('seam', bagName(), function(_, _, value)
        apply(value)
    end)

    Wait(500)
    local state = LocalPlayer.state
    if state and state.seam then apply(state.seam) end
end)

RegisterNetEvent(SeaM.event('player:loaded'), function(snapshot)
    apply(snapshot)

    if not SeaM.Config.Server.CoreHandlesSpawn then return end

    local position = SeaM.Callbacks.await('player:spawnpoint')
    if not position then return end

    local ped = PlayerPedId()
    RequestCollisionAtCoord(position.x, position.y, position.z)
    SetEntityCoordsNoOffset(ped, position.x + 0.0, position.y + 0.0, position.z + 0.0, false, false, false)
    SetEntityHeading(ped, position.w + 0.0)
    FreezeEntityPosition(ped, true)

    local deadline = GetGameTimer() + 10000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(50) end

    FreezeEntityPosition(ped, false)
    ShutdownLoadingScreen()
    DoScreenFadeIn(750)
    SetEntityVisible(ped, true, false)

    TriggerEvent(SeaM.event('client:spawned'), position)
end)

RegisterNetEvent(SeaM.event('player:unloaded'), function() apply(nil) end)

SeaM.provide('Player', player)
