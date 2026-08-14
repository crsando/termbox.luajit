local Color = require("tui.color")
local Markdown = require("tui.markdown")
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

local default_markdown_theme = {
    normal = {},
    emphasis = {
        fg = Color.rgb(116, 192, 252),
        italic = true,
    },
    strong = {
        fg = Color.rgb(255, 214, 102),
        bold = true,
    },
    strong_emphasis = {
        fg = Color.rgb(255, 214, 102),
        bold = true,
        italic = true,
    },
    heading = {
        [1] = { fg = Color.rgb(255, 214, 102), bold = true },
        [2] = { fg = Color.rgb(116, 192, 252), bold = true },
        [3] = { fg = Color.rgb(105, 219, 124), bold = true },
        [4] = { fg = Color.rgb(218, 119, 242), bold = true },
    },
}

local function copy_style(style)
    local result = {}

    for key, value in pairs(style or {}) do
        result[key] = value
    end

    return result
end

local function merge_style(base, overlay)
    local result = copy_style(base)

    for key, value in pairs(overlay or {}) do
        result[key] = value
    end

    return result
end

local function check_style(style, name)
    if style ~= nil and type(style) ~= "table" then
        error(name .. " must be a table", 4)
    end

    return style
end

local function markdown_theme(override)
    if override ~= nil and type(override) ~= "table" then
        error("markdown_theme must be a table", 3)
    end

    override = override or {}
    local override_heading = override.heading

    if override_heading ~= nil and type(override_heading) ~= "table" then
        error("markdown_theme.heading must be a table", 3)
    end

    local theme = {
        normal = merge_style(
            default_markdown_theme.normal,
            check_style(override.normal, "markdown_theme.normal")
        ),
        emphasis = merge_style(
            default_markdown_theme.emphasis,
            check_style(override.emphasis, "markdown_theme.emphasis")
        ),
        strong = merge_style(
            default_markdown_theme.strong,
            check_style(override.strong, "markdown_theme.strong")
        ),
        strong_emphasis = merge_style(
            default_markdown_theme.strong_emphasis,
            check_style(
                override.strong_emphasis,
                "markdown_theme.strong_emphasis"
            )
        ),
        heading = {},
    }

    for level = 1, 4 do
        theme.heading[level] = merge_style(
            default_markdown_theme.heading[level],
            check_style(
                override_heading and override_heading[level],
                "markdown_theme.heading[" .. level .. "]"
            )
        )
    end

    return theme
end

function TextBox.new(opts)
    opts = opts or {}
    local follow_tail = opts.follow_tail == true
    local format = opts.format == nil and "plain" or opts.format

    if format ~= "plain" and format ~= "markdown" then
        error("TextBox format must be plain or markdown", 2)
    end

    return setmetatable({
        text = opts.text or "",
        scroll = 0,
        scroll_step = opts.scroll_step or 3,
        max_scroll = 0,
        follow_tail = follow_tail,
        at_tail = follow_tail,
        format = format,
        markdown_theme = markdown_theme(opts.markdown_theme),
        parsed_lines = nil,
        layout_width = nil,
        layout_lines = nil,
    }, TextBox)
end

function TextBox:parse_markdown()
    if self.format ~= "markdown" then
        return nil
    end

    local parsed = {}

    for line in (self.text .. "\n"):gmatch("(.-)\n") do
        parsed[#parsed + 1] = Markdown.parse_line(line)
    end

    self.parsed_lines = parsed
    self.layout_width = nil
    self.layout_lines = nil
    return parsed
end

function TextBox:layout_markdown(width)
    if self.layout_width == width and self.layout_lines then
        return self.layout_lines
    end

    local parsed = self.parsed_lines or self:parse_markdown() or {}
    local lines = {}

    for _, line in ipairs(parsed) do
        local wrapped = Markdown.wrap_line(line, width)

        for _, visual_line in ipairs(wrapped) do
            lines[#lines + 1] = visual_line
        end
    end

    self.layout_width = width
    self.layout_lines = lines
    return lines
end

function TextBox:update(msg)
    if msg.type == "mouse" then
        if msg.action == "wheel_up" then
            return self:update({
                type = "scroll",
                delta = -self.scroll_step,
            })
        end

        if msg.action == "wheel_down" then
            return self:update({
                type = "scroll",
                delta = self.scroll_step,
            })
        end

        return false
    end

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
        self.parsed_lines = nil
        self.layout_width = nil
        self.layout_lines = nil

        if self.format == "markdown" then
            self:parse_markdown()
        end

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

    if self.format == "markdown" then
        lines = self:layout_markdown(content.width)
    else
        for line in (self.text .. "\n"):gmatch("(.-)\n") do
            local wrapped = Text.wrap(line, content.width)

            for _, wrapped_line in ipairs(wrapped) do
                lines[#lines + 1] = wrapped_line
            end
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
            if self.format == "markdown" then
                local x = content.x
                local used_width = 0

                for _, segment in ipairs(line.segments) do
                    local style = self:markdown_style(line.heading, segment.role)
                    local drawn_width = canvas:text(
                        x,
                        content.y + i - 1,
                        segment.text,
                        style,
                        content.width - used_width
                    )
                    x = x + drawn_width
                    used_width = used_width + drawn_width
                end
            else
                canvas:text(content.x, content.y + i - 1, line, {}, content.width)
            end
        end
    end
end

function TextBox:markdown_style(heading, role)
    local theme = self.markdown_theme
    local style = theme.normal

    if role ~= "normal" then
        style = merge_style(style, theme[role])
    end

    if heading then
        style = merge_style(style, theme.heading[heading])
    end

    return style
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
        last_input_width = nil,
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
    local previous_input_width = self.last_input_width
    self.last_input_width = input_width

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

    if previous_input_width and input_width > previous_input_width then
        while self.scroll > 0 do
            local previous_width = characters[self.scroll].width

            if cursor_width + previous_width >= input_width then
                break
            end

            self.scroll = self.scroll - 1
            cursor_width = cursor_width + previous_width
        end
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
