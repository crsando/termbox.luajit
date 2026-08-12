#define TB_OPT_ATTR_W 32
#define TB_IMPL
#include "termbox.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>

static int l_init(lua_State *L) { lua_pushinteger(L, tb_init()); return 1; }
static int l_shutdown(lua_State *L) { (void)L; lua_pushinteger(L, tb_shutdown()); return 1; }
static int l_width(lua_State *L) { (void)L; lua_pushinteger(L, tb_width()); return 1; }
static int l_height(lua_State *L) { (void)L; lua_pushinteger(L, tb_height()); return 1; }
static int l_clear(lua_State *L) { (void)L; lua_pushinteger(L, tb_clear()); return 1; }
static int l_present(lua_State *L) { (void)L; lua_pushinteger(L, tb_present()); return 1; }
static int l_set_cursor(lua_State *L) { tb_set_cursor((int)luaL_checkinteger(L, 1), (int)luaL_checkinteger(L, 2)); return 0; }
static int l_hide_cursor(lua_State *L) { (void)L; tb_set_cursor(-1, -1); return 0; }

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

static int l_set_cell(lua_State *L) {
    int x = (int)luaL_checkinteger(L, 1), y = (int)luaL_checkinteger(L, 2);
    size_t n; const char *s = luaL_checklstring(L, 3, &n);
    uintattr_t fg = check_attr(L, 4), bg = check_attr(L, 5);
    uint32_t ch = n ? (unsigned char)s[0] : ' ';
    uintattr_t attrs = lua_toboolean(L, 6) ? TB_BOLD : 0;
    tb_set_cell(x, y, ch, fg | attrs, bg);
    return 0;
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
    if (rv < 0) { lua_pushnil(L); return 1; }
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
    } else {
        lua_pushliteral(L, "other"); lua_setfield(L, -2, "type");
    }
    return 1;
}

static const luaL_Reg funcs[] = {
    {"init", l_init}, {"shutdown", l_shutdown}, {"width", l_width}, {"height", l_height},
    {"clear", l_clear}, {"present", l_present}, {"set_cursor", l_set_cursor}, {"hide_cursor", l_hide_cursor},
    {"set_cell", l_set_cell}, {"set_output_mode", l_set_output_mode}, {"output_mode", l_output_mode},
    {"has_truecolor", l_has_truecolor}, {"attr_width", l_attr_width}, {"poll", l_poll}, {NULL, NULL}
};

int luaopen_ltermbox(lua_State *L) {
#if LUA_VERSION_NUM >= 502
    luaL_newlib(L, funcs);
#else
    luaL_register(L, "ltermbox", funcs);
#endif
    lua_pushinteger(L, TB_EVENT_KEY); lua_setfield(L, -2, "EVENT_KEY");
    lua_pushinteger(L, TB_EVENT_RESIZE); lua_setfield(L, -2, "EVENT_RESIZE");
    lua_pushinteger(L, TB_KEY_ARROW_LEFT); lua_setfield(L, -2, "KEY_ARROW_LEFT");
    lua_pushinteger(L, TB_KEY_ARROW_RIGHT); lua_setfield(L, -2, "KEY_ARROW_RIGHT");
    lua_pushinteger(L, TB_KEY_BACKSPACE); lua_setfield(L, -2, "KEY_BACKSPACE");
    lua_pushinteger(L, TB_KEY_BACKSPACE2); lua_setfield(L, -2, "KEY_BACKSPACE2");
    lua_pushinteger(L, TB_KEY_ENTER); lua_setfield(L, -2, "KEY_ENTER");
    lua_pushnumber(L, (lua_Number)TB_BRIGHT); lua_setfield(L, -2, "ATTR_BRIGHT");
    lua_pushnumber(L, (lua_Number)TB_HI_BLACK); lua_setfield(L, -2, "ATTR_HI_BLACK");
    return 1;
}
