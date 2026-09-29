local Schema = SeaM.Schema
local Config = SeaM.Config

local accountSpec = {
    type = 'table',
    fields = {
        name          = { type = 'string', min = 1, max = 24 },
        label         = { type = 'string', min = 1 },
        default       = { type = 'number', default = 0 },
        allowNegative = { type = 'boolean', default = false },
        hidden        = { type = 'boolean', default = false },
    },
}

local configSpec = {
    type = 'table',
    fields = {
        Locale   = { type = 'string', default = 'en' },
        LogLevel = { type = 'string', default = 'info', oneOf = { 'trace', 'debug', 'info', 'warn', 'error' } },

        Server = {
            type = 'table',
            fields = {
                Name          = { type = 'string', min = 1 },
                MaxCharacters = { type = 'integer', min = 1, max = 20 },
                UseDeferrals  = { type = 'boolean', default = true },
                RequiredIdent = { type = 'string', oneOf = { 'license', 'license2', 'discord', 'steam', 'fivem' } },
                WhitelistOnly    = { type = 'boolean', default = false },
                CoreHandlesSpawn = { type = 'boolean', default = false },
            },
        },

        Persistence = {
            type = 'table',
            fields = {
                AutosaveInterval = { type = 'integer', min = 30, max = 3600 },
                FlushInterval    = { type = 'integer', min = 1, max = 60 },
                SaveOnDrop       = { type = 'boolean', default = true },
                SlowQueryMs      = { type = 'integer', min = 10, default = 150 },
            },
        },

        Accounts = {
            type = 'array', of = accountSpec, min = 1,
            check = function(list)
                local seen = {}
                for i = 1, #list do
                    if seen[list[i].name] then
                        return false, ('contains duplicate account "%s"'):format(list[i].name)
                    end
                    seen[list[i].name] = true
                end
                return true
            end,
        },

        Ledger = {
            type = 'table',
            fields = {
                Enabled      = { type = 'boolean', default = true },
                RetainDays   = { type = 'integer', min = 0, default = 30 },
                TrackHandler = { type = 'boolean', default = true },
            },
        },

        Defaults = {
            type = 'table',
            fields = {
                Job   = { type = 'table' },
                Gang  = { type = 'table' },
                Spawn = {
                    type = 'table',
                    fields = {
                        x = { type = 'number' }, y = { type = 'number' },
                        z = { type = 'number' }, w = { type = 'number', default = 0.0 },
                    },
                },
                Metadata       = { type = 'table' },
                ReplicatedMeta = { type = 'array', of = { type = 'string' } },
            },
        },

        Permissions = {
            type = 'table',
            fields = {
                Groups            = { type = 'array', min = 1 },
                SyncAcePrincipals = { type = 'boolean', default = false },
                MapAceGroups      = { type = 'boolean', default = true },
                AceGroups         = { type = 'table' },
            },
        },

        RateLimits = {
            type = 'table',
            fields = {
                Enabled             = { type = 'boolean', default = true },
                Buckets             = { type = 'table' },
                KickAfterViolations = { type = 'integer', min = 0, default = 40 },
            },
        },

        Callbacks = {
            type = 'table',
            fields = { TimeoutMs = { type = 'integer', min = 1000, max = 60000, default = 10000 } },
        },

        Admin = {
            type = 'table',
            fields = {
                NoclipSpeeds          = { type = 'array', of = { type = 'number' }, min = 1 },
                ReplaceSpawnedVehicle = { type = 'boolean', default = true },
                AnnounceTitle         = { type = 'string', default = 'Announcement' },
                LogActions            = { type = 'boolean', default = true },
            },
        },

        Prompts = {
            type = 'table',
            fields = {
                position = { type = 'string', default = 'bottom-center',
                    oneOf = { 'bottom-center', 'center-right', 'center-left' } },
            },
        },

        Notifications = {
            type = 'table',
            fields = {
                position = { type = 'string', default = 'top-right',
                    oneOf = { 'top-right', 'top-left', 'bottom-right', 'bottom-left' } },
                duration   = { type = 'integer', min = 500, max = 30000, default = 4000 },
                maxVisible = { type = 'integer', min = 1, max = 12, default = 4 },
                accent     = { type = 'string', default = '#4fd1c5' },
            },
        },

        Logging = {
            type = 'table',
            fields = {
                Enabled  = { type = 'boolean', default = false },
                Username = { type = 'string', default = 'SeaM_Core' },
                Webhooks = { type = 'table' },
            },
        },
    },
}

Schema.assert(Config, configSpec, 'SeaM.Config')

local errors = {}

if not SeaM.Jobs[Config.Defaults.Job.name] then
    errors[#errors + 1] = ('Defaults.Job.name "%s" is not defined in config/jobs.lua')
        :format(Config.Defaults.Job.name)
end
if not SeaM.Gangs[Config.Defaults.Gang.name] then
    errors[#errors + 1] = ('Defaults.Gang.name "%s" is not defined in config/gangs.lua')
        :format(Config.Defaults.Gang.name)
end

for name, job in pairs(SeaM.Jobs) do
    if type(job.grades) ~= 'table' or not next(job.grades) then
        errors[#errors + 1] = ('job "%s" has no grades'):format(name)
    elseif not job.grades[0] then
        errors[#errors + 1] = ('job "%s" must define grade 0'):format(name)
    end
end

for name, gang in pairs(SeaM.Gangs) do
    if type(gang.grades) ~= 'table' or not gang.grades[0] then
        errors[#errors + 1] = ('gang "%s" must define grade 0'):format(name)
    end
end

for _, key in ipairs(Config.Defaults.ReplicatedMeta) do
    if Config.Defaults.Metadata[key] == nil then
        errors[#errors + 1] = ('ReplicatedMeta lists "%s" which is not in Defaults.Metadata'):format(key)
    end
end

if #errors > 0 then
    print(('^1[SeaM_Core] %d configuration error(s):^0'):format(#errors))
    for i = 1, #errors do print(('^1  %d. %s^0'):format(i, errors[i])) end
    error('SeaM_Core refused to start with an invalid configuration', 0)
end

SeaM.Log.level      = Config.LogLevel
SeaM.Locale.current = Config.Locale

SeaM.AccountIndex    = {}
SeaM.AccountDefaults = {}
for _, account in ipairs(Config.Accounts) do
    SeaM.AccountIndex[account.name] = account
    SeaM.AccountDefaults[account.name] = account.default
end

SeaM.ReplicatedMetaSet = {}
for _, key in ipairs(Config.Defaults.ReplicatedMeta) do
    SeaM.ReplicatedMetaSet[key] = true
end

CreateThread(function()
    if GetResourceState('oxmysql') ~= 'started' then
        SeaM.Log.error('boot', ('dependency "oxmysql" is not started (state: %s)')
            :format(GetResourceState('oxmysql')))
    end

    if GetConvar('onesync', 'off') == 'off' then
        SeaM.Log.warn('boot', 'OneSync appears to be disabled; state bag replication will not work')
    end

    print('^5' .. ([[
  ___          __  __   ___
 / __| ___ __ _|  \/  | / __|___ _ _ ___
 \__ \/ -_) _` | |\/| || (__/ _ \ '_/ -_)
 |___/\___\__,_|_|  |_| \___\___/_| \___|  v%s
]]):format(SeaM.Version) .. '^0')

    SeaM.Log.info('boot', ('config validated - %d accounts, %d jobs, %d gangs')
        :format(#Config.Accounts, SeaM.Util.count(SeaM.Jobs), SeaM.Util.count(SeaM.Gangs)))
end)
