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

local mismatched_strong = Markdown.inline("**bold*")
assert(#mismatched_strong == 1)
assert(mismatched_strong[1].text == "**bold*")
assert(mismatched_strong[1].role == "normal")

local mismatched_emphasis = Markdown.inline("*italic**")
assert(#mismatched_emphasis == 1)
assert(mismatched_emphasis[1].text == "*italic**")
assert(mismatched_emphasis[1].role == "normal")

local strong_emphasis = Markdown.inline("***both*** ___also both___")
assert(#strong_emphasis == 3)
assert(strong_emphasis[1].text == "both")
assert(strong_emphasis[1].role == "strong_emphasis")
assert(strong_emphasis[3].text == "also both")
assert(strong_emphasis[3].role == "strong_emphasis")

local mismatched_strong_emphasis = Markdown.inline("***both**")
assert(#mismatched_strong_emphasis == 1)
assert(mismatched_strong_emphasis[1].text == "***both**")
assert(mismatched_strong_emphasis[1].role == "normal")

local recovered = Markdown.inline("**bad* *ok*")
assert(#recovered == 2)
assert(recovered[1].text == "**bad* ")
assert(recovered[1].role == "normal")
assert(recovered[2].text == "ok")
assert(recovered[2].role == "emphasis")

local wrapped = Markdown.wrap_line(
    Markdown.parse_line("# A *long heading*"),
    8
)
assert(#wrapped == 2)
assert(wrapped[1].heading == 1)
assert(wrapped[1].segments[1].text == "A ")
assert(wrapped[2].segments[1].role == "emphasis")

local unicode_wrapped = Markdown.wrap_line(
    Markdown.parse_line("A中B"),
    3
)
assert(#unicode_wrapped == 2)
assert(unicode_wrapped[1].segments[1].text == "A中")
assert(unicode_wrapped[2].segments[1].text == "B")

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

local themed = Widgets.TextBox.new({
    format = "markdown",
    text = "### *Title*",
    markdown_theme = {
        normal = { bg = Color.rgb(1, 2, 3) },
        heading = {
            [3] = { bold = false },
        },
    },
})
local themed_canvas = Canvas.new(20, 3)
themed:view(themed_canvas, { x = 0, y = 0, width = 20, height = 3 })

assert(themed_canvas.cells[1][1].ch == "T")
assert(themed_canvas.cells[1][1].italic)
assert(not themed_canvas.cells[1][1].bold)
assert(themed_canvas.cells[1][1].fg == Color.rgb(105, 219, 124))
assert(themed_canvas.cells[1][1].bg == Color.rgb(1, 2, 3))

local combined = Widgets.TextBox.new({
    format = "markdown",
    text = "***both***",
    markdown_theme = {
        strong_emphasis = { fg = Color.rgb(1, 2, 3) },
    },
})
local combined_canvas = Canvas.new(20, 3)
combined:view(combined_canvas, { x = 0, y = 0, width = 20, height = 3 })

assert(combined_canvas.cells[1][1].ch == "b")
assert(combined_canvas.cells[1][1].bold)
assert(combined_canvas.cells[1][1].italic)
assert(combined_canvas.cells[1][1].fg == Color.rgb(1, 2, 3))

local original_layout = box.layout_lines
box:update({ type = "set_text", text = "# Changed" })
assert(box.layout_lines == nil)
box:view(Canvas.new(12, 3), { x = 0, y = 0, width = 12, height = 3 })
assert(box.layout_width == 10)
assert(box.layout_lines ~= original_layout)

local wide_layout = box.layout_lines
box:view(Canvas.new(8, 4), { x = 0, y = 0, width = 8, height = 4 })
assert(box.layout_width == 6)
assert(box.layout_lines ~= wide_layout)

assert(not pcall(Widgets.TextBox.new, { format = "md" }))
assert(not pcall(Widgets.TextBox.new, { format = false }))
assert(not pcall(Widgets.TextBox.new, {
    format = "markdown",
    markdown_theme = { heading = "invalid" },
}))

print("markdown: ok")
