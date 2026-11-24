--[[--
Hop lookup: a hop.nvim style word lookup for KOReader.

A Dispatcher action (`hop_lookup_action`) opens a full screen overlay that
tags every distinct word of the visible page. Typing the characters of a tag
narrows the tag set and looks the word up as soon as a tag is complete (no
Enter needed). The cursor can be moved over the words with the arrow
keys/D-pad, the page can be turned from within the overlay, and the word is
looked up either in GoldenDict or in KOReader's own dictionaries.

@module koplugin.hop_lookup
--]]--

local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Notification = require("ui/widget/notification")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")
local T = require("ffi/util").template

local Defaults = require("hoplookup_defaults")
local HintLayer = require("hoplookup_hintlayer")
local Lookup = require("hoplookup_lookup")

local HopLookup = WidgetContainer:extend{
    name = "hop_lookup",
    is_doc_only = true,
}

-- Name of the Dispatcher action (used by gestures, profiles, hotkeys, ...).
HopLookup.action_name = "hop_lookup_action"

local HOP_HELP = _([[
Tags every distinct word of the visible page. Type the characters of a tag to
narrow the tag set: the word is looked up as soon as its tag is complete.

Left/Right move to the previous/next word, Up/Down to the closest word above
or below, F6/PageUp and F7/PageDown turn the page and rescan, and Backspace
undoes a typed character. Esc, Ctrl+H or a tap closes the overlay.

To look a word up: open the overlay, then type the tag shown *on* the word (a
tag of two letters is typed one letter after the other); the word is looked up
as soon as its tag is complete, no Enter needed. Enter looks up the word under
the cursor. Esc / Ctrl+H close the overlay *without* looking anything up.

Inside the overlay, the context menu key (the PC application/right click menu
key, the Kindle Menu button, a gamepad face button) or F10 switches GoldenDict
between its popup and main window; the current mode is shown at the bottom of
the screen. It can also be set here, with "GoldenDict window".]])

local BACKEND_TITLES = {
    auto = _("auto (GoldenDict, then built-in)"),
    goldendict = _("GoldenDict"),
    internal = _("built-in dictionary"),
}

local WINDOW_TITLES = {
    popup = _("popup window"),
    main = _("main window"),
}

local CURSOR_TITLES = {
    center = _("word closest to the middle of the screen"),
    first = _("first word of the page"),
    none = _("no cursor until an arrow key is pressed"),
}

function HopLookup:init()
    self.config = Defaults.read()
    self.pending_lookup = nil
    self.hint_layer = nil
    self:onDispatcherRegisterActions()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function HopLookup:onDispatcherRegisterActions()
    Dispatcher:registerAction(HopLookup.action_name, {
        category = "none",
        event = "HopLookup",
        title = _("Hop lookup (tag words)"),
        reader = true,
        separator = true,
    })
end

----------------------------------------------------------------------
-- Menu
----------------------------------------------------------------------

function HopLookup:addToMainMenu(menu_items)
    menu_items.hop_lookup = {
        text = _("Hop lookup"),
        help_text = HOP_HELP,
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Start hop lookup"),
                callback = function()
                    self:start()
                end,
                separator = true,
            },
            self:charset_menu_item(),
            self:choice_menu_item("backend", _("Lookup backend"), BACKEND_TITLES, Defaults.backends),
            self:choice_menu_item("goldendict_window", _("GoldenDict window"), WINDOW_TITLES,
                Defaults.goldendict_windows,
                _("Which GoldenDict window to use. It can also be toggled from inside the overlay with the context menu key or F10.")),
            self:path_menu_item(),
            {
                text = _("Check GoldenDict"),
                help_text = _("Shows which GoldenDict was found and which command line would be used."),
                callback = function()
                    self:show_goldendict_status()
                end,
                keep_menu_open = true,
            },
            {
                text = _("Test GoldenDict lookup"),
                help_text = _("Sends a test word to GoldenDict and shows whether the shell works, "
                    .. "whether the executable really runs and which command line is used."),
                callback = function()
                    self:test_goldendict()
                end,
                keep_menu_open = true,
            },
            {
                text = _("Uppercase tags"),
                checked_func = function()
                    return self.config.label_uppercase
                end,
                callback = function(touchmenu_instance)
                    self:update_config("label_uppercase", not self.config.label_uppercase, touchmenu_instance)
                end,
                keep_menu_open = true,
            },
            self:spin_menu_item("min_word_length", _("Minimum word length"), 1, 64, 1, "%d"),
            self:choice_menu_item("initial_cursor", _("Initial cursor"), CURSOR_TITLES, Defaults.initial_cursors),
            self:spin_menu_item("lookup_debounce", _("Lookup debounce"), 0, 2000, 50, _("%d ms")),
        },
    }
end

function HopLookup:update_config(key, value, touchmenu_instance)
    self.config[key] = value
    self:save_config(self.config)
    if touchmenu_instance then
        touchmenu_instance:updateItems()
    end
end

function HopLookup:save_config(config)
    self.config = Defaults.write(config or self.config)
    return self.config
end

--[[--
A menu entry cycling through a fixed list of values.
]]
function HopLookup:choice_menu_item(key, title, value_titles, values, help_text)
    local plugin = self
    return {
        help_text = help_text,
        text_func = function()
            local current = plugin.config[key]
            return T(_("%1: %2"), title, value_titles[current] or current)
        end,
        sub_item_table_func = function()
            local items = {}
            for _index, value in ipairs(values) do
                items[#items + 1] = {
                    text = value_titles[value] or value,
                    checked_func = function()
                        return plugin.config[key] == value
                    end,
                    callback = function(touchmenu_instance)
                        plugin:update_config(key, value, touchmenu_instance)
                    end,
                    keep_menu_open = true,
                }
            end
            return items
        end,
    }
end

--[[--
A menu entry opening a number picker for one of the numeric settings.
`value_format` is a string.format() pattern used to render the current value.
]]
function HopLookup:spin_menu_item(key, title, value_min, value_max, value_step, value_format)
    local plugin = self
    return {
        text_func = function()
            local value = plugin.config[key]
            local text = string.format(value_format or "%d", value)
            return T(_("%1: %2"), title, text)
        end,
        callback = function(touchmenu_instance)
            local spin = SpinWidget:new{
                title_text = title,
                value = plugin.config[key],
                default_value = Defaults.values[key],
                value_min = value_min,
                value_max = value_max,
                value_step = value_step,
                value_hold_step = value_step * 10,
                precision = "%1d",
                callback = function(spin_widget)
                    plugin:update_config(key, spin_widget.value, touchmenu_instance)
                end,
            }
            UIManager:show(spin)
        end,
        keep_menu_open = true,
    }
end

--[[--
The tag charset: free text input, with a few ready made charsets.
]]
function HopLookup:charset_menu_item()
    local plugin = self
    return {
        text_func = function()
            return T(_("Tag charset: %1"), plugin.config.label_chars)
        end,
        sub_item_table_func = function()
            local items = {}
            for _index, preset in ipairs(Defaults.charset_presets) do
                items[#items + 1] = {
                    text = T(_("%1 (%2)"), preset[1], preset[2]),
                    checked_func = function()
                        return plugin.config.label_chars == preset[1]
                    end,
                    callback = function(touchmenu_instance)
                        plugin:update_config("label_chars", preset[1], touchmenu_instance)
                    end,
                    keep_menu_open = true,
                }
            end
            items[#items + 1] = {
                text = _("Custom charset…"),
                callback = function(touchmenu_instance)
                    plugin:show_text_input(
                        _("Tag charset"),
                        _("Characters used to build the word tags. Whitespace is ignored."),
                        plugin.config.label_chars,
                        function(text)
                            plugin:update_config("label_chars", text, touchmenu_instance)
                        end
                    )
                end,
                keep_menu_open = true,
            }
            return items
        end,
    }
end

function HopLookup:path_menu_item()
    local plugin = self
    return {
        text_func = function()
            return T(_("GoldenDict path: %1"), plugin.config.goldendict_path)
        end,
        callback = function(touchmenu_instance)
            plugin:show_text_input(
                _("GoldenDict path"),
                _("Path of the GoldenDict executable, or its command name if it is in $PATH."),
                plugin.config.goldendict_path,
                function(text)
                    plugin:update_config("goldendict_path", text, touchmenu_instance)
                end
            )
        end,
        keep_menu_open = true,
    }
end

--[[--
Small text input dialog helper.
]]
function HopLookup:show_text_input(title, description, value, callback)
    local dialog
    dialog = InputDialog:new{
        title = title,
        description = description,
        input = value,
        input_type = "text",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Set"),
                    is_enter_default = true,
                    callback = function()
                        local text = dialog:getInputText()
                        UIManager:close(dialog)
                        if text and text ~= "" then
                            callback(text)
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

--[[--
Show what the GoldenDict probe found (executable, variant, resulting command
line), so that a missing popup can be diagnosed without a terminal.
]]
function HopLookup:show_goldendict_status()
    self.config = Defaults.read()
    UIManager:show(InfoMessage:new{
        text = Lookup.describe(self.config),
        show_icon = false,
    })
end

--[[--
Send a test word to GoldenDict and show what actually happened: whether shell
commands work at all, whether the executable really runs, which command line
is used, and whether a GoldenDict process is left running.
]]
function HopLookup:test_goldendict()
    self.config = Defaults.read()
    UIManager:show(InfoMessage:new{
        text = Lookup.diagnostics(self.config, true),
        show_icon = false,
    })
end

--[[--
With the "auto" backend a missing GoldenDict falls back on the built-in
dictionary; say so once per configured path, otherwise it just looks like
nothing happened.
]]
function HopLookup:notify_goldendict_fallback(reason)
    local path = self.config.goldendict_path
    local key = path .. "|" .. tostring(reason)
    if self.warned_missing_goldendict == key then
        return
    end
    self.warned_missing_goldendict = key
    Notification:notify(T(_("GoldenDict not used (%1) — using the built-in dictionary"),
        reason or path))
end

----------------------------------------------------------------------
-- The overlay
----------------------------------------------------------------------

function HopLookup:onHopLookup()
    self:start()
    return true
end

function HopLookup:start()
    if self.hint_layer then
        -- Already open: leave it as it is (and keep the focus on it).
        return
    end
    if not self.ui or not self.ui.document then
        return
    end
    self.config = Defaults.read()
    local layer = HintLayer:new{
        ui = self.ui,
        config = self.config,
        plugin = self,
    }
    self.hint_layer = layer
    UIManager:show(layer)
    logger.dbg("hop_lookup: overlay opened")
end

--[[--
Run the configured lookup for `word` (called by the overlay once a tag is
complete). The optional `box` is the screen rectangle of the word, used by
the built-in dictionary to highlight it.

The lookup is delayed by `lookup_debounce` milliseconds so that a lookup is
not launched for every word of a fast typing burst; a new lookup within that
delay replaces the pending one.
]]
function HopLookup:lookup_word(word, box)
    if self.pending_lookup then
        UIManager:unschedule(self.pending_lookup)
        self.pending_lookup = nil
    end
    local function perform()
        self.pending_lookup = nil
        if not self.ui or not self.ui.document then
            return
        end
        local backend, failure, reason = Lookup.perform(self.ui, self.config, word, box)
        if backend == "goldendict" then
            logger.dbg("hop_lookup: lookup of", word, "done with", backend)
            -- Short feedback: GoldenDict may take a moment, or be hidden
            -- behind the reader, so say that the word was handed over.
            Notification:notify(T(_("→ GoldenDict: %1"), word))
        elseif backend == "internal" then
            if self.config.backend == "auto" then
                self:notify_goldendict_fallback(reason)
            else
                logger.dbg("hop_lookup: lookup of", word, "done with", backend)
            end
        elseif failure == "goldendict" then
            if reason then
                Notification:notify(T(_("GoldenDict cannot be used: %1"), reason))
            else
                Notification:notify(T(_("GoldenDict not found: %1"), self.config.goldendict_path))
            end
        end
    end
    local delay = (self.config.lookup_debounce or 0) / 1000
    if delay > 0 then
        self.pending_lookup = perform
        UIManager:scheduleIn(delay, perform)
    else
        perform()
    end
end

function HopLookup:onCloseDocument()
    -- Make sure nothing is left over when the document goes away.
    if self.pending_lookup then
        UIManager:unschedule(self.pending_lookup)
        self.pending_lookup = nil
    end
    if self.hint_layer then
        self.hint_layer:close()
        self.hint_layer = nil
    end
end

return HopLookup
