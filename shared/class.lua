local function instantiate(cls, ...)
    local self = setmetatable({}, cls)
    local ctor = cls.constructor
    if ctor then ctor(self, ...) end
    return self
end

local function class(name, base)
    local cls = {}
    cls.__name  = name
    cls.__index = cls
    cls.__base  = base

    if base then
        setmetatable(cls, { __index = base, __call = instantiate })
    else
        setmetatable(cls, { __call = instantiate })
    end

    cls.__tostring = function(self)
        return ('%s<%s>'):format(name, self.citizenid or self.id or 'anon')
    end

    function cls:extend(childName) return class(childName, self) end

    function cls:parent(method, ...)
        local meta = getmetatable(self)
        local base_ = meta and meta.__base
        if not base_ or not base_[method] then
            error(('no parent method "%s"'):format(method), 2)
        end
        return base_[method](self, ...)
    end

    function cls:isA(other)
        local c = getmetatable(self)
        while c do
            if c == other then return true end
            c = c.__base
        end
        return false
    end

    return cls
end

SeaM.class = class
