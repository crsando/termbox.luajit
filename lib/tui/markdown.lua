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

local function same_marker(chars, index, marker, length)
    for offset = 0, length - 1 do
        if not chars[index + offset] or chars[index + offset].text ~= marker then
            return false
        end
    end

    return true
end

local function closing_marker(chars, start, marker, length)
    for index = start, #chars - length + 1 do
        if same_marker(chars, index, marker, length) then
            return index
        end
    end

    return nil
end

function Markdown.inline(value)
    local chars = Text.characters(value)
    local segments = {}
    local plain = {}
    local index = 1

    local function flush_plain()
        if #plain > 0 then
            append_segment(segments, table.concat(plain), "normal")
            plain = {}
        end
    end

    while index <= #chars do
        local marker = chars[index].text
        local marker_length
        local role

        if (marker == "*" or marker == "_") and same_marker(chars, index, marker, 3) then
            marker_length = 3
            role = "strong_emphasis"
        elseif (marker == "*" or marker == "_") and same_marker(chars, index, marker, 2) then
            marker_length = 2
            role = "strong"
        elseif marker == "*" or marker == "_" then
            marker_length = 1
            role = "emphasis"
        end

        if marker_length then
            local close = closing_marker(
                chars,
                index + marker_length,
                marker,
                marker_length
            )

            if close and close > index + marker_length then
                flush_plain()

                local content = {}

                for content_index = index + marker_length, close - 1 do
                    content[#content + 1] = chars[content_index].text
                end

                append_segment(segments, table.concat(content), role)
                index = close + marker_length
            else
                plain[#plain + 1] = marker
                index = index + 1
            end
        else
            plain[#plain + 1] = marker
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

local function append_visual_segment(segments, text, role)
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

            append_visual_segment(current.segments, character.text, segment.role)
            current.width = current.width + character.width
        end
    end

    if current.width > 0 or #result == 0 then
        finish_line()
    end

    return result
end

return Markdown
