local uv = require("luv")
local Canvas = require("tui.canvas")
local Color = require("tui.color")

local Runtime = {}
Runtime.__index = Runtime

local function traceback(message)
    return debug.traceback(message, 2)
end

local default_signals = { "sigterm", "sighup", "sigint" }

function Runtime.new(terminal, model, opts)
    opts = opts or {}
    local signals = opts.signals

    local input = opts.input == nil and "auto" or opts.input

    if input ~= "auto"
        and input ~= "poll"
        and input ~= "thread"
        and input ~= "timer"
    then
        error("input must be auto, poll, thread, or timer", 2)
    end

    if signals == nil then
        signals = default_signals
    elseif signals == false then
        signals = {}
    elseif type(signals) ~= "table" then
        error("signals must be a list of signal names or false", 2)
    end

    return setmetatable({
        terminal = terminal,
        model = model,
        signals = signals,
        input_mode = input,
        active_input = nil,
        input_handles = nil,
        render_timer = nil,
        render_callback = nil,
        draining = false,
        signal_handles = {},
        stop_signal = nil,
        dirty = true,
        running = false,
        loop_running = false,
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

    -- In poll mode nothing wakes up periodically, so a dispatch coming from
    -- an application callback (timer, socket, ...) schedules its own frame.
    -- Dispatches from terminal input are rendered at the end of drain().
    if self.render_timer and not self.draining and self.running then
        self.render_timer:start(0, 0, self.render_callback)
    end
end

-- Wrap a libuv callback: an error stops the runtime and is re-raised by run().
function Runtime:protect(callback)
    return function(...)
        local args = { ... }
        local count = select("#", ...)
        local ok, callback_error = xpcall(function()
            if self.running then
                callback(unpack(args, 1, count))
            end
        end, traceback)

        if not ok then
            self.callback_error = callback_error
            local quit_ok, quit_error = xpcall(function()
                self:quit()
            end, traceback)

            if not quit_ok then
                self.callback_error = self.callback_error
                    .. "\nwhile stopping runtime:\n"
                    .. quit_error
                uv.stop()
            end
        end
    end
end

-- Deliver every queued terminal event, then draw one frame.
function Runtime:drain()
    self.draining = true

    while self.running do
        local event = self.terminal:poll(0)

        if not event then
            break
        end

        self:dispatch(event)
    end

    self.draining = false

    if self.running then
        self:render()
    end
end

local function close_handle(handle)
    if not handle:is_closing() then
        handle:stop()
        handle:close()
    end
end

-- Watch the terminal's tty and resize descriptors so the process sleeps
-- until input arrives. Falls back to a 16 ms polling timer when the terminal
-- exposes no descriptors or libuv cannot watch them.
function Runtime:start_poll_input()
    if self.input_mode == "timer"
        or self.input_mode == "thread"
        or type(self.terminal.fds) ~= "function"
    then
        return false
    end

    local fds = { self.terminal:fds() }

    if #fds == 0 then
        return false
    end

    local on_readable = self:protect(function(poll_error)
        if poll_error then
            error("terminal input poll failed: " .. tostring(poll_error), 0)
        end

        self:drain()
    end)
    local handles = {}

    for _, fd in ipairs(fds) do
        local created, handle = pcall(uv.new_poll, fd)
        handle = created and handle or nil
        local started = handle ~= nil and pcall(function()
            assert(handle:start("r", on_readable))
        end)

        if not started then
            if handle then
                close_handle(handle)
            end

            for _, opened in ipairs(handles) do
                close_handle(opened)
            end

            if self.input_mode == "poll" then
                error("cannot watch terminal descriptor " .. tostring(fd), 0)
            end

            return false
        end

        handles[#handles + 1] = handle
    end

    self.input_handles = handles
    self.render_timer = assert(uv.new_timer(), "failed to create render timer")
    self.render_callback = self:protect(function()
        self:render()
    end)
    -- Input that arrived before the handles were started.
    self.render_timer:start(0, 0, self:protect(function()
        self:drain()
    end))
    return true
end

-- Runs in a libuv worker thread with its own Lua state: no upvalues, only
-- primitive arguments and results.
local function wait_work(cpath, module, timeout, ...)
    package.cpath = cpath
    local fds = { ... }
    return pcall(function()
        return require(module).wait_readable(timeout, unpack(fds))
    end)
end

-- macOS fallback: block in select(2) on a worker thread, drain on the main
-- thread, then wait again. A byte on the wake pipe releases the worker when
-- the runtime quits.
function Runtime:start_thread_input()
    if self.input_mode == "timer"
        or self.input_mode == "poll"
        or type(self.terminal.fds) ~= "function"
        or type(self.terminal.wait_module) ~= "function"
    then
        return false
    end

    local fds = { self.terminal:fds() }

    if #fds == 0 then
        return false
    end

    local module = self.terminal:wait_module()
    local wake = assert(uv.pipe({ nonblock = true }, { nonblock = true }))
    local wait_fds = { wake.read }

    for _, fd in ipairs(fds) do
        wait_fds[#wait_fds + 1] = fd
    end

    local work
    local on_ready = self:protect(function(ok, first, message)
        if not ok then
            error("terminal input wait failed: " .. tostring(first), 0)
        end

        if first == nil then
            error("terminal input wait failed: " .. tostring(message), 0)
        end

        if first ~= false then
            self:drain()
        end
    end)

    work = uv.new_work(wait_work, function(...)
        if self.running then
            on_ready(...)
        end

        if self.running then
            work:queue(package.cpath, module, -1, unpack(wait_fds))
        else
            uv.fs_close(wake.read)
            uv.fs_close(wake.write)
        end
    end)

    self.wake_pipe = wake
    self.render_timer = assert(uv.new_timer(), "failed to create render timer")
    self.render_callback = self:protect(function()
        self:render()
    end)
    work:queue(package.cpath, module, -1, unpack(wait_fds))
    return true
end

function Runtime:start_input()
    if self:start_poll_input() then
        self.active_input = "poll"
        return
    end

    if self:start_thread_input() then
        self.active_input = "thread"
        return
    end

    if self.input_mode == "thread" then
        error("thread input requires a terminal with fds() and wait_module()", 0)
    end

    self.active_input = "timer"
    self.timer = assert(uv.new_timer(), "failed to create runtime timer")
    self.timer:start(0, 16, self:protect(function()
        self:drain()
    end))
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

        -- Termination signals stop the runtime normally so that close()
        -- restores the terminal instead of leaving it in raw mode.
        for _, name in ipairs(self.signals) do
            local handle = assert(uv.new_signal(), "failed to create signal handle")
            self.signal_handles[#self.signal_handles + 1] = handle
            handle:start(name, function()
                self.stop_signal = self.stop_signal or name
                self:quit()
            end)
        end

        self:start_input()

        self.loop_running = true
        local loop_ok, loop_error = pcall(uv.run)
        self.loop_running = false

        if not loop_ok then
            error(loop_error, 0)
        end

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

    -- nil after a normal quit, otherwise the name of the signal (e.g.
    -- "sigterm") so callers can exit with the conventional status.
    return self.stop_signal
end

function Runtime:quit()
    self.running = false

    if self.timer then
        local timer = self.timer
        self.timer = nil
        timer:stop()
        timer:close()
    end

    for _, handle in ipairs(self.input_handles or {}) do
        close_handle(handle)
    end

    self.input_handles = nil

    if self.render_timer then
        close_handle(self.render_timer)
        self.render_timer = nil
    end

    if self.wake_pipe then
        -- The worker's completion callback closes the pipe.
        uv.fs_write(self.wake_pipe.write, "x", -1)
        self.wake_pipe = nil
    end

    local handles = self.signal_handles
    self.signal_handles = {}

    for _, handle in ipairs(handles) do
        handle:stop()
        handle:close()
    end

    -- Other handles owned by the application (sockets, timers, ...) would
    -- otherwise keep uv.run() alive after the runtime has quit. Only stop the
    -- loop while run() is inside it; a stale stop flag would make the next
    -- uv.run() elsewhere return immediately.
    if self.loop_running then
        uv.stop()
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
