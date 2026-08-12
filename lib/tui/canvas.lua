local Canvas = {}
Canvas.__index = Canvas

function Canvas.new(width, height)
    local cells = {}

    for y = 0, height - 1 do
        cells[y] = {}

        for x = 0, width - 1 do
            cells[y][x] = {
                ch = " ",
                fg = "default",
                bg = "default",
            }
        end
    end

    return setmetatable({
        width = width,
        height = height,
        cells = cells,
        cursor = nil,
    }, Canvas)
end

function Canvas:set(x, y, ch, style)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return
    end

    style = style or {}

    self.cells[y][x] = {
        ch = ch,
        fg = style.fg or "default",
        bg = style.bg or "default",
        bold = style.bold,
    }
end

function Canvas:text(x, y, text, style)
    for i = 1, #text do
        self:set(x + i - 1, y, text:sub(i, i), style)
    end
end

function Canvas:box(rect, style)
    if rect.width < 2 or rect.height < 2 then
        return
    end

    self:set(rect.x, rect.y, "+", style)
    self:set(rect.x + rect.width - 1, rect.y, "+", style)
    self:set(rect.x, rect.y + rect.height - 1, "+", style)
    self:set(
        rect.x + rect.width - 1,
        rect.y + rect.height - 1,
        "+",
        style
    )

    for x = rect.x + 1, rect.x + rect.width - 2 do
        self:set(x, rect.y, "-", style)
        self:set(x, rect.y + rect.height - 1, "-", style)
    end

    for y = rect.y + 1, rect.y + rect.height - 2 do
        self:set(rect.x, y, "|", style)
        self:set(rect.x + rect.width - 1, y, "|", style)
    end
end

function Canvas:cursor_at(x, y)
    self.cursor = { x = x, y = y }
end

return Canvas
