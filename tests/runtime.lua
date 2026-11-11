package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Runtime = require("tui").Runtime

local function fake_terminal(events)
    local terminal = {
        closed = 0,
        events = events or {},
        presented = 0,
    }

    function terminal:size()
        return 4, 3
    end

    function terminal:poll()
        return table.remove(self.events, 1)
    end

    function terminal:present()
        self.presented = self.presented + 1
    end

    function terminal:close()
        self.closed = self.closed + 1
    end

    return terminal
end

local render_failure_terminal = fake_terminal()
local render_failure = Runtime.new(render_failure_terminal, {
    update = function()
        return {}
    end,
    view = function()
        error("render failed")
    end,
})
local render_ok, render_error = pcall(function()
    render_failure:run()
end)

assert(not render_ok)
assert(tostring(render_error):find("render failed", 1, true))
assert(render_failure_terminal.closed == 1)
render_failure:close()
assert(render_failure_terminal.closed == 1)

local init_quit_terminal = fake_terminal()
local init_quit = Runtime.new(init_quit_terminal, {
    update = function(_, msg)
        if msg.type == "init" then
            return {
                function(runtime)
                    runtime:quit()
                end,
            }
        end

        return {}
    end,
    view = function()
        error("view must not run after init quit")
    end,
})

init_quit:run()
assert(init_quit.timer == nil)
assert(init_quit_terminal.closed == 1)

local callback_terminal = fake_terminal({ { type = "test" } })
local callback_failure = Runtime.new(callback_terminal, {
    update = function(_, msg)
        if msg.type == "test" then
            error("callback failed")
        end

        return {}
    end,
    view = function()
    end,
})
local callback_ok, callback_error = pcall(function()
    callback_failure:run()
end)

assert(not callback_ok)
assert(tostring(callback_error):find("callback failed", 1, true))
assert(callback_terminal.closed == 1)
assert(callback_failure.timer == nil)

local normal_quit_terminal = fake_terminal({ { type = "quit" } })
local normal_quit = Runtime.new(normal_quit_terminal, {
    update = function(_, msg)
        if msg.type == "quit" then
            return {
                function(runtime)
                    runtime:quit()
                end,
            }
        end

        return {}
    end,
    view = function()
    end,
})

normal_quit:run()
assert(normal_quit_terminal.presented == 1)
assert(normal_quit_terminal.closed == 1)
assert(normal_quit.timer == nil)
assert(not pcall(function()
    normal_quit:run()
end))

local uv = require("tui").uv
local app_timer = uv.new_timer()
local app_ticks = 0
app_timer:start(0, 5, function()
    app_ticks = app_ticks + 1
end)
local watchdog = uv.new_timer()
local watchdog_fired = false
watchdog:start(2000, 0, function()
    watchdog_fired = true
    uv.stop()
end)

local extra_handle_terminal = fake_terminal({ { type = "quit" } })
local extra_handle = Runtime.new(extra_handle_terminal, {
    update = function(_, msg)
        if msg.type == "quit" then
            return {
                function(runtime)
                    runtime:quit()
                end,
            }
        end

        return {}
    end,
    view = function()
    end,
})

extra_handle:run()
assert(not watchdog_fired, "quit() must stop uv.run() while app handles are alive")
assert(extra_handle_terminal.closed == 1)
assert(not extra_handle.loop_running)
app_timer:close()
watchdog:close()
uv.run()

-- A termination signal quits the runtime and still closes the terminal.
local signal_terminal = fake_terminal()
local signal_runtime = Runtime.new(signal_terminal, {
    update = function()
        return {}
    end,
    view = function()
    end,
})
local signal_watchdog = uv.new_timer()
local signal_watchdog_fired = false
signal_watchdog:start(2000, 0, function()
    signal_watchdog_fired = true
    uv.stop()
end)
local sender = uv.new_timer()
sender:start(20, 0, function()
    uv.kill(uv.os_getpid(), "sigterm")
end)

assert(signal_runtime:run() == "sigterm")
assert(not signal_watchdog_fired)
assert(signal_terminal.closed == 1)
assert(#signal_runtime.signal_handles == 0)
sender:close()
signal_watchdog:close()
uv.run()

assert(not pcall(Runtime.new, signal_terminal, {}, { signals = "sigterm" }))
local no_signals = Runtime.new(fake_terminal({ { type = "quit" } }), {
    update = function(_, msg)
        if msg.type == "quit" then
            return {
                function(runtime)
                    runtime:quit()
                end,
            }
        end

        return {}
    end,
    view = function()
    end,
}, { signals = false })
assert(no_signals:run() == nil)

-- Poll mode: input is driven by descriptor readiness, no periodic timer.
local function pipe_terminal(events)
    local terminal = fake_terminal(events)
    local pipe = assert(uv.pipe({ nonblock = true }, { nonblock = true }))
    terminal.pipe = pipe

    function terminal:fds()
        return pipe.read
    end

    function terminal:poll()
        local event = table.remove(self.events, 1)

        if event then
            uv.fs_read(pipe.read, 1, -1)
        end

        return event
    end

    function terminal:push(event)
        self.events[#self.events + 1] = event
        uv.fs_write(pipe.write, "x", -1)
    end

    return terminal
end

local function quit_on(type_name, extra)
    return {
        update = function(model, msg)
            model.seen = (model.seen or 0) + 1

            if extra then
                local commands = extra(msg)

                if commands then
                    return commands
                end
            end

            if msg.type == type_name then
                return {
                    function(runtime)
                        runtime:quit()
                    end,
                }
            end

            return {}
        end,
        view = function()
        end,
    }
end

local poll_terminal = pipe_terminal()
local poll_model = quit_on("quit")
local poll_runtime = Runtime.new(poll_terminal, poll_model, { signals = false })
local poll_watchdog = uv.new_timer()
local poll_watchdog_fired = false
poll_watchdog:start(2000, 0, function()
    poll_watchdog_fired = true
    uv.stop()
end)
local idle_check = uv.new_timer()
local presented_while_idle
idle_check:start(150, 0, function()
    presented_while_idle = poll_terminal.presented
    poll_terminal:push({ type = "key" })
    poll_terminal:push({ type = "quit" })
end)

poll_runtime:run()
assert(not poll_watchdog_fired)
assert(poll_runtime.active_input == "poll")
assert(poll_runtime.timer == nil)
assert(presented_while_idle == 1)
assert(poll_model.seen == 3)
assert(poll_runtime.input_handles == nil and poll_runtime.render_timer == nil)
assert(poll_terminal.closed == 1)
idle_check:close()
poll_watchdog:close()

-- A dispatch from an application callback still produces a frame.
local async_terminal = pipe_terminal()
local async_runtime
async_runtime = Runtime.new(async_terminal, quit_on("done", function(msg)
    if msg.type == "init" then
        return {
            function(runtime)
                local app_timer = uv.new_timer()
                app_timer:start(30, 0, function()
                    app_timer:close()
                    runtime:dispatch({ type = "tick" })
                end)
            end,
        }
    end

    if msg.type == "tick" then
        local check = uv.new_timer()
        check:start(30, 0, function()
            check:close()
            async_terminal.presented_after_tick = async_terminal.presented
            async_terminal:push({ type = "done" })
        end)
    end
end), { signals = false })
local async_watchdog = uv.new_timer()
async_watchdog:start(2000, 0, function()
    uv.stop()
    error("async render test timed out")
end)
async_runtime:run()
assert(async_terminal.presented_after_tick == 2)
async_watchdog:close()

-- Thread mode: select(2) on a worker thread (used where kqueue cannot poll
-- a tty). Uses the real ltermbox.wait_readable on the fake pipe.
local thread_terminal = pipe_terminal()

function thread_terminal:wait_module()
    return "ltermbox"
end

local thread_model = quit_on("quit")
local thread_runtime = Runtime.new(thread_terminal, thread_model, {
    signals = false,
    input = "thread",
})
local thread_watchdog = uv.new_timer()
local thread_watchdog_fired = false
thread_watchdog:start(3000, 0, function()
    thread_watchdog_fired = true
    uv.stop()
end)
local thread_feed = uv.new_timer()
thread_feed:start(100, 0, function()
    thread_terminal.presented_idle = thread_terminal.presented
    thread_terminal:push({ type = "key" })
    thread_terminal:push({ type = "quit" })
end)
thread_runtime:run()
assert(not thread_watchdog_fired)
assert(thread_runtime.active_input == "thread")
assert(thread_terminal.presented_idle == 1)
assert(thread_model.seen == 3)
thread_feed:close()
thread_watchdog:close()

-- Quitting from outside input (e.g. a signal) releases the blocked worker.
local released_terminal = pipe_terminal()

function released_terminal:wait_module()
    return "ltermbox"
end

local released = Runtime.new(released_terminal, quit_on("never"), {
    signals = false,
    input = "thread",
})
local external_quit = uv.new_timer()
external_quit:start(50, 0, function()
    released:quit()
end)
local release_start = uv.hrtime()
released:run()
external_quit:close()
uv.run()
assert((uv.hrtime() - release_start) / 1e6 < 1000)
assert(released_terminal.closed == 1)

local native = require("ltermbox")
local probe = assert(uv.pipe({ nonblock = true }, { nonblock = true }))
assert(native.wait_readable(0, probe.read) == false)
uv.fs_write(probe.write, "x", -1)
assert(native.wait_readable(100, probe.read) == probe.read)
assert(not pcall(native.wait_readable, 0, -1))
uv.fs_close(probe.read)
uv.fs_close(probe.write)

-- Forced timer mode ignores descriptors; invalid modes are rejected.
local timer_terminal = pipe_terminal({ { type = "quit" } })
local timer_runtime = Runtime.new(timer_terminal, quit_on("quit"), {
    signals = false,
    input = "timer",
})
timer_runtime:run()
assert(timer_runtime.active_input == "timer")
assert(not pcall(Runtime.new, timer_terminal, {}, { input = "kqueue" }))

for _, terminal in ipairs({
    poll_terminal,
    async_terminal,
    timer_terminal,
    thread_terminal,
    released_terminal,
}) do
    uv.fs_close(terminal.pipe.read)
    uv.fs_close(terminal.pipe.write)
end

uv.run()

print("runtime: ok")
