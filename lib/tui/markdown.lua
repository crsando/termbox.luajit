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

local function marker_run(chars, index, marker)
    local length = 0

    while chars[index + length] and chars[index + length].text == marker do
        length = length + 1
    end

    return length
end

local function next_marker_run(chars, start, marker)
    for index = start, #chars do
        if chars[index].text == marker then
            return index, marker_run(chars, index, marker)
        end
    end

    return nil, nil
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

        if marker == "*" or marker == "_" then
            marker_length = marker_run(chars, index, marker)

            if marker_length == 1 then
                role = "emphasis"
            elseif marker_length == 2 then
                role = "strong"
            end
        end

        if role then
            local close, close_length = next_marker_run(
                chars,
                index + marker_length,
                marker
            )

            if close
                and close_length == marker_length
                and close > index + marker_length
            then
                flush_plain()

                local content = {}

                for content_index = index + marker_length, close - 1 do
                    content[#content + 1] = chars[content_index].text
                end

                append_segment(segments, table.concat(content), role)
                index = close + marker_length
            elseif close then
                for plain_index = index, close + close_length - 1 do
                    plain[#plain + 1] = chars[plain_index].text
                end

                index = close + close_length
            else
                for _ = 1, marker_length do
                    plain[#plain + 1] = marker
                end

                index = index + marker_length
            end
        elseif marker_length then
            for _ = 1, marker_length do
                plain[#plain + 1] = marker
            end

            index = index + marker_length
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
