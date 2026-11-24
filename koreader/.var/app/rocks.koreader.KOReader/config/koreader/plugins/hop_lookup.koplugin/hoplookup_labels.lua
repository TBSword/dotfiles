--[[--
Tag (label) generation for the hop lookup overlay.

Tags are built over a user configured charset (e.g. `asdfghjkl`) and are
*prefix-free*: no tag is the prefix of another one. Typing a whole tag
therefore always designates exactly one word, which can then be looked up
immediately, without having to press Enter.

This module is pure Lua (no KOReader dependency) so that it can be unit
tested on its own.

@module koplugin.hop_lookup.hoplookup_labels
--]]--

local Labels = {}

-- Safety net for pathological charsets / pages.
Labels.max_tags = 2000
Labels.max_depth = 8

--[[--
Split a charset string into an array of unique UTF-8 characters.
Whitespace is ignored, so a charset may be written `"a s d f"`.
]]
function Labels.split_charset(charset)
    local chars, seen = {}, {}
    if type(charset) ~= "string" then
        return chars
    end
    for ch in charset:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
        if ch ~= "" and not ch:match("^%s$") and not seen[ch] then
            seen[ch] = true
            chars[#chars + 1] = ch
        end
    end
    return chars
end

--[[--
Normalize a charset into an array of unique single characters. A table is
accepted for convenience, but its entries are split into characters and
deduplicated, so that the generated tags stay prefix-free whatever the caller
passes.
]]
local function charset_characters(charset)
    local chars, seen = {}, {}
    local function add(ch)
        if type(ch) == "string" and ch ~= "" and not seen[ch] then
            seen[ch] = true
            chars[#chars + 1] = ch
        end
    end
    if type(charset) == "table" then
        for _, entry in ipairs(charset) do
            if type(entry) == "string" then
                for ch in entry:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
                    add(ch)
                end
            end
        end
    else
        for _, ch in ipairs(Labels.split_charset(charset)) do
            add(ch)
        end
    end
    return chars
end
Labels.charset_characters = charset_characters

--[[--
Build `count` prefix-free tags over the given characters.

Short tags are handed out first, following the charset order: with
`"asdfghjkl"` and 12 words, the first 8 words get `a s d f g h j k`, and the
last four get `la ls ld lf` (the tags of the expanded character). The
expansion always picks the *last* shortest tag, so the characters listed
first in the charset keep being used as short tags for the first words.

The result is an antichain of the tag tree: no tag is the prefix of another
one, which is what makes "tag fully typed = exactly one word" possible.
]]
function Labels.generate(charset, count)
    local chars = charset_characters(charset)
    local k = #chars
    local tags = {}
    if k == 0 or count <= 0 then
        return tags
    end
    count = math.min(count, Labels.max_tags)

    -- Trivial case: we have enough single characters for everybody.
    if count <= k then
        for i = 1, count do
            tags[i] = chars[i]
        end
        return tags
    end

    -- A single character alphabet cannot produce more than one prefix-free
    -- tag (the only candidate chain is "a", "aa", "aaa", ...).
    if k == 1 then
        tags[1] = chars[1]
        return tags
    end

    -- Grow a tree: the leaves are kept in order (shortest first), and the last
    -- shallowest leaf is expanded into its k children until we have enough
    -- leaves. `head` marks the first leaf that is still available. The depth
    -- is tracked explicitly (instead of using the string length) so that
    -- multi byte charsets work the same as ASCII ones.
    local leaves = {}
    for i = 1, k do
        leaves[i] = { tag = chars[i], depth = 1 }
    end
    local head = 1
    local min_depth = 1
    while (#leaves - head + 1) < count do
        if min_depth >= Labels.max_depth then
            break
        end
        local index
        for i = #leaves, head, -1 do
            if leaves[i].depth == min_depth then
                index = i
                break
            end
        end
        if not index then
            min_depth = min_depth + 1
        else
            local parent = table.remove(leaves, index)
            for i = 1, k do
                leaves[#leaves + 1] = {
                    tag = parent.tag .. chars[i],
                    depth = parent.depth + 1,
                }
            end
        end
    end
    for i = 1, math.min(count, #leaves - head + 1) do
        tags[i] = leaves[head + i - 1].tag
    end
    return tags
end

--[[--
Assign a tag to every distinct word of `words` (an array of word records as
returned by the scanner), in reading order.

Returns an array of entries:
    { tag = "a", key = "the", word = "The", index = 3 }
where `index` is the position of the first occurrence of that word in the
scanned word list.

`opts.key_func(word)` may be given to customize the deduplication key.
]]
function Labels.assign(words, charset, key_func)
    local entries, seen = {}, {}
    if type(words) ~= "table" then
        return entries
    end
    key_func = key_func or function(w) return (w.key or w.word or ""):lower() end
    for i, w in ipairs(words) do
        local word = w.word
        local key = key_func(w)
        if word and word ~= "" and key ~= "" and not seen[key] then
            seen[key] = true
            entries[#entries + 1] = {
                key = key,
                word = word,
                index = i,
            }
        end
    end
    local tags = Labels.generate(charset, #entries)
    for i = #entries, #tags + 1, -1 do
        entries[i] = nil -- more distinct words than available tags
    end
    for i, tag in ipairs(tags) do
        entries[i].tag = tag
    end
    return entries
end

--[[--
Return the subset of `entries` whose tag starts with `typed` (case
insensitive). An empty prefix matches everything.
]]
function Labels.filter(entries, typed)
    if not typed or typed == "" then
        return entries
    end
    local prefix = typed:lower()
    local matches = {}
    for _, entry in ipairs(entries) do
        if entry.tag:lower():sub(1, #prefix) == prefix then
            matches[#matches + 1] = entry
        end
    end
    return matches
end

--[[--
Part of a tag that still has to be typed after `typed`.
]]
function Labels.remaining(tag, typed)
    if not typed or typed == "" then
        return tag
    end
    return tag:sub(#typed + 1)
end

--[[--
The string to display for a tag: either the whole tag, or only the part
that is still to be typed, in the configured case.
]]
function Labels.display(tag, typed, uppercase)
    local text = Labels.remaining(tag, typed)
    if uppercase then
        text = text:upper()
    end
    return text
end

--[[--
Tags are compared (and accepted) case insensitively, so that a charset
given in lowercase still works when the user has caps lock on.
]]
function Labels.normalize_char(ch)
    return (ch or ""):lower()
end

return Labels
