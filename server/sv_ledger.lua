local Config = SeaM.Config.Ledger
local ledger = {}

function ledger.record(citizenid, account, delta, balance, reason, handler, actor)
    if not Config.Enabled then return end

    SeaM.DB.enqueueUnique(
        'INSERT INTO seam_transactions (citizenid, account, delta, balance, reason, handler, actor) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            citizenid,
            account,
            math.floor(delta),
            math.floor(balance),
            reason and reason:sub(1, 128) or nil,
            Config.TrackHandler and handler or nil,
            actor,
        })
end

function ledger.history(citizenid, limit, account)
    limit = math.min(tonumber(limit) or 25, 200)

    if account then
        return SeaM.DB.query(
            'SELECT account, delta, balance, reason, handler, actor, created_at FROM seam_transactions WHERE citizenid = ? AND account = ? ORDER BY id DESC LIMIT ?',
            { citizenid, account, limit })
    end

    return SeaM.DB.query(
        'SELECT account, delta, balance, reason, handler, actor, created_at FROM seam_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT ?',
        { citizenid, limit })
end

function ledger.summary(citizenid, hours)
    local rows = SeaM.DB.query(
        'SELECT account, SUM(delta) AS net, COUNT(*) AS moves FROM seam_transactions WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? HOUR) GROUP BY account',
        { citizenid, tonumber(hours) or 24 })

    local out = {}
    for _, row in ipairs(rows) do
        out[row.account] = { net = row.net, moves = row.moves }
    end
    return out
end

function ledger.economy(hours)
    return SeaM.DB.query([[
        SELECT account,
               SUM(CASE WHEN delta > 0 THEN delta ELSE 0 END) AS created,
               SUM(CASE WHEN delta < 0 THEN -delta ELSE 0 END) AS destroyed,
               COUNT(*) AS moves
        FROM seam_transactions
        WHERE created_at > DATE_SUB(NOW(), INTERVAL ? HOUR)
        GROUP BY account
    ]], { tonumber(hours) or 24 })
end

SeaM.provide('Ledger', ledger)
