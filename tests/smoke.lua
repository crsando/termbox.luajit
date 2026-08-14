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

local wide_prompt_canvas = Canvas.new(20, 4)
long_prompt:view(wide_prompt_canvas, {
    x = 0,
    y = 0,
    width = 20,
    height = 3,
})

assert(long_prompt.scroll == 0)
assert(wide_prompt_canvas.cells[1][3].ch == "a")
assert(wide_prompt_canvas.cells[1][10].ch == "h")
assert(wide_prompt_canvas.cursor.x == 11)

local unicode_prompt = Widgets.PromptBox.new({ prompt = "你>" })
unicode_prompt:update({ type = "text", text = "中a文" })
assert(unicode_prompt.cursor == 3)
unicode_prompt:update({ type = "key", code = "left" })
unicode_prompt:update({ type = "key", code = "backspace" })
assert(unicode_prompt.value == "中文")
assert(unicode_prompt.cursor == 1)

local unicode_canvas = Canvas.new(12, 3)
unicode_prompt:view(unicode_canvas, {
    x = 0,
    y = 0,
    width = 12,
    height = 3,
})
assert(unicode_canvas.cells[1][1].ch == "你")
assert(unicode_canvas.cells[1][2].continuation)
assert(unicode_canvas.cells[1][3].ch == ">")
assert(unicode_canvas.cells[1][4].ch == "中")
assert(unicode_canvas.cursor.x == 6)

local narrow_unicode_canvas = Canvas.new(8, 3)
unicode_prompt:update({ type = "key", code = "ctrl-e" })
unicode_prompt:view(narrow_unicode_canvas, {
    x = 0,
    y = 0,
    width = 8,
    height = 3,
})
assert(unicode_prompt.scroll == 1)
assert(narrow_unicode_canvas.cells[1][4].ch == "文")
assert(narrow_unicode_canvas.cursor.x == 6)

local history = { "first", "中文" }
local history_prompt = Widgets.PromptBox.new({ history = history })
history_prompt:update({ type = "text", text = "draft" })
history_prompt:update({ type = "key", code = "up" })
assert(history_prompt.value == "中文")
history_prompt:update({ type = "key", code = "up" })
assert(history_prompt.value == "first")
history_prompt:update({ type = "key", code = "up" })
assert(history_prompt.value == "first")
history_prompt:update({ type = "key", code = "down" })
assert(history_prompt.value == "中文")
history_prompt:update({ type = "key", code = "down" })
assert(history_prompt.value == "draft")
assert(history_prompt.history_index == nil)

history_prompt:update({ type = "key", code = "up" })
history_prompt:update({ type = "text", text = "!" })
assert(history_prompt.value == "中文!")
assert(history_prompt.history_index == nil)
assert(history[2] == "中文")
assert(history_prompt:update({ type = "key", code = "enter" }) == "中文!")
assert(history[#history] == "中文!")

local scrolling = Widgets.TextBox.new({
    text = "one\ntwo\nthree\nfour\nfive",
    follow_tail = true,
})
local scrolling_canvas = Canvas.new(12, 4)
local scrolling_rect = { x = 0, y = 0, width = 12, height = 4 }
scrolling:view(scrolling_canvas, scrolling_rect)
assert(scrolling.max_scroll == 3)
assert(scrolling.scroll == 3)

scrolling:update({ type = "scroll", delta = -3 })
assert(scrolling.scroll == 0)
assert(not scrolling.at_tail)
scrolling:update({
    type = "set_text",
    text = "one\ntwo\nthree\nfour\nfive\nsix",
})
scrolling:view(Canvas.new(12, 4), scrolling_rect)
assert(scrolling.max_scroll == 4)
assert(scrolling.scroll == 0)

scrolling:update({ type = "scroll", delta = 20 })
assert(scrolling.scroll == 4)
assert(scrolling.at_tail)
scrolling:update({
    type = "set_text",
    text = "one\ntwo\nthree\nfour\nfive\nsix\nseven",
})
scrolling:view(Canvas.new(12, 4), scrolling_rect)
assert(scrolling.max_scroll == 5)
assert(scrolling.scroll == 5)

assert(scrolling:update({ type = "mouse", action = "wheel_up" }))
assert(scrolling.scroll == 2)
assert(not scrolling.at_tail)
assert(scrolling:update({ type = "mouse", action = "wheel_down" }))
assert(scrolling.scroll == 5)
assert(scrolling.at_tail)

local ignored_prompt = Widgets.PromptBox.new({ history = { "previous" } })
ignored_prompt:update({ type = "text", text = "draft" })
assert(not ignored_prompt:update({
    type = "mouse",
    action = "wheel_up",
}))
assert(ignored_prompt.value == "draft")
assert(ignored_prompt.history_index == nil)

local unicode_text_box = Widgets.TextBox.new({ text = "A中文B" })
local unicode_text_canvas = Canvas.new(7, 4)
unicode_text_box:view(unicode_text_canvas, {
    x = 0,
    y = 0,
    width = 7,
    height = 4,
})
assert(unicode_text_canvas.cells[1][1].ch == "A")
assert(unicode_text_canvas.cells[1][2].ch == "中")
assert(unicode_text_canvas.cells[2][1].ch == "B")

local tiny_prompt = Widgets.PromptBox.new({ prompt = "> " })
local tiny_canvas = Canvas.new(6, 2)
tiny_prompt:view(tiny_canvas, { x = 0, y = 0, width = 6, height = 2 })
assert(tiny_canvas.cursor == nil)

local resized_prompt = Widgets.PromptBox.new({ prompt = "> " })
resized_prompt:update({ type = "text", text = "abcdef" })
resized_prompt:view(Canvas.new(4, 3), {
    x = 0,
    y = 0,
    width = 4,
    height = 3,
})
assert(resized_prompt.scroll == 6)

local resized_canvas = Canvas.new(20, 3)
resized_prompt:view(resized_canvas, {
    x = 0,
    y = 0,
    width = 20,
    height = 3,
})
assert(resized_prompt.scroll == 0)
assert(resized_canvas.cells[1][3].ch == "a")
assert(resized_canvas.cursor.x == 9)

print("smoke: ok")
