local uv = require("luv")
local Canvas = require("tui.canvas")
local Color = require("tui.color")

local Runtime = {}
Runtime.__index = Runtime

local function traceback(message)
    return debug.traceback(message, 2)
end

function Runtime.new(terminal, model)
    return setmetatable({
        terminal = terminal,
        model = model,
        dirty = true,
        running = false,
        closed = false,
        callback_error = nil,
    }, Runtime)
end

function Runtime:dispatch(msg)
    local commands = self.model:update(msg) or {}
    self.dirty = true

    for _, command in ipairs(commands) do
        command(self)
    end
end

function Runtime:render()
    if not self.dirty then
        return
    end

    local width, height = self.terminal:size()
    local canvas = Canvas.new(width, height)

    self.model:view(canvas, {
        x = 0,
        y = 0,
        width = width,
        height = height,
    })

    self.terminal:present(canvas)
    self.dirty = false
end

function Runtime:run()
    if self.closed then
        error("cannot run a closed runtime", 2)
    end

    if self.running then
        error("runtime is already running", 2)
    end

    local ok, run_error = xpcall(function()
        self.running = true
        self:dispatch({ type = "init" })

        if not self.running then
            return
        end

        self:render()

        if not self.running then
            return
        end

        self.timer = assert(uv.new_timer(), "failed to create runtime timer")
        self.timer:start(0, 16, function()
            local callback_ok, callback_error = xpcall(function()
                if not self.running then
                    return
                end

                while self.running do
                    local event = self.terminal:poll(0)

                    if not event then
                        break
                    end

                    self:dispatch(event)
                end

                if self.running then
                    self:render()
                end
            end, traceback)

            if not callback_ok then
                self.callback_error = callback_error
                local quit_ok, quit_error = xpcall(function()
                    self:quit()
                end, traceback)

                if not quit_ok then
                    self.callback_error = self.callback_error
                        .. "\nwhile stopping runtime:\n"
                        .. quit_error
                end

                uv.stop()
            end
        end)

        uv.run()

        if self.callback_error then
            error(self.callback_error, 0)
        end
    end, traceback)

    local close_ok, close_error = xpcall(function()
        self:close()
    end, traceback)

    if not ok then
        if not close_ok then
            run_error = run_error .. "\nwhile closing runtime:\n" .. close_error
        end

        error(run_error, 0)
    end

    if not close_ok then
        error(close_error, 0)
    end
end

function Runtime:quit()
    self.running = false

    if self.timer then
        local timer = self.timer
        self.timer = nil
        timer:stop()
        timer:close()
    end
end

function Runtime:close()
    if self.closed then
        return
    end

    self.closed = true
    local quit_ok, quit_error = xpcall(function()
        self:quit()
    end, traceback)
    local terminal_ok, terminal_error = xpcall(function()
        self.terminal:close()
    end, traceback)

    if not quit_ok then
        if not terminal_ok then
            quit_error = quit_error
                .. "\nwhile closing terminal:\n"
                .. terminal_error
        end

        error(quit_error, 0)
    end

    if not terminal_ok then
        error(terminal_error, 0)
    end
end

return {
    Runtime = Runtime,
    Color = Color,
    uv = uv,
}
