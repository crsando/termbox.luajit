local Text = require("tui.text")

local Markdown = {}

local function append_segment(segments, text, role)
    if text == "" then
        return
    end

    local previous = segments[#segments]

    if previous and previous.role == role then
        previous.text = previous.text .. text
    else
        segments[#segments + 1] = {
            text = text,
            role = role,
        }
    end
end

local escapable = {
    ["\\"] = true,
    ["*"] = true,
    ["_"] = true,
    ["#"] = true,
}

-- Decode "\*", "\_", "\#" and "\\" into literal characters that can never
-- act as markers.
local function scan(value)
    local source = Text.characters(value)
    local chars = {}
    local index = 1

    while index <= #source do
        local character = source[index]
        local following = source[index + 1]

        if character.text == "\\" and following and escapable[following.text] then
            chars[#chars + 1] = { text = following.text, escaped = true }
            index = index + 2
        else
            chars[#chars + 1] = { text = character.text }
            index = index + 1
        end
    end

    return chars
end

local function is_space(character)
    return character == nil or character.text:match("^%s$") ~= nil
end

-- ASCII letters/digits and any non-ASCII codepoint count as word characters,
-- matching CommonMark's "not whitespace and not punctuation" for CJK text.
local function is_word(character)
    if character == nil then
        return false
    end

    local text = character.text
    return #text > 1 or text:match("^%w$") ~= nil
end

local function is_marker(character, marker)
    return character ~= nil and not character.escaped and character.text == marker
end

local function marker_run(chars, index, marker)
    local length = 0

    while is_marker(chars[index + length], marker) do
        length = length + 1
    end

    return length
end

-- Simplified CommonMark flanking rules: an opener must be followed by a
-- non-space character and a closer preceded by one. "_" additionally may not
-- open or close inside a word, so snake_case_name stays plain.
local function can_open(chars, index, length, marker)
    if is_space(chars[index + length]) then
        return false
    end

    return marker ~= "_" or not is_word(chars[index - 1])
end

local function can_close(chars, index, length, marker)
    if is_space(chars[index - 1]) then
        return false
    end

    return marker ~= "_" or not is_word(chars[index + length])
end

local function next_closing_run(chars, start, marker)
    local index = start

    while index <= #chars do
        if is_marker(chars[index], marker)
            and not is_marker(chars[index - 1], marker)
        then
            local length = marker_run(chars, index, marker)

            if can_close(chars, index, length, marker) then
                return index, length
            end

            index = index + length
        else
            index = index + 1
        end
    end

    return nil, nil
end

function Markdown.inline(value)
    local chars = scan(value)
    local segments = {}
    local plain = {}
    local index = 1

    local function flush_plain()
        if #plain > 0 then
            append_segment(segments, table.concat(plain), "normal")
            plain = {}
        end
    end

    local function push_plain(first, last)
        for plain_index = first, last do
            plain[#plain + 1] = chars[plain_index].text
        end
    end

    while index <= #chars do
        local character = chars[index]
        local marker = not character.escaped and character.text
        local marker_length
        local role

        if marker == "*" or marker == "_" then
            marker_length = marker_run(chars, index, marker)

            if marker_length <= 3
                and can_open(chars, index, marker_length, marker)
            then
                role = marker_length == 1 and "emphasis"
                    or marker_length == 2 and "strong"
                    or "strong_emphasis"
            end
        end

        if role then
            local close, close_length = next_closing_run(
                chars,
                index + marker_length,
                marker
            )

            if close and close_length == marker_length then
                flush_plain()

                local content = {}

                for content_index = index + marker_length, close - 1 do
                    content[#content + 1] = chars[content_index].text
                end

                append_segment(segments, table.concat(content), role)
                index = close + marker_length
            elseif close then
                push_plain(index, close + close_length - 1)
                index = close + close_length
            else
                push_plain(index, index + marker_length - 1)
                index = index + marker_length
            end
        elseif marker_length then
            push_plain(index, index + marker_length - 1)
            index = index + marker_length
        else
            plain[#plain + 1] = character.text
            index = index + 1
        end
    end

    flush_plain()
    return segments
end

function Markdown.parse_line(value)
    local hashes, content = value:match("^(#+)[ \t]+(.+)$")

    if hashes and #hashes <= 4 then
        return {
            heading = #hashes,
            segments = Markdown.inline(content),
        }
    end

    return {
        heading = nil,
        segments = Markdown.inline(value),
    }
end

function Markdown.wrap_line(line, max_width)
    if max_width <= 0 then
        return {}
    end

    local result = {}
    local current = {
        heading = line.heading,
        segments = {},
        width = 0,
    }

    local function finish_line()
        result[#result + 1] = current
        current = {
            heading = line.heading,
            segments = {},
            width = 0,
        }
    end

    for _, segment in ipairs(line.segments) do
        for _, character in ipairs(Text.characters(segment.text)) do
            if current.width > 0
                and current.width + character.width > max_width
            then
                finish_line()
            end

            append_segment(current.segments, character.text, segment.role)
            current.width = current.width + character.width
        end
    end

    if current.width > 0 or #result == 0 then
        finish_line()
    end

    return result
end

return Markdown
