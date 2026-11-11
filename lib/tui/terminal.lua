local bit = require("bit")
local native = require("ltermbox")
local ColorEncoder = require("tui.color_encoder")
local Text = require("tui.text")
local Terminal = {}
Terminal.__index = Terminal

local function native_error(operation, result)
    return string.format(
        "termbox %s failed (%d): %s",
        operation,
        result,
        native.error_string(result)
    )
end

local function check_result(operation, result, level)
    if result ~= 0 then
        error(native_error(operation, result), level or 3)
    end

    return result
end

local keys = {
    [native.KEY_ARROW_UP] = "up",
    [native.KEY_ARROW_DOWN] = "down",
    [native.KEY_ARROW_LEFT] = "left",
    [native.KEY_ARROW_RIGHT] = "right",
    [native.KEY_BACKSPACE] = "backspace",
    [native.KEY_BACKSPACE2] = "backspace",
    [native.KEY_ENTER] = "enter",
    [native.KEY_HOME] = "home",
    [native.KEY_END] = "end",
    [native.KEY_DELETE] = "delete",
    [native.KEY_TAB] = "tab",
    [native.KEY_ESC] = "escape",
    [native.KEY_CTRL_A] = "ctrl-a",
    [native.KEY_CTRL_E] = "ctrl-e",
    [native.KEY_CTRL_K] = "ctrl-k",
    [native.KEY_CTRL_U] = "ctrl-u",
    [native.KEY_CTRL_W] = "ctrl-w",
}

local function has_alt(event)
    return bit.band(event.mod or 0, native.MOD_ALT) ~= 0
end

function Terminal.new(opts)
    opts = opts or {}
    local colors = ColorEncoder.new({
        mode = opts.color_mode or "auto",
        env = opts.env,
        has_truecolor = native.has_truecolor(),
        bright_attribute = native.ATTR_BRIGHT,
        black_attribute = native.ATTR_HI_BLACK,
    })

    check_result("init", native.init(), 2)
    local mode_result = native.set_output_mode(colors.mode)

    if mode_result ~= 0 then
        local message = native_error("set output mode " .. colors.mode, mode_result)
        local shutdown_result = native.shutdown()

        if shutdown_result ~= 0 then
            message = message
                .. "; "
                .. native_error("shutdown", shutdown_result)
        end

        error(message, 2)
    end

    local mouse_enabled = opts.mouse == true
    local mouse_result = native.set_mouse_enabled(mouse_enabled)

    if mouse_result ~= 0 then
        local message = native_error("set mouse mode", mouse_result)
        local shutdown_result = native.shutdown()

        if shutdown_result ~= 0 then
            message = message
                .. "; "
                .. native_error("shutdown", shutdown_result)
        end

        error(message, 2)
    end

    return setmetatable({
        colors = colors,
        color_mode = colors.mode,
        mouse_enabled = mouse_enabled,
        closed = false,
    }, Terminal)
end

function Terminal:size()
    return native.width(), native.height()
end

function Terminal.normalize_event(event)
    if not event then
        return nil
    end

    if event.type == "resize" then
        return event
    end

    local mouse_action

    if event.key == native.KEY_MOUSE_WHEEL_UP then
        mouse_action = "wheel_up"
    elseif event.key == native.KEY_MOUSE_WHEEL_DOWN then
        mouse_action = "wheel_down"
    end

    if mouse_action then
        return {
            type = "mouse",
            action = mouse_action,
            x = event.x,
            y = event.y,
            raw = event.key,
        }
    end

    if event.type == "mouse" then
        return nil
    end

    if event.type == "key" then
        local ch = event.ch or 0
        local code = keys[event.key]

        if code then
            local alt = has_alt(event)

            return {
                type = "key",
                code = alt and "alt-" .. code or code,
                alt = alt or nil,
                raw = event.key,
            }
        end

        if ch == 3 or event.key == 3 then
            return {
                type = "key",
                code = "ctrl-c",
                raw = event.key ~= 0 and event.key or ch,
            }
        end

        if ch ~= 0 and native.wcwidth(ch) > 0 then
            if has_alt(event) then
                return {
                    type = "key",
                    code = "alt-" .. Text.char(ch),
                    alt = true,
                    raw = ch,
                }
            end

            return {
                type = "text",
                text = Text.char(ch),
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

local function read_raw(self, timeout)
    local pending = self.pending

    if pending then
        self.pending = nil
        return pending
    end

    return native.poll(timeout)
end

-- In termbox's default TB_INPUT_ESC mode Alt+x arrives as an ESC key event
-- immediately followed by "x" from the same read. Fold the pair into one
-- alt-modified event; a lone ESC (nothing queued behind it) stays "escape".
local function fold_alt(self, event)
    if not (event.type == "key" and event.key == native.KEY_ESC) then
        return event
    end

    local following = native.poll(0)

    if following
        and following.type == "key"
        and (following.mod or 0) == 0
        and (following.ch or 0) ~= 0
    then
        following.mod = native.MOD_ALT
        return following
    end

    self.pending = following
    return event
end

-- Returns the next framework message, or nil once the native queue is empty.
-- Events the framework ignores (mouse clicks, releases, ...) are skipped
-- instead of being reported as "no event", so queued input behind them is
-- still delivered in the same tick.
function Terminal:poll(timeout)
    local event = read_raw(self, timeout or 0)

    while event do
        local message = Terminal.normalize_event(fold_alt(self, event))

        if message then
            return message
        end

        event = read_raw(self, 0)
    end

    return nil
end

function Terminal:present(canvas)
    check_result("clear", native.clear(), 2)

    for y = 0, canvas.height - 1 do
        for x = 0, canvas.width - 1 do
            local cell = canvas.cells[y][x]

            if not cell.continuation then
                check_result(
                    "set cell",
                    native.set_cell(
                        x,
                        y,
                        cell.ch,
                        self.colors:encode(cell.fg),
                        self.colors:encode(cell.bg),
                        cell.bold,
                        cell.italic
                    ),
                    2
                )
            end
        end
    end

    if canvas.cursor then
        check_result(
            "set cursor",
            native.set_cursor(canvas.cursor.x, canvas.cursor.y),
            2
        )
    else
        check_result("hide cursor", native.hide_cursor(), 2)
    end

    check_result("present", native.present(), 2)
end

function Terminal:close()
    if self.closed then
        return
    end

    self.closed = true
    check_result("shutdown", native.shutdown(), 2)
end

return Terminal
