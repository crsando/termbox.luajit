local ok, utf8 = pcall(require, "lua-utf8")

if not ok then
    error(
        "tui.text requires luautf8; install it with "
            .. "'luarocks --lua-version=5.1 install luautf8'",
        0
    )
end

local native = require("ltermbox")
local Text = {}

local function check_string(value, level)
    if type(value) ~= "string" then
        error("text must be a string", level or 3)
    end

    local length, invalid_at = utf8.len(value)

    if not length then
        error("invalid UTF-8 at byte " .. invalid_at, level or 3)
    end

    return length
end

function Text.length(value)
    return check_string(value, 3)
end

function Text.char(codepoint)
    return utf8.char(codepoint)
end

function Text.characters(value)
    check_string(value, 3)
    local result = {}

    for byte_index, codepoint in utf8.codes(value) do
        local width = math.max(1, native.wcwidth(codepoint))
        result[#result + 1] = {
            byte_index = byte_index,
            codepoint = codepoint,
            text = utf8.char(codepoint),
            width = width,
        }
    end

    return result
end

-- C0 controls (except newline, which callers split on), DEL and C1 controls.
-- termbox renders these as U+FFFD, so they must never reach a cell.
function Text.is_control(codepoint)
    return (codepoint < 0x20 and codepoint ~= 0x0a)
        or (codepoint >= 0x7f and codepoint <= 0x9f)
end

-- Prepare text for display: drop carriage returns and other control
-- characters, expand tabs to the next tab stop. Newlines are kept.
function Text.sanitize(value, tab_width)
    check_string(value, 3)
    tab_width = tab_width or 4

    if not value:find("[%z\1-\9\11-\31\127\194]") then
        return value
    end

    local parts = {}
    local column = 0

    for _, codepoint in utf8.codes(value) do
        if codepoint == 0x0a then
            parts[#parts + 1] = "\n"
            column = 0
        elseif codepoint == 0x09 then
            local spaces = tab_width - column % tab_width
            parts[#parts + 1] = string.rep(" ", spaces)
            column = column + spaces
        elseif not Text.is_control(codepoint) then
            parts[#parts + 1] = utf8.char(codepoint)
            column = column + math.max(1, native.wcwidth(codepoint))
        end
    end

    return table.concat(parts)
end

function Text.sub(value, first, last)
    check_string(value, 3)
    return utf8.sub(value, first, last)
end

function Text.prefix(value, count)
    if count <= 0 then
        check_string(value, 3)
        return ""
    end

    return Text.sub(value, 1, count)
end

function Text.suffix(value, first)
    local length = check_string(value, 3)

    if first > length then
        return ""
    end

    return utf8.sub(value, first, length)
end

function Text.width(value)
    local width = 0

    for _, character in ipairs(Text.characters(value)) do
        width = width + character.width
    end

    return width
end

function Text.range_width(value, first, last)
    local width = 0

    for index, character in ipairs(Text.characters(value)) do
        if index > last then
            break
        end

        if index >= first then
            width = width + character.width
        end
    end

    return width
end

function Text.take(value, skipped, max_width)
    local parts = {}
    local width = 0
    local count = 0

    if max_width <= 0 then
        check_string(value, 3)
        return "", 0, 0
    end

    for index, character in ipairs(Text.characters(value)) do
        if index > skipped then
            if width + character.width > max_width then
                break
            end

            parts[#parts + 1] = character.text
            width = width + character.width
            count = count + 1
        end
    end

    return table.concat(parts), width, count
end

local function set_of(...)
    local result = {}

    for _, value in ipairs({ ... }) do
        result[value] = true
    end

    return result
end

-- Simplified CJK line-breaking rules (kinsoku): closing punctuation may not
-- start a line, opening punctuation may not end one.
local no_line_start = set_of(
    "，", "。", "、", "；", "：", "！", "？", "）", "」", "』", "》", "】",
    "〉", "〕", "”", "’", "…", "·", ",", ".", ";", ":", "!", "?", ")", "]", "}"
)
local no_line_end = set_of(
    "（", "「", "『", "《", "【", "〈", "〔", "“", "‘", "(", "[", "{"
)

local function is_space(character)
    return character.text == " " or character.text == "\227\128\128"
end

-- Wide (CJK) text has a break opportunity between any two characters.
local function can_break_between(left, right)
    return (left.width > 1 or right.width > 1)
        and not no_line_start[right.text]
        and not no_line_end[left.text]
end

-- Split a list of { text = ..., width = ... } characters into visual lines no
-- wider than max_width and return them as { first, last } index ranges.
--
-- mode "char" breaks at the last character that fits. mode "word" breaks at
-- the latest space or CJK opportunity, drops the spaces at the break (like
-- ratatui's WordWrapper), and only hard-breaks words longer than a line.
-- Leading indentation of the paragraph is kept.
function Text.wrap_ranges(chars, max_width, mode)
    local lines = {}

    if max_width <= 0 then
        return lines
    end

    local count = #chars

    if count == 0 then
        lines[1] = { 1, 0 }
        return lines
    end

    local word = mode == "word"
    local start = 1
    local width = 0
    local last_content = 0
    local space_end
    local break_end
    local break_next
    local index = 1

    local function new_line(first)
        start = first
        width = 0
        last_content = first - 1
        space_end = nil
        break_end = nil
        break_next = nil
    end

    while index <= count do
        local character = chars[index]
        local space = word and is_space(character)

        if width > 0 and width + character.width > max_width then
            if not word then
                lines[#lines + 1] = { start, index - 1 }
                new_line(index)
            elseif space and last_content >= start then
                lines[#lines + 1] = { start, last_content }
                local next_index = index

                while next_index <= count and is_space(chars[next_index]) do
                    next_index = next_index + 1
                end

                new_line(next_index)
                index = next_index
            else
                local line_end, line_next = break_end, break_next
                local previous = chars[index - 1]

                if is_space(previous) then
                    if space_end and space_end >= start then
                        line_end, line_next = space_end, index
                    end
                elseif can_break_between(previous, character) then
                    line_end, line_next = index - 1, index
                end

                if line_end and line_end >= start and line_next > start then
                    lines[#lines + 1] = { start, line_end }
                    new_line(line_next)

                    for carried = line_next, index - 1 do
                        width = width + chars[carried].width

                        if not is_space(chars[carried]) then
                            last_content = carried
                        end
                    end
                else
                    lines[#lines + 1] = { start, index - 1 }
                    new_line(index)
                end
            end
        else
            if word and index > start then
                local previous = chars[index - 1]

                if space then
                    if not is_space(previous) then
                        space_end = index - 1
                    end
                elseif is_space(previous) then
                    if space_end then
                        break_end, break_next = space_end, index
                    end
                elseif can_break_between(previous, character) then
                    break_end, break_next = index - 1, index
                end
            end

            if not space then
                last_content = index
            end

            width = width + character.width
            index = index + 1
        end
    end

    if start <= count or #lines == 0 then
        lines[#lines + 1] = { start, count }
    end

    return lines
end

function Text.wrap(value, max_width, mode)
    check_string(value, 3)
    local chars = Text.characters(value)
    local lines = {}

    for _, range in ipairs(Text.wrap_ranges(chars, max_width, mode)) do
        local parts = {}

        for index = range[1], range[2] do
            parts[#parts + 1] = chars[index].text
        end

        lines[#lines + 1] = table.concat(parts)
    end

    return lines
end

return Text
