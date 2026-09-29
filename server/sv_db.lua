local Config = SeaM.Config
local db = { ready = false }

local pending      = {}
local pendingOrder = {}
local pendingCount = 0

local function timed(label, fn, ...)
    local start = os.clock()
    local ok, result = pcall(fn, ...)
    local elapsed = (os.clock() - start) * 1000

    if not ok then
        SeaM.Log.error('db', ('%s failed: %s'):format(label, result))
        return nil, result
    end
    if elapsed >= Config.Persistence.SlowQueryMs then
        SeaM.Log.warn('db', ('slow query (%.1fms): %s'):format(elapsed, label))
    end
    return result
end

function db.query(query, params)
    return timed(query, MySQL.query.await, query, params) or {}
end

function db.single(query, params)
    return timed(query, MySQL.single.await, query, params)
end

function db.scalar(query, params)
    return timed(query, MySQL.scalar.await, query, params)
end

function db.execute(query, params)
    return timed(query, MySQL.update.await, query, params) or 0
end

function db.insert(query, params)
    return timed(query, MySQL.insert.await, query, params)
end

function db.transaction(queries)
    if #queries == 0 then return true end
    return timed('transaction', MySQL.transaction.await, queries) and true or false
end

function db.enqueue(key, query, params)
    if not pending[key] then
        pendingOrder[#pendingOrder + 1] = key
        pendingCount = pendingCount + 1
    end
    pending[key] = { query = query, values = params }
end

function db.enqueueUnique(query, params)
    db.enqueue(('append:%s'):format(SeaM.Util.uuid()), query, params)
end

function db.flush()
    if pendingCount == 0 then return 0 end

    local batch, count = {}, 0
    for i = 1, #pendingOrder do
        local job = pending[pendingOrder[i]]
        if job then
            count = count + 1
            batch[count] = { query = job.query, values = job.values }
        end
    end

    pending, pendingOrder, pendingCount = {}, {}, 0

    if not db.transaction(batch) then
        SeaM.Log.error('db', ('write queue flush failed - %d statement(s) lost'):format(count))
        return 0
    end

    SeaM.Log.trace('db', ('flushed %d statement(s)'):format(count))
    return count
end

function db.pendingCount() return pendingCount end

function db.tableExists(name)
    local found = db.scalar(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
        { name })
    return (found or 0) > 0
end

function db.requireTables(label, tables, sqlFile)
    while not db.ready do Wait(250) end

    local missing = {}
    for _, name in ipairs(tables) do
        if not db.tableExists(name) then missing[#missing + 1] = name end
    end

    if #missing > 0 then
        SeaM.Log.error(label, ('missing table(s): %s - import %s, then restart the resource')
            :format(table.concat(missing, ', '), sqlFile or 'the resource\'s SQL file'))
        return false
    end

    return true
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    Wait(500)

    local ok = pcall(function() return MySQL.scalar.await('SELECT 1') end)
    if not ok then
        SeaM.Log.error('db', 'could not reach the database - check your mysql_connection_string convar')
        return
    end

    local missing = {}
    for _, tableName in ipairs({ 'seam_players', 'seam_transactions', 'seam_bans', 'seam_sessions', 'seam_permissions' }) do
        local found = MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
            { tableName })
        if (found or 0) == 0 then missing[#missing + 1] = tableName end
    end

    if #missing > 0 then
        SeaM.Log.error('db', ('missing table(s): %s - import install/schema.sql')
            :format(table.concat(missing, ', ')))
        return
    end

    db.ready = true
    SeaM.Log.info('db', 'connected, schema verified')

    if Config.Ledger.Enabled and Config.Ledger.RetainDays > 0 then
        local pruned = db.execute(
            'DELETE FROM seam_transactions WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
            { Config.Ledger.RetainDays })
        if pruned > 0 then SeaM.Log.info('db', ('pruned %d old ledger row(s)'):format(pruned)) end
    end

    SeaM.markReady()

    local interval = Config.Persistence.FlushInterval * 1000
    while true do
        Wait(interval)
        local success, err = pcall(db.flush)
        if not success then SeaM.Log.error('db', ('flush loop error: %s'):format(err)) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= SeaM.Resource then return end
    db.flush()
end)

SeaM.provide('DB', db)
