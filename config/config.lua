--- SeaM_Core :: main configuration
--- Every value here is validated at boot by server/sv_boot.lua. If you mistype
--- something the server tells you exactly which key is wrong and refuses to
--- start, rather than crashing later.

SeaM.Config = {
    Locale   = 'en',
    LogLevel = 'info', -- trace | debug | info | warn | error

    Server = {
        Name          = 'SeaM Roleplay',
        MaxCharacters = 3,     -- character slots per license
        UseDeferrals  = true,  -- show the connection card while we check bans
        RequiredIdent = 'license',
        WhitelistOnly = false, -- require ace permission `seam.join`
        --- Leave false when a multicharacter resource owns spawning (the usual
        --- case). Set true only if nothing else moves the player on login.
        CoreHandlesSpawn = false,
    },

    Persistence = {
        AutosaveInterval = 300, -- seconds between full autosaves
        FlushInterval    = 5,   -- seconds between write-queue flushes
        SaveOnDrop       = true,
        SlowQueryMs      = 150, -- warn when a query takes longer than this
    },

    Accounts = {
        -- The framework is account-agnostic: add or remove entries freely.
        -- `allowNegative` lets an account go below zero (useful for a debt/tab
        -- account); `hidden` keeps it out of the client snapshot.
        { name = 'cash',   label = 'Cash',   default = 500,  allowNegative = false, hidden = false },
        { name = 'bank',   label = 'Bank',   default = 5000, allowNegative = false, hidden = false },
        { name = 'crypto', label = 'Crypto', default = 0,    allowNegative = false, hidden = true  },
    },

    Ledger = {
        Enabled      = true, -- record every balance change in seam_transactions
        RetainDays   = 30,   -- pruned on boot; 0 disables pruning
        TrackHandler = true, -- store which resource caused the change
    },

    Defaults = {
        Job   = { name = 'unemployed', grade = 0, onDuty = true },
        Gang  = { name = 'none', grade = 0 },
        Spawn = { x = -1035.71, y = -2731.87, z = 12.86, w = 240.0 },
        Metadata = {
            hunger      = 100,
            thirst      = 100,
            stress      = 0,
            isDead      = false,
            inLastStand = false,
            armour      = 0,
            health      = 200,
            fingerprint = false, -- generated on first login
            phone       = false,
            licences    = { driver = false, weapon = false, business = false },
            jailed      = 0,
        },
        --- Metadata keys replicated to the owning client's state bag. Anything
        --- not listed stays server-side only, which keeps the bag small and
        --- stops clients reading data they have no business seeing.
        ReplicatedMeta = {
            'hunger', 'thirst', 'stress', 'isDead', 'inLastStand',
            'armour', 'health', 'licences', 'phone', 'jailed',
        },
    },

    Permissions = {
        --- Groups inherit in a single chain: an `admin` satisfies `mod` and
        --- `user` checks automatically.
        Groups = {
            { name = 'user',  label = 'User',          inherits = nil     },
            { name = 'vip',   label = 'VIP',           inherits = 'user'  },
            { name = 'mod',   label = 'Moderator',     inherits = 'vip'   },
            { name = 'admin', label = 'Administrator', inherits = 'mod'   },
            { name = 'owner', label = 'Owner',         inherits = 'admin' },
        },
        --- Mirror groups onto FiveM ace principals (group.seam.admin etc), so
        --- other resources can check them.
        ---
        --- Off by default because writing principals is a privileged command.
        --- A resource cannot run it unless the server explicitly allows it, and
        --- without that every attempt is refused in the console. Turn this on
        --- only if you also add these to server.cfg:
        ---
        ---     add_ace resource.SeaM_Core command.add_ace allow
        ---     add_ace resource.SeaM_Core command.add_principal allow
        ---     add_ace resource.SeaM_Core command.remove_principal allow
        ---
        --- Nothing here needs it: reading aces works without any of that.
        SyncAcePrincipals = false,

        --- Standard FiveM ace groups that count as a SeaM group.
        ---
        --- This is what makes an ordinary server.cfg work as-is:
        ---
        ---     add_ace group.admin command allow
        ---     add_principal identifier.discord:123456 group.admin
        ---
        --- With `group.admin` mapped to `admin` below, that person is an admin
        --- here too, without being added to the database. Nothing else in
        --- your cfg has to change: the group is read, never written.
        ---
        --- Someone who is an admin both ways gets whichever rank is higher.
        ---
        --- This needs one line in server.cfg, because reading an ace group
        --- means first granting the core an ace to read:
        ---
        ---     add_ace resource.SeaM_Core command.add_ace allow
        ---
        --- Being a *member* of group.admin does not make "group.admin" an ace
        --- object anyone can test for, so the core grants group.admin the
        --- seam.admin ace at boot and tests that instead. Without the line
        --- above it says so once in the console rather than failing quietly.
        MapAceGroups = true,

        AceGroups = {
            ['group.superadmin'] = 'owner',
            ['group.owner']      = 'owner',
            ['group.admin']      = 'admin',
            ['group.moderator']  = 'mod',
            ['group.mod']        = 'mod',
            ['group.vip']        = 'vip',
        },
    },

    RateLimits = {
        --- Token bucket per player. `rate` tokens are restored per second up to
        --- `burst`. A request that cannot pay is dropped and counted.
        Enabled = true,
        Buckets = {
            callback = { rate = 12, burst = 24 },
            command  = { rate = 4,  burst = 8  },
            event    = { rate = 20, burst = 40 },
        },
        KickAfterViolations = 40, -- 0 disables auto-kick
    },

    Callbacks = {
        TimeoutMs = 10000, -- client-side wait before a callback rejects
    },

    Admin = {
        --- Speeds cycled with the scroll wheel while noclipping, slowest first.
        NoclipSpeeds = { 0.4, 1.2, 4.0, 12.0, 30.0 },

        --- Vehicles spawned with /car are deleted when the admin spawns another
        --- one, so a night of testing does not leave a car park behind.
        ReplaceSpawnedVehicle = true,

        --- Heading shown above an /announce message.
        AnnounceTitle = 'Announcement',


        --- Every admin action is written to the log and, if you have the
        --- webhook set, to the `admin` Discord channel.
        LogActions = true,
    },

    Prompts = {
        --- Where the "[E] Do the thing" prompt sits when you walk into a point.
        position = 'bottom-center', -- 'bottom-center' | 'center-right' | 'center-left'
    },

    Notifications = {
        --- Where the stack sits. Toasts fill downwards from a top corner and
        --- upwards from a bottom one.
        position   = 'top-right', -- 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left'
        duration   = 4000,        -- default lifetime in milliseconds
        maxVisible = 4,           -- older toasts are retired past this
        accent     = '#b7843b',
    },

    Logging = {
        Enabled  = false, -- set true and fill in the webhooks below
        Username = 'SeaM_Core',
        Webhooks = {
            default   = '',
            money     = '',
            join      = '',
            admin     = '',
            anticheat = '',
        },
    },
}
