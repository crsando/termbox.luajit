package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Canvas = require("tui.canvas")
local Color = require("tui.color")
local Markdown = require("tui.markdown")
local Widgets = require("tui.widgets")

local segments = Markdown.inline("normal *italic* **bold** _again_ __strong__")
assert(#segments == 8)
assert(segments[1].text == "normal ")
assert(segments[2].text == "italic")
assert(segments[2].role == "emphasis")
assert(segments[3].text == " ")
assert(segments[4].text == "bold")
assert(segments[4].role == "strong")
assert(segments[6].role == "emphasis")
assert(segments[8].role == "strong")

local heading = Markdown.parse_line("### *Title*")
assert(heading.heading == 3)
assert(heading.segments[1].text == "Title")
assert(heading.segments[1].role == "emphasis")

local plain = Markdown.parse_line("not a # heading")
assert(plain.heading == nil)
assert(plain.segments[1].text == "not a # heading")

local unclosed = Markdown.inline("keep *this marker")
assert(unclosed[1].text == "keep *this marker")
assert(unclosed[1].role == "normal")

local wrapped = Markdown.wrap_line(
    Markdown.parse_line("# A *long heading*"),
    8
)
assert(#wrapped == 2)
assert(wrapped[1].heading == 1)
assert(wrapped[1].segments[1].text == "A ")
assert(wrapped[2].segments[1].role == "emphasis")

local box = Widgets.TextBox.new({
    format = "markdown",
    text = "# Title\nplain *italic* and **bold**",
    follow_tail = false,
})
local canvas = Canvas.new(38, 8)
box:view(canvas, { x = 0, y = 0, width = 38, height = 8 })

assert(box.parsed_lines ~= nil)
assert(box.layout_lines ~= nil)
assert(canvas.cells[1][1].ch == "T")
assert(canvas.cells[1][1].bold)
assert(canvas.cells[1][1].fg == Color.rgb(255, 214, 102))
assert(canvas.cells[2][7].ch == "i")
assert(canvas.cells[2][7].italic)
assert(canvas.cells[2][7].fg == Color.rgb(116, 192, 252))
assert(canvas.cells[2][18].ch == "b")
assert(canvas.cells[2][18].bold)

print("markdown: ok")
