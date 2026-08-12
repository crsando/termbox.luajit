package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Color = require("tui.color")
local ColorEncoder = require("tui.color_encoder")
local native = require("ltermbox")

local function encoder(opts)
    opts = opts or {}
    opts.env = opts.env or {}
    opts.has_truecolor = opts.has_truecolor ~= false
    opts.bright_attribute = native.ATTR_BRIGHT
    opts.black_attribute = native.ATTR_HI_BLACK
    return ColorEncoder.new(opts)
end

assert(native.attr_width() == 32)
assert(native.has_truecolor())

assert(Color.rgb(0x12, 0x34, 0x56) == 0x123456)
assert(Color.hex("#d3d3d3") == Color.light_gray)
assert(Color.normalize("red") == Color.red)
assert(Color.normalize("#ffffff") == 0xffffff)
assert(Color.normalize(nil) == Color.default)

local valid_rgb = pcall(Color.rgb, 256, 0, 0)
local valid_name = pcall(Color.normalize, "orange")
local valid_hex = pcall(Color.hex, "#fff")
assert(not valid_rgb)
assert(not valid_name)
assert(not valid_hex)

local truecolor = encoder({ mode = "truecolor" })
assert(truecolor.mode == "truecolor")
assert(truecolor:encode(Color.default) == 0)
assert(truecolor:encode(Color.black) == native.ATTR_HI_BLACK)
assert(truecolor:encode(0x123456) == 0x123456)
assert(truecolor:encode(0x123456) == truecolor.cache[0x123456])

local indexed = encoder({ mode = "256" })
assert(indexed:encode(Color.bright_red) == 196)
assert(indexed:encode(Color.light_gray) == 252)
assert(indexed:encode(Color.black) == 16)

local normal = encoder({ mode = "normal" })
assert(normal:encode(Color.red) == 2)
assert(normal:encode(Color.bright_red) == 2 + native.ATTR_BRIGHT)
assert(normal:encode(Color.white) == 8)

local explicit = encoder({
    mode = "256",
    env = { TUI_COLOR_MODE = "truecolor" },
})
assert(explicit.mode == "256")

local configured = encoder({
    env = { TUI_COLOR_MODE = "truecolor" },
})
assert(configured.mode == "truecolor")

local configured_256 = encoder({
    env = { TUI_COLOR_MODE = "256", COLORTERM = "truecolor" },
})
assert(configured_256.mode == "256")

local detected_truecolor = encoder({
    env = { COLORTERM = "24bit", TERM = "xterm-256color" },
})
assert(detected_truecolor.mode == "truecolor")

local detected_256 = encoder({
    env = { TERM = "xterm-256color" },
})
assert(detected_256.mode == "256")

local fallback = encoder({ env = { TERM = "xterm" } })
assert(fallback.mode == "normal")

local no_color = encoder({
    env = { NO_COLOR = "1", COLORTERM = "truecolor" },
})
assert(no_color.mode == "normal")
assert(no_color.no_color)
assert(no_color:encode(Color.red) == 0)

local compiled_fallback = encoder({
    env = { COLORTERM = "truecolor", TERM = "xterm-256color" },
    has_truecolor = false,
})
assert(compiled_fallback.mode == "256")

local valid_truecolor = pcall(function()
    encoder({ mode = "truecolor", has_truecolor = false })
end)
assert(not valid_truecolor)

print("colors: ok")
