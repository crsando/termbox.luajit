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

print("runtime: ok")
