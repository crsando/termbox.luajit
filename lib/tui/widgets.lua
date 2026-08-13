local Color = require("tui.color")
local Text = require("tui.text")
local M = {}

local function inner(rect)
    return {
        x = rect.x + 1,
        y = rect.y + 1,
        width = math.max(0, rect.width - 2),
        height = math.max(0, rect.height - 2),
    }
end

local TextBox = {}
TextBox.__index = TextBox

function TextBox.new(opts)
    opts = opts or {}
    local follow_tail = opts.follow_tail == true

    return setmetatable({
        text = opts.text or "",
        scroll = 0,
        scroll_step = opts.scroll_step or 3,
        max_scroll = 0,
        follow_tail = follow_tail,
        at_tail = follow_tail,
    }, TextBox)
end

function TextBox:update(msg)
    if msg.type == "scroll" then
        local delta = msg.delta or 0
        self.scroll = math.max(0, math.min(self.max_scroll, self.scroll + delta))

        if self.follow_tail then
            self.at_tail = self.scroll >= self.max_scroll
        end

        return true
    end

    if msg.type == "set_text" then
        self.text = msg.text or ""

        if not self.follow_tail then
            self.scroll = 0
        end

        return true
    end

    return false
end

function TextBox:view(canvas, rect)
    canvas:box(rect, { fg = Color.white })

    local content = inner(rect)
    local lines = {}

    for line in (self.text .. "\n"):gmatch("(.-)\n") do
        local wrapped = Text.wrap(line, content.width)

        for _, wrapped_line in ipairs(wrapped) do
            lines[#lines + 1] = wrapped_line
        end
    end

    self.max_scroll = math.max(0, #lines - content.height)

    if self.follow_tail and self.at_tail then
        self.scroll = self.max_scroll
    else
        self.scroll = math.max(0, math.min(self.scroll, self.max_scroll))
    end

    if self.follow_tail and self.scroll >= self.max_scroll then
        self.at_tail = true
    end

    for i = 1, content.height do
        local line = lines[self.scroll + i]

        if line then
            canvas:text(content.x, content.y + i - 1, line, {}, content.width)
        end
    end
end

local PromptBox = {}
PromptBox.__index = PromptBox

function PromptBox.new(opts)
    opts = opts or {}

    return setmetatable({
        prompt = opts.prompt or "> ",
        value = "",
        cursor = 0,
        scroll = 0,
        history = opts.history or {},
        history_index = nil,
        history_draft = nil,
        submitted = nil,
    }, PromptBox)
end

function PromptBox:leave_history()
    self.history_index = nil
    self.history_draft = nil
end

function PromptBox:show_history(index)
    self.history_index = index
    self.value = self.history[index]
    self.cursor = Text.length(self.value)
    self.scroll = 0
end

function PromptBox:history_up()
    if #self.history == 0 then
        return
    end

    if not self.history_index then
        self.history_draft = self.value
        self:show_history(#self.history)
    elseif self.history_index > 1 then
        self:show_history(self.history_index - 1)
    end
end

function PromptBox:history_down()
    if not self.history_index then
        return
    end

    if self.history_index < #self.history then
        self:show_history(self.history_index + 1)
        return
    end

    self.value = self.history_draft or ""
    self.cursor = Text.length(self.value)
    self.scroll = 0
    self:leave_history()
end

function PromptBox:update(msg)
    if msg.type == "text" then
        self:leave_history()
        local inserted_length = Text.length(msg.text)
        self.value = Text.prefix(self.value, self.cursor)
            .. msg.text
            .. Text.suffix(self.value, self.cursor + 1)
        self.cursor = self.cursor + inserted_length
        return true
    end

    if msg.type ~= "key" then
        return false
    end

    if msg.code == "left" then
        self.cursor = math.max(0, self.cursor - 1)
    elseif msg.code == "right" then
        self.cursor = math.min(Text.length(self.value), self.cursor + 1)
    elseif msg.code == "up" then
        self:history_up()
    elseif msg.code == "down" then
        self:history_down()
    elseif msg.code == "ctrl-a" then
        self.cursor = 0
    elseif msg.code == "ctrl-e" then
        self.cursor = Text.length(self.value)
    elseif msg.code == "backspace" and self.cursor > 0 then
        self:leave_history()
        self.value = Text.prefix(self.value, self.cursor - 1)
            .. Text.suffix(self.value, self.cursor + 1)
        self.cursor = self.cursor - 1
    elseif msg.code == "enter" then
        self.submitted = self.value

        if self.value ~= "" then
            table.insert(self.history, self.value)
        end

        local submitted = self.value
        self.value = ""
        self.cursor = 0
        self.scroll = 0
        self:leave_history()
        return submitted
    else
        return false
    end

    return true
end

function PromptBox:ensure_cursor_visible(input_width)
    if input_width <= 0 then
        self.scroll = self.cursor
        return 0
    end

    if self.cursor < self.scroll then
        self.scroll = self.cursor
    end

    local characters = Text.characters(self.value)
    local cursor_width = 0

    for index = self.scroll + 1, self.cursor do
        cursor_width = cursor_width + characters[index].width
    end

    while self.scroll < self.cursor and cursor_width >= input_width do
        self.scroll = self.scroll + 1
        cursor_width = cursor_width - characters[self.scroll].width
    end

    self.scroll = math.max(0, math.min(self.scroll, Text.length(self.value)))
    return cursor_width
end

function PromptBox:view(canvas, rect)
    local style = {
        fg = Color.rgb(168, 170, 166),
        bg = Color.rgb(30, 30, 30),
    }
    canvas:fill(rect, style)

    local content = inner(rect)
    local visible_prompt, prompt_width = Text.take(self.prompt, 0, content.width)
    local input_width = math.max(0, content.width - prompt_width)

    local cursor_width = self:ensure_cursor_visible(input_width)

    if content.height > 0 and prompt_width > 0 then
        canvas:text(
            content.x,
            content.y,
            visible_prompt,
            style
        )
    end

    if content.height > 0 and input_width > 0 then
        local visible_value = Text.take(self.value, self.scroll, input_width)
        canvas:text(
            content.x + prompt_width,
            content.y,
            visible_value,
            style
        )
    end

    if content.width > 0 and content.height > 0 then
        canvas:cursor_at(
            math.min(
                content.x
                    + prompt_width
                    + cursor_width,
                content.x + content.width - 1
            ),
            content.y
        )
    end
end

M.TextBox = TextBox
M.PromptBox = PromptBox

return M
