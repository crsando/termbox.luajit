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
termbox.so
```

模块名为 `termbox`：

```lua
local termbox = require("termbox")
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
local termbox = require("termbox")
termbox.init()
termbox.width()
termbox.height()
termbox.clear()
termbox.set_cell(x, y, ch, fg, bg, bold)
termbox.set_cursor(x, y)
termbox.hide_cursor()
termbox.poll(timeout_ms)
termbox.present()
termbox.shutdown()
```

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
#define TB_IMPL
#include "termbox.h"
```

因此不需要额外安装 termbox 动态库。

## 目录

```text
vendor/termbox.h        termbox single-header
src/termbox.c           LuaJIT C binding
termbox.so              编译产物
lib/tui/init.lua        MUV runtime
lib/tui/canvas.lua      cell canvas
lib/tui/widgets.lua     TextBox / PromptBox
lib/tui/terminal.lua    binding adapter
examples/prompt.lua     demo model
tests/smoke.lua         no-terminal smoke test
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
- 原生 binding 的颜色目前只映射基础颜色名。
