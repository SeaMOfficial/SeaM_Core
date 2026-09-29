local Config = SeaM.Config.Admin

local state = {
    noclip = false,
    invisible = false,
    god = false,
    frozen = false,
    speed = 2,
    spectating = nil,
    camera = nil,
    origin = nil,
    vehicle = nil,
}

local function notify(message, kind)
    TriggerEvent(SeaM.event('notify'), message, kind or 'inform')
end

local function groundAt(x, y, z)
    for _, height in ipairs({ 1000.0, 800.0, 600.0, 400.0, 250.0, 150.0, 90.0, 60.0, 40.0, 20.0, 5.0 }) do
        RequestCollisionAtCoord(x, y, height)

        local found, ground = GetGroundZFor_3dCoord(x, y, height, false)
        if found then return ground end

        Wait(0)
    end
    return z
end

local function teleport(coords, findGround)
    local ped = PlayerPedId()
    local entity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local deadline = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() < deadline do Wait(0) end

    if findGround then
        local ground = groundAt(coords.x, coords.y, coords.z)
        SetEntityCoordsNoOffset(entity, coords.x, coords.y, ground + 1.0, false, false, false)
    end

    DoScreenFadeIn(400)
end

RegisterNetEvent(SeaM.event('admin:teleport'), function(coords)
    if not coords then return end
    teleport(coords, false)
end)

RegisterNetEvent(SeaM.event('admin:teleportMarker'), function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        return notify('Set a waypoint first.', 'error')
    end

    local coords = GetBlipInfoIdCoord(blip)
    teleport(vector3(coords.x, coords.y, coords.z), true)
end)

RegisterNetEvent(SeaM.event('admin:coords'), function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local line = ('vector4(%.2f, %.2f, %.2f, %.2f)')
        :format(coords.x, coords.y, coords.z, heading)

    notify(line)
    print(('[SeaM] %s'):format(line))
end)

local function stopNoclip()
    local ped = PlayerPedId()

    state.noclip = false
    SetEntityInvincible(ped, state.god)
    SetEntityVisible(ped, not state.invisible, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityAlpha(ped, 255, false)
end

local function startNoclip()
    state.noclip = true

    CreateThread(function()
        while state.noclip do
            local ped = PlayerPedId()
            local entity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

            SetEntityInvincible(entity, true)
            SetEntityCollision(entity, false, false)
            FreezeEntityPosition(entity, true)
            SetEntityAlpha(ped, state.invisible and 0 or 130, false)

            for _, control in ipairs({ 30, 31, 32, 33, 34, 35, 21, 22, 23, 75, 71, 72 }) do
                DisableControlAction(0, control, true)
            end

            local speed = Config.NoclipSpeeds[state.speed] or 1.0
            local coords = GetEntityCoords(entity)
            local rotation = GetGameplayCamRot(2)
            local heading = math.rad(rotation.z)
            local pitch = math.rad(rotation.x)

            local forward = vector3(-math.sin(heading) * math.abs(math.cos(pitch)),
                math.cos(heading) * math.abs(math.cos(pitch)), math.sin(pitch))
            local right = vector3(math.cos(heading), math.sin(heading), 0.0)

            local move = vector3(0.0, 0.0, 0.0)

            if IsDisabledControlPressed(0, 32) then move = move + forward end
            if IsDisabledControlPressed(0, 33) then move = move - forward end
            if IsDisabledControlPressed(0, 34) then move = move - right end
            if IsDisabledControlPressed(0, 35) then move = move + right end
            if IsDisabledControlPressed(0, 22) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, 36) then move = move - vector3(0.0, 0.0, 1.0) end

            if IsControlJustPressed(0, 241) then
                state.speed = math.min(state.speed + 1, #Config.NoclipSpeeds)
                notify(('Speed %d of %d'):format(state.speed, #Config.NoclipSpeeds))
            elseif IsControlJustPressed(0, 242) then
                state.speed = math.max(state.speed - 1, 1)
                notify(('Speed %d of %d'):format(state.speed, #Config.NoclipSpeeds))
            end

            if #(move) > 0.0 then
                local target = coords + (move * speed)
                SetEntityCoordsNoOffset(entity, target.x, target.y, target.z, true, true, true)
            end

            SetEntityHeading(entity, rotation.z)
            Wait(0)
        end
    end)
end

RegisterNetEvent(SeaM.event('admin:noclip'), function()
    if state.noclip then
        stopNoclip()
        notify('Noclip off.')
    else
        startNoclip()
        notify('Noclip on. Scroll to change speed.')
    end
end)

RegisterNetEvent(SeaM.event('admin:invisible'), function()
    state.invisible = not state.invisible
    SetEntityVisible(PlayerPedId(), not state.invisible, false)
    notify(state.invisible and 'Invisible.' or 'Visible again.')
end)

RegisterNetEvent(SeaM.event('admin:god'), function()
    state.god = not state.god

    local ped = PlayerPedId()
    SetEntityInvincible(ped, state.god)
    SetPlayerInvincible(PlayerId(), state.god)
    SetEntityProofs(ped, state.god, state.god, state.god, state.god, state.god, state.god, state.god, state.god)

    notify(state.god and 'God mode on.' or 'God mode off.')
end)

RegisterNetEvent(SeaM.event('admin:freeze'), function()
    state.frozen = not state.frozen

    local ped = PlayerPedId()
    local entity = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or ped

    FreezeEntityPosition(entity, state.frozen)
    notify(state.frozen and 'You have been frozen.' or 'You can move again.',
        state.frozen and 'warning' or 'success')
end)

RegisterNetEvent(SeaM.event('admin:revive'), function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if IsEntityDead(ped) then
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end)

RegisterNetEvent(SeaM.event('admin:armour'), function(amount)
    SetPedArmour(PlayerPedId(), math.min(tonumber(amount) or 100, 100))
end)

--- Health can only be set by the client that owns the ped, so /heal and /kill
--- (and SeaM_Admin) ask for it here instead of calling SetEntityHealth on the server.
RegisterNetEvent(SeaM.event('admin:heal'), function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent(SeaM.event('admin:kill'), function()
    SetEntityHealth(PlayerPedId(), 0)
end)

local function stopSpectate()
    if not state.spectating then return end

    NetworkSetInSpectatorMode(false, PlayerPedId())

    local ped = PlayerPedId()
    if state.origin then
        SetEntityCoordsNoOffset(ped, state.origin.x, state.origin.y, state.origin.z, false, false, false)
    end

    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, state.god)

    state.spectating = nil
    state.origin = nil

    notify('Spectating stopped.')
end

RegisterNetEvent(SeaM.event('admin:spectate'), function(target, coords)
    if not target or state.spectating == target then return stopSpectate() end

    local player = GetPlayerFromServerId(target)
    if player == -1 then return notify('They are too far away to spectate.', 'error') end

    local ped = PlayerPedId()
    state.origin = GetEntityCoords(ped)
    state.spectating = target

    if coords then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    end

    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)

    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(GetPlayerPed(player)) and GetGameTimer() < deadline do Wait(50) end

    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    notify('Spectating. Run the command again to stop.')
end)

RegisterNetEvent(SeaM.event('admin:spawnVehicle'), function(model, replace)
    local hash = joaat(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return notify(('There is no vehicle called "%s".'):format(model), 'error')
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end

    if not HasModelLoaded(hash) then
        return notify('That vehicle would not load.', 'error')
    end

    if replace and state.vehicle and DoesEntityExist(state.vehicle) then
        SetEntityAsMissionEntity(state.vehicle, true, true)
        DeleteVehicle(state.vehicle)
    end

    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)

    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(hash)

    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehRadioStation(vehicle, 'OFF')
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    state.vehicle = vehicle
    notify(('Spawned %s.'):format(model), 'success')
end)

RegisterNetEvent(SeaM.event('admin:deleteVehicle'), function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        local coords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return notify('No vehicle near you.', 'error')
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)

    if not DoesEntityExist(vehicle) then
        if state.vehicle == vehicle then state.vehicle = nil end
        notify('Vehicle deleted.', 'success')
    else
        notify('That vehicle is not yours to delete.', 'error')
    end
end)

RegisterNetEvent(SeaM.event('admin:fixVehicle'), function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then return notify('You are not in a vehicle.', 'error') end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleFuelLevel(vehicle, 100.0)

    notify('Repaired.', 'success')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= SeaM.Resource then return end

    if state.noclip then stopNoclip() end
    if state.spectating then stopSpectate() end

    DoScreenFadeIn(0)
end)

RegisterNetEvent(SeaM.event('player:unloaded'), function()
    if state.noclip then stopNoclip() end
    if state.spectating then stopSpectate() end
end)
