local Color = require("tui.color")
local Text = require("tui.text")
local Canvas = {}
Canvas.__index = Canvas

local borders = {
    ascii = {
        top_left = "+",
        top_right = "+",
        bottom_left = "+",
        bottom_right = "+",
        horizontal = "-",
        vertical = "|",
    },
    single = {
        top_left = "┌",
        top_right = "┐",
        bottom_left = "└",
        bottom_right = "┘",
        horizontal = "─",
        vertical = "│",
    },
    rounded = {
        top_left = "╭",
        top_right = "╮",
        bottom_left = "╰",
        bottom_right = "╯",
        horizontal = "─",
        vertical = "│",
    },
    double = {
        top_left = "╔",
        top_right = "╗",
        bottom_left = "╚",
        bottom_right = "╝",
        horizontal = "═",
        vertical = "║",
    },
}

local function new_cell(ch, style)
    style = style or {}

    return {
        ch = ch or " ",
        fg = Color.normalize(style.fg),
        bg = Color.normalize(style.bg),
        bold = style.bold,
    }
end

function Canvas.new(width, height)
    local cells = {}

    for y = 0, height - 1 do
        cells[y] = {}

        for x = 0, width - 1 do
            cells[y][x] = new_cell()
        end
    end

    return setmetatable({
        width = width,
        height = height,
        cells = cells,
        cursor = nil,
    }, Canvas)
end

function Canvas:clear_span(x, y)
    local cell = self.cells[y][x]
    local start_x = cell.owner_x or x
    local start = self.cells[y][start_x]
    local width = start.width or 1

    for cell_x = start_x, math.min(self.width - 1, start_x + width - 1) do
        self.cells[y][cell_x] = new_cell()
    end
end

function Canvas:set(x, y, ch, style)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return false
    end

    if ch == "" then
        ch = " "
    end

    local characters = Text.characters(ch)

    if #characters ~= 1 then
        error("Canvas:set expects exactly one UTF-8 codepoint", 2)
    end

    local width = characters[1].width

    if x + width > self.width then
        self:clear_span(x, y)
        return false
    end

    self:clear_span(x, y)

    for offset = 1, width - 1 do
        self:clear_span(x + offset, y)
    end

    self.cells[y][x] = new_cell(ch, style)
    self.cells[y][x].width = width

    for offset = 1, width - 1 do
        local continuation = new_cell(" ", style)
        continuation.continuation = true
        continuation.owner_x = x
        self.cells[y][x + offset] = continuation
    end

    return true
end

function Canvas:text(x, y, text, style, max_width)
    local column = x
    local drawn_width = 0

    for _, character in ipairs(Text.characters(text)) do
        if (max_width and drawn_width + character.width > max_width)
            or column + character.width > self.width
        then
            break
        end

        if column >= 0 then
            self:set(column, y, character.text, style)
        end

        column = column + character.width
        drawn_width = drawn_width + character.width
    end

    return drawn_width
end

function Canvas:fill(rect, style)
    for y = rect.y, rect.y + rect.height - 1 do
        for x = rect.x, rect.x + rect.width - 1 do
            self:set(x, y, " ", style)
        end
    end
end

function Canvas:box(rect, style)
    if rect.width < 2 or rect.height < 2 then
        return
    end

    style = style or {}
    local border = style.border or "single"

    if type(border) == "string" then
        border = borders[border]
    end

    if not border then
        error("unknown border style", 2)
    end

    self:set(rect.x, rect.y, border.top_left, style)
    self:set(rect.x + rect.width - 1, rect.y, border.top_right, style)
    self:set(rect.x, rect.y + rect.height - 1, border.bottom_left, style)
    self:set(
        rect.x + rect.width - 1,
        rect.y + rect.height - 1,
        border.bottom_right,
        style
    )

    for x = rect.x + 1, rect.x + rect.width - 2 do
        self:set(x, rect.y, border.horizontal, style)
        self:set(x, rect.y + rect.height - 1, border.horizontal, style)
    end

    for y = rect.y + 1, rect.y + rect.height - 2 do
        self:set(rect.x, y, border.vertical, style)
        self:set(rect.x + rect.width - 1, y, border.vertical, style)
    end
end

function Canvas:cursor_at(x, y)
    self.cursor = { x = x, y = y }
end

return Canvas
