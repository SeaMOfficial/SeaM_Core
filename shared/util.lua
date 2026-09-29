local util = {}

local floor, random, format = math.floor, math.random, string.format
local insert, concat = table.insert, table.concat

function util.round(n, places)
    local mult = 10 ^ (places or 0)
    return floor(n * mult + 0.5) / mult
end

function util.clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

function util.trim(str) return (str:gsub('^%s*(.-)%s*$', '%1')) end

function util.split(str, sep)
    sep = sep or '%s'
    local out = {}
    for piece in str:gmatch('([^' .. sep .. ']+)') do out[#out + 1] = piece end
    return out
end

local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

function util.randomString(len)
    local buf = {}
    for i = 1, len do
        local idx = random(#charset)
        buf[i] = charset:sub(idx, idx)
    end
    return concat(buf)
end

function util.uuid()
    return (('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(c)
        local v = (c == 'x') and random(0, 15) or random(8, 11)
        return format('%x', v)
    end))
end

function util.deepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = util.deepCopy(v) end
    return setmetatable(out, getmetatable(tbl))
end

function util.merge(target, source)
    for k, v in pairs(source) do
        if type(v) == 'table' and type(target[k]) == 'table' then
            util.merge(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

function util.defaults(tbl, defaults)
    tbl = tbl or {}
    for k, v in pairs(defaults) do
        if tbl[k] == nil then
            tbl[k] = type(v) == 'table' and util.deepCopy(v) or v
        elseif type(v) == 'table' and type(tbl[k]) == 'table' then
            util.defaults(tbl[k], v)
        end
    end
    return tbl
end

function util.find(tbl, predicate)
    for k, v in pairs(tbl) do
        if predicate(v, k) then return v, k end
    end
end

function util.filter(tbl, predicate)
    local out = {}
    for k, v in pairs(tbl) do
        if predicate(v, k) then out[#out + 1] = v end
    end
    return out
end

function util.count(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

function util.keys(tbl)
    local out = {}
    for k in pairs(tbl) do out[#out + 1] = k end
    return out
end

function util.contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

function util.formatMoney(amount, symbol)
    local whole, fraction = format('%.2f', math.abs(amount)):match('^(%d+)%.(%d+)$')
    local grouped = whole:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return format('%s%s%s.%s', amount < 0 and '-' or '', symbol or '$', grouped, fraction)
end

function util.formatDuration(seconds)
    local d = floor(seconds / 86400)
    local h = floor(seconds % 86400 / 3600)
    local m = floor(seconds % 3600 / 60)
    local parts = {}
    if d > 0 then insert(parts, d .. 'd') end
    if h > 0 then insert(parts, h .. 'h') end
    if m > 0 or #parts == 0 then insert(parts, m .. 'm') end
    return concat(parts, ' ')
end

function util.isCallable(value)
    if type(value) == 'function' then return true end
    if value == nil then return false end

    local ok, meta = pcall(getmetatable, value)
    return ok and type(meta) == 'table' and meta.__call ~= nil
end

function util.sanitize(str, maxLen)
    if type(str) ~= 'string' then return nil end
    str = str:gsub("[^%w%s%-%_%.%,']", '')
    str = util.trim(str)
    if maxLen and #str > maxLen then str = str:sub(1, maxLen) end
    return #str > 0 and str or nil
end

SeaM.provide('Util', util)
