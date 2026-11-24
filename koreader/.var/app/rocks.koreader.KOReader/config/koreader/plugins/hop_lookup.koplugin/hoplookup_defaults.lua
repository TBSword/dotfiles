--[[--
Default configuration of the hop lookup plugin.

The plugin has exactly 8 settings, all stored in a single table under the
`hop_lookup` key of G_reader_settings:

    label_chars       string   charset used to build the word tags
    backend           string   "auto" | "goldendict" | "internal"
    goldendict_window string   "popup" | "main"
    goldendict_path   string   path or command name of the goldendict binary
    label_uppercase   boolean  display (and accept) tags in uppercase
    min_word_length   number   words shorter than this are not tagged
    initial_cursor    string   "center" | "first" | "none"
    lookup_debounce   number   milliseconds to wait before looking a word up

@module koplugin.hop_lookup.hoplookup_defaults
--]]--

local Defaults = {}

-- G_reader_settings key holding the whole configuration table.
Defaults.settings_key = "hop_lookup"

-- Keys, in the order they are shown in the menu.
Defaults.order = {
    "label_chars",
    "backend",
    "goldendict_window",
    "goldendict_path",
    "label_uppercase",
    "min_word_length",
    "initial_cursor",
    "lookup_debounce",
}

Defaults.values = {
    label_chars = "asdfghjkl",
    backend = "auto",
    goldendict_window = "popup",
    goldendict_path = "goldendict",
    label_uppercase = false,
    min_word_length = 2,
    initial_cursor = "center",
    lookup_debounce = 200,
}

-- Allowed values for the enum-like settings.
Defaults.backends = { "auto", "goldendict", "internal" }
Defaults.goldendict_windows = { "popup", "main" }
Defaults.initial_cursors = { "center", "first", "none" }

-- A few ready made charsets, offered in the "tag charset" dialog.
Defaults.charset_presets = {
    { "asdfghjkl", "home row (asdfghjkl)" },
    { "asdfghjklqwertyuiop", "home row + top row" },
    { "abcdefghijklmnopqrstuvwxyz", "alphabet" },
    { "1234567890", "digits" },
}

local function is_one_of(value, list)
    for _, v in ipairs(list) do
        if value == v then return true end
    end
    return false
end

--[[--
Return a complete, sanitized configuration table.

Any missing or invalid value falls back to the default one, so the rest of
the plugin never has to check the configuration again.
]]
function Defaults.normalize(config)
    local cfg = {}
    for k, v in pairs(Defaults.values) do
        cfg[k] = v
    end
    if type(config) == "table" then
        for k, v in pairs(config) do
            if cfg[k] ~= nil then
                cfg[k] = v
            end
        end
    end

    if type(cfg.label_chars) ~= "string" or cfg.label_chars == "" then
        cfg.label_chars = Defaults.values.label_chars
    end
    if not is_one_of(cfg.backend, Defaults.backends) then
        cfg.backend = Defaults.values.backend
    end
    if not is_one_of(cfg.goldendict_window, Defaults.goldendict_windows) then
        cfg.goldendict_window = Defaults.values.goldendict_window
    end
    if type(cfg.goldendict_path) ~= "string" or cfg.goldendict_path == "" then
        cfg.goldendict_path = Defaults.values.goldendict_path
    end
    cfg.label_uppercase = cfg.label_uppercase and true or false
    cfg.min_word_length = tonumber(cfg.min_word_length) or Defaults.values.min_word_length
    cfg.min_word_length = math.max(1, math.floor(cfg.min_word_length))
    if not is_one_of(cfg.initial_cursor, Defaults.initial_cursors) then
        cfg.initial_cursor = Defaults.values.initial_cursor
    end
    cfg.lookup_debounce = tonumber(cfg.lookup_debounce) or Defaults.values.lookup_debounce
    if cfg.lookup_debounce < 0 then
        cfg.lookup_debounce = 0
    end
    return cfg
end

--[[--
Read the configuration from G_reader_settings (KOReader only).
]]
function Defaults.read()
    local stored
    if G_reader_settings then
        stored = G_reader_settings:readSetting(Defaults.settings_key)
    end
    return Defaults.normalize(stored)
end

--[[--
Persist the configuration to G_reader_settings (KOReader only).
]]
function Defaults.write(config)
    local cfg = Defaults.normalize(config)
    if G_reader_settings then
        G_reader_settings:saveSetting(Defaults.settings_key, cfg)
    end
    return cfg
end

return Defaults
