local active = false

RegisterNetEvent('SeaM_Core:progress:show', function(data)
    if type(data) ~= 'table' then return end

    active = true
    SendNUIMessage({
        action = 'progress',
        data = {
            visible   = true,
            label     = tostring(data.label or 'Working'),
            duration  = tonumber(data.duration) or 1000,
            canCancel = data.canCancel ~= false,
        },
    })
end)

RegisterNetEvent('SeaM_Core:progress:hide', function(completed)
    if not active then return end

    active = false
    SendNUIMessage({
        action = 'progress',
        data = { visible = false, completed = completed ~= false },
    })
end)

exports('IsProgressActive', function() return active end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= SeaM.Resource or not active then return end
    SendNUIMessage({ action = 'progress', data = { visible = false } })
end)
