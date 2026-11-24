--[[--
Scan the words visible on the current page, with their screen coordinates.

Two document families are supported:

* reflowable documents (EPUB/FB2/... via crengine): the visible text range is
  walked word by word with the document's xpointer API, and each word gets
  its on screen box from crengine;
* paged documents (PDF/DjVu/...): the per word text boxes of the page are
  fetched at once and transformed to screen coordinates by the reader view.

@module koplugin.hop_lookup.hoplookup_scanner
--]]--

local Device = require("device")
local Geom = require("ui/geometry")
local logger = require("logger")
local util = require("util")

local Scanner = {}

-- Never scan more than that many words, whatever happens.
Scanner.max_words = 2000

local MAX_WORD_CHARS = 64

--[[--
Decode the code point of a single UTF-8 character (nil if invalid).
]]
local function utf8_codepoint(ch)
    if type(ch) ~= "string" or ch == "" then
        return nil
    end
    local first = ch:byte(1)
    if not first then
        return nil
    end
    if first < 0x80 then
        return first
    end
    local length = #ch
    local codepoint
    if length == 2 then
        codepoint = first - 0xC0
    elseif length == 3 then
        codepoint = first - 0xE0
    elseif length == 4 then
        codepoint = first - 0xF0
    else
        return nil
    end
    for i = 2, length do
        local byte = ch:byte(i)
        if not byte or byte < 0x80 or byte > 0xBF then
            return nil
        end
        codepoint = codepoint * 0x40 + (byte - 0x80)
    end
    return codepoint
end
Scanner.utf8_codepoint = utf8_codepoint

-- Characters that separate words but are not covered by Lua's `%s` (which
-- does not know any Unicode space), plus the zero width formatters.
local UNICODE_SEPARATORS = {
    ["\194\160"] = true, -- U+00A0 no-break space
    ["\226\128\128"] = true, -- U+2000 en quad
    ["\226\128\129"] = true, -- U+2001 em quad
    ["\226\128\130"] = true, -- U+2002 en space
    ["\226\128\131"] = true, -- U+2003 em space
    ["\226\128\132"] = true, -- U+2004 three-per-em space
    ["\226\128\133"] = true, -- U+2005 four-per-em space
    ["\226\128\134"] = true, -- U+2006 six-per-em space
    ["\226\128\135"] = true, -- U+2007 figure space
    ["\226\128\136"] = true, -- U+2008 punctuation space
    ["\226\128\137"] = true, -- U+2009 thin space
    ["\226\128\138"] = true, -- U+200A hair space
    ["\226\128\139"] = true, -- U+200B zero width space
    ["\226\128\140"] = true, -- U+200C zero width non-joiner
    ["\226\128\141"] = true, -- U+200D zero width joiner
    ["\226\128\168"] = true, -- U+2028 line separator
    ["\226\128\169"] = true, -- U+2029 paragraph separator
    ["\226\128\175"] = true, -- U+202F narrow no-break space
    ["\226\129\159"] = true, -- U+205F medium mathematical space
    ["\227\128\128"] = true, -- U+3000 ideographic space
    ["\239\187\191"] = true, -- U+FEFF zero width no-break space / BOM
}

--[[--
Replace the Unicode spaces/formatters and the control characters by a plain
space, so that the checks below (and `util.trim`) can see them.
]]
local function normalize_token(text)
    local normalized = {}
    for ch in text:gmatch(util.UTF8_CHAR_PATTERN) do
        if UNICODE_SEPARATORS[ch] or ch:match("^[%z\1-\31\127]$") then
            normalized[#normalized + 1] = " "
        else
            normalized[#normalized + 1] = ch
        end
    end
    return table.concat(normalized)
end
Scanner.normalize_token = normalize_token

-- Ranges of code points that are symbols, punctuation or formatters, i.e.
-- that cannot make a token a word on their own (emoji, arrows, currency
-- signs, combining marks, CJK punctuation, ...). Letters of any script and
-- all digits are *not* listed.
local SYMBOL_RANGES = {
    { 0x0300, 0x036F }, -- combining diacritical marks
    { 0x2000, 0x206F }, -- general punctuation and format characters
    { 0x20A0, 0x20CF }, -- currency symbols
    { 0x2100, 0x214F }, -- letterlike symbols
    { 0x2190, 0x2BFF }, -- arrows, mathematical operators, symbols, dingbats
    { 0x2E00, 0x2E7F }, -- supplemental punctuation
    { 0x3000, 0x303F }, -- CJK symbols and punctuation
    { 0xFE00, 0xFE0F }, -- variation selectors
    { 0xFE30, 0xFE6F }, -- CJK compatibility forms and small form variants
    { 0xFF01, 0xFF0F }, -- fullwidth punctuation
    { 0xFF1A, 0xFF20 },
    { 0xFF3B, 0xFF40 },
    { 0xFF5B, 0xFF65 },
    { 0xFFF0, 0xFFFF }, -- specials
    { 0x1F000, 0x1FBFF }, -- emoji, symbols, legacy computing
    { 0xE0000, 0xE007F }, -- tags
}

local function is_symbol_codepoint(codepoint)
    for _, range in ipairs(SYMBOL_RANGES) do
        if codepoint >= range[1] and codepoint <= range[2] then
            return true
        end
    end
    return false
end
Scanner.is_symbol_codepoint = is_symbol_codepoint

--[[--
Whether a single character can make a token a word: an ASCII letter/digit,
or a character of any script that is not a symbol/punctuation/formatter.
]]
local function is_word_char(ch)
    if ch:match("^[%w]$") then
        return true
    end
    if #ch == 1 then
        return false
    end
    local codepoint = utf8_codepoint(ch)
    if not codepoint then
        return false
    end
    return not is_symbol_codepoint(codepoint)
end
Scanner.is_word_char = is_word_char

-- Typographic punctuation that may surround a word in a book. ASCII
-- punctuation is handled by Lua patterns, these are the (multi byte) ones
-- that Lua patterns cannot classify.
local UNICODE_PUNCTUATION = {
    ["«"] = true, ["»"] = true, ["‹"] = true, ["›"] = true,
    ["„"] = true, ["“"] = true, ["”"] = true, ["‘"] = true, ["’"] = true,
    ["‚"] = true, ["‛"] = true, ["‟"] = true,
    ["‐"] = true, ["‑"] = true, ["‒"] = true, ["–"] = true, ["—"] = true, ["―"] = true,
    ["…"] = true, ["·"] = true, ["•"] = true, ["‣"] = true, ["◦"] = true,
    ["※"] = true, ["†"] = true, ["‡"] = true, ["§"] = true, ["¶"] = true,
    ["¡"] = true, ["¿"] = true,
    ["、"] = true, ["。"] = true, ["，"] = true, ["．"] = true, ["："] = true,
    ["；"] = true, ["！"] = true, ["？"] = true, ["～"] = true, ["〜"] = true,
    ["（"] = true, ["）"] = true, ["〔"] = true, ["〕"] = true, ["【"] = true,
    ["】"] = true, ["「"] = true, ["」"] = true, ["『"] = true, ["』"] = true,
    ["《"] = true, ["》"] = true, ["〈"] = true, ["〉"] = true,
    ["〖"] = true, ["〗"] = true, ["・"] = true,
    ["＃"] = true, ["＆"] = true, ["＊"] = true, ["＋"] = true, ["－"] = true,
    ["／"] = true, ["＝"] = true, ["＠"] = true, ["｜"] = true, ["％"] = true,
}

--[[--
Number of UTF-8 characters of a string.
]]
local function utf8_len(text)
    local n = 0
    for _ in text:gmatch(util.UTF8_CHAR_PATTERN) do
        n = n + 1
    end
    return n
end
Scanner.utf8_len = utf8_len

local function is_strippable(ch)
    return ch:match("^[%p%z]$") ~= nil or UNICODE_PUNCTUATION[ch] == true
end

--[[--
Remove the punctuation that surrounds a word ("(word)," -> "word"), keeping
inner hyphens and apostrophes ("don't", "well-known"). Works on UTF-8.
]]
local function strip_edge_punctuation(text)
    local chars = {}
    for ch in text:gmatch(util.UTF8_CHAR_PATTERN) do
        chars[#chars + 1] = ch
    end
    local first, last = 1, #chars
    while first <= last and is_strippable(chars[first]) do
        first = first + 1
    end
    while last >= first and is_strippable(chars[last]) do
        last = last - 1
    end
    if first > last then
        return ""
    end
    return table.concat(chars, "", first, last)
end
Scanner.strip_edge_punctuation = strip_edge_punctuation

--[[--
Clean up a raw token coming from the document and tell whether it is worth
tagging: it must be a single word (no space), contain at least one letter or
digit, and be long enough.
]]
local function clean_word(text, min_length)
    if type(text) ~= "string" then
        return nil
    end
    local word = util.trim(normalize_token(text))
    if word == "" then
        return nil
    end
    word = strip_edge_punctuation(word)
    if word == "" or word:find("%s") then
        return nil
    end
    local has_word_char = false
    for ch in word:gmatch(util.UTF8_CHAR_PATTERN) do
        if is_word_char(ch) then
            has_word_char = true
            break
        end
    end
    if not has_word_char then
        return nil
    end
    local length = utf8_len(word)
    local minimum = min_length or 1
    if minimum > 1 and util.hasCJKChar(word) then
        -- A CJK "word" is very often a single character: keep those even when
        -- the minimum word length asks for longer words.
        minimum = 1
    end
    if length < minimum or length > MAX_WORD_CHARS then
        return nil
    end
    return word
end
Scanner.clean_word = clean_word

local function make_word(word, box, extra)
    local record = {
        word = word,
        key = word:lower(),
        x = box.x,
        y = box.y,
        w = box.w,
        h = box.h,
    }
    if extra then
        for k, v in pairs(extra) do
            record[k] = v
        end
    end
    return record
end

local function is_visible_box(box, screen_w, screen_h)
    if not box or not box.x or not box.y or not box.w or not box.h then
        return false
    end
    if box.w <= 0 or box.h <= 0 then
        return false
    end
    if box.y + box.h <= 0 or box.y >= screen_h then
        return false
    end
    if box.x + box.w <= 0 or box.x >= screen_w then
        return false
    end
    return true
end

--[[--
Word by word walk of the visible area of a reflowable document.

The visible text range is used as both the starting point and the boundary:
words are walked with `getNextVisibleWordStart()`/`getNextVisibleWordEnd()`
from the beginning of the range, and the walk stops as soon as we leave it.
]]
local function scan_rolling(ui, opts)
    local doc = ui.document
    local words = {}
    if not doc.getTextFromPositions or not doc.getNextVisibleWordStart
        or not doc.getNextVisibleWordEnd or not doc.getTextFromXPointers then
        return words
    end
    local screen_w, screen_h = opts.screen_w, opts.screen_h
    local range = doc:getTextFromPositions({ x = 0, y = 0 }, { x = screen_w, y = screen_h }, true)
    if not range or not range.pos0 or not range.pos1 then
        logger.dbg("hop_lookup: no visible text range")
        return words
    end

    local xp = range.pos0
    -- `getNextVisibleWordStart()` skips the word the given pointer sits on, so
    -- the word at the very beginning of the visible range needs to be picked
    -- up separately (a leading indentation makes the token start with a space,
    -- in which case clean_word() rejects it and the walk below finds it).
    local function add_word(start_xp)
        local end_xp = doc:getNextVisibleWordEnd(start_xp)
        if not end_xp then
            return nil
        end
        local word = clean_word(doc:getTextFromXPointers(start_xp, end_xp), opts.min_word_length)
        if word then
            local boxes = doc.getScreenBoxesFromPositions
                and doc:getScreenBoxesFromPositions(start_xp, end_xp, true)
            if boxes and #boxes > 0 then
                for _, box in ipairs(boxes) do
                    if #words >= Scanner.max_words then
                        break
                    end
                    if is_visible_box(box, screen_w, screen_h) then
                        words[#words + 1] = make_word(word, box, {
                            pos0 = start_xp,
                            pos1 = end_xp,
                        })
                    end
                end
            else
                -- Fallback for documents where only xpointer based positions
                -- are available: build an approximate box around the word.
                local screen_y, screen_x
                if doc.getScreenPositionFromXPointer then
                    -- Note: this one returns y first, then x.
                    screen_y, screen_x = doc:getScreenPositionFromXPointer(start_xp)
                end
                if screen_x and screen_y then
                    local char_size = 8
                    local box = Geom:new{
                        x = screen_x,
                        y = screen_y,
                        w = math.max(utf8_len(word) * char_size, char_size),
                        h = char_size * 2,
                    }
                    if #words < Scanner.max_words and is_visible_box(box, screen_w, screen_h) then
                        words[#words + 1] = make_word(word, box, {
                            pos0 = start_xp,
                            pos1 = end_xp,
                        })
                    end
                end
            end
        end
        return end_xp
    end

    xp = add_word(xp) or xp

    while #words < Scanner.max_words do
        local word_start = doc:getNextVisibleWordStart(xp)
        if not word_start or word_start == xp then
            break
        end
        -- Stop at the end of the visible range: compareXPointers() returns 1
        -- when its second argument is after its first one (nil if invalid).
        if doc.compareXPointers then
            local order = doc:compareXPointers(range.pos1, word_start)
            if order == nil or order > 0 then
                break
            end
        end
        local word_end = add_word(word_start)
        if not word_end then
            break
        end
        xp = word_end
    end
    return words
end

--[[--
Word boxes of the visible pages of a paged document (PDF/DjVu/...).

The boxes returned by `document:getTextBoxes()` are in native page
coordinates; they are converted to screen coordinates by the reader view, so
they follow the current zoom and rotation.
]]
local function scan_paged(ui, opts)
    local doc = ui.document
    local view = ui.view
    local words = {}
    if not doc.getTextBoxes or not view or not view.pageToScreenTransform then
        return words
    end
    local first_page
    if ui.getCurrentPage then
        first_page = ui:getCurrentPage()
    end
    if not first_page and doc.getCurrentPage then
        first_page = doc:getCurrentPage()
    end
    if not first_page then
        logger.dbg("hop_lookup: no current page for the paged scan")
        return words
    end
    local page_count = 1
    if doc.getVisiblePageCount then
        page_count = doc:getVisiblePageCount() or 1
    end
    for page = first_page, first_page + page_count - 1 do
        local page_boxes = doc:getTextBoxes(page)
        if page_boxes then
            for _, line in ipairs(page_boxes) do
                for _, box in ipairs(line) do
                    local word = clean_word(box.word, opts.min_word_length)
                    if word then
                        local rect = view:pageToScreenTransform(page, {
                            x = box.x0,
                            y = box.y0,
                            w = box.x1 - box.x0,
                            h = box.y1 - box.y0,
                        })
                        if is_visible_box(rect, opts.screen_w, opts.screen_h) then
                            words[#words + 1] = make_word(word, rect, {
                                page = page,
                            })
                            if #words >= Scanner.max_words then
                                return words
                            end
                        end
                    end
                end
            end
        end
    end
    return words
end

--[[--
Scan the currently visible words.

`ui` is the reader UI (`self.ui` in a plugin), `opts` may carry:
    min_word_length (number), screen_w, screen_h (numbers)

Returns an array of word records, in reading order:
    { word = "The", key = "the", x = .., y = .., w = .., h = .., page = .. }
]]
function Scanner.scan(ui, opts)
    opts = opts or {}
    local screen = Device.screen
    local ctx = {
        min_word_length = opts.min_word_length or 1,
        screen_w = opts.screen_w or (screen and screen:getWidth()) or 600,
        screen_h = opts.screen_h or (screen and screen:getHeight()) or 800,
    }
    if not ui or not ui.document then
        return {}
    end
    local words
    if ui.paging then
        words = scan_paged(ui, ctx)
    elseif ui.rolling then
        words = scan_rolling(ui, ctx)
    elseif ui.document.getTextBoxes then
        words = scan_paged(ui, ctx)
    else
        words = scan_rolling(ui, ctx)
    end
    logger.dbg("hop_lookup: scanned", #words, "words")
    return words
end

return Scanner
