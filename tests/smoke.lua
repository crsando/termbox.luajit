package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Canvas = require("tui.canvas")
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

print("smoke: ok")
