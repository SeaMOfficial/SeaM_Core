local StateBagPlayer = Player

local Config = SeaM.Config
local Hooks  = SeaM.Hooks
local Util   = SeaM.Util

local Player = SeaM.class('Player')

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return (ok and type(decoded) == 'table') and decoded or fallback
end

function Player:constructor(row, source)
    self.source    = source
    self.citizenid = row.citizenid
    self.license   = row.license
    self.slot      = row.slot or 1
    self.group     = row.permission_group or 'user'
    self.playtime  = row.playtime or 0

    self.charinfo = decode(row.charinfo, {})
    self.money    = Util.defaults(decode(row.money, {}), SeaM.AccountDefaults)
    self.job      = Util.defaults(decode(row.job, {}), Config.Defaults.Job)
    self.gang     = Util.defaults(decode(row.gang, {}), Config.Defaults.Gang)
    self.metadata = Util.defaults(decode(row.metadata, {}), Config.Defaults.Metadata)
    self.position = decode(row.position, Config.Defaults.Spawn)

    self.name = row.name or ('%s %s')
        :format(self.charinfo.firstname or 'John', self.charinfo.lastname or 'Doe')

    self.sessionStart = os.time()
    self.dirty  = {}
    self.loaded = false

    self:refreshJob()
    self:refreshGang()
end

function Player:markDirty(...)
    for i = 1, select('#', ...) do self.dirty[select(i, ...)] = true end
end

function Player:isDirty() return next(self.dirty) ~= nil end

function Player:toRow()
    return {
        name             = self.name,
        charinfo         = json.encode(self.charinfo),
        money            = json.encode(self.money),
        job              = json.encode({ name = self.job.name, grade = self.job.grade, onDuty = self.job.onDuty }),
        gang             = json.encode({ name = self.gang.name, grade = self.gang.grade }),
        metadata         = json.encode(self.metadata),
        position         = json.encode(self.position),
        permission_group = self.group,
        playtime         = self:getPlaytime(),
    }
end

function Player:save(immediate)
    self:capturePosition()

    local row = self:toRow()
    local query = [[
        UPDATE seam_players SET
            name = ?, charinfo = ?, money = ?, job = ?, gang = ?,
            metadata = ?, position = ?, permission_group = ?, playtime = ?
        WHERE citizenid = ?
    ]]
    local params = {
        row.name, row.charinfo, row.money, row.job, row.gang,
        row.metadata, row.position, row.permission_group, row.playtime,
        self.citizenid,
    }

    if immediate then
        SeaM.DB.execute(query, params)
    else
        SeaM.DB.enqueue(('player:%s'):format(self.citizenid), query, params)
    end

    self.dirty = {}
end

function Player:capturePosition()
    local ped = GetPlayerPed(self.source)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    if coords.x == 0.0 and coords.y == 0.0 then return end

    self.position = {
        x = Util.round(coords.x, 2),
        y = Util.round(coords.y, 2),
        z = Util.round(coords.z, 2),
        w = Util.round(GetEntityHeading(ped), 2),
    }
end

function Player:snapshot()
    local money = {}
    for account, amount in pairs(self.money) do
        local def = SeaM.AccountIndex[account]
        if def and not def.hidden then money[account] = amount end
    end

    local meta = {}
    for key in pairs(SeaM.ReplicatedMetaSet) do meta[key] = self.metadata[key] end

    return {
        source    = self.source,
        citizenid = self.citizenid,
        name      = self.name,
        charinfo  = self.charinfo,
        money     = money,
        job       = self.job,
        gang      = self.gang,
        metadata  = meta,
        group     = self.group,
        playtime  = self:getPlaytime(),
    }
end

function Player:sync()
    local entity = StateBagPlayer(self.source)
    if not entity or not entity.state then return end
    entity.state:set('seam', self:snapshot(), true)
end

function Player:getMoney(account) return self.money[account] or 0 end

function Player:getAllMoney() return Util.deepCopy(self.money) end

function Player:hasMoney(account, amount)
    return self:getMoney(account) >= (tonumber(amount) or 0)
end

local function validAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount <= 0 then return nil end
    return math.floor(amount)
end

function Player:applyMoney(account, delta, reason, actor, hookName)
    local def = SeaM.AccountIndex[account]
    if not def then return false, ('unknown account "%s"'):format(account) end

    local ctx = {
        player  = self,
        account = account,
        delta   = delta,
        amount  = math.abs(delta),
        reason  = reason,
        actor   = actor,
        handler = GetInvokingResource() or SeaM.Resource,
    }

    local allowed, vetoReason = Hooks.run(hookName, ctx)
    if not allowed then return false, vetoReason or 'cancelled by hook' end

    account = ctx.account
    reason  = ctx.reason
    delta   = math.floor(tonumber(ctx.delta) or delta)

    def = SeaM.AccountIndex[account]
    if not def then return false, ('unknown account "%s"'):format(account) end

    local result = self:getMoney(account) + delta
    if result < 0 and not def.allowNegative then return false, 'insufficient_funds' end

    self.money[account] = result
    self:markDirty('money')
    self:sync()

    SeaM.Ledger.record(self.citizenid, account, delta, result, reason, ctx.handler, actor)

    TriggerEvent(SeaM.event('money:changed'), self.source, account, delta, result, reason)
    TriggerClientEvent(SeaM.event('money:changed'), self.source, account, delta, result, reason)
    return true
end

function Player:addMoney(account, amount, reason, actor)
    amount = validAmount(amount)
    if not amount then return false, 'invalid_amount' end
    return self:applyMoney(account, amount, reason, actor, 'money:add')
end

function Player:removeMoney(account, amount, reason, actor)
    amount = validAmount(amount)
    if not amount then return false, 'invalid_amount' end
    return self:applyMoney(account, -amount, reason, actor, 'money:remove')
end

function Player:setMoney(account, amount, reason)
    amount = tonumber(amount)
    if not amount then return false, 'invalid_amount' end

    local delta = math.floor(amount) - self:getMoney(account)
    if delta == 0 then return true end
    return self:applyMoney(account, delta, reason or 'set', 'system', 'money:set')
end

function Player:transferMoney(from, to, amount, reason)
    amount = validAmount(amount)
    if not amount then return false, 'invalid_amount' end
    if not self:hasMoney(from, amount) then return false, 'insufficient_funds' end

    local ok, err = self:removeMoney(from, amount, reason or ('transfer to ' .. to))
    if not ok then return false, err end

    if not self:addMoney(to, amount, reason or ('transfer from ' .. from)) then
        self:addMoney(from, amount, 'transfer rollback')
        return false, 'transfer_failed'
    end
    return true
end

function Player:refreshJob()
    local def = SeaM.Jobs[self.job.name] or SeaM.Jobs[Config.Defaults.Job.name]
    local grade = def.grades[self.job.grade] or def.grades[0]

    self.job.label       = def.label
    self.job.type        = def.type
    self.job.isBoss      = grade.isBoss or false
    self.job.payment     = grade.payment or 0
    self.job.permissions = grade.permissions or {}
    self.job.gradeLabel  = grade.name
    if self.job.onDuty == nil then self.job.onDuty = def.defaultDuty ~= false end
end

function Player:refreshGang()
    local def = SeaM.Gangs[self.gang.name] or SeaM.Gangs[Config.Defaults.Gang.name]
    local grade = def.grades[self.gang.grade] or def.grades[0]

    self.gang.label      = def.label
    self.gang.colour     = def.colour
    self.gang.isBoss     = grade.isBoss or false
    self.gang.gradeLabel = grade.name
end

function Player:getJob() return self.job end

function Player:getGang() return self.gang end

function Player:setJob(name, grade)
    local def = SeaM.Jobs[name]
    if not def then return false, ('unknown job "%s"'):format(name) end

    grade = tonumber(grade) or 0
    if not def.grades[grade] then return false, ('job "%s" has no grade %s'):format(name, grade) end

    local ctx = { player = self, job = name, grade = grade, previous = Util.deepCopy(self.job) }
    local allowed, reason = Hooks.run('job:change', ctx)
    if not allowed then return false, reason or 'cancelled by hook' end

    self.job = { name = ctx.job, grade = ctx.grade, onDuty = def.defaultDuty ~= false }
    self:refreshJob()
    self:markDirty('job')
    self:sync()

    TriggerEvent(SeaM.event('job:changed'), self.source, self.job, ctx.previous)
    TriggerClientEvent(SeaM.event('job:changed'), self.source, self.job, ctx.previous)
    return true
end

function Player:setDuty(onDuty)
    onDuty = onDuty and true or false
    if self.job.onDuty == onDuty then return true end

    self.job.onDuty = onDuty
    self:markDirty('job')
    self:sync()

    TriggerEvent(SeaM.event('duty:changed'), self.source, self.job.name, onDuty)
    TriggerClientEvent(SeaM.event('duty:changed'), self.source, self.job.name, onDuty)
    return true
end

function Player:hasJobPermission(permission)
    local list = self.job.permissions
    if not list then return false end
    for i = 1, #list do
        if list[i] == '*' or list[i] == permission then return true end
    end
    return false
end

function Player:setGang(name, grade)
    local def = SeaM.Gangs[name]
    if not def then return false, ('unknown gang "%s"'):format(name) end

    grade = tonumber(grade) or 0
    if not def.grades[grade] then return false, ('gang "%s" has no grade %s'):format(name, grade) end

    local ctx = { player = self, gang = name, grade = grade, previous = Util.deepCopy(self.gang) }
    local allowed, reason = Hooks.run('gang:change', ctx)
    if not allowed then return false, reason or 'cancelled by hook' end

    self.gang = { name = ctx.gang, grade = ctx.grade }
    self:refreshGang()
    self:markDirty('gang')
    self:sync()

    TriggerEvent(SeaM.event('gang:changed'), self.source, self.gang, ctx.previous)
    TriggerClientEvent(SeaM.event('gang:changed'), self.source, self.gang, ctx.previous)
    return true
end

function Player:getMeta(key)
    if key == nil then return Util.deepCopy(self.metadata) end
    local value = self.metadata[key]
    return type(value) == 'table' and Util.deepCopy(value) or value
end

function Player:setMeta(key, value)
    if type(key) ~= 'string' then return false end

    local ctx = { player = self, key = key, value = value, previous = self.metadata[key] }
    if not Hooks.run('metadata:set', ctx) then return false end

    self.metadata[ctx.key] = ctx.value
    self:markDirty('metadata')

    if SeaM.ReplicatedMetaSet[ctx.key] then self:sync() end

    TriggerEvent(SeaM.event('metadata:changed'), self.source, ctx.key, ctx.value, ctx.previous)
    return true
end

function Player:addMeta(key, delta, min, max)
    local result = (tonumber(self.metadata[key]) or 0) + (tonumber(delta) or 0)
    if min or max then result = Util.clamp(result, min or -math.huge, max or math.huge) end
    self:setMeta(key, result)
    return result
end

function Player:getSource()    return self.source end
function Player:getCitizenId() return self.citizenid end
function Player:getName()      return self.name end
function Player:getCharInfo()  return Util.deepCopy(self.charinfo) end

function Player:getPlaytime()
    return self.playtime + (os.time() - self.sessionStart)
end

function Player:getCoords()
    local ped = GetPlayerPed(self.source)
    local coords = GetEntityCoords(ped)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
end

function Player:hasGroup(group) return SeaM.Perms.has(self.source, group) end

function Player:notify(message, kind)
    TriggerClientEvent(SeaM.event('notify'), self.source, message, kind or 'inform')
end

function Player:kick(reason)
    DropPlayer(self.source, reason or 'Kicked by SeaM_Core')
end

SeaM.provide('PlayerClass', Player)
