--[[--
The full screen hint overlay of the hop lookup plugin.

It draws a tag above every distinct word of the visible page, narrows the
tag set as characters are typed (looking the word up as soon as a tag is
complete, without Enter), moves a cursor over the words with the arrow
keys/D-pad, and can turn the page (F6/F7, PageUp/PageDown) and rescan.

    Esc / tap / Ctrl+H      close
    tag characters          narrow the tags, complete one to look it up
    Backspace               undo one typed character
    Left/Right              previous/next word (linear)
    Up/Down                 nearest word above/below (|dx| * 2 + |dy|)
    F6/PageUp, F7/PageDown  previous/next page, then rescan
    Context menu key / F10   toggle GoldenDict popup/main mode
    Enter                   look up the word under the cursor

@module koplugin.hop_lookup.hoplookup_hintlayer
--]]--

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")

local Labels = require("hoplookup_labels")
local Nav = require("hoplookup_nav")
local Scanner = require("hoplookup_scanner")

local Screen = Device.screen

local HintLayer = InputContainer:extend{
    -- Do not pretend to hide the reader: it must keep being repainted when
    -- we turn a page (we then take a fresh snapshot of the background).
    covers_fullscreen = false,
    modal = true,
}

local STATUS_TEXT = _("Esc close · tag lookup · Space/F6/F7 page · F10: GD mode")
local STATUS_TEXT_EMPTY = _("No word on this page · F6/F7 page · Esc close")

--[[--
Build a new overlay. `opts` must carry:
    ui      the reader UI
    config  the plugin configuration (see hoplookup_defaults)
    plugin  the plugin itself (used to run the lookup and to be told when
            the overlay is closed)
]]
function HintLayer:init()
    self.screen_w = Screen:getWidth()
    self.screen_h = Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.screen_h }

    self.label_face = Font:getFace("x_smallinfofont")
    self.label_bg = Blitbuffer.COLOR_BLACK
    self.label_fg = Blitbuffer.COLOR_WHITE
    self.label_pad_x = Screen:scaleBySize(3)
    self.label_pad_y = Screen:scaleBySize(1)
    self.label_gap = Screen:scaleBySize(1)
    self.margin = Screen:scaleBySize(4)

    self.text_widgets = {}
    self.typed_chars = {}
    self.typed = ""
    self.words = {}
    self.entries = {}
    self.matches = {}
    self.cursor = nil
    self.closed = false
    self.bg_bb = nil
    self.bg_invalid = true
    self.prev_region = nil
    self.painted_region = nil
    self.status_dirty = true

    self.alphabet = Labels.split_charset(self.config.label_chars)
    self.alphabet_set = {}
    for _, ch in ipairs(self.alphabet) do
        self.alphabet_set[Labels.normalize_char(ch)] = true
    end

    self.ges_events = {
        TapClose = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            },
        },
    }

    self:rescan(false)
end

--[[--
(Re)scan the visible page and rebuild the tag set.
]]
function HintLayer:rescan(page_turn)
    if self.closed then
        return
    end
    local start_time = os.clock and os.clock() or 0
    self.words = Scanner.scan(self.ui, {
        min_word_length = self.config.min_word_length,
        screen_w = self.screen_w,
        screen_h = self.screen_h,
    })
    self.scanned_page = self.ui.getCurrentPage and self.ui:getCurrentPage() or nil
    self.entries = Labels.assign(self.words, self.config.label_chars)
    self.typed_chars = {}
    self.typed = ""
    self.matches = self.entries
    self:set_initial_cursor()
    if page_turn then
        -- The reader has to repaint the new page, and our snapshot of the
        -- background is stale: ask for a full repaint and take a new one.
        self:free_text_widgets()
        self.bg_invalid = true
        self.prev_region = nil
        self.painted_region = nil
        UIManager:setDirty("all", "ui")
    end
    logger.dbg("hop_lookup: scanned", #self.words, "words,", #self.entries,
        "tags in", string.format("%.3f", (os.clock and os.clock() or 0) - start_time), "s")
end

function HintLayer:set_initial_cursor()
    local mode = self.config.initial_cursor
    if mode == "none" or #self.words == 0 then
        self.cursor = nil
    elseif mode == "first" then
        self.cursor = 1
    else
        self.cursor = Nav.initial_index(self.words, self.screen_w, self.screen_h)
    end
end

function HintLayer:onSetDimensions(dimen)
    self.screen_w, self.screen_h = dimen.w, dimen.h
    -- Mutate the existing Geom instead of replacing it: the tap gesture range
    -- set up in init() holds a reference to it.
    self.dimen.x, self.dimen.y = 0, 0
    self.dimen.w, self.dimen.h = self.screen_w, self.screen_h
    self.bg_invalid = true
    self.prev_region = nil
    self.painted_region = nil
    self.status_dirty = true
    -- The page is being re-laid out: rescan once the reader is done with it.
    UIManager:nextTick(function()
        if not self.closed then
            self:rescan(true)
        end
    end)
    return true
end

----------------------------------------------------------------------
-- Input
----------------------------------------------------------------------

--[[--
Whether a key is one of the given names. Device key names are strings ("Up",
"Backspace", "H", ...); matching on the name only (instead of
`Key:match()`, which also requires the exact modifier set) keeps the overlay
usable when an unexpected modifier is reported as held (e.g. Super on some
desktop setups, or a stuck Shift).
]]
local function key_is(key, names)
    local name = key and key.key
    if type(name) ~= "string" then
        return false
    end
    for _, candidate in ipairs(names) do
        if name == candidate then
            return true
        end
    end
    return false
end

--[[--
Shift+Space (previous page, as in the reader), compared by hand because plain
`key_is` ignores modifiers.
]]
local function is_shift_space(key)
    return key_is(key, { " " }) and key.modifiers ~= nil and key.modifiers.Shift == true
end

--[[--
Ctrl+H: compared by hand so that the key name case and any extra modifier
cannot make it fail.
]]
local function is_ctrl_h(key)
    local name = key and key.key
    if type(name) ~= "string" or name:lower() ~= "h" then
        return false
    end
    local modifiers = key.modifiers
    return modifiers ~= nil and modifiers.Ctrl == true
end

--[[--
Handle one key press. Never called directly: `onKeyPress` wraps it so that an
unexpected error can not take the reader down (see `HintLayer:abort`).
]]
local function handle_key_press(self, key)
    -- TextInput events carry no modifier information, but their KeyPress
    -- always follows immediately: remember what the device already sent as
    -- text so that it is not inserted twice.
    local seen_text_input = self.seen_text_input
    self.seen_text_input = nil
    if key_is(key, { "Back", "KeyHome", "Home" }) or is_ctrl_h(key) then
        self:close()
        return true
    end
    -- Context menu key (the PC "application"/right click menu key, the Kindle
    -- Menu button, a gamepad's north face button) -- F10 is the usual keyboard
    -- stand-in and is free in the reader.
    if key_is(key, { "ContextMenu", "Menu", "F10" }) then
        self:toggle_goldendict_window()
        return true
    end
    if key_is(key, { "Left" }) then
        return self:move_cursor("left")
    end
    if key_is(key, { "Right" }) then
        return self:move_cursor("right")
    end
    if key_is(key, { "Up" }) then
        return self:move_cursor("up")
    end
    if key_is(key, { "Down" }) then
        return self:move_cursor("down")
    end
    if key_is(key, { "LPgBack", "RPgBack" }) then
        return self:turn_page(-1)
    end
    if key_is(key, { "LPgFwd", "RPgFwd" }) then
        return self:turn_page(1)
    end
    -- Space pages like it does in the reader (Shift+Space goes back).
    if is_shift_space(key) then
        return self:turn_page(-1)
    end
    if key_is(key, { " " }) then
        return self:turn_page(1)
    end
    if key_is(key, { "Backspace", "Del" }) then
        return self:undo_char()
    end
    if key_is(key, { "Press" }) then
        return self:lookup_cursor_word()
    end
    -- A printable key: its name is the character itself (see the device event
    -- maps, e.g. "A".."Z", "0".."9", punctuation). Depending on the device a
    -- printable press may also have been delivered as a TextInput event just
    -- before this one (and on some devices -- e.g. SDL, where
    -- hasKeyboardTextInput() is always true -- only this KeyPress is
    -- delivered), so `seen_text_input` tells us whether that character was
    -- already handled.
    local ch = self:key_to_char(key)
    self.seen_text_input = nil
    if ch then
        if seen_text_input ~= Labels.normalize_char(ch) then
            self:input_char(ch)
        end
        return true
    end
    -- Stay modal: never let stray keys reach the reader below.
    return true
end

function HintLayer:onKeyPress(key)
    if self.closed then
        return true
    end
    local ok, err = pcall(handle_key_press, self, key)
    if not ok then
        self:abort(err)
    end
    return true
end

local function handle_key_repeat(self, key)
    if key_is(key, { "Left", "Right", "Up", "Down", "LPgBack", "RPgBack", "LPgFwd", "RPgFwd" }) then
        return self:onKeyPress(key)
    end
    return true
end

function HintLayer:onKeyRepeat(key)
    if self.closed then
        return true
    end
    local ok, err = pcall(handle_key_repeat, self, key)
    if not ok then
        self:abort(err)
    end
    return true
end

--[[--
Give up on the overlay after an unexpected error: log it and close, so that a
broken overlay can never swallow the reader's input.
]]
function HintLayer:abort(err)
    logger.err("hop_lookup: input handling failed:", err)
    pcall(self.close, self)
end

--[[--
Swallow key releases too: the overlay is modal, and the reader below must not
see a release for a press it never got.
]]
function HintLayer:onKeyRelease()
    return true
end

--[[--
Whether a shortcut modifier is currently held. Such keys are never text, so
`Ctrl+H` can never be mistaken for the tag character "h" (on devices that
emit a TextInput event for printable keys).
]]
function HintLayer:has_input_modifier()
    local modifiers = Device.input and Device.input.modifiers
    if not modifiers then
        return false
    end
    return modifiers.Ctrl or modifiers.Alt or modifiers.AltGr
        or modifiers.Super or modifiers.Meta or false
end

--[[--
Characters coming from the device layer (external keyboards with a layout,
soft keyboards, ...). Always consumed, like the key presses.
]]
local function handle_text_input(self, text)
    if type(text) ~= "string" or text == "" then
        return false
    end
    if self:has_input_modifier() then
        -- Ctrl/Alt/... combinations are shortcuts, not text.
        return false
    end
    if Scanner.utf8_len(text) ~= 1 then
        -- A pasted string is not a tag: ignore it rather than completing tags
        -- in the middle of it.
        return true
    end
    self.seen_text_input = Labels.normalize_char(text)
    self:input_char(text)
    return true
end

function HintLayer:onTextInput(text)
    if self.closed then
        return true
    end
    local ok, err = pcall(handle_text_input, self, text)
    if not ok then
        self:abort(err)
        return true
    end
    return true
end

--[[--
Turn a printable key press into the character it represents. Used on devices
that do not emit TextInput events for physical keyboards.
]]
function HintLayer:key_to_char(key)
    local name = key.key
    if type(name) ~= "string" or Scanner.utf8_len(name) ~= 1 then
        return nil
    end
    if key.modifiers then
        for _, modifier in ipairs({ "Ctrl", "Alt", "AltGr", "Super", "Meta", "Sym", "ScreenKB" }) do
            if key.modifiers[modifier] then
                return nil
            end
        end
    end
    return name
end

function HintLayer:onTapClose()
    local ok, err = pcall(self.close, self)
    if not ok then
        self:abort(err)
    end
    return true
end

----------------------------------------------------------------------
-- Tag input and lookup
----------------------------------------------------------------------

--[[--
Feed one character to the tag input. Returns true when the character was
part of the tag charset (even if it leads to a lookup).
]]
function HintLayer:input_char(ch)
    if self.closed or not ch or ch == "" or Scanner.utf8_len(ch) ~= 1 then
        return false
    end
    local normalized = Labels.normalize_char(ch)
    if not self.alphabet_set[normalized] then
        return false
    end
    local typed = self.typed .. normalized
    local matches = Labels.filter(self.entries, typed)
    if #matches == 0 then
        -- Dead end: ignore the key and keep the current tag set.
        return false
    end
    self.typed_chars[#self.typed_chars + 1] = normalized
    self.typed = typed
    self.matches = matches
    if #matches == 1 then
        -- Look the word up right away, without Enter: this is either the
        -- whole tag, or the only tag that can still match what was typed.
        self:lookup_entry(matches[1])
        return true
    end
    self:update()
    return true
end

function HintLayer:undo_char()
    local count = #self.typed_chars
    if self.closed or count == 0 then
        return true
    end
    table.remove(self.typed_chars)
    self.typed = table.concat(self.typed_chars)
    self.matches = Labels.filter(self.entries, self.typed)
    self:update()
    return true
end

--[[--
Look up the word a tag designates.

The overlay deliberately stays open, so that several words can be looked up
one after the other without reopening it: only Esc, Ctrl+H and a tap close it.
The typed tag is consumed, so the next tag can be typed right away.
]]
function HintLayer:lookup_entry(entry)
    if self.closed or not entry then
        return
    end
    local word = entry.word
    local box = self.words[entry.index]
    self.typed_chars = {}
    self.typed = ""
    self.matches = self.entries
    self:update()
    if word and word ~= "" then
        self.plugin:lookup_word(word, box)
    end
end

function HintLayer:lookup_cursor_word()
    if self.closed or not self.cursor then
        return true
    end
    local word = self.words[self.cursor]
    if not word then
        return true
    end
    self.typed_chars = {}
    self.typed = ""
    self.matches = self.entries
    self:update()
    self.plugin:lookup_word(word.word, word)
    return true
end

--[[--
Toggle the GoldenDict window mode (popup <-> main) with the context menu
key, like the requirement asks.
]]
function HintLayer:toggle_goldendict_window()
    if self.closed then
        return true
    end
    local config = self.config
    config.goldendict_window = config.goldendict_window == "popup" and "main" or "popup"
    if self.plugin then
        -- Keep using the (sanitized) configuration the plugin just saved.
        self.config = self.plugin:save_config(config) or config
    end
    self.status_dirty = true
    self:update()
    return true
end

----------------------------------------------------------------------
-- Cursor
----------------------------------------------------------------------

function HintLayer:move_cursor(direction)
    if self.closed or #self.words == 0 then
        return true
    end
    if not self.cursor then
        -- No cursor yet (initial_cursor = "none"): reveal it where the other
        -- modes would have put it, without moving on this first key press.
        self.cursor = Nav.initial_index(self.words, self.screen_w, self.screen_h) or 1
    else
        local target
        if direction == "left" then
            target = Nav.move_linear(self.words, self.cursor, -1)
        elseif direction == "right" then
            target = Nav.move_linear(self.words, self.cursor, 1)
        elseif direction == "up" then
            target = Nav.move_vertical(self.words, self.cursor, -1)
        else
            target = Nav.move_vertical(self.words, self.cursor, 1)
        end
        if target then
            self.cursor = target
        end
    end
    self:update()
    return true
end

----------------------------------------------------------------------
-- Paging
----------------------------------------------------------------------

--[[--
Turn the page (from inside the overlay) and rescan the new page.

Both readers implement `GotoViewRel` for their page turn keys
(`ReaderPaging:onGotoViewRel` handles the paged/scroll modes and
`ReaderRolling:onGotoViewRel` the reflowable ones), so it is the right event
for F6/F7 and PageUp/PageDown here too.
]]
function HintLayer:turn_page(direction)
    logger.dbg("hop_lookup: turning page", direction)
    self.ui:handleEvent(Event:new("GotoViewRel", direction))
    self:rescan(true)
    return true
end

----------------------------------------------------------------------
-- Painting
----------------------------------------------------------------------

local function clamp(value, min_value, max_value)
    if value < min_value then return min_value end
    if value > max_value then return max_value end
    return value
end

function HintLayer:get_text_widget(text)
    local widget = self.text_widgets[text]
    if not widget then
        widget = TextWidget:new{
            text = text,
            face = self.label_face,
            bold = true,
            fgcolor = self.label_fg,
            padding = self.label_pad_y,
            use_xtext = false,
        }
        self.text_widgets[text] = widget
    end
    return widget
end

function HintLayer:free_text_widgets()
    for _, widget in pairs(self.text_widgets) do
        widget:free()
    end
    self.text_widgets = {}
end

--[[--
Screen rectangle of the tag of `entry`, or nil when the tag has been fully
typed (nothing left to display).

The tag is drawn *on its word*, at the word's left edge and vertically
centred on the word box, hop.nvim style. Reflowable text has barely any room
between two lines, so a tag hovering above the word would land on the
previous line and look like it belonged to it.
]]
function HintLayer:get_label_rect(entry)
    local word = self.words[entry.index]
    if not word then
        return nil
    end
    local text = Labels.display(entry.tag, self.typed, self.config.label_uppercase)
    if text == "" then
        return nil
    end
    local size = self:get_text_widget(text):getSize()
    local w = size.w + 2 * self.label_pad_x
    local h = size.h
    local x = math.floor(word.x)
    local y = math.floor(word.y + (word.h - h) / 2)
    x = clamp(x, 0, math.max(0, self.screen_w - w))
    y = clamp(y, 0, math.max(0, self.screen_h - h))
    return Geom:new{ x = x, y = y, w = w, h = h }
end

function HintLayer:get_cursor_rect()
    local word = self.cursor and self.words[self.cursor]
    if not word then
        return nil
    end
    local border = Screen:scaleBySize(1)
    local rect = Geom:new{
        x = math.max(0, math.floor(word.x - border)),
        y = math.max(0, math.floor(word.y - border)),
        w = math.ceil(word.w + 2 * border),
        h = math.ceil(word.h + 2 * border),
    }
    return rect:intersect(Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.screen_h })
end

--[[--
Text of the status bar: the GoldenDict window mode matters here, and an empty
page says so instead of showing nothing at all.
]]
function HintLayer:get_status_text()
    if #self.words == 0 then
        return STATUS_TEXT_EMPTY
    end
    local mode = self.config.goldendict_window == "popup" and _("popup") or _("main")
    return string.format("%s [%s]", STATUS_TEXT, mode)
end

function HintLayer:get_status_rect()
    local size = self:get_text_widget(STATUS_TEXT):getSize()
    return Geom:new{
        x = 0,
        y = math.max(0, self.screen_h - size.h),
        w = self.screen_w,
        h = size.h,
    }
end

--[[--
Dirty region to refresh: everything we may have painted before (including the
tags drawn by the last full paint, which the next keystroke may drop),
everything we paint now, and the cursor. Kept as small as possible: on e-ink
devices this is what drives the (fast) partial refresh on each keystroke.
]]
function HintLayer:update()
    if self.closed then
        return
    end
    local boxes = {}
    if self.prev_region then
        boxes[#boxes + 1] = self.prev_region
    end
    if self.painted_region then
        boxes[#boxes + 1] = self.painted_region
    end
    for _, entry in ipairs(self.matches) do
        local rect = self:get_label_rect(entry)
        if rect then
            boxes[#boxes + 1] = rect
        end
    end
    local cursor_rect = self:get_cursor_rect()
    if cursor_rect then
        boxes[#boxes + 1] = cursor_rect
    end
    if self.status_dirty then
        boxes[#boxes + 1] = self:get_status_rect()
    end
    local region
    if #boxes > 0 then
        region = Geom.boundingBox(boxes)
        region.x = math.floor(region.x - self.margin)
        region.y = math.floor(region.y - self.margin)
        region.w = math.ceil(region.w + 2 * self.margin)
        region.h = math.ceil(region.h + 2 * self.margin)
        region = region:intersect(Geom:new{ x = 0, y = 0, w = self.screen_w, h = self.screen_h })
    end
    self.prev_region = region
    self.painted_region = nil -- now covered by prev_region
    self.status_dirty = false
    UIManager:setDirty(self, "ui", region)
end

function HintLayer:capture_background(bb)
    local w, h = bb:getWidth(), bb:getHeight()
    if not self.bg_bb or self.bg_bb:getWidth() ~= w or self.bg_bb:getHeight() ~= h
        or self.bg_bb:getType() ~= bb:getType() then
        self:free_background()
        self.bg_bb = Blitbuffer.new(w, h, bb:getType())
    end
    self.bg_bb:blitFrom(bb, 0, 0, 0, 0, w, h)
    self.bg_invalid = false
end

function HintLayer:free_background()
    if self.bg_bb then
        self.bg_bb:free()
        self.bg_bb = nil
    end
end

--[[--
Draw the overlay. Never called directly: `paintTo` wraps it so that a drawing
error cannot take the reader down.
]]
local function paint_overlay(self, bb, x, y, is_dirty)
    -- Safety net: if the reader changed page behind our back (another module
    -- turned the page while we were open), our tags are stale -- rescan and
    -- let the next repaint draw the new state.
    if self.ui.getCurrentPage and self.scanned_page
        and self.ui:getCurrentPage() ~= self.scanned_page then
        self:rescan(true)
    end
    -- is_dirty == nil means we are being repainted because something below us
    -- changed: whatever we saved is stale, take a fresh snapshot.
    if not self.bg_bb or self.bg_invalid or is_dirty == nil then
        self:capture_background(bb)
    end
    if self.bg_bb then
        bb:blitFrom(self.bg_bb, x, y, 0, 0, self.bg_bb:getWidth(), self.bg_bb:getHeight())
    end

    -- Everything we paint now is remembered, so that the partial refresh that
    -- follows the next keystroke also wipes the tags that disappear then.
    local painted = {}

    local cursor_rect = self:get_cursor_rect()
    if cursor_rect then
        bb:invertRect(cursor_rect.x, cursor_rect.y, cursor_rect.w, cursor_rect.h)
        painted[#painted + 1] = cursor_rect
    end

    for _, entry in ipairs(self.matches) do
        local rect = self:get_label_rect(entry)
        if rect then
            bb:paintRect(rect.x, rect.y, rect.w, rect.h, self.label_bg)
            local text = Labels.display(entry.tag, self.typed, self.config.label_uppercase)
            if text ~= "" then
                self:get_text_widget(text):paintTo(bb, rect.x + self.label_pad_x, rect.y)
            end
            painted[#painted + 1] = rect
        end
    end

    local status_rect = self:get_status_rect()
    bb:paintRect(status_rect.x, status_rect.y, status_rect.w, status_rect.h, self.label_bg)
    local widget = self:get_text_widget(self:get_status_text())
    widget:paintTo(bb, status_rect.x + self.label_pad_x, status_rect.y)
    painted[#painted + 1] = status_rect

    self.painted_region = Geom.boundingBox(painted)
end

function HintLayer:paintTo(bb, x, y, is_dirty)
    if self.closed then
        -- A closed overlay is off the window stack and must not be painted
        -- any more; nothing to do (the reader repaints the page itself).
        return
    end
    local ok, err = pcall(paint_overlay, self, bb, x, y, is_dirty)
    if not ok then
        logger.err("hop_lookup: painting failed:", err)
        -- Stop drawing decorations rather than failing on every repaint.
        self.entries, self.matches = {}, {}
        self.cursor = nil
        self.painted_region = nil
    end
end

----------------------------------------------------------------------
-- Closing
----------------------------------------------------------------------

function HintLayer:close()
    if self.closed then
        return
    end
    self.closed = true
    UIManager:close(self, "ui")
end
-- Also answer a broadcast Home event (InputContainer:onHome closes the
-- topmost widget through onClose).
HintLayer.onClose = HintLayer.close

--[[--
Called by UIManager whenever the widget leaves the window stack, whatever
the reason (our own close(), the document being closed, ...).
]]
function HintLayer:onCloseWidget()
    self.closed = true
    if self.plugin then
        self.plugin.hint_layer = nil
    end
    self:free_text_widgets()
    self:free_background()
end

return HintLayer
