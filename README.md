# termbox.luajit

一个基于 LuaJIT、luv 和 termbox 的小型 TUI 框架首版。

当前包含：

- `TextBox`：只读 UTF-8 文字展示，支持 Unicode 边框、按显示列换行、鼠标滚轮和
  可暂停的自动追尾。
- `PromptBox`：单行 UTF-8 命令输入，支持光标移动、Backspace、Enter 提交以及
  Up/Down 命令历史导航。

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
- luautf8（独立 C 模块，Lua 模块名为 `lua-utf8`）
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

luautf8 不纳入本仓库，也不由 Makefile 编译。使用与 LuaJIT 兼容的 Lua 5.1
LuaRocks 单独编译安装：

```sh
luarocks --lua-version=5.1 install luautf8
luajit -e 'local utf8 = require("lua-utf8"); assert(utf8.len("中文") == 2)'
```

使用自定义或用户级 LuaRocks tree 时，需要确保 `luarocks path --lua-version=5.1`
给出的 `LUA_PATH` 和 `LUA_CPATH` 对运行 demo、测试的 LuaJIT 进程可见。项目代码使用
`require("lua-utf8")`，不能使用 Lua 5.3 标准库的模块名 `require("utf8")`。

## 运行 demo

```sh
make run
```

目前 demo 支持：

- UTF-8 文本和中文等双列字符
- Left / Right 按 codepoint 移动光标
- Backspace 按 codepoint 删除
- Up / Down 浏览已提交的命令历史
- Enter
- 在 TextBox 区域使用鼠标滚轮查看历史记录
- 输入 `/exit` 后按 Enter 退出
- `Ctrl-C` 退出

Demo 将 PromptBox 提交视为用户与程序的对话。用户记录以 `>>> ` 开头，程序回复紧随
其后。TextBox 默认追踪最新记录；用户向上滚动后保持当前阅读位置，滚回底部后恢复
自动追尾。PromptBox 固定在 terminal 最下方，TextBox 占据上方全部空间。

## Binding API

```lua
local termbox = require("ltermbox")
termbox.init()
termbox.set_output_mode("truecolor")
termbox.output_mode()
termbox.has_truecolor()
termbox.attr_width()
termbox.wcwidth(codepoint)
termbox.set_mouse_enabled(true)
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
{ type = "mouse", key = ..., x = ..., y = ..., mod = ... }
```

`lib/tui/terminal.lua` 将其转换成框架消息：

```lua
{ type = "text", text = "中" }
{ type = "key", code = "up|down|left|right" }
{ type = "mouse", action = "wheel_up|wheel_down", x = 4, y = 2 }
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
lib/tui/text.lua        UTF-8 operations and terminal display width
lib/tui/widgets.lua     TextBox / PromptBox
lib/tui/terminal.lua    binding adapter
examples/prompt.lua     demo model
tests/colors.lua        color model and quantization tests
tests/text.lua          UTF-8, event and canvas tests
tests/smoke.lua         widget smoke test
```

## UTF-8、历史和滚动设计

以下三项能力已经按本节设计实现。保留这些约定用于说明模块职责和后续扩展边界。

### 1. UTF-8 文本与 Unicode 边框

目标是让框架正确处理 UTF-8 文本、中文等双列字符以及 Unicode
box-drawing 字符，同时保持现有 ASCII 行为兼容。第一阶段不承诺完整支持由多个
codepoint 组成的 grapheme cluster，例如组合音标、ZWJ emoji 和部分变体选择符。

UTF-8 字符串处理采用 [starwing/luautf8](https://github.com/starwing/luautf8)。
该库作为外部运行时依赖，由用户通过 LuaRocks 单独编译安装；项目不复制其源码，
不生成第二份 `lua-utf8.so`，Makefile 在运行 demo 和测试前检查模块是否能够加载。

实现时必须区分三种坐标，避免继续用 Lua 字符串字节下标表示终端位置：

- 字节位置：只用于 UTF-8 字符串的存储和编解码。
- codepoint 位置：用于 PromptBox 的左右移动和 Backspace。
- 显示列位置：由字符宽度决定，用于 Canvas 绘制、裁剪、滚动和光标定位。

实现方式如下：

- 使用 `require("lua-utf8")` 加载 luautf8，由它负责 UTF-8 校验、codepoint
  遍历、字符计数、按字符截取、字节位置转换以及 codepoint 与 UTF-8 字符串互转。
  项目不自行实现另一套 UTF-8 解码器。
- 增加轻量的文本适配层，集中封装项目需要的遍历、截取和显示宽度操作。Canvas 与
  Widget 依赖该适配层，而不在各模块中分别组合 luautf8 API；适配层只统一语义，
  不复制 luautf8 的编解码实现。
- C binding 的 `set_cell` 从读取首字节改为解码一个完整 UTF-8 codepoint；同时
  暴露基于 `tb_wcwidth()` 的字符宽度查询。非法或包含多个字符的 cell 输入应给出
  明确错误，而不是静默截断。
- luautf8 的 `width()` 不作为 Canvas 的最终显示宽度依据。文本适配层遍历
  codepoint 后调用 binding 暴露的 `tb_wcwidth()`，确保布局、裁剪、光标位置与
  termbox 实际写入终端时采用同一套列宽规则。
- `Terminal:poll()` 将 termbox 事件中的 Unicode codepoint 转换为
  `{ type = "text", text = "..." }`，ASCII 和 UTF-8 输入走同一条消息路径。
- `Canvas:text()` 按 codepoint 和显示宽度绘制。宽度为 2 的字符占用两个 cell，
  第二个 cell 使用内部 continuation 标记，提交帧时不被当作独立字符绘制；字符在
  画布右边界放不下时整体裁剪。
- PromptBox 的光标、删除、水平滚动和可见窗口统一改为按 codepoint 与显示列计算，
  不允许光标停在 UTF-8 字节序列或双列字符中间。
- `Canvas:box()` 增加可配置的边框字符集，默认采用 `┌─┐│└┘`，并保留
  `+ - |` ASCII 样式作为显式兼容选项。边框仍由 Canvas primitive 绘制，不在
  Widget 中拼接字符串，也不直接输出 ANSI 转义序列。

验收标准：ASCII 行为不回退；中文可以输入、显示、移动光标、删除和水平滚动；
Unicode 边框连续显示；宽字符在画布边缘不会产生残留 cell；非法 UTF-8 不会导致
越界访问或进程崩溃。相关行为需要覆盖文本适配层、Canvas、PromptBox 和 binding
边界测试，并在 macOS 与 Linux/WSL 终端各完成一次手工验证。测试还需要明确检查
缺少或无法加载 `lua-utf8` 时的错误信息，不能在运行中静默退回按字节处理。

### 2. TextBox 鼠标滚轮查看历史记录

termbox 提供 `TB_INPUT_MOUSE`、`TB_EVENT_MOUSE`、滚轮按键以及鼠标坐标，实现沿用
现有事件分层：

```text
termbox mouse event
    -> binding { type = "mouse", key = ..., x = ..., y = ... }
    -> Terminal { type = "mouse", action = "wheel_up|wheel_down", x, y }
    -> model gives mouse events to TextBox first
    -> TextBox updates its scroll position
```

具体设计如下：

- binding 增加输入模式配置及鼠标相关常量，并在鼠标事件中返回 `key`、`x`、`y`。
  `Terminal.new({ mouse = true })` 显式开启鼠标报告，避免不使用鼠标的应用改变终端
  输入行为；demo 已开启该选项。组合使用 TextBox 和 PromptBox 时必须开启鼠标报告，
  否则部分终端会把滚轮模拟成普通 Up/Down，应用无法将其与真实方向键区分。
- Terminal 将滚轮事件归一化为稳定的框架消息，坐标继续使用当前 Canvas 的 0-based
  坐标。组合使用 TextBox 和 PromptBox 时，应用 model 优先把所有滚轮消息交给
  TextBox 并结束该消息的分发；PromptBox 只接收 `text` 和 `key` 消息，不接收滚轮。
- TextBox 继续使用首个可见行作为滚动状态，并根据内容行数和 viewport 高度把位置
  限制在 `0..max_scroll`。每个滚轮刻度默认滚动 3 行，后续可通过构造参数调整。
- `follow_tail` 拆分为“允许自动追尾”的配置和“当前是否位于末尾”的运行状态。
  用户向上滚动后暂停追尾，新内容到达时保持阅读位置；用户滚动回最底部后自动恢复
  追尾。这样重新渲染不会立即把用户拉回最新记录。
- demo 将滚轮统一用于 TextBox 历史视图，不受鼠标当前位于 TextBox 或 PromptBox
  区域的影响。布局尺寸变化后重新计算并限制滚动位置。

验收标准：滚轮向上和向下方向正确；不能滚过开头或末尾；查看旧记录时追加内容不会
跳回末尾；滚回底部后新内容继续自动追尾；鼠标未启用时现有键盘操作不受影响。

### 3. PromptBox 上下键浏览命令历史

PromptBox 使用以下独立状态管理历史浏览：

- `history`：已提交的非空命令，保持现有提交顺序。
- `history_index`：当前浏览位置；`nil` 表示正在编辑尚未提交的输入。
- `history_draft`：第一次按 Up 前保存的当前输入，用于从最新历史继续按 Down 时恢复。

交互规则与 Bash/readline 的常用行为保持一致：

- 第一次按 Up 保存当前草稿并选择最近一条命令；继续按 Up 向更早的记录移动，到第一
  条后保持不变。
- 按 Down 向更新的记录移动；越过最新记录后退出历史浏览并恢复之前保存的草稿。
- 选中历史项后，输入内容和光标立即更新，光标位于行尾，水平滚动重新计算。
- 历史记录本身不可变。对调出的命令进行字符插入或 Backspace 时，将其复制为当前
  草稿并退出历史浏览，不会原地修改已保存记录；左右移动只改变光标，不退出浏览。
- Enter 提交当前显示内容，按现有规则加入历史，然后清空输入、浏览位置和草稿。
  空历史、单条历史以及空草稿均应安全处理。

binding 和 Terminal 提供 Up/Down 键映射，向 Widget 发送
`{ type = "key", code = "up" }` 和 `{ type = "key", code = "down" }`。

验收标准：可以从最新记录向前和向后浏览；边界按键不会越界；从历史末尾按 Down
能够恢复原草稿；编辑调出的命令不会修改历史；提交后下一次 Up 可以取到刚提交的
命令。ASCII 与 UTF-8 命令使用同一套历史状态机。

### 实施顺序

实现按 UTF-8 基础能力、PromptBox 历史导航、TextBox 鼠标滚动的顺序完成，避免后两项
继续建立在字节下标语义上。相关自动化测试统一通过 `make test` 执行。

## 编码规范

- 所有项目代码统一使用 4 个空格缩进，不使用 Tab；Makefile recipe 行是 GNU Make 的语法例外，必须使用 Tab。
- 特别简单、语义清晰的语句可以写在一行，例如简单的 `return` 或短函数。
- `if`、`function`、`for`、`while` 等结构默认展开换行，保持代码易读；只有非常简单的单分支逻辑才允许紧凑书写。
- 复杂表达式、函数参数和 table 字段按需要分行，保证每行职责清晰。
- 第三方 `vendor/termbox.h` 保持上游格式，不参与本项目格式化。

## 当前限制

- 当前没有剪贴板、复杂布局和 ViewTable；鼠标只处理 TextBox 滚轮事件。
- PromptBox 采用单行水平滚动：保留完整输入内容，只显示光标附近的可视窗口。
- UTF-8 编辑以 codepoint 为单位，尚未支持完整 grapheme cluster；组合音标、ZWJ
  emoji 和部分变体选择符可能无法作为一个整体移动、删除或计算宽度。
