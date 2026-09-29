local logger = {}

local LEVELS  = { trace = 1, debug = 2, info = 3, warn = 4, error = 5 }
local COLOURS = { trace = '^8', debug = '^5', info = '^2', warn = '^3', error = '^1' }
local EMBED   = { trace = 9807270, debug = 3447003, info = 3066993, warn = 16776960, error = 15158332 }

logger.level = 'info'

local function shouldLog(level)
    return (LEVELS[level] or 3) >= (LEVELS[logger.level] or 3)
end

local function stringify(...)
    local parts = {}
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        parts[i] = type(v) == 'table' and json.encode(v) or tostring(v)
    end
    return table.concat(parts, ' ')
end

function logger.write(level, tag, ...)
    if not shouldLog(level) then return end
    print(('%s[SeaM:%s]^7 [%s] %s^0'):format(
        COLOURS[level] or '^7', level:upper(), tag or 'core', stringify(...)))
end

for level in pairs(LEVELS) do
    logger[level] = function(tag, ...) logger.write(level, tag, ...) end
end

function logger.audit(channel, title, message, level)
    level = level or 'info'
    logger.write(level, channel, title .. ' :: ' .. message)

    if not SeaM.IsServer then return end
    local cfg = SeaM.Config and SeaM.Config.Logging
    if not cfg or not cfg.Enabled then return end

    local url = cfg.Webhooks[channel] or cfg.Webhooks.default
    if not url or url == '' then return end

    local payload = json.encode({
        username = cfg.Username or 'SeaM_Core',
        embeds = { {
            title = title,
            description = message,
            color = EMBED[level] or EMBED.info,
            footer = { text = ('%s | %s'):format(channel, os.date('%Y-%m-%d %H:%M:%S')) },
        } },
    })

    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            logger.write('warn', 'logger', ('discord webhook "%s" returned %s'):format(channel, status))
        end
    end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

SeaM.provide('Log', logger)
