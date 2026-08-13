package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Canvas = require("tui.canvas")
local Text = require("tui.text")
local Terminal = require("tui.terminal")
local native = require("ltermbox")

assert(Text.length("A中│") == 3)
assert(Text.width("A中│") == 4)
assert(Text.sub("A中│", 2, 2) == "中")
assert(Text.prefix("A中│", 2) == "A中")
assert(Text.suffix("A中│", 3) == "│")
assert(Text.range_width("A中│", 2, 3) == 3)

local taken, taken_width, taken_count = Text.take("A中文", 1, 3)
assert(taken == "中")
assert(taken_width == 2)
assert(taken_count == 1)

local wrapped = Text.wrap("A中文B", 3)
assert(#wrapped == 2)
assert(wrapped[1] == "A中")
assert(wrapped[2] == "文B")

local valid_utf8 = pcall(Text.length, "\255")
local valid_cell = pcall(native.set_cell, 0, 0, "中文", 0, 0, false)
local valid_empty_cell = pcall(native.set_cell, 0, 0, "", 0, 0, false)
local valid_scalar = pcall(native.wcwidth, 0xd800)
assert(not valid_utf8)
assert(not valid_cell)
assert(not valid_empty_cell)
assert(not valid_scalar)
assert(native.wcwidth(0x4e2d) == 2)
assert(native.wcwidth(0x2502) == 1)

local unicode_event = Terminal.normalize_event({
    type = "key",
    key = 0,
    ch = 0x4e2d,
})
assert(unicode_event.type == "text")
assert(unicode_event.text == "中")

local up_event = Terminal.normalize_event({
    type = "key",
    key = native.KEY_ARROW_UP,
    ch = 0,
})
assert(up_event.type == "key")
assert(up_event.code == "up")

local incomplete_event = Terminal.normalize_event({ type = "key", key = 0 })
assert(incomplete_event.type == "key")
assert(incomplete_event.code == "unknown")

local wheel_event = Terminal.normalize_event({
    type = "mouse",
    key = native.KEY_MOUSE_WHEEL_UP,
    x = 4,
    y = 2,
})
assert(wheel_event.type == "mouse")
assert(wheel_event.action == "wheel_up")
assert(wheel_event.x == 4)
assert(wheel_event.y == 2)

local canvas = Canvas.new(8, 3)
assert(canvas:text(0, 1, "A中B", {}) == 4)
assert(canvas.cells[1][0].ch == "A")
assert(canvas.cells[1][1].ch == "中")
assert(canvas.cells[1][1].width == 2)
assert(canvas.cells[1][2].continuation)
assert(canvas.cells[1][2].owner_x == 1)
assert(canvas.cells[1][3].ch == "B")

canvas:set(2, 1, "x", {})
assert(canvas.cells[1][1].ch == " ")
assert(canvas.cells[1][2].ch == "x")
assert(not canvas.cells[1][2].continuation)

canvas:set(7, 1, "中", {})
assert(canvas.cells[1][7].ch == " ")

canvas:box({ x = 0, y = 0, width = 8, height = 3 }, {})
assert(canvas.cells[0][0].ch == "┌")
assert(canvas.cells[0][1].ch == "─")
assert(canvas.cells[1][0].ch == "│")
assert(canvas.cells[2][7].ch == "┘")

local clipped = Canvas.new(5, 3)
clipped:box({ x = 0, y = 0, width = 5, height = 3 }, {})
assert(clipped:text(1, 1, "A中", {}, 2) == 1)
assert(clipped.cells[1][1].ch == "A")
assert(clipped.cells[1][2].ch == " ")
assert(clipped.cells[1][4].ch == "│")

local ascii = Canvas.new(4, 3)
ascii:box({ x = 0, y = 0, width = 4, height = 3 }, { border = "ascii" })
assert(ascii.cells[0][0].ch == "+")
assert(ascii.cells[1][0].ch == "|")

print("text: ok")
