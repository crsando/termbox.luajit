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

print("runtime: ok")
