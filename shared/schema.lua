local schema = {}

local function typeOf(value)
    local t = type(value)
    if t ~= 'table' then return t end
    return (#value > 0 or next(value) == nil) and 'array' or 'table'
end

local function validateValue(value, spec, path, errors)
    if value == nil then
        if spec.default ~= nil then return SeaM.Util.deepCopy(spec.default) end
        if spec.required == false then return nil end
        errors[#errors + 1] = ('%s is required'):format(path)
        return nil
    end

    local expected, actual = spec.type or 'any', typeOf(value)

    if expected == 'integer' then
        if actual ~= 'number' or value % 1 ~= 0 then
            errors[#errors + 1] = ('%s must be a whole number, got %s'):format(path, tostring(value))
            return value
        end
    elseif expected == 'array' or expected == 'table' then
        if type(value) ~= 'table' then
            errors[#errors + 1] = ('%s must be a %s, got %s'):format(path, expected, actual)
            return value
        end
    elseif expected ~= 'any' and actual ~= expected then
        errors[#errors + 1] = ('%s must be a %s, got %s'):format(path, expected, actual)
        return value
    end

    if spec.min or spec.max then
        local n = (expected == 'string' or expected == 'array') and #value or value
        if spec.min and n < spec.min then
            errors[#errors + 1] = ('%s must be >= %s'):format(path, spec.min)
        end
        if spec.max and n > spec.max then
            errors[#errors + 1] = ('%s must be <= %s'):format(path, spec.max)
        end
    end

    if spec.oneOf and not SeaM.Util.contains(spec.oneOf, value) then
        errors[#errors + 1] = ('%s must be one of: %s'):format(path, table.concat(spec.oneOf, ', '))
    end

    if spec.fields then
        for key, childSpec in pairs(spec.fields) do
            value[key] = validateValue(value[key], childSpec, ('%s.%s'):format(path, key), errors)
        end
    end

    if spec.of then
        for i = 1, #value do
            value[i] = validateValue(value[i], spec.of, ('%s[%d]'):format(path, i), errors)
        end
    end

    if spec.check then
        local ok, reason = spec.check(value)
        if not ok then
            errors[#errors + 1] = ('%s %s'):format(path, reason or 'failed validation')
        end
    end

    return value
end

function schema.validate(value, spec, label)
    local errors = {}
    validateValue(value, spec, label or 'config', errors)
    return #errors == 0, errors
end

function schema.assert(value, spec, label)
    local ok, errors = schema.validate(value, spec, label)
    if ok then return true end
    print(('^1[SeaM_Core] %d configuration error(s):^0'):format(#errors))
    for i = 1, #errors do print(('^1  %d. %s^0'):format(i, errors[i])) end
    error('SeaM_Core refused to start with an invalid configuration', 0)
end

SeaM.provide('Schema', schema)
