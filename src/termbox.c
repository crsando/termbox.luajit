#define TB_OPT_ATTR_W 32
#define TB_IMPL
#include "termbox.h"
#include <lua.h>
#include <lauxlib.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>

static int l_init(lua_State *L) { lua_pushinteger(L, tb_init()); return 1; }
static int l_shutdown(lua_State *L) { (void)L; lua_pushinteger(L, tb_shutdown()); return 1; }
static int l_width(lua_State *L) { (void)L; lua_pushinteger(L, tb_width()); return 1; }
static int l_height(lua_State *L) { (void)L; lua_pushinteger(L, tb_height()); return 1; }
static int l_clear(lua_State *L) { (void)L; lua_pushinteger(L, tb_clear()); return 1; }
static int l_present(lua_State *L) { (void)L; lua_pushinteger(L, tb_present()); return 1; }
static int l_set_cursor(lua_State *L) {
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);

    lua_pushinteger(L, tb_set_cursor(x, y));
    return 1;
}

static int l_hide_cursor(lua_State *L) {
    (void)L;
    lua_pushinteger(L, tb_hide_cursor());
    return 1;
}

static uintattr_t check_attr(lua_State *L, int index) {
    lua_Number value = luaL_checknumber(L, index);

    if (value != value
        || value < 0
        || value > (lua_Number)UINT32_MAX
        || value != (lua_Number)(uint32_t)value)
    {
        luaL_argerror(L, index, "attribute must be a 32-bit unsigned integer");
    }

    return (uintattr_t)value;
}

static int decode_utf8_codepoint(const char *s, size_t n, uint32_t *ch) {
    unsigned char lead;
    size_t length;
    size_t i;

    if (n == 0) {
        return 0;
    }

    lead = (unsigned char)s[0];

    if (lead < 0x80) {
        length = 1;
    } else if (lead >= 0xc2 && lead <= 0xdf) {
        length = 2;
    } else if (lead >= 0xe0 && lead <= 0xef) {
        length = 3;
    } else if (lead >= 0xf0 && lead <= 0xf4) {
        length = 4;
    } else {
        return 0;
    }

    if (n != length) {
        return 0;
    }

    for (i = 1; i < length; ++i) {
        unsigned char byte = (unsigned char)s[i];

        if ((byte & 0xc0) != 0x80) {
            return 0;
        }
    }

    if ((length == 3 && lead == 0xe0 && (unsigned char)s[1] < 0xa0)
        || (length == 3 && lead == 0xed && (unsigned char)s[1] >= 0xa0)
        || (length == 4 && lead == 0xf0 && (unsigned char)s[1] < 0x90)
        || (length == 4 && lead == 0xf4 && (unsigned char)s[1] >= 0x90))
    {
        return 0;
    }

    return tb_utf8_char_to_unicode(ch, s) == (int)length;
}

static int l_set_cell(lua_State *L) {
    int x = (int)luaL_checkinteger(L, 1), y = (int)luaL_checkinteger(L, 2);
    size_t n; const char *s = luaL_checklstring(L, 3, &n);
    uintattr_t fg = check_attr(L, 4), bg = check_attr(L, 5);
    uint32_t ch;
    uintattr_t attrs = 0;

    if (lua_toboolean(L, 6)) {
        attrs |= TB_BOLD;
    }

    if (lua_toboolean(L, 7)) {
        attrs |= TB_ITALIC;
    }

    if (!decode_utf8_codepoint(s, n, &ch)) {
        return luaL_argerror(L, 3, "cell must contain exactly one valid UTF-8 codepoint");
    }

    lua_pushinteger(L, tb_set_cell(x, y, ch, fg | attrs, bg));
    return 1;
}

static int l_error_string(lua_State *L) {
    int code = (int)luaL_checkinteger(L, 1);

    lua_pushstring(L, tb_strerror(code));
    return 1;
}

static int l_wcwidth(lua_State *L) {
    lua_Number value = luaL_checknumber(L, 1);
    uint32_t ch;

    if (value != value
        || value < 0
        || value > 0x10ffff
        || value != (lua_Number)(uint32_t)value
        || (value >= 0xd800 && value <= 0xdfff))
    {
        return luaL_argerror(L, 1, "codepoint must be a valid Unicode scalar value");
    }

    ch = (uint32_t)value;
    lua_pushinteger(L, tb_wcwidth(ch));
    return 1;
}

static int l_set_mouse_enabled(lua_State *L) {
    int mode = tb_set_input_mode(TB_INPUT_CURRENT);

    if (mode < 0) {
        lua_pushinteger(L, mode);
        return 1;
    }

    if (lua_toboolean(L, 1)) {
        mode |= TB_INPUT_MOUSE;
    } else {
        mode &= ~TB_INPUT_MOUSE;
    }

    lua_pushinteger(L, tb_set_input_mode(mode));
    return 1;
}

static int output_mode(const char *name) {
    if (strcmp(name, "normal") == 0) return TB_OUTPUT_NORMAL;
    if (strcmp(name, "256") == 0) return TB_OUTPUT_256;
    if (strcmp(name, "truecolor") == 0) return TB_OUTPUT_TRUECOLOR;
    return -1;
}

static const char *output_mode_name(int mode) {
    if (mode == TB_OUTPUT_NORMAL) return "normal";
    if (mode == TB_OUTPUT_256) return "256";
    if (mode == TB_OUTPUT_TRUECOLOR) return "truecolor";
    return NULL;
}

static int l_set_output_mode(lua_State *L) {
    const char *name = luaL_checkstring(L, 1);
    int mode = output_mode(name);

    if (mode < 0) {
        return luaL_argerror(L, 1, "mode must be normal, 256, or truecolor");
    }

    lua_pushinteger(L, tb_set_output_mode(mode));
    return 1;
}

static int l_output_mode(lua_State *L) {
    const char *name = output_mode_name(tb_set_output_mode(TB_OUTPUT_CURRENT));

    if (!name) {
        lua_pushnil(L);
    } else {
        lua_pushstring(L, name);
    }

    return 1;
}

static int l_has_truecolor(lua_State *L) {
    (void)L;
    lua_pushboolean(L, tb_has_truecolor());
    return 1;
}

static int l_attr_width(lua_State *L) {
    (void)L;
    lua_pushinteger(L, tb_attr_width());
    return 1;
}

static int l_poll(lua_State *L) {
    struct tb_event event;
    int rv = tb_peek_event(&event, (int)luaL_optinteger(L, 1, 0));

    if (rv == TB_ERR_NO_EVENT
        || rv == TB_ERR_NEED_MORE
        || (rv == TB_ERR_POLL && tb_last_errno() == EINTR))
    {
        lua_pushnil(L);
        return 1;
    }

    if (rv < 0) {
        return luaL_error(
            L,
            "termbox poll failed (%d): %s",
            rv,
            tb_strerror(rv)
        );
    }

    lua_newtable(L);
    if (event.type == TB_EVENT_RESIZE) {
        lua_pushliteral(L, "resize"); lua_setfield(L, -2, "type");
        lua_pushinteger(L, event.w); lua_setfield(L, -2, "width");
        lua_pushinteger(L, event.h); lua_setfield(L, -2, "height");
    } else if (event.type == TB_EVENT_KEY) {
        lua_pushliteral(L, "key"); lua_setfield(L, -2, "type");
        lua_pushinteger(L, event.key); lua_setfield(L, -2, "key");
        lua_pushinteger(L, event.ch); lua_setfield(L, -2, "ch");
        lua_pushinteger(L, event.mod); lua_setfield(L, -2, "mod");
    } else if (event.type == TB_EVENT_MOUSE) {
        lua_pushliteral(L, "mouse"); lua_setfield(L, -2, "type");
        lua_pushinteger(L, event.key); lua_setfield(L, -2, "key");
        lua_pushinteger(L, event.x); lua_setfield(L, -2, "x");
        lua_pushinteger(L, event.y); lua_setfield(L, -2, "y");
        lua_pushinteger(L, event.mod); lua_setfield(L, -2, "mod");
    } else {
        lua_pushliteral(L, "other"); lua_setfield(L, -2, "type");
    }
    return 1;
}

static const luaL_Reg funcs[] = {
    {"init", l_init}, {"shutdown", l_shutdown}, {"width", l_width}, {"height", l_height},
    {"clear", l_clear}, {"present", l_present}, {"set_cursor", l_set_cursor}, {"hide_cursor", l_hide_cursor},
    {"set_cell", l_set_cell}, {"set_output_mode", l_set_output_mode}, {"output_mode", l_output_mode},
    {"has_truecolor", l_has_truecolor}, {"attr_width", l_attr_width}, {"wcwidth", l_wcwidth},
    {"error_string", l_error_string},
    {"set_mouse_enabled", l_set_mouse_enabled}, {"poll", l_poll}, {NULL, NULL}
};

int luaopen_ltermbox(lua_State *L) {
#if LUA_VERSION_NUM >= 502
    luaL_newlib(L, funcs);
#else
    luaL_register(L, "ltermbox", funcs);
#endif
    lua_pushinteger(L, TB_EVENT_KEY); lua_setfield(L, -2, "EVENT_KEY");
    lua_pushinteger(L, TB_EVENT_RESIZE); lua_setfield(L, -2, "EVENT_RESIZE");
    lua_pushinteger(L, TB_EVENT_MOUSE); lua_setfield(L, -2, "EVENT_MOUSE");
    lua_pushinteger(L, TB_KEY_ARROW_UP); lua_setfield(L, -2, "KEY_ARROW_UP");
    lua_pushinteger(L, TB_KEY_ARROW_DOWN); lua_setfield(L, -2, "KEY_ARROW_DOWN");
    lua_pushinteger(L, TB_KEY_ARROW_LEFT); lua_setfield(L, -2, "KEY_ARROW_LEFT");
    lua_pushinteger(L, TB_KEY_ARROW_RIGHT); lua_setfield(L, -2, "KEY_ARROW_RIGHT");
    lua_pushinteger(L, TB_KEY_BACKSPACE); lua_setfield(L, -2, "KEY_BACKSPACE");
    lua_pushinteger(L, TB_KEY_BACKSPACE2); lua_setfield(L, -2, "KEY_BACKSPACE2");
    lua_pushinteger(L, TB_KEY_ENTER); lua_setfield(L, -2, "KEY_ENTER");
    lua_pushinteger(L, TB_KEY_MOUSE_WHEEL_UP); lua_setfield(L, -2, "KEY_MOUSE_WHEEL_UP");
    lua_pushinteger(L, TB_KEY_MOUSE_WHEEL_DOWN); lua_setfield(L, -2, "KEY_MOUSE_WHEEL_DOWN");
    lua_pushnumber(L, (lua_Number)TB_BRIGHT); lua_setfield(L, -2, "ATTR_BRIGHT");
    lua_pushnumber(L, (lua_Number)TB_HI_BLACK); lua_setfield(L, -2, "ATTR_HI_BLACK");
    return 1;
}
