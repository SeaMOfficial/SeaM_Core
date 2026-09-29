--- SeaM_Core :: jobs
--- Grades are a sparse map keyed by grade level, so you can jump 0 -> 2 -> 4.
--- `payment` is the base paycheck, `isBoss` unlocks management menus in
--- resources that ask the core, and `permissions` are job-scoped strings
--- checked with player:hasJobPermission('...'). '*' grants everything.

SeaM.Jobs = {
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = true,
        grades = {
            [0] = { name = 'Freelancer', payment = 10 },
        },
    },

    police = {
        label = 'Los Santos Police',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Cadet',      payment = 50,  permissions = { 'cuff', 'search' } },
            [1] = { name = 'Officer',    payment = 75,  permissions = { 'cuff', 'search', 'impound' } },
            [2] = { name = 'Sergeant',   payment = 100, permissions = { 'cuff', 'search', 'impound', 'evidence' } },
            [3] = { name = 'Lieutenant', payment = 125, permissions = { 'cuff', 'search', 'impound', 'evidence' } },
            [4] = { name = 'Chief',      payment = 150, isBoss = true, permissions = { '*' } },
        },
    },

    ambulance = {
        label = 'Pillbox Medical',
        type = 'ems',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Trainee',   payment = 50,  permissions = { 'treat' } },
            [1] = { name = 'Paramedic', payment = 75,  permissions = { 'treat', 'revive' } },
            [2] = { name = 'Doctor',    payment = 100, permissions = { 'treat', 'revive', 'surgery' } },
            [3] = { name = 'Chief',     payment = 150, isBoss = true, permissions = { '*' } },
        },
    },

    mechanic = {
        label = "Benny's Motorworks",
        grades = {
            [0] = { name = 'Apprentice', payment = 40 },
            [1] = { name = 'Mechanic',   payment = 60, permissions = { 'tune' } },
            [2] = { name = 'Owner',      payment = 90, isBoss = true, permissions = { '*' } },
        },
    },

    taxi = {
        label = 'Downtown Cab Co.',
        grades = {
            [0] = { name = 'Driver', payment = 35 },
            [1] = { name = 'Owner',  payment = 70, isBoss = true, permissions = { '*' } },
        },
    },
}
