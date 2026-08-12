# termbox.luajit

一个基于 LuaJIT、luv 和 termbox 的小型 TUI 框架首版。

当前包含：

- `TextBox`：只读文字展示，支持边框、基础换行、垂直滚动和自动追踪最新内容。
- `PromptBox`：单行命令输入，支持字符输入、左右移动、Backspace 和 Enter 提交。

## 架构

```text
termbox C event -> Lua binding -> normalized message -> model:update(msg)
                                                              |
                                                       state + commands
                                                              |
                                                   model:view(canvas, rect)
                                                              |
                                                       cell buffer -> binding
```

`luv` 提供异步事件循环。`src/termbox.c` 是原生 Lua binding，直接使用 `vendor/termbox.h` 的 C API；Lua 层不使用 LuaJIT FFI。

## 依赖

- LuaJIT 2.1
- luv
- C compiler
- LuaJIT development headers and library
- macOS/Linux terminal

## 构建和测试

```sh
cd ~/Develop/termbox.luajit
make
make test
```

`make` 会编译 LuaJIT 原生模块：

```text
ltermbox.so
```

模块名为 `ltermbox`：

```lua
local termbox = require("ltermbox")
```

Makefile 默认通过 `pkg-config --cflags --libs luajit` 查找 LuaJIT，也可以手动覆盖：

```sh
make LUAJIT_CFLAGS="-I/opt/homebrew/opt/luajit/include/luajit-2.1" \
     LUAJIT_LIBS="-L/opt/homebrew/opt/luajit/lib -lluajit-5.1"
```

## 运行 demo

```sh
make run
```

目前 demo 支持：

- 可打印 ASCII 字符
- Left / Right
- Backspace
- Enter
- 输入 `/exit` 后按 Enter 退出
- `Ctrl-C` 退出

Demo 将 PromptBox 提交视为用户与程序的对话。用户记录以 `>>> ` 开头，程序回复紧随其后；TextBox 始终优先展示最近记录。PromptBox 固定在 terminal 最下方，TextBox 占据上方全部空间。

## Binding API

```lua
local termbox = require("ltermbox")
termbox.init()
termbox.set_output_mode("truecolor")
termbox.output_mode()
termbox.has_truecolor()
termbox.attr_width()
termbox.width()
termbox.height()
termbox.clear()
termbox.set_cell(x, y, ch, fg_attr, bg_attr, bold)
termbox.set_cursor(x, y)
termbox.hide_cursor()
termbox.poll(timeout_ms)
termbox.present()
termbox.shutdown()
```

Binding 接收的是已经按当前输出模式编码的数值颜色属性。应用和 Widget
应通过 `Canvas` 使用 RGB 颜色，由 `Terminal` 统一完成编码和降级。

## 颜色

框架以 RGB 作为统一颜色模型：

```lua
local Color = require("tui").Color

local style = {
    fg = Color.rgb(32, 32, 32),
    bg = Color.hex("#d3d3d3"),
}

canvas:text(1, 1, "hello", style)
```

也可以使用内置名称，现有字符串写法保持兼容：

```lua
canvas:text(1, 1, "hello", {
    fg = "black",
    bg = "light_gray",
})
```

`Color.default` 表示终端默认颜色。它与纯黑色 `Color.black` 不同。

Terminal 支持以下颜色输出模式：

- `truecolor`：RGB 原样输出。
- `256`：RGB 映射到最接近的 xterm 256 色或灰阶。
- `normal`：RGB 映射到最接近的 ANSI 16 色。
- `auto`：根据环境自动选择，默认值。

可以在创建 Terminal 时显式选择：

```lua
local terminal = Terminal.new({ color_mode = "256" })
```

也可以通过环境变量配置：

```sh
TUI_COLOR_MODE=truecolor make run
```

`auto` 模式按以下顺序判断：显式 `color_mode`、`TUI_COLOR_MODE`、
`NO_COLOR`、`COLORTERM=truecolor/24bit`、`TERM=*256color`，最后回退到
`normal`。终端能力检测并不完全可靠，需要时应显式指定模式。

`termbox.poll()` 返回原生事件表：

```lua
{ type = "key", key = ..., ch = ..., mod = ... }
{ type = "resize", width = ..., height = ... }
```

`lib/tui/terminal.lua` 将其转换成框架消息：

```lua
{ type = "text", text = "a" }
{ type = "key", code = "left" }
{ type = "resize", width = 80, height = 24 }
```

## termbox 来源

项目内使用的 single-header 文件是：

```text
vendor/termbox.h
```

它下载自上游仓库：

<https://github.com/termbox/termbox2>

仓库 URL 中的 `termbox2` 是上游项目的真实名称；本项目内部统一使用 `termbox` 命名。

C binding 通过以下方式包含实现：

```c
#define TB_OPT_ATTR_W 32
#define TB_IMPL
#include "termbox.h"
```

`TB_OPT_ATTR_W=32` 启用 truecolor 和 32 位颜色属性；项目不需要额外安装
termbox 动态库。

## 目录

```text
vendor/termbox.h        termbox single-header
src/termbox.c           LuaJIT C binding
ltermbox.so             编译产物
lib/tui/init.lua        MUV runtime
lib/tui/canvas.lua      cell canvas
lib/tui/color.lua       RGB color model
lib/tui/color_encoder.lua terminal color quantization
lib/tui/widgets.lua     TextBox / PromptBox
lib/tui/terminal.lua    binding adapter
examples/prompt.lua     demo model
tests/colors.lua        color model and quantization tests
tests/smoke.lua         widget smoke test
```

## 编码规范

- 所有项目代码统一使用 4 个空格缩进，不使用 Tab；Makefile recipe 行是 GNU Make 的语法例外，必须使用 Tab。
- 特别简单、语义清晰的语句可以写在一行，例如简单的 `return` 或短函数。
- `if`、`function`、`for`、`while` 等结构默认展开换行，保持代码易读；只有非常简单的单分支逻辑才允许紧凑书写。
- 复杂表达式、函数参数和 table 字段按需要分行，保证每行职责清晰。
- 第三方 `vendor/termbox.h` 保持上游格式，不参与本项目格式化。

## 当前限制

- 当前没有鼠标、剪贴板、复杂布局和 ViewTable。
- PromptBox 采用单行水平滚动：保留完整输入内容，只显示光标附近的可视窗口。
- 输入和绘制暂按 ASCII 字符处理，UTF-8 display width 尚未加入。
