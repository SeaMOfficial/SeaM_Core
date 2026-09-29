local Points = { list = {}, sequence = 0 }

local active = nil
local owner = nil
local shownText = nil
local shownKey = nil
local promptVisible = false
local enabled = true

local function blocked()
    return not enabled or IsPauseMenuActive() or IsNuiFocused() or IsPedDeadOrDying(PlayerPedId(), true)
end

function Points.showPrompt(text, by, key)
    by = by or 'anonymous'
    text = tostring(text or ''):gsub('[\r\n\t]', ' '):gsub('%s+', ' ')
    text = text:match('^%s*(.-)%s*$') or ''
    key = tostring(key or 'E'):match('^%s*(.-)%s*$') or 'E'

    -- Empty text used to leave a bare "E" permanently on screen because nil
    -- was also used as the hidden-state marker. Empty prompts now close cleanly.
    if text == '' then
        Points.hidePrompt(by)
        return false
    end

    if promptVisible and shownText == text and shownKey == key and owner == by then return true end

    owner = by
    shownText = text
    shownKey = key ~= '' and key or 'E'
    promptVisible = true

    SendNUIMessage({
        action = 'prompt',
        data = { text = shownText, key = shownKey, visible = true },
    })

    return true
end

function Points.hidePrompt(by)
    if not promptVisible then return end
    if by and owner and owner ~= by then return end

    owner = nil
    shownText = nil
    shownKey = nil
    promptVisible = false
    SendNUIMessage({ action = 'prompt', data = { visible = false } })
end

function Points.register(data)
    if not data.coords or not SeaM.Util.isCallable(data.onSelect) then
        SeaM.Log.error('points', 'a point needs coords and an onSelect function')
        return nil
    end

    Points.sequence = Points.sequence + 1

    data.id       = data.id or ('point:%d'):format(Points.sequence)
    data.distance = data.distance or 2.0
    data.key      = data.key or 38
    data.keyLabel = data.keyLabel or 'E'
    data.resource = GetInvokingResource() or SeaM.Resource

    Points.list[data.id] = data
    return data.id
end

function Points.remove(id)
    if active == id then
        Points.hidePrompt('points')
        active = nil
    end
    Points.list[id] = nil
end

function Points.removeResource(resource)
    for id, point in pairs(Points.list) do
        if point.resource == resource then Points.remove(id) end
    end
end

CreateThread(function()
    while true do
        local wait = 500

        if blocked() then

            if active then
                local point = Points.list[active]
                if point and SeaM.Util.isCallable(point.onExit) then pcall(point.onExit) end
                active = nil
            end

            Points.hidePrompt('points')
        else
            local coords = GetEntityCoords(PlayerPedId())

            local nearest, nearestDistance
            local anyClose = false

            for id, point in pairs(Points.list) do
                local distance = #(coords - point.coords)

                if distance < point.distance + 8.0 then anyClose = true end

                if distance <= point.distance then
                    local allowed = true

                    if SeaM.Util.isCallable(point.canInteract) then
                        local ok, result = pcall(point.canInteract)
                        allowed = ok and result ~= false
                    end

                    if allowed and (not nearestDistance or distance < nearestDistance) then
                        nearest, nearestDistance = id, distance
                    end
                end
            end

            if anyClose then wait = 0 end

            if nearest ~= active then
                local previous = active and Points.list[active]
                if previous and SeaM.Util.isCallable(previous.onExit) then pcall(previous.onExit) end

                active = nearest

                if nearest then
                    local point = Points.list[nearest]
                    if SeaM.Util.isCallable(point.onEnter) then pcall(point.onEnter) end
                    Points.showPrompt(point.label or 'Interact', 'points', point.keyLabel)
                else
                    Points.hidePrompt('points')
                end
            end

            if active then
                local point = Points.list[active]

                if point and IsControlJustReleased(0, point.key) then
                    local ok, err = pcall(point.onSelect)
                    if not ok then
                        SeaM.Log.error('points', ('"%s" (from %s) errored: %s')
                            :format(point.id, point.resource, err))
                    end
                    Wait(300)
                end
            end
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == SeaM.Resource then
        Points.hidePrompt()
        return
    end
    Points.removeResource(resource)
end)

SeaM.provide('Points', Points)

exports('RegisterPoint', function(data) return Points.register(data) end)
exports('RemovePoint', function(id) Points.remove(id) end)

exports('SetPointsEnabled', function(value)
    enabled = value ~= false
    if not enabled then Points.hidePrompt('points') end
end)

exports('ShowTextUI', function(text, by, key) Points.showPrompt(text, by, key) end)
exports('HideTextUI', function(by) Points.hidePrompt(by) end)
