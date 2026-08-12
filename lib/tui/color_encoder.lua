local Color = require("tui.color")

local ColorEncoder = {}
ColorEncoder.__index = ColorEncoder

local modes = {
    auto = true,
    normal = true,
    ["256"] = true,
    truecolor = true,
}

local normal_palette = {
    { color = 0x000000, base = 1 },
    { color = 0x800000, base = 2 },
    { color = 0x008000, base = 3 },
    { color = 0x808000, base = 4 },
    { color = 0x000080, base = 5 },
    { color = 0x800080, base = 6 },
    { color = 0x008080, base = 7 },
    { color = 0xc0c0c0, base = 8 },
    { color = 0x808080, base = 1, bright = true },
    { color = 0xff0000, base = 2, bright = true },
    { color = 0x00ff00, base = 3, bright = true },
    { color = 0xffff00, base = 4, bright = true },
    { color = 0x0000ff, base = 5, bright = true },
    { color = 0xff00ff, base = 6, bright = true },
    { color = 0x00ffff, base = 7, bright = true },
    { color = 0xffffff, base = 8, bright = true },
}

local cube_levels = { 0, 95, 135, 175, 215, 255 }

local function env_value(env, name)
    if env then
        return env[name]
    end

    return os.getenv(name)
end

local function check_mode(mode, source)
    mode = mode or "auto"

    if not modes[mode] then
        error(source .. " must be auto, truecolor, 256, or normal", 3)
    end

    return mode
end

local function explicit_mode(mode, has_truecolor, source)
    mode = check_mode(mode, source)

    if mode == "truecolor" and not has_truecolor then
        error(source .. " requests truecolor, but the binding does not support it", 3)
    end

    return mode
end

local function resolve_mode(opts)
    local requested = explicit_mode(
        opts.mode or "auto",
        opts.has_truecolor,
        "color mode"
    )

    if requested ~= "auto" then
        return requested, false
    end

    local configured = env_value(opts.env, "TUI_COLOR_MODE")

    if configured and configured ~= "" then
        configured = explicit_mode(
            configured:lower(),
            opts.has_truecolor,
            "TUI_COLOR_MODE"
        )

        if configured ~= "auto" then
            return configured, false
        end
    end

    local no_color = env_value(opts.env, "NO_COLOR")

    if no_color and no_color ~= "" then
        return "normal", true
    end

    local color_term = (env_value(opts.env, "COLORTERM") or ""):lower()

    if opts.has_truecolor
        and (color_term == "truecolor" or color_term == "24bit")
    then
        return "truecolor", false
    end

    local term = (env_value(opts.env, "TERM") or ""):lower()

    if term:find("256color", 1, true) then
        return "256", false
    end

    return "normal", false
end

local function distance(red, green, blue, color)
    local other_red, other_green, other_blue = Color.channels(color)
    local delta_red = red - other_red
    local delta_green = green - other_green
    local delta_blue = blue - other_blue

    return 30 * delta_red * delta_red
        + 59 * delta_green * delta_green
        + 11 * delta_blue * delta_blue
end

local function nearest_cube_level(channel)
    local best_index = 0
    local best_delta = math.huge

    for index = 0, 5 do
        local delta = math.abs(channel - cube_levels[index + 1])

        if delta < best_delta then
            best_index = index
            best_delta = delta
        end
    end

    return best_index, cube_levels[best_index + 1]
end

local function encode_256(color)
    local red, green, blue = Color.channels(color)
    local red_index, cube_red = nearest_cube_level(red)
    local green_index, cube_green = nearest_cube_level(green)
    local blue_index, cube_blue = nearest_cube_level(blue)
    local cube_color = Color.rgb(cube_red, cube_green, cube_blue)
    local cube_distance = distance(red, green, blue, cube_color)
    local cube_index = 16 + 36 * red_index + 6 * green_index + blue_index
    local luminance = (30 * red + 59 * green + 11 * blue) / 100
    local gray_index = math.max(
        0,
        math.min(23, math.floor((luminance - 8) / 10 + 0.5))
    )
    local gray_level = 8 + 10 * gray_index
    local gray_color = Color.rgb(gray_level, gray_level, gray_level)
    local gray_distance = distance(red, green, blue, gray_color)

    if gray_distance < cube_distance then
        return 232 + gray_index
    end

    return cube_index
end

local function encode_normal(color, bright_attribute)
    local red, green, blue = Color.channels(color)
    local best
    local best_distance = math.huge

    for _, candidate in ipairs(normal_palette) do
        local candidate_distance = distance(red, green, blue, candidate.color)

        if candidate_distance < best_distance then
            best = candidate
            best_distance = candidate_distance
        end
    end

    if best.bright then
        return best.base + bright_attribute
    end

    return best.base
end

function ColorEncoder.new(opts)
    opts = opts or {}

    if opts.has_truecolor == nil then
        opts.has_truecolor = true
    end

    local mode, no_color = resolve_mode(opts)

    return setmetatable({
        mode = mode,
        no_color = no_color,
        bright_attribute = opts.bright_attribute or 0x40000000,
        black_attribute = opts.black_attribute or 0x20000000,
        cache = {},
    }, ColorEncoder)
end

function ColorEncoder:encode(value)
    local color = Color.normalize(value)

    if color == Color.default or self.no_color then
        return 0
    end

    local cached = self.cache[color]

    if cached ~= nil then
        return cached
    end

    local encoded

    if self.mode == "truecolor" then
        encoded = color == 0 and self.black_attribute or color
    elseif self.mode == "256" then
        encoded = encode_256(color)
    else
        encoded = encode_normal(color, self.bright_attribute)
    end

    self.cache[color] = encoded
    return encoded
end

return ColorEncoder
