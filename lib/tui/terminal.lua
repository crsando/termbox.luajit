local native = require("ltermbox")
local ColorEncoder = require("tui.color_encoder")
local Terminal = {}
Terminal.__index = Terminal

local keys = {
    [native.KEY_ARROW_LEFT] = "left",
    [native.KEY_ARROW_RIGHT] = "right",
    [native.KEY_BACKSPACE] = "backspace",
    [native.KEY_BACKSPACE2] = "backspace",
    [native.KEY_ENTER] = "enter",
    [1] = "ctrl-a",
    [5] = "ctrl-e",
}

function Terminal.new(opts)
    opts = opts or {}
    local colors = ColorEncoder.new({
        mode = opts.color_mode or "auto",
        env = opts.env,
        has_truecolor = native.has_truecolor(),
        bright_attribute = native.ATTR_BRIGHT,
        black_attribute = native.ATTR_HI_BLACK,
    })

    assert(native.init() == 0, "termbox init failed")
    local mode_result = native.set_output_mode(colors.mode)

    if mode_result ~= 0 then
        native.shutdown()
        error("termbox output mode failed: " .. colors.mode)
    end

    return setmetatable({
        colors = colors,
        color_mode = colors.mode,
    }, Terminal)
end

function Terminal:size()
    return native.width(), native.height()
end

function Terminal:poll(timeout)
    local event = native.poll(timeout or 0)

    if not event then
        return nil
    end

    if event.type == "resize" then
        return event
    end

    if event.type == "key" then
        local code = keys[event.key]

        if code then
            return {
                type = "key",
                code = code,
                raw = event.key,
            }
        end

        if event.ch == 3 or event.key == 3 then
            return {
                type = "key",
                code = "ctrl-c",
                raw = event.key ~= 0 and event.key or event.ch,
            }
        end

        if event.ch >= 32 and event.ch <= 126 then
            return {
                type = "text",
                text = string.char(event.ch),
            }
        end

        return {
            type = "key",
            code = "unknown",
            raw = event.key,
        }
    end

    return nil
end

function Terminal:present(canvas)
    native.clear()

    for y = 0, canvas.height - 1 do
        for x = 0, canvas.width - 1 do
            local cell = canvas.cells[y][x]
            native.set_cell(
                x,
                y,
                cell.ch,
                self.colors:encode(cell.fg),
                self.colors:encode(cell.bg),
                cell.bold
            )
        end
    end

    if canvas.cursor then
        native.set_cursor(canvas.cursor.x, canvas.cursor.y)
    else
        native.hide_cursor()
    end

    native.present()
end

function Terminal:close()
    native.shutdown()
end

return Terminal
