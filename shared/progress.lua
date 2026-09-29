Progress = {}

local running = false
local cancelled = false

local CANCEL_CONTROL = 73

function Progress.active() return running end

function Progress.cancel()
    if running then cancelled = true end
end

local function loadAnim(dict)
    if not dict or HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end

    return HasAnimDictLoaded(dict)
end

local function attachProps(props)
    local created = {}
    if not props then return created end

    local ped = PlayerPedId()

    for _, prop in ipairs(props) do
        local model = type(prop.model) == 'string' and joaat(prop.model) or prop.model

        if IsModelInCdimage(model) and IsModelValid(model) then
            RequestModel(model)
            local deadline = GetGameTimer() + 4000
            while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(10) end

            if HasModelLoaded(model) then
                local coords = GetEntityCoords(ped)
                local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
                local pos = prop.pos or vector3(0.0, 0.0, 0.0)
                local rot = prop.rot or vector3(0.0, 0.0, 0.0)

                AttachEntityToEntity(object, ped,
                    GetPedBoneIndex(ped, prop.bone or 28422),
                    pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
                    true, true, false, true, 1, true)

                SetModelAsNoLongerNeeded(model)
                created[#created + 1] = object
            end
        end
    end

    return created
end

local function clearProps(handles)
    for _, object in ipairs(handles) do
        if DoesEntityExist(object) then
            DetachEntity(object, true, true)
            DeleteObject(object)
        end
    end
end

function Progress.start(options)
    if running then return false end
    if type(options) ~= 'table' or not options.duration then return false end

    local ped = PlayerPedId()
    if not options.useWhileDead and IsPedDeadOrDying(ped, true) then return false end

    running = true
    cancelled = false

    local canCancel = options.canCancel ~= false
    local disable = options.disable or {}

    TriggerEvent('SeaM_Core:progress:show', {
        label     = options.label or 'Working',
        duration  = options.duration,
        canCancel = canCancel,
    })

    local anim = options.anim
    if anim and loadAnim(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip,
            anim.blendIn or 3.0, anim.blendOut or -8.0, -1,
            anim.flag or 49, 0.0, false, false, false)
    elseif options.scenario then
        TaskStartScenarioInPlace(ped, options.scenario, 0, true)
    end

    local props = attachProps(options.prop and { options.prop } or options.props)

    local deadline = GetGameTimer() + options.duration

    while GetGameTimer() < deadline and not cancelled do
        ped = PlayerPedId()

        if disable.move then
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
        end
        if disable.car then
            DisableControlAction(0, 63, true)
            DisableControlAction(0, 64, true)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)
        end
        if disable.combat then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
        end

        if canCancel and IsControlJustPressed(0, CANCEL_CONTROL) then cancelled = true end

        if not options.useWhileDead and IsPedDeadOrDying(ped, true) then cancelled = true end

        Wait(0)
    end

    local completed = not cancelled

    clearProps(props)
    if anim or options.scenario then ClearPedTasks(PlayerPedId()) end

    TriggerEvent('SeaM_Core:progress:hide', completed)

    running = false
    cancelled = false

    return completed
end

function Progress.async(options, cb)
    CreateThread(function() cb(Progress.start(options)) end)
end
