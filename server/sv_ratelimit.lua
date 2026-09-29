local Config = SeaM.Config.RateLimits
local limiter = {}

local buckets    = {}
local violations = {}

local function bucketFor(source, name)
    local def = Config.Buckets[name]
    if not def then return nil end

    buckets[source] = buckets[source] or {}
    local bucket = buckets[source][name]

    if not bucket then
        bucket = { tokens = def.burst, last = os.clock() }
        buckets[source][name] = bucket
    end

    local now = os.clock()
    bucket.tokens = math.min(def.burst, bucket.tokens + (now - bucket.last) * def.rate)
    bucket.last = now
    return bucket
end

function limiter.consume(source, name, cost)
    if not Config.Enabled or source == 0 then return true end

    local bucket = bucketFor(source, name)
    if not bucket then return true end

    cost = cost or 1
    if bucket.tokens < cost then
        limiter.flag(source, name)
        return false
    end

    bucket.tokens = bucket.tokens - cost
    return true
end

function limiter.flag(source, reason)
    violations[source] = (violations[source] or 0) + 1
    local count = violations[source]

    SeaM.Log.debug('ratelimit', ('%s (%s) exceeded "%s" [%d]')
        :format(GetPlayerName(source) or '?', source, reason, count))

    local threshold = Config.KickAfterViolations
    if threshold > 0 and count >= threshold then
        SeaM.Log.audit('anticheat', 'Rate limit kick',
            ('`%s` (%s) hit %d violations, latest on `%s`')
                :format(GetPlayerName(source) or '?', source, count, reason), 'warn')
        DropPlayer(source, 'Kicked by SeaM_Core: too many requests.')
    end
end

function limiter.clear(source)
    buckets[source] = nil
    violations[source] = nil
end

function limiter.violations(source) return violations[source] or 0 end

AddEventHandler('playerDropped', function()
    limiter.clear(source)
end)

SeaM.provide('RateLimit', limiter)
