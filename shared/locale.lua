local locale = { current = 'en', strings = {} }

function locale.register(lang, entries)
    locale.strings[lang] = locale.strings[lang] or {}
    for k, v in pairs(entries) do locale.strings[lang][k] = v end
end

function locale.t(key, ...)
    local pack = locale.strings[locale.current] or locale.strings.en or {}
    local str = pack[key] or (locale.strings.en and locale.strings.en[key]) or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        return ok and formatted or str
    end
    return str
end

SeaM.provide('Locale', locale)
SeaM.t = locale.t
