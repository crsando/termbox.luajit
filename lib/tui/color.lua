local Color = {}

local named = {
    black = 0x000000,
    red = 0x800000,
    green = 0x008000,
    yellow = 0x808000,
    blue = 0x000080,
    magenta = 0x800080,
    cyan = 0x008080,
    white = 0xc0c0c0,
    bright_black = 0x808080,
    bright_red = 0xff0000,
    bright_green = 0x00ff00,
    bright_yellow = 0xffff00,
    bright_blue = 0x0000ff,
    bright_magenta = 0xff00ff,
    bright_cyan = 0x00ffff,
    bright_white = 0xffffff,
    light_gray = 0xd3d3d3,
}

Color.default = "default"

local function check_channel(value, name)
    if type(value) ~= "number"
        or value ~= math.floor(value)
        or value < 0
        or value > 255
    then
        error(name .. " must be an integer between 0 and 255", 3)
    end

    return value
end

function Color.rgb(red, green, blue)
    red = check_channel(red, "red")
    green = check_channel(green, "green")
    blue = check_channel(blue, "blue")
    return red * 0x10000 + green * 0x100 + blue
end

function Color.hex(value)
    if type(value) ~= "string" then
        error("hex color must be a string", 2)
    end

    local digits = value:match("^#(%x%x%x%x%x%x)$")

    if not digits then
        error("hex color must use #RRGGBB format", 2)
    end

    return tonumber(digits, 16)
end

function Color.named(name)
    if type(name) ~= "string" then
        error("color name must be a string", 2)
    end

    local color = named[name:lower()]

    if color == nil then
        error("unknown color: " .. name, 2)
    end

    return color
end

function Color.normalize(value)
    if value == nil or value == Color.default then
        return Color.default
    end

    if type(value) == "number" then
        if value ~= math.floor(value) or value < 0 or value > 0xffffff then
            error("RGB color must be an integer between 0x000000 and 0xffffff", 2)
        end

        return value
    end

    if type(value) == "string" then
        if value:sub(1, 1) == "#" then
            return Color.hex(value)
        end

        return Color.named(value)
    end

    error("color must be default, a name, #RRGGBB, or an RGB number", 2)
end

function Color.channels(value)
    value = Color.normalize(value)

    if value == Color.default then
        error("default color has no RGB channels", 2)
    end

    return math.floor(value / 0x10000) % 0x100,
        math.floor(value / 0x100) % 0x100,
        value % 0x100
end

for name, value in pairs(named) do
    Color[name] = value
end

return Color
