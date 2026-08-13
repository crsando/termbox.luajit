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

function Text.wrap(value, max_width)
    check_string(value, 3)

    if max_width <= 0 then
        return {}
    end

    local lines = {}
    local parts = {}
    local width = 0

    for _, character in ipairs(Text.characters(value)) do
        if width > 0 and width + character.width > max_width then
            lines[#lines + 1] = table.concat(parts)
            parts = {}
            width = 0
        end

        parts[#parts + 1] = character.text
        width = width + character.width
    end

    lines[#lines + 1] = table.concat(parts)
    return lines
end

return Text
