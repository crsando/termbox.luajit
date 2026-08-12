package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path
local Widgets = require("tui.widgets")
local Runtime = require("tui").Runtime
local Terminal = require("tui.terminal")

local prompt = Widgets.PromptBox.new({ prompt = "> " })
local text = Widgets.TextBox.new({ follow_tail = true })
local terminal = Terminal.new()

local model = {
  messages = {
    "Program: Ready. Type /exit or press Ctrl-C to quit.",
  },

  refresh_text = function(self)
    text:update({ type = "set_text", text = table.concat(self.messages, "\n") })
  end,

  update = function(self, msg)
    if msg.type == "init" then
      self:refresh_text()
      return {}
    end

    if msg.type == "key" and msg.code == "ctrl-c" then
      return { function(runtime) runtime:quit() end }
    end

    if msg.type == "text" or msg.type == "key" then
      local submitted = prompt:update(msg)
      if type(submitted) == "string" and submitted ~= "" then
        if submitted == "/exit" then
          return { function(runtime) runtime:quit() end }
        end
        table.insert(self.messages, ">>> " .. submitted)
        table.insert(self.messages, "Program: You said: " .. submitted)
        self:refresh_text()
      end
    end

    return {}
  end,

  view = function(self, canvas)
    local horizontal_margin = canvas.width >= 4 and 1 or 0
    local width = canvas.width - horizontal_margin * 2
    local prompt_height = math.min(3, canvas.height)
    local prompt_y = canvas.height - prompt_height

    if prompt_y >= 2 then
      text:view(canvas, {
        x = horizontal_margin,
        y = 0,
        width = width,
        height = prompt_y,
      })
    end

    prompt:view(canvas, {
      x = horizontal_margin,
      y = prompt_y,
      width = width,
      height = prompt_height,
    })
  end,
}

Runtime.new(terminal, model):run()
