# termbox.luajit

一个基于 LuaJIT、luv 和 termbox2 的小型 TUI 框架首版。

当前包含：

- `TextBox`：只读文字展示，支持边框、基础换行和垂直滚动消息。
- `PromptBox`：单行命令输入，支持字符输入、左右移动、Backspace、Enter 提交。`update()` 在 Enter 时返回提交字符串，其他已处理事件返回 `true`。

## 架构

```text
termbox2 C event -> Lua binding -> normalized message -> model:update(msg)
                                                               |
                                                        state + commands
                                                               |
                                                    model:view(canvas, rect)
                                                               |
                                                        cell buffer -> binding
```

`luv` 提供异步事件循环。`src/termbox_lua.c` 是原生 Lua binding，直接使用 `vendor/termbox2.h` 的 C API；Lua 层不使用 LuaJIT FFI。

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

`make` 会编译：

```text
termbox.so
```

这是 LuaJIT 可加载的原生模块，模块名为 `termbox`。Makefile 默认通过 `pkg-config --cflags --libs luajit` 找 LuaJIT 编译参数，也可以手动覆盖 `LUAJIT_CFLAGS` 和 `LUAJIT_LIBS`。

例如：

```sh
make LUAJIT_CFLAGS="-I/opt/homebrew/opt/luajit/include/luajit-2.1" \
     LUAJIT_LIBS="-L/opt/homebrew/opt/luajit/lib -lluajit-5.1"
```

## 运行 demo

```sh
make run
```

目前 demo 使用的终端事件包括：

- 可打印 ASCII 字符
- Left / Right
- Backspace
- Enter
- 输入 `/exit` 后按 Enter 退出
- `Ctrl-C` 退出

## Binding API

Lua 原生模块目前暴露：

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

`termbox.poll()` 返回标准化前的事件表，例如：

```lua
{ type = "key", key = ..., ch = ..., mod = ... }
{ type = "resize", width = ..., height = ... }
```

`lib/tui/terminal.lua` 再把它转换成框架消息：

```lua
{ type = "text", text = "a" }
{ type = "key", code = "left" }
{ type = "resize", width = 80, height = 24 }
```

## termbox2 来源

`vendor/termbox2.h` 从以下官方仓库下载：

<https://github.com/termbox/termbox2>

它是 single-header library。`src/termbox_lua.c` 使用：

```c
#define TB_IMPL
#include "termbox2.h"
```

因此不需要额外安装 termbox2 动态库。

## 目录

```text
vendor/termbox2.h       官方 termbox2 single-header
src/termbox_lua.c       LuaJIT C binding
termbox.so              编译产物
lib/tui/init.lua        MUV runtime
lib/tui/canvas.lua      cell canvas
lib/tui/widgets.lua     TextBox / PromptBox
lib/tui/terminal.lua    binding adapter
examples/prompt.lua     demo model
tests/smoke.lua          no-terminal smoke test
```

## 当前限制

- 输入和绘制暂按 ASCII 字符处理，UTF-8 display width 尚未加入。
- 当前没有鼠标、剪贴板、复杂布局和 ViewTable。
- demo 使用纵向自适应布局：PromptBox 固定在 terminal 最下方，TextBox 占据其上方的全部空间；两者宽度跟随 terminal，正常尺寸下左右各保留 1 列边距。
- demo 将 PromptBox 提交视为用户与程序的对话：用户记录以 `>>> ` 开头，程序回复紧随其后；TextBox 的 `follow_tail` 模式始终优先展示最近记录。
- 原生 binding 的颜色目前只映射基础颜色名，Canvas 样式扩展留待后续版本。
