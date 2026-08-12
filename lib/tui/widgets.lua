local M = {}
local function inner(rect) return { x = rect.x + 1, y = rect.y + 1, width = math.max(0, rect.width - 2), height = math.max(0, rect.height - 2) } end

local TextBox = {}; TextBox.__index = TextBox
function TextBox.new(opts)
  return setmetatable({
    text = opts.text or "",
    scroll = 0,
    follow_tail = opts.follow_tail or false,
  }, TextBox)
end
function TextBox:update(msg)
  if msg.type == "scroll" then self.scroll = math.max(0, self.scroll + (msg.delta or 0)); return true end
  if msg.type == "set_text" then self.text = msg.text or ""; self.scroll = 0; return true end
  return false
end
function TextBox:view(canvas, rect)
  canvas:box(rect, { fg = "white" }); local r = inner(rect); local lines = {}
  for line in (self.text .. "\n"):gmatch("(.-)\n") do
    if r.width == 0 then break end
    while #line > r.width do table.insert(lines, line:sub(1, r.width)); line = line:sub(r.width + 1) end
    table.insert(lines, line)
  end
  if self.follow_tail then self.scroll = math.max(0, #lines - r.height) end
  for i = 1, r.height do if lines[self.scroll + i] then canvas:text(r.x, r.y + i - 1, lines[self.scroll + i], {}) end end
end

local PromptBox = {}; PromptBox.__index = PromptBox
function PromptBox.new(opts) return setmetatable({ prompt = opts.prompt or "> ", value = "", cursor = 0, scroll = 0, history = opts.history or {}, submitted = nil }, PromptBox) end
function PromptBox:update(msg)
  if msg.type == "text" then self.value = self.value:sub(1, self.cursor) .. msg.text .. self.value:sub(self.cursor + 1); self.cursor = self.cursor + #msg.text; return true end
  if msg.type ~= "key" then return false end
  if msg.code == "left" then self.cursor = math.max(0, self.cursor - 1)
  elseif msg.code == "right" then self.cursor = math.min(#self.value, self.cursor + 1)
  elseif msg.code == "backspace" and self.cursor > 0 then self.value = self.value:sub(1, self.cursor - 1) .. self.value:sub(self.cursor + 1); self.cursor = self.cursor - 1
  elseif msg.code == "enter" then self.submitted = self.value; if #self.value > 0 then table.insert(self.history, self.value) end; local submitted = self.value; self.value = ""; self.cursor = 0; return submitted
  else return false end
  return true
end
function PromptBox:view(canvas, rect)
  canvas:box(rect, { fg = "cyan" }); local r = inner(rect); local visible = self.prompt .. self.value:sub(self.scroll + 1, self.scroll + r.width)
  canvas:text(r.x, r.y, visible, {}); canvas:cursor_at(math.min(r.x + #self.prompt + self.cursor - self.scroll, r.x + r.width - 1), r.y)
end
M.TextBox = TextBox; M.PromptBox = PromptBox
return M
