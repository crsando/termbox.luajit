--[=[
    PromptBox + TextBox conversation demo

    This file demonstrates a minimal MUV application:

        Message -> model.update(self, msg)
                          |
                          +-- update application state
                          +-- update child widgets
                          +-- return Cmd list
                          |
                      model.view(self, canvas)
                          |
                      draw TextBox and PromptBox

    Runtime drives the process:

    1. Read terminal events.
    2. Convert native events into framework messages.
    3. Call model.update(self, msg).
    4. Execute commands returned by update().
    5. Call model.view(self, canvas) and present the frame.
]=]

package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Widgets = require("tui.widgets")
local Layout = require("tui.layout")
local Runtime = require("tui").Runtime
local Terminal = require("tui.terminal")

local prompt = Widgets.PromptBox.new({ prompt = "> " })
local text = Widgets.TextBox.new({ follow_tail = true })
local terminal = Terminal.new({ mouse = true })

local model = {
    messages = {
        "Program: Ready. Type /exit or press Ctrl-C to quit.",
    },
}

function model.refresh_text(self)
    text:update({
        type = "set_text",
        text = table.concat(self.messages, "\n"),
    })
end

local function quit_command()
    return function(runtime)
        runtime:quit()
    end
end

function model.update(self, msg)
    if msg.type == "init" then
        self:refresh_text()
        return {}
    end

    if msg.type == "key" and msg.code == "ctrl-c" then
        return { quit_command() }
    end

    if msg.type == "mouse" then
        text:update(msg)
        return {}
    end

    if msg.type == "text" or msg.type == "key" then
        local submitted = prompt:update(msg)

        if type(submitted) == "string" and submitted ~= "" then
            if submitted == "/exit" then
                return { quit_command() }
            end

            table.insert(self.messages, ">>> " .. submitted)
            table.insert(self.messages, "Program: You said: " .. submitted)
            self:refresh_text()
        end
    end

    return {}
end

function model.view(self, canvas)
    local horizontal_margin = canvas.width >= 4 and 1 or 0
    local width = canvas.width - horizontal_margin * 2
    local prompt_height = math.min(3, canvas.height)
    local layout = Layout.vertical({
        Layout.flex("text", 1),
        Layout.fixed("prompt", prompt_height),
    })
    local areas = layout:split({
        x = horizontal_margin,
        y = 0,
        width = width,
        height = canvas.height,
    })
    text:view(canvas, areas.text)
    prompt:view(canvas, areas.prompt)
end

Runtime.new(terminal, model):run()
