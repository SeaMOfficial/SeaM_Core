local Config = SeaM.Config.Notifications

local sessionReady = false
local nuiReady = false
local pending = {}

local function sendSetup()
    if not sessionReady then return end

    SendNUIMessage({
        action = 'setup',
        data = {
            position   = Config.position,
            maxVisible = Config.maxVisible,
            accent     = Config.accent,
            prompt     = SeaM.Config.Prompts.position,
        },
    })
end

local function sendNotification(data)
    SendNUIMessage({ action = 'notify', data = data })
end

local function flushPending()
    if not sessionReady or not nuiReady or #pending == 0 then return end

    for i = 1, #pending do sendNotification(pending[i]) end
    pending = {}
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end

    sessionReady = true
    sendSetup()
    flushPending()
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendSetup()
    flushPending()
    cb({ ok = true })
end)

local function readingTime(message)
    return Config.duration + math.min(#message * 22, 3500)
end

local function notify(message, kind, duration, title)
    if type(message) ~= 'string' or message == '' then return end

    local data = {
        message  = message,
        kind     = kind or 'inform',
        duration = tonumber(duration) or readingTime(message),
        title    = title and tostring(title) or nil,
    }

    if sessionReady and nuiReady then
        sendNotification(data)
        return
    end

    pending[#pending + 1] = data
    if #pending > 20 then table.remove(pending, 1) end
end

SeaM.notify = notify

RegisterNetEvent(SeaM.event('notify'), function(message, kind, duration, title)
    notify(message, kind, duration, title)
end)

exports('Notify', function(message, kind, duration, title)
    notify(message, kind, duration, title)
end)

exports('ClearNotifications', function()
    pending = {}
    SendNUIMessage({ action = 'clear' })
end)

RegisterCommand('notifytest', function()
    notify('Saved to the ledger.', 'inform')
    SetTimeout(300, function() notify('Payment received.', 'success', nil, 'Bank') end)
    SetTimeout(600, function() notify('Your fuel is running low.', 'warning') end)
    SetTimeout(900, function()
        notify('That character could not be loaded. Try again in a moment.', 'error', nil, 'Failed')
    end)
end, false)
