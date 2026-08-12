local uv = require("luv")
local Canvas = require("tui.canvas")

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(terminal, model)
  return setmetatable({ terminal = terminal, model = model, dirty = true, running = false }, Runtime)
end

function Runtime:dispatch(msg)
  local commands = self.model:update(msg) or {}
  self.dirty = true
  for _, command in ipairs(commands) do command(self) end
end

function Runtime:render()
  if not self.dirty then return end
  local w, h = self.terminal:size()
  local canvas = Canvas.new(w, h)
  self.model:view(canvas, { x = 0, y = 0, width = w, height = h })
  self.terminal:present(canvas)
  self.dirty = false
end

function Runtime:run()
  self.running = true
  self:dispatch({ type = "init" })
  self:render()
  self.timer = uv.new_timer()
  self.timer:start(0, 16, function()
    if not self.running then return end
    while true do
      local event = self.terminal:poll(0)
      if not event then break end
      self:dispatch(event)
      if not self.running then break end
    end
    self:render()
  end)
  uv.run()
  self:close()
end

function Runtime:quit()
  self.running = false
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
end

function Runtime:close()
  self:quit()
  self.terminal:close()
end
return { Runtime = Runtime, uv = uv }
