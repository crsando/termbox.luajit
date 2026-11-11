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
assert(native.error_string(-8) == "Termbox not initialized")
assert(native.set_cell(0, 0, "x", 0, 0, false, false) == -8)
assert(native.hide_cursor() == -8)

local poll_ok, poll_error = pcall(native.poll, 0)
assert(not poll_ok)
assert(tostring(poll_error):find("Termbox not initialized", 1, true))

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

local key_typed_wheel = Terminal.normalize_event({
    type = "key",
    key = native.KEY_MOUSE_WHEEL_DOWN,
    ch = 0,
})
assert(key_typed_wheel.type == "mouse")
assert(key_typed_wheel.action == "wheel_down")

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

assert(Text.sanitize("plain") == "plain")
assert(Text.sanitize("a\tb") == "a   b")
assert(Text.sanitize("中\tx") == "中  x")
assert(Text.sanitize("ab\r\ncd\te") == "ab\ncd  e")
assert(Text.sanitize("x\0y\127z\194\133w") == "xyzw")
assert(Text.sanitize("\t", 8) == "        ")
assert(Text.is_control(9) and Text.is_control(0x9b))
assert(not Text.is_control(10) and not Text.is_control(32))

local function joined(value, width, mode)
    return table.concat(Text.wrap(value, width, mode), "|")
end

assert(joined("hello world foo", 11, "word") == "hello world|foo")
assert(joined("hello world foo", 8, "word") == "hello|world|foo")
assert(joined("abcdefghij xy", 4, "word") == "abcd|efgh|ij|xy")
assert(joined("  indented text here", 10, "word") == "  indented|text here")
assert(joined("a    b", 3, "word") == "a|b")
assert(joined("word   ", 4, "word") == "word")
assert(joined("x 中文", 3, "word") == "x|中|文")
assert(joined("中文文本，测试换行。", 6, "word") == "中文文|本，测|试换|行。")
assert(joined("你好（世界）", 6, "word") == "你好|（世|界）")
assert(joined("A中文B", 3, "word") == "A中|文B")
assert(joined("", 5, "word") == "")
assert(#Text.wrap("abc", 0, "word") == 0)
assert(joined("hello world", 8) == "hello wo|rld")

print("text: ok")
