package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Canvas = require("tui.canvas")
local Color = require("tui.color")
local Widgets = require("tui.widgets")

local canvas = Canvas.new(40, 8)
local text_box = Widgets.TextBox.new({ text = "hello\nworld" })
text_box:view(canvas, { x = 0, y = 0, width = 20, height = 4 })

local prompt_box = Widgets.PromptBox.new({ prompt = "> " })
prompt_box:update({ type = "text", text = "abc" })
prompt_box:update({ type = "key", code = "backspace" })
prompt_box:view(canvas, { x = 0, y = 4, width = 20, height = 3 })

assert(canvas.cells[1][1].ch == "h")
assert(prompt_box.value == "ab")
assert(canvas.cells[4][0].ch == " ")
assert(canvas.cells[4][0].bg == Color.hex("#1e1e1e"))
assert(canvas.cells[5][1].ch == ">")
assert(canvas.cells[5][1].fg == Color.rgb(168, 170, 166))
assert(canvas.cells[5][1].bg == Color.hex("#1e1e1e"))
assert(canvas.cells[5][3].ch == "a")
assert(canvas.cells[5][3].fg == Color.rgb(168, 170, 166))
assert(canvas.cells[5][3].bg == Color.hex("#1e1e1e"))

prompt_box:update({ type = "key", code = "enter" })
assert(prompt_box.submitted == "ab")
assert(prompt_box.value == "")

local tail = Widgets.TextBox.new({
    text = "one\ntwo\nthree\nfour",
    follow_tail = true,
})
local tail_canvas = Canvas.new(20, 4)
tail:view(tail_canvas, { x = 0, y = 0, width = 10, height = 4 })

assert(tail.scroll == 2)
assert(tail_canvas.cells[1][1].ch == "t")

local long_prompt = Widgets.PromptBox.new({ prompt = "> " })
long_prompt:update({ type = "text", text = "abcdefghij" })
local prompt_canvas = Canvas.new(20, 4)
long_prompt:view(prompt_canvas, { x = 0, y = 0, width = 8, height = 3 })

assert(long_prompt.cursor == 10)
assert(long_prompt.scroll == 7)
assert(prompt_canvas.cells[1][3].ch == "h")
assert(prompt_canvas.cursor.x == 6)

long_prompt:update({ type = "key", code = "left" })
long_prompt:update({ type = "key", code = "left" })
long_prompt:view(prompt_canvas, { x = 0, y = 0, width = 8, height = 3 })

assert(long_prompt.cursor == 8)
assert(long_prompt.scroll == 7)
assert(prompt_canvas.cursor.x == 4)

print("smoke: ok")
