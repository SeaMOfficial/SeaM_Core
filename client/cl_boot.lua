SeaM.Ready = false

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    SeaM.Ready = true
    SeaM.markReady()
    TriggerServerEvent(SeaM.event('client:ready'))
end)
