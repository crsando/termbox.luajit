--[=[
    PromptBox + TextBox 对话 demo

    这个文件展示一个最小的 MUV 应用结构：

        Message -> model.update(self, msg)
                          |
                          +-- 修改应用状态
                          +-- 更新子控件状态
                          +-- 返回 Cmd 列表
                          |
                      model.view(self, canvas)
                          |
                      绘制 TextBox 和 PromptBox

    Runtime 负责驱动整个流程：

    1. 从 Terminal 读取底层终端事件。
    2. 将底层事件转换成框架 Message。
    3. 调用 model.update(self, msg)。
    4. 执行 update 返回的 Cmd。
    5. 调用 model.view(self, canvas) 重新绘制当前状态。

    这个 demo 没有真正的后端服务，程序回复只是回显用户输入。
    后续接入网络、文件或子进程时，可以在 update 中返回异步 Cmd；
    Cmd 完成后再向 Runtime 发送新的 Message。
]=]

package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local Widgets = require("tui.widgets")
local Runtime = require("tui").Runtime
local Terminal = require("tui.terminal")

-- PromptBox 负责输入编辑，不负责解释命令含义。
-- 它维护当前输入字符串和光标，并在 Enter 时返回提交内容。
local prompt = Widgets.PromptBox.new({ prompt = "> " })

-- TextBox 负责展示历史对话。
-- follow_tail = true 表示内容超出可见区域时自动滚到底部，
-- 因此最近的对话会优先显示。
local text = Widgets.TextBox.new({ follow_tail = true })

-- Terminal 封装 termbox 的原生 C binding。
-- 它负责终端初始化、事件读取、Cell 绘制和终端恢复。
local terminal = Terminal.new()

-- Model 只保存应用层状态。
--
-- messages 是一个字符串数组，每个元素代表 TextBox 中的一行：
--
--     {
--         "Program: Ready...",
--         ">>> hello",
--         "Program: You said: hello",
--     }
--
-- 用户消息使用 ">>> " 前缀，程序消息使用 "Program: " 前缀。
local model = {
    messages = {
        "Program: Ready. Type /exit or press Ctrl-C to quit.",
    },
}

-- 将 Model 中的消息状态同步到 TextBox。
--
-- 输入格式：
--     self.messages: string[]，每个元素是一行对话文本。
--
-- 发送给 TextBox 的消息格式：
--     {
--         type = "set_text",
--         text = "line 1\nline 2\n...",
--     }
--
-- 返回值：无。
-- TextBox 的内部文本会被更新，后续 view() 会读取新状态绘制。
function model.refresh_text(self)
    text:update({
        type = "set_text",
        text = table.concat(self.messages, "\n"),
    })
end

-- 返回一个 Runtime Cmd。
--
-- Cmd 是一个函数。Runtime 执行 Cmd 时，会把 runtime 对象作为参数传入。
-- 这个 Cmd 请求 Runtime 停止事件循环并清理终端。
local function quit_command()
    return function(runtime)
        runtime:quit()
    end
end

-- 处理一个输入 Message，并返回 Cmd 列表。
--
-- 输入格式：
--
-- 1. 初始化消息：
--        { type = "init" }
--
-- 2. 可打印字符：
--        { type = "text", text = "a" }
--
-- 3. 控制键：
--        { type = "key", code = "left" }
--        { type = "key", code = "right" }
--        { type = "key", code = "backspace" }
--        { type = "key", code = "enter" }
--        { type = "key", code = "ctrl-c" }
--
-- 4. 窗口尺寸变化：
--        { type = "resize", width = 80, height = 24 }
--
-- 当前 demo 主要消费 init、text、key 三类消息。
-- resize 不需要在这里单独处理，因为 view() 每次都会从 canvas 的尺寸
-- 重新计算布局。
--
-- 返回格式：
--     Cmd[]
--
-- 普通输入没有异步动作时返回：
--     {}
--
-- 请求退出时返回：
--     { quit_command() }
--
-- update() 的职责：
--
-- 1. 判断消息类型。
-- 2. 把输入消息交给 PromptBox。
-- 3. 处理 PromptBox 提交的完整字符串。
-- 4. 修改 self.messages。
-- 5. 将最新状态同步给 TextBox。
-- 6. 返回需要 Runtime 执行的 Cmd 列表。
--
-- update() 不负责直接绘制字符，所有绘制都由 view() 完成。
function model.update(self, msg)
    if msg.type == "init" then
        self:refresh_text()
        return {}
    end

    -- Ctrl-C 是全局退出快捷键，不经过 PromptBox 的文本编辑逻辑。
    if msg.type == "key" and msg.code == "ctrl-c" then
        return { quit_command() }
    end

    if msg.type == "text" or msg.type == "key" then
        -- PromptBox:update() 的返回值约定：
        --
        --     true       已处理，但没有提交完整输入
        --     false      没有处理这个消息
        --     string     用户按 Enter 后提交的完整输入
        --
        -- 这里只对 string 做提交处理，避免把 true 当成字符串使用。
        local submitted = prompt:update(msg)

        if type(submitted) == "string" and submitted ~= "" then
            -- /exit 是 demo 级命令，不作为对话内容展示。
            if submitted == "/exit" then
                return { quit_command() }
            end

            -- 记录用户消息和程序回复。
            -- table.insert 会保留全部历史，TextBox 的 follow_tail 会显示最近部分。
            table.insert(self.messages, ">>> " .. submitted)
            table.insert(self.messages, "Program: You said: " .. submitted)
            self:refresh_text()
        end
    end

    -- 没有异步任务或退出请求时，返回空 Cmd 列表。
    return {}
end

-- 根据当前 terminal 的 Canvas 尺寸绘制界面。
--
-- 输入格式：
--     canvas.width  当前 terminal 的列数。
--     canvas.height 当前 terminal 的行数。
--
-- 布局规则：
--     1. PromptBox 固定在 terminal 最下方，占最多 3 行。
--     2. TextBox 占据 PromptBox 上方的全部空间。
--     3. 两侧正常保留 1 列边距。
--     4. terminal resize 后，下一次 view() 自动重新计算布局。
--
-- view() 不返回值，也不修改 Model 业务状态；它只把当前状态写入 Canvas。
function model.view(self, canvas)
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
end

-- Runtime.new() 接收 Terminal 和 Model。
-- run() 随后启动 luv 事件循环，并反复执行：
--     poll event -> update -> execute Cmd -> view -> present
Runtime.new(terminal, model):run()
