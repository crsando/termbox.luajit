package.path = "./lib/?.lua;./lib/?/init.lua;" .. package.path

local calls = {
    shutdown = 0,
}
local native = {
    ATTR_BRIGHT = 0x01000000,
    ATTR_HI_BLACK = 0x20000000,
    KEY_ARROW_UP = 101,
    KEY_ARROW_DOWN = 102,
    KEY_ARROW_LEFT = 103,
    KEY_ARROW_RIGHT = 104,
    KEY_BACKSPACE = 105,
    KEY_BACKSPACE2 = 106,
    KEY_ENTER = 107,
    KEY_MOUSE_WHEEL_UP = 108,
    KEY_MOUSE_WHEEL_DOWN = 109,
    KEY_HOME = 110,
    KEY_END = 111,
    KEY_DELETE = 112,
    KEY_TAB = 9,
    KEY_ESC = 27,
    KEY_CTRL_A = 1,
    KEY_CTRL_E = 5,
    KEY_CTRL_K = 11,
    KEY_CTRL_U = 21,
    KEY_CTRL_W = 23,
    MOD_ALT = 1,
    MOD_CTRL = 2,
    MOD_SHIFT = 4,
    poll_queue = {},
    init_result = -4,
    output_result = 0,
    present_result = 0,
}

function native.error_string(code)
    return ({
        [-4] = "open failed",
        [-10] = "write failed",
    })[code] or "test error"
end

function native.has_truecolor()
    return true
end

function native.init()
    return native.init_result
end

function native.set_output_mode()
    return native.output_result
end

function native.set_mouse_enabled()
    return 0
end

function native.shutdown()
    calls.shutdown = calls.shutdown + 1
    return 0
end

function native.width()
    return 2
end

function native.height()
    return 1
end

function native.clear()
    return 0
end

function native.set_cell(...)
    calls.cell = { ... }
    return 0
end

function native.set_cursor()
    return 0
end

function native.hide_cursor()
    return 0
end

function native.present()
    return native.present_result
end

function native.poll()
    return table.remove(native.poll_queue, 1)
end

function native.wcwidth()
    return 1
end

package.loaded.ltermbox = native

local Canvas = require("tui.canvas")
local Terminal = require("tui.terminal")

local init_ok, init_error = pcall(Terminal.new)
assert(not init_ok)
assert(tostring(init_error):find("init failed (-4): open failed", 1, true))
assert(calls.shutdown == 0)

native.init_result = 0
native.output_result = -10
local output_ok, output_error = pcall(Terminal.new)
assert(not output_ok)
assert(tostring(output_error):find("set output mode", 1, true))
assert(calls.shutdown == 1)

native.output_result = 0
local terminal = Terminal.new({ env = { TERM = "xterm" } })
local canvas = Canvas.new(1, 1)
canvas:set(0, 0, "x", { bold = true, italic = true })
terminal:present(canvas)

assert(calls.cell[1] == 0)
assert(calls.cell[2] == 0)
assert(calls.cell[3] == "x")
assert(calls.cell[6] == true)
assert(calls.cell[7] == true)

native.present_result = -10
local present_ok, present_error = pcall(function()
    terminal:present(canvas)
end)
assert(not present_ok)
assert(tostring(present_error):find("present failed (-10): write failed", 1, true))

-- Ignored events must not end the drain early.
native.poll_queue = {
    { type = "mouse", key = 0, x = 0, y = 0, mod = 0 },
    { type = "key", key = 0, ch = 0x61, mod = 0 },
}
local after_ignored = terminal:poll(0)
assert(after_ignored.type == "text" and after_ignored.text == "a")
assert(terminal:poll(0) == nil)

-- ESC immediately followed by a character is Alt+character.
native.poll_queue = {
    { type = "key", key = 27, ch = 0, mod = 0 },
    { type = "key", key = 0, ch = 0x62, mod = 0 },
}
local alt_b = terminal:poll(0)
assert(alt_b.type == "key" and alt_b.code == "alt-b" and alt_b.alt)
assert(terminal:poll(0) == nil)

-- A lone ESC stays escape; whatever followed it is delivered afterwards.
native.poll_queue = {
    { type = "key", key = 27, ch = 0, mod = 0 },
}
assert(terminal:poll(0).code == "escape")
native.poll_queue = {
    { type = "key", key = 27, ch = 0, mod = 0 },
    { type = "key", key = 101, ch = 0, mod = 0 },
}
assert(terminal:poll(0).code == "escape")
assert(terminal:poll(0).code == "up")
assert(terminal:poll(0) == nil)

-- Reported TB_MOD_ALT (TB_INPUT_ALT mode) and the new editing keys.
assert(Terminal.normalize_event({ type = "key", key = 0, ch = 0x78, mod = 1 }).code == "alt-x")
assert(Terminal.normalize_event({ type = "key", key = 110, ch = 0, mod = 0 }).code == "home")
assert(Terminal.normalize_event({ type = "key", key = 111, ch = 0, mod = 0 }).code == "end")
assert(Terminal.normalize_event({ type = "key", key = 112, ch = 0, mod = 0 }).code == "delete")
assert(Terminal.normalize_event({ type = "key", key = 21, ch = 0, mod = 2 }).code == "ctrl-u")
assert(Terminal.normalize_event({ type = "key", key = 23, ch = 0, mod = 2 }).code == "ctrl-w")

terminal:close()
terminal:close()
assert(calls.shutdown == 2)

print("terminal: ok")
